#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MEMO 共享基础模块
=================
service.py / sync.py / mcp_server.py 共用的基础能力，集中一处避免规则漂移：
- 标签解析（#标签、#父/子 多级）
- 时间工具（now_ms / normalize_ts）
- 运行路径（is_frozen / resolve_data_dir）
- 数据库（连接 / 建表迁移 / 写入 / Row→dict / 统计）
"""
import os
import re
import sqlite3
import sys
import time
import uuid as uuid_mod
from contextlib import contextmanager
from datetime import datetime, timedelta
from pathlib import Path

# ---------------------------------------------------------------------------
# 标签解析（flomo 风格：#标签、#父/子 多级）
# ---------------------------------------------------------------------------
TAG_RE = re.compile(r"#([^\s#，。！？!?,;；:：\u201c\u201d\u2018\u2019（）()【】\[\]<>《》]+)")
_TAG_STRIP = re.compile(r"^[^\w\u4e00-\u9fff]+|[^\w\u4e00-\u9fff]+$")


def parse_tags(content):
    tags = set()
    for m in TAG_RE.finditer(content or ""):
        raw = _TAG_STRIP.sub("", m.group(1))
        parts = [p for p in raw.split("/") if p]
        if not parts:
            continue
        path = []
        for p in parts:                 # 父/子 → 存 '父' 与 '父/子'
            path.append(p)
            tags.add("/".join(path))
    return tags


def rebuild_tag_counts(conn):
    conn.execute("DELETE FROM tags")
    conn.execute(
        "INSERT INTO tags(name, count) SELECT name, COUNT(*) FROM memo_tags GROUP BY name")


def set_memo_tags(conn, memo_id, tags):
    conn.execute("DELETE FROM memo_tags WHERE memo_id=?", (memo_id,))
    for t in sorted(tags):
        conn.execute("INSERT OR IGNORE INTO memo_tags(memo_id, name) VALUES(?,?)", (memo_id, t))
    rebuild_tag_counts(conn)


# ---------------------------------------------------------------------------
# 时间工具
# ---------------------------------------------------------------------------
def now_ms():
    return int(time.time() * 1000)


def normalize_ts(v):
    """兼容毫秒时间戳 / ISO 字符串 / 'YYYY-MM-DD HH:MM'"""
    if isinstance(v, (int, float)):
        return int(v)
    s = str(v).strip()
    try:
        return int(s)
    except ValueError:
        pass
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S",
                "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return int(datetime.strptime(s, fmt).timestamp() * 1000)
        except ValueError:
            continue
    return now_ms()


def new_uuid():
    return uuid_mod.uuid4().hex


# ---------------------------------------------------------------------------
# 运行路径
# ---------------------------------------------------------------------------
def is_frozen():
    """PyInstaller 打包运行时为 True"""
    return bool(getattr(sys, "_MEIPASS", None))


def resolve_data_dir(source_dir):
    """解析数据目录：
    - 优先 MEMO_DATA_DIR 环境变量（桌面版 Electron / 测试 / 多实例）
    - 打包运行回退 %APPDATA%\\memo\\data（Windows 惯例，与桌面版一致）
    - 源码运行回退 source_dir（项目目录，网页版模式）
    """
    env = os.environ.get("MEMO_DATA_DIR")
    if env:
        return Path(env)
    if is_frozen():
        appdata = os.environ.get("APPDATA")
        if appdata:
            return Path(appdata) / "memo" / "data"
        return Path.home() / ".memo" / "data"
    return Path(source_dir)


# ---------------------------------------------------------------------------
# 数据库
# ---------------------------------------------------------------------------
_SCHEMA = (
    """CREATE TABLE IF NOT EXISTS memos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        pinned INTEGER DEFAULT 0)""",
    """CREATE TABLE IF NOT EXISTS memo_tags(
        memo_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY(memo_id, name))""",
    """CREATE TABLE IF NOT EXISTS tags(
        name TEXT PRIMARY KEY,
        count INTEGER DEFAULT 0)""",
    "CREATE INDEX IF NOT EXISTS idx_memos_created ON memos(created_at DESC)",
    "CREATE INDEX IF NOT EXISTS idx_memo_tags_name ON memo_tags(name)",
)


def connect(db_path):
    """建立数据库连接（WAL + busy_timeout，兼顾多进程读写）"""
    conn = sqlite3.connect(db_path, timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


@contextmanager
def db_session(db_path):
    """连接上下文：自动提交 / 异常回滚 / 关闭（避免连接泄漏）"""
    conn = connect(db_path)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_schema(conn):
    """建表 + 存量库迁移（补 uuid 列并生成全局唯一 ID，多端同步依赖）"""
    for sql in _SCHEMA:
        conn.execute(sql)
    cols = [r[1] for r in conn.execute("PRAGMA table_info(memos)")]
    if "uuid" not in cols:
        conn.execute("ALTER TABLE memos ADD COLUMN uuid TEXT")
    missing = conn.execute("SELECT id FROM memos WHERE uuid IS NULL OR uuid=''").fetchall()
    for (mid,) in missing:
        conn.execute("UPDATE memos SET uuid=? WHERE id=?", (new_uuid(), mid))
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_memos_uuid ON memos(uuid)")


def memo_row_to_dict(row, tags=None):
    return {
        "id": row["id"],
        "uuid": row["uuid"],
        "content": row["content"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "pinned": bool(row["pinned"]),
        "tags": tags or [],
    }


def insert_memo(conn, content, created_at=None, memo_uuid=None):
    """统一写入一条笔记（含标签索引），返回新 memo id。
    调用方负责 commit 与同步日志（log_op）。"""
    ts = normalize_ts(created_at) if created_at is not None else now_ms()
    cur = conn.execute(
        "INSERT INTO memos(uuid, content, created_at) VALUES(?,?,?)",
        (memo_uuid or new_uuid(), content, ts))
    memo_id = cur.lastrowid
    set_memo_tags(conn, memo_id, parse_tags(content))
    return memo_id


def fetch_memo(conn, mid):
    row = conn.execute("SELECT * FROM memos WHERE id=?", (mid,)).fetchone()
    if not row:
        return None
    tags = [r[0] for r in conn.execute("SELECT name FROM memo_tags WHERE memo_id=?", (mid,))]
    return memo_row_to_dict(row, tags)


def compute_stats(conn, days=365):
    """统计：总数 / 连续记录天数 / 本周新增（周一起算）；days>0 时附带逐日序列。
    字段名统一为 thisWeek（与前端一致），供 REST 与 MCP 共用。"""
    rows = conn.execute(
        "SELECT date(created_at/1000, 'unixepoch', 'localtime') AS d, COUNT(*) AS c "
        "FROM memos GROUP BY d").fetchall()
    by_day = {r["d"]: r["c"] for r in rows}
    today = datetime.now().date()
    # 连续记录天数（允许今天未记，从昨天起算）
    streak = 0
    d = today if by_day.get(today.isoformat()) else today - timedelta(days=1)
    while by_day.get(d.isoformat(), 0) > 0:
        streak += 1
        d -= timedelta(days=1)
    monday = today - timedelta(days=today.weekday())
    week = sum(by_day.get((monday + timedelta(days=i)).isoformat(), 0) for i in range(7))
    total = conn.execute("SELECT COUNT(*) AS c FROM memos").fetchone()["c"]
    result = {
        "total": total,
        "streak": streak,
        "thisWeek": week,
        "today": today.isoformat(),
    }
    if days and days > 0:
        series = []
        for i in range(days - 1, -1, -1):
            dd = today - timedelta(days=i)
            series.append({"date": dd.isoformat(), "count": by_day.get(dd.isoformat(), 0)})
        result["days"] = series
    return result
