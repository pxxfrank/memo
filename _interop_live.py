# -*- coding: utf-8 -*-
"""跨语言联调 A/D 步：Python 桌面端写日志 + 拉取验证"""
import json
import os
import sqlite3
import sys

sys.path.insert(0, r"G:\AI_Project\06-New flomo")
from sync import SyncEngine

CLOUD = r"G:\AI_Project\06-New flomo\sync_interop2"
DB = os.path.join(CLOUD, "desktop.db")
PASS = "interop-pass"


def open_db():
    conn = sqlite3.connect(DB)
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS memos(
          id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT,
          content TEXT NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER, pinned INTEGER DEFAULT 0);
        CREATE TABLE IF NOT EXISTS memo_tags(
          memo_id INTEGER NOT NULL, name TEXT NOT NULL, PRIMARY KEY(memo_id, name));
        CREATE TABLE IF NOT EXISTS tags(name TEXT PRIMARY KEY, count INTEGER DEFAULT 0);
    """)
    conn.commit()
    return conn


def count(conn):
    return conn.execute("SELECT COUNT(*) FROM memos").fetchone()[0]


os.makedirs(CLOUD, exist_ok=True)
# salt 固定（真实桌面端存于 config.json；此处模拟持久化的 salt）
cfg = lambda: {"sync": {"dir": CLOUD, "passphrase": PASS, "salt": "c" * 32}}
eng = SyncEngine(CLOUD, DB, cfg, device="desktop")

if len(sys.argv) > 1 and sys.argv[1] == "write":
    # A 步：模拟桌面写 2 条（走真实引擎日志链路）
    conn = open_db()
    for i in (1, 2):
        uid = f"desk-uuid-{i}"
        ts = 1786355000000 + i
        conn.execute("INSERT INTO memos(uuid, content, created_at) VALUES(?,?,?)",
                     (uid, f"桌面端笔记{i} #联调测试", ts))
        conn.commit()
        eng.log_op("add", {"uuid": uid, "content": f"桌面端笔记{i} #联调测试",
                           "created_at": ts, "pinned": False}, ts=ts)
    print(f"A: 桌面写 2 条 → {CLOUD}/desktop.jsonl")

elif len(sys.argv) > 1 and sys.argv[1] == "pull":
    # D 步：桌面拉取手机日志合并
    conn = open_db()
    applied, fail = eng.pull_and_merge()
    n = count(conn)
    print(f"D: 桌面 pull_and_merge: applied={applied} fail={fail} 总数={n}")
    rows = conn.execute("SELECT content FROM memos").fetchall()
    for r in rows:
        print(f"    {r[0]}")
    ok = applied >= 1 and n >= 3 and fail == 0
    print("跨语言联调(Dart→Python):", "通过" if ok else "失败")
    sys.exit(0 if ok else 1)
