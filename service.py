#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MEMO · flomo 平替（本地私有版）常驻服务
======================================
- 托管前端应用（app/ 目录）
- REST API（笔记/标签/统计/导出/导入/配置）
- flomo 兼容写入 API：POST /v1/memo
- 全局热键快速记录（tkinter 小窗，替代微信输入）
- 系统托盘 + 每日回顾通知

用法：
    python service.py                 # 正常运行（托盘+热键+回顾）
    python service.py --no-gui        # 仅 HTTP 服务（测试/调试）
    python service.py --port 8899 --open
"""
import argparse
import hmac
import json
import mimetypes
import os
import re
import secrets
import sqlite3
import sys
import threading
import time
import urllib.request
import webbrowser
from datetime import datetime, timedelta
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

import sync as sync_mod

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def _is_frozen():
    return bool(getattr(sys, "_MEIPASS", None))


if _is_frozen():
    # PyInstaller 打包运行：静态资源在解压目录，数据在用户数据目录
    RUNTIME_DIR = Path(getattr(sys, "_MEIPASS"))
    DATA_DIR = Path(os.environ.get("MEMO_DATA_DIR", Path.home() / ".memo"))
else:
    # 源码运行：优先 MEMO_DATA_DIR 环境变量（测试/多实例/桌面版数据目录），默认项目目录
    RUNTIME_DIR = Path(__file__).resolve().parent
    DATA_DIR = Path(os.environ.get("MEMO_DATA_DIR", str(RUNTIME_DIR)))

APP_DIR = RUNTIME_DIR / "app"
DB_PATH = DATA_DIR / "memo.db"
CONFIG_PATH = DATA_DIR / "config.json"
DEFAULT_PORT = 8899
HOST = "127.0.0.1"
APP_VERSION = "1.3.0"  # 版本迭代时同步更新（见 CLAUDE.md 版本规范）

DEFAULT_CONFIG = {
    "hotkey": "ctrl+shift+m",   # 全局热键：呼出快速记录窗
    "review_time": "09:30",     # 每日回顾时间
    "review_count": 3,          # 每次回顾条数
}

PORT = DEFAULT_PORT  # 由 main() 覆盖

mimetypes.add_type("application/manifest+json", ".webmanifest")

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
def load_config():
    if CONFIG_PATH.exists():
        try:
            cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        except Exception:
            cfg = {}
    else:
        cfg = {}
    merged = dict(DEFAULT_CONFIG)
    merged.update(cfg)
    return merged


def save_config(cfg):
    CONFIG_PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")


# ---------------------------------------------------------------------------
# 访问令牌（局域网访问鉴权；localhost 免鉴权）
# ---------------------------------------------------------------------------
def ensure_token():
    """返回配置中的访问令牌，不存在则自动生成并保存"""
    cfg = load_config()
    if cfg.get("token"):
        return cfg["token"]
    token = secrets.token_hex(16)
    cfg["token"] = token
    save_config(cfg)
    return token


def reset_token():
    token = secrets.token_hex(16)
    cfg = load_config()
    cfg["token"] = token
    save_config(cfg)
    return token


# ---------------------------------------------------------------------------
# 数据库
# ---------------------------------------------------------------------------
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    with get_db() as c:
        c.execute("""CREATE TABLE IF NOT EXISTS memos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            pinned INTEGER DEFAULT 0)""")
        c.execute("""CREATE TABLE IF NOT EXISTS memo_tags(
            memo_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            PRIMARY KEY(memo_id, name))""")
        c.execute("""CREATE TABLE IF NOT EXISTS tags(
            name TEXT PRIMARY KEY,
            count INTEGER DEFAULT 0)""")
        c.execute("CREATE INDEX IF NOT EXISTS idx_memos_created ON memos(created_at DESC)")
        c.execute("CREATE INDEX IF NOT EXISTS idx_memo_tags_name ON memo_tags(name)")
        # 存量库迁移：补 uuid 列并生成全局唯一 ID（多端同步依赖）
        cols = [r[1] for r in c.execute("PRAGMA table_info(memos)")]
        if "uuid" not in cols:
            c.execute("ALTER TABLE memos ADD COLUMN uuid TEXT")
        missing = c.execute("SELECT id FROM memos WHERE uuid IS NULL OR uuid=''").fetchall()
        for (mid,) in missing:
            c.execute("UPDATE memos SET uuid=? WHERE id=?", (sync_mod.new_uuid(), mid))
        c.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_memos_uuid ON memos(uuid)")


# ---------------------------------------------------------------------------
# 标签解析（flomo 风格：#标签、#父/子 多级）
# ---------------------------------------------------------------------------
TAG_RE = re.compile(r"#([^\s#，。！？!?,;；:：\u201c\u201d\u2018\u2019（）()【】\[\]<>《》]+)")
_TAG_STRIP = re.compile(r"^[^\w\u4e00-\u9fff]+|[^\w\u4e00-\u9fff]+$")


def parse_tags(content):
    tags = set()
    for m in TAG_RE.finditer(content):
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


def fetch_memo(conn, mid):
    row = conn.execute("SELECT * FROM memos WHERE id=?", (mid,)).fetchone()
    if not row:
        return None
    tags = [r[0] for r in conn.execute("SELECT name FROM memo_tags WHERE memo_id=?", (mid,))]
    return memo_row_to_dict(row, tags)


# 同步引擎（main() 初始化；写操作经此追加变更日志）
SYNC = None


# ---------------------------------------------------------------------------
# HTTP 处理
# ---------------------------------------------------------------------------
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(APP_DIR), **kwargs)

    def log_message(self, fmt, *args):
        pass  # 静默访问日志

    # ---------- 工具 ----------
    def _json(self, obj, status=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _error(self, msg, status=400):
        self._json({"error": msg}, status)

    def _read_body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _read_json(self):
        raw = self._read_body()
        if not raw:
            return {}
        try:
            return json.loads(raw.decode("utf-8"))
        except Exception:
            return {}

    def _query(self):
        return parse_qs(urlparse(self.path).query)

    def _is_local(self):
        """本机来源（127.0.0.1 / ::1）免鉴权"""
        return self.client_address[0] in ("127.0.0.1", "::1")

    def _check_auth(self):
        """本机放行；非本机必须携带正确令牌（Authorization / X-Memo-Token / ?token=）"""
        if self._is_local():
            return True
        token = ensure_token()
        given = ""
        auth = self.headers.get("Authorization", "")
        if auth.lower().startswith("bearer "):
            given = auth[7:].strip()
        if not given:
            given = self.headers.get("X-Memo-Token", "").strip()
        if not given:
            given = self._query().get("token", [""])[0]
        return bool(given) and hmac.compare_digest(given, token)

    def _route(self, method):
        path = urlparse(self.path).path
        path = unquote(path)

        # ---- 鉴权：API 接口在非本机来源时强制令牌 ----
        if path.startswith("/api/") or path.startswith("/v1/"):
            if not self._check_auth():
                return self._error("unauthorized: 需要访问令牌", 401)

        # ---- 笔记 ----
        if method == "GET" and path == "/api/memos":
            return self.api_list_memos()
        if method == "POST" and path == "/api/memos":
            return self.api_create_memo()
        if method == "DELETE" and path == "/api/memos":
            return self.api_clear_memos()
        m = re.fullmatch(r"/api/memos/(\d+)", path)
        if m:
            if method == "PUT":
                return self.api_update_memo(int(m.group(1)))
            if method == "DELETE":
                return self.api_delete_memo(int(m.group(1)))

        # ---- 标签 / 统计 / 导出 / 导入 / 配置 ----
        if method == "GET" and path == "/api/tags":
            return self.api_tags()
        if method == "GET" and path == "/api/stats":
            return self.api_stats()
        if method == "GET" and path == "/api/export":
            return self.api_export()
        if method == "POST" and path == "/api/import":
            return self.api_import()
        if method == "GET" and path == "/api/config":
            cfg = dict(load_config())
            cfg["token"] = ensure_token()
            return self._json(cfg)
        if method == "POST" and path == "/api/config":
            body = self._read_json()
            merged = dict(load_config())
            if body.get("reset_token"):
                merged["token"] = reset_token()
            # 同步口令：设置时自动生成盐；提供空字符串则清除加密
            if "passphrase" in body:
                sync_cfg = dict(merged.get("sync", {}) or {})
                pp = (body["passphrase"] or "").strip()
                if pp:
                    sync_cfg["passphrase"] = pp
                    if not sync_cfg.get("salt"):
                        sync_cfg["salt"] = secrets.token_hex(16)
                else:
                    sync_cfg.pop("passphrase", None)
                    sync_cfg.pop("salt", None)
                merged["sync"] = sync_cfg
            body = {k: v for k, v in body.items() if k not in ("reset_token", "passphrase")}
            merged.update(body)
            save_config(merged)
            resp = dict(merged)
            resp["token"] = merged.get("token", ensure_token())
            return self._json(resp)

        # ---- 同步 ----
        if method == "GET" and path == "/api/sync/status":
            cfg = load_config().get("sync", {}) or {}
            return self._json({
                "enabled": bool(cfg.get("dir")),
                "dir": cfg.get("dir", ""),
                "device": "desktop",
                "has_passphrase": bool(cfg.get("passphrase")),
            })
        if method == "POST" and path == "/api/sync/now":
            if SYNC:
                try:
                    n = SYNC.pull_and_merge()
                    return self._json({"ok": True, "applied": n})
                except Exception as e:
                    return self._json({"ok": False, "error": str(e)})
            return self._json({"ok": False, "error": "同步引擎未初始化"})

        # ---- flomo 兼容写入 ----
        if method == "POST" and path == "/v1/memo":
            return self.api_flomo()

        # ---- 健康检查 ----
        if method == "GET" and path == "/api/health":
            return self._json({"ok": True, "version": APP_VERSION, "time": int(time.time() * 1000)})

        if path.startswith("/api/"):
            return self._error("not found", 404)
        return None  # 交给静态文件

    # ---------- 实现 ----------
    def api_list_memos(self):
        qs = self._query()
        limit = min(int(qs.get("limit", ["30"])[0]), 200)
        offset = int(qs.get("offset", ["0"])[0])
        tag = qs.get("tag", [""])[0].strip()
        q = qs.get("q", [""])[0].strip()

        where, params = [], []
        if tag:
            where.append("(t.name = ? OR t.name LIKE ?)")
            params += [tag, tag + "/%"]
        if q:
            where.append("m.content LIKE ?")
            params.append("%" + q + "%")
        wsql = ("WHERE " + " AND ".join(where)) if where else ""

        conn = get_db()
        total = conn.execute(
            f"SELECT COUNT(DISTINCT m.id) AS c FROM memos m LEFT JOIN memo_tags t ON m.id=t.memo_id {wsql}",
            params).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT m.id, m.uuid, m.content, m.created_at, m.updated_at, m.pinned,
                       GROUP_CONCAT(t.name) AS tag_list
                FROM memos m LEFT JOIN memo_tags t ON m.id = t.memo_id
                {wsql}
                GROUP BY m.id
                ORDER BY m.pinned DESC, m.created_at DESC
                LIMIT ? OFFSET ?""",
            params + [limit, offset]).fetchall()
        items = []
        for r in rows:
            d = memo_row_to_dict(r, tags=[x for x in (r["tag_list"] or "").split(",") if x])
            items.append(d)
        return self._json({"items": items, "total": total, "limit": limit, "offset": offset})

    def api_create_memo(self):
        body = self._read_json()
        content = (body.get("content") or "").strip()
        if not content:
            return self._error("content 不能为空")
        created_at = body.get("created_at") or int(time.time() * 1000)
        created_at = normalize_ts(created_at)
        conn = get_db()
        cur = conn.execute(
            "INSERT INTO memos(uuid, content, created_at) VALUES(?,?,?)",
            (sync_mod.new_uuid(), content, created_at))
        memo_id = cur.lastrowid
        set_memo_tags(conn, memo_id, parse_tags(content))
        conn.commit()
        memo = fetch_memo(conn, memo_id)
        if SYNC:
            SYNC.log_op("add", memo)
        return self._json(memo, 201)

    def api_update_memo(self, mid):
        body = self._read_json()
        conn = get_db()
        if not conn.execute("SELECT id FROM memos WHERE id=?", (mid,)).fetchone():
            return self._error("memo 不存在", 404)
        if "pinned" in body:
            conn.execute("UPDATE memos SET pinned=? WHERE id=?",
                         (1 if body["pinned"] else 0, mid))
            conn.commit()
            memo = fetch_memo(conn, mid)
            if SYNC:
                SYNC.log_op("pin", memo)
            return self._json(memo)
        content = (body.get("content") or "").strip()
        if not content:
            return self._error("content 不能为空")
        conn.execute("UPDATE memos SET content=?, updated_at=? WHERE id=?",
                     (content, int(time.time() * 1000), mid))
        set_memo_tags(conn, mid, parse_tags(content))
        conn.commit()
        memo = fetch_memo(conn, mid)
        if SYNC:
            SYNC.log_op("update", memo)
        return self._json(memo)

    def api_clear_memos(self):
        conn = get_db()
        uuids = [r[0] for r in conn.execute("SELECT uuid FROM memos")]
        conn.execute("DELETE FROM memos")
        conn.execute("DELETE FROM memo_tags")
        rebuild_tag_counts(conn)
        conn.commit()
        if SYNC:
            for u in uuids:
                SYNC.log_op("delete", id=u)
        return self._json({"ok": True})

    def api_delete_memo(self, mid):
        conn = get_db()
        row = conn.execute("SELECT * FROM memos WHERE id=?", (mid,)).fetchone()
        if not row:
            return self._error("memo 不存在", 404)
        conn.execute("DELETE FROM memos WHERE id=?", (mid,))
        conn.execute("DELETE FROM memo_tags WHERE memo_id=?", (mid,))
        rebuild_tag_counts(conn)
        conn.commit()
        if SYNC:
            SYNC.log_op("delete", id=row["uuid"])
        return self._json({"ok": True})

    def api_tags(self):
        conn = get_db()
        rows = conn.execute(
            "SELECT name, count FROM tags WHERE count > 0 ORDER BY count DESC, name").fetchall()
        return self._json({"tags": [{"name": r["name"], "count": r["count"]} for r in rows]})

    def api_stats(self):
        qs = self._query()
        days = min(int(qs.get("days", ["365"])[0]), 3650)
        conn = get_db()
        rows = conn.execute(
            "SELECT date(created_at/1000, 'unixepoch', 'localtime') AS d, COUNT(*) AS c "
            "FROM memos GROUP BY d").fetchall()
        by_day = {r["d"]: r["c"] for r in rows}
        today = datetime.now().date()
        series = []
        for i in range(days - 1, -1, -1):
            d = today - timedelta(days=i)
            series.append({"date": d.isoformat(), "count": by_day.get(d.isoformat(), 0)})
        # 连续记录天数（允许今天未记，从昨天起算）
        streak = 0
        d = today if by_day.get(today.isoformat()) else today - timedelta(days=1)
        while by_day.get(d.isoformat(), 0) > 0:
            streak += 1
            d -= timedelta(days=1)
        monday = today - timedelta(days=today.weekday())
        week = 0
        for i in range(7):
            week += by_day.get((monday + timedelta(days=i)).isoformat(), 0)
        total = conn.execute("SELECT COUNT(*) AS c FROM memos").fetchone()["c"]
        return self._json({
            "days": series, "streak": streak, "total": total,
            "thisWeek": week, "today": today.isoformat()})

    def api_export(self):
        qs = self._query()
        fmt = qs.get("format", ["json"])[0]
        conn = get_db()
        rows = conn.execute(
            "SELECT * FROM memos ORDER BY created_at ASC").fetchall()
        memos = [memo_row_to_dict(r) for r in rows]
        ts = datetime.now().strftime("%Y%m%d")
        if fmt == "md":
            lines = ["# MEMO 导出", f"# 导出时间：{datetime.now().strftime('%Y-%m-%d %H:%M')}", ""]
            cur_day = None
            for m in memos:
                d = datetime.fromtimestamp(m["created_at"] / 1000).strftime("%Y-%m-%d")
                if d != cur_day:
                    cur_day = d
                    lines.append(f"## {d}")
                lines.append(f"- {m['content']}")
            data = "\n".join(lines).encode("utf-8")
            fname = f"memo-export-{ts}.md"
            ctype = "text/markdown; charset=utf-8"
        elif fmt == "csv":
            import csv, io
            buf = io.StringIO()
            w = csv.writer(buf)
            w.writerow(["id", "created_at", "content"])
            for m in memos:
                w.writerow([m["id"], m["created_at"], m["content"]])
            data = buf.getvalue().encode("utf-8-sig")
            fname = f"memo-export-{ts}.csv"
            ctype = "text/csv; charset=utf-8"
        else:
            data = json.dumps(memos, ensure_ascii=False, indent=1).encode("utf-8")
            fname = f"memo-export-{ts}.json"
            ctype = "application/json; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Disposition", f'attachment; filename="{fname}"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def api_import(self):
        body = self._read_json()
        data = body.get("data") or body.get("memos") or body
        if isinstance(data, dict):
            data = data.get("memos", [])
        if not isinstance(data, list):
            return self._error("导入数据格式不正确")
        conn = get_db()
        n = 0
        for item in data:
            content = (item.get("content") or "").strip()
            if not content:
                continue
            created_at = normalize_ts(item.get("created_at") or int(time.time() * 1000))
            cur = conn.execute("INSERT INTO memos(uuid, content, created_at) VALUES(?,?,?)",
                               (sync_mod.new_uuid(), content, created_at))
            set_memo_tags(conn, cur.lastrowid, parse_tags(content))
            memo = fetch_memo(conn, cur.lastrowid)
            if SYNC:
                SYNC.log_op("add", memo)
            n += 1
        conn.commit()
        return self._json({"ok": True, "imported": n})

    def api_flomo(self):
        """flomo 兼容：POST /v1/memo  body: {"content": "..."} 或表单 content=..."""
        raw = self._read_body()
        try:
            body = json.loads(raw.decode("utf-8"))
        except Exception:
            body = {}
        if not body:
            qs = parse_qs(raw.decode("utf-8"))
            body = {k: v[0] for k, v in qs.items()}
        content = (body.get("content") or "").strip()
        if not content:
            return self._error("content 不能为空")
        created_at = body.get("created_at") or int(time.time() * 1000)
        conn = get_db()
        cur = conn.execute("INSERT INTO memos(uuid, content, created_at) VALUES(?,?,?)",
                           (sync_mod.new_uuid(), content, normalize_ts(created_at)))
        set_memo_tags(conn, cur.lastrowid, parse_tags(content))
        conn.commit()
        memo = fetch_memo(conn, cur.lastrowid)
        if SYNC:
            SYNC.log_op("add", memo)
        notify("MEMO 已记录", memo["content"][:60])
        return self._json({"code": 0, "message": "ok", "data": memo}, 201)

    # ---------- 入口 ----------
    def do_GET(self):
        r = self._route("GET")
        if r is not None:
            return
        super().do_GET()

    def do_POST(self):
        r = self._route("POST")
        if r is not None:
            return
        self._error("not found", 404)

    def do_PUT(self):
        r = self._route("PUT")
        if r is not None:
            return
        self._error("not found", 404)

    def do_DELETE(self):
        r = self._route("DELETE")
        if r is not None:
            return
        self._error("not found", 404)


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
    return int(time.time() * 1000)


# ---------------------------------------------------------------------------
# 图标（Pillow 绘制，同时用于 PWA 图标）
# ---------------------------------------------------------------------------
def make_icon(size):
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(size * 0.2)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=(233, 90, 60, 255))
    pad = size * 0.26
    top, bot = size * 0.30, size * 0.70
    mid = size * 0.5
    lw = max(3, int(size * 0.10))
    d.line([pad, bot, pad, top, mid, bot, size - pad, top, size - pad, bot],
           fill=(255, 255, 255, 255), width=lw, joint="curve")
    return img


def ensure_icons():
    for s in (192, 512):
        p = APP_DIR / f"icon-{s}.png"
        if not p.exists():
            make_icon(s).save(p)
    tray = DATA_DIR / ".icon-tray.png"
    if not tray.exists():
        make_icon(64).save(tray)
    return tray


# ---------------------------------------------------------------------------
# 通知 / 托盘 / 热键 / 快速记录窗
# ---------------------------------------------------------------------------
ICON = None
CAPTURE_OPEN = threading.Lock()


def notify(title, message):
    if ICON is not None:
        try:
            ICON.notify(message[:120], title)
        except Exception:
            pass


def open_capture():
    if not CAPTURE_OPEN.acquire(blocking=False):
        return
    threading.Thread(target=_capture_window, daemon=True).start()


def _capture_window():
    try:
        _capture_window_impl()
    except Exception:
        pass
    finally:
        try:
            CAPTURE_OPEN.release()
        except Exception:
            pass


def _capture_window_impl():
    import tkinter as tk
    cfg = load_config()
    url = f"http://{HOST}:{PORT}/v1/memo"

    root = tk.Tk()
    root.title("MEMO 快速记录")
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    root.configure(bg="#1c1c1e")
    root.geometry("560x120")
    # 顶部居中偏上
    sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
    root.geometry(f"560x120+{(sw - 560)//2}+{int(sh * 0.18)}")

    entry = tk.Text(root, height=2, font=("Microsoft YaHei", 13),
                    bg="#1c1c1e", fg="#f2f2f2", insertbackground="#f2f2f2",
                    relief="flat", padx=16, pady=10, wrap="word", undo=True)
    entry.pack(fill="both", expand=True)

    def submit(event=None):
        content = entry.get("1.0", "end").strip()
        if content:
            try:
                req = urllib.request.Request(
                    url, data=json.dumps({"content": content}).encode("utf-8"),
                    headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=3) as resp:
                    pass
            except Exception:
                pass
        root.destroy()
        CAPTURE_OPEN.release()

    def newline(event=None):
        entry.insert("insert", "\n")
        return "break"

    entry.bind("<Return>", submit)
    entry.bind("<Shift-Return>", newline)
    root.bind("<Escape>", lambda e: (root.destroy(), CAPTURE_OPEN.release()))
    root.protocol("WM_DELETE_WINDOW", lambda: (root.destroy(), CAPTURE_OPEN.release()))

    entry.focus_set()
    root.mainloop()


def review_loop():
    while True:
        cfg = load_config()
        try:
            hh, mm = (int(x) for x in cfg.get("review_time", "09:30").split(":"))
        except Exception:
            hh, mm = 9, 30
        now = datetime.now()
        nxt = now.replace(hour=hh, minute=mm, second=0, microsecond=0)
        if nxt <= now:
            nxt += timedelta(days=1)
        time.sleep(max(1, (nxt - now).total_seconds()))
        do_review()


def do_review():
    cfg = load_config()
    n = int(cfg.get("review_count", 3))
    conn = get_db()
    today0 = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    rows = conn.execute(
        "SELECT * FROM memos WHERE created_at < ? ORDER BY RANDOM() LIMIT ?",
        (int(today0.timestamp() * 1000), n)).fetchall()
    if not rows:
        rows = conn.execute("SELECT * FROM memos ORDER BY RANDOM() LIMIT ?", (n,)).fetchall()
    if not rows:
        notify("每日回顾", "还没有笔记，先记一条吧 ✍️")
        return
    lines = []
    for r in rows:
        first = r["content"].splitlines()[0][:38]
        lines.append("· " + first)
    notify("每日回顾 · " + datetime.now().strftime("%m月%d日"), "\n".join(lines))


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main():
    global ICON, PORT
    ap = argparse.ArgumentParser(description="MEMO 本地服务")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--host", default=HOST,
                    help="监听地址，默认 127.0.0.1；局域网访问用 --host 0.0.0.0（自动启用令牌鉴权）")
    ap.add_argument("--no-gui", action="store_true", help="不启用托盘/热键/回顾（测试用）")
    ap.add_argument("--open", action="store_true", help="启动后自动打开应用")
    ap.add_argument("--device", default="desktop",
                    help="本机设备名（云同步日志标识，多端必须不同，如 desktop/mobile）")
    args = ap.parse_args()
    PORT = args.port
    HOST_BIND = args.host

    APP_DIR.mkdir(exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    init_db()

    # 同步引擎：本地写操作记日志；启用坚果云目录后定时拉取其他设备日志
    global SYNC
    SYNC = sync_mod.SyncEngine(str(DATA_DIR), str(DB_PATH), load_config, device=args.device)
    threading.Thread(target=SYNC.loop, daemon=True).start()

    try:
        server = ThreadingHTTPServer((HOST_BIND, PORT), Handler)
    except OSError:
        print(f"端口 {PORT} 被占用，服务可能已在运行？", file=sys.stderr)
        sys.exit(1)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f"http://{HOST_BIND}:{PORT}/"
    print(f"MEMO 本地服务已启动：{base_url}")
    if HOST_BIND != "127.0.0.1":
        print(f"已开启局域网访问（{HOST_BIND}），访问令牌: {ensure_token()}")

    if args.open:
        webbrowser.open(base_url)

    if args.no_gui:
        try:
            while True:
                time.sleep(3600)
        except KeyboardInterrupt:
            pass
        server.shutdown()
        return

    # ---- 托盘 ----
    import keyboard
    import pystray
    ensure_icons()
    menu = pystray_menu(base_url)
    ICON = pystray.Icon("memo-local", make_icon(64), "MEMO · 本地版", menu)
    try:
        ICON.run_detached()
    except Exception:
        pass

    # ---- 全局热键 ----
    try:
        keyboard.add_hotkey(load_config().get("hotkey", "ctrl+shift+m"), open_capture)
    except Exception as e:
        print("热键注册失败：", e)

    # ---- 每日回顾 ----
    threading.Thread(target=review_loop, daemon=True).start()

    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass
    try:
        keyboard.unhook_all()
    except Exception:
        pass
    server.shutdown()


def pystray_menu(base_url):
    import pystray

    def open_app(icon, item):
        webbrowser.open(base_url)

    def quick_capture(icon, item):
        open_capture()

    def review_now(icon, item):
        do_review()

    def quit_app(icon, item):
        icon.stop()
        keyboard.unhook_all()
        sys.exit(0)

    return pystray.Menu(
        pystray.MenuItem("快速记录", quick_capture, default=True),
        pystray.MenuItem("打开应用", open_app),
        pystray.MenuItem("立即回顾", review_now),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("退出", quit_app),
    )


if __name__ == "__main__":
    main()
