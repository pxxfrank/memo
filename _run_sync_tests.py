# -*- coding: utf-8 -*-
"""同步引擎端到端测试：模拟桌面/手机双端 + 坚果云共享目录"""
import json
import os
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path

BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE))

from sync import SyncEngine, new_uuid, parse_tags, set_memo_tags

SCHEMA = """
CREATE TABLE memos(id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT,
  content TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER,
  pinned INTEGER DEFAULT 0);
CREATE TABLE memo_tags(memo_id INTEGER NOT NULL, name TEXT NOT NULL,
  PRIMARY KEY(memo_id, name));
CREATE TABLE tags(name TEXT PRIMARY KEY, count INTEGER DEFAULT 0);
"""

results = []


def record(tid, ok, note=""):
    results.append((tid, ok, note))
    print(f"  {'PASS' if ok else 'FAIL'}  {tid}  {note}")


class Backend:
    """模拟一端：本地库 + 引擎（后端写路径的精简版）"""

    def __init__(self, data_dir, device, cloud_dir, passphrase="", salt=None):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db = str(self.data_dir / "memo.db")
        conn = sqlite3.connect(self.db)
        conn.executescript(SCHEMA)
        conn.commit()
        conn.close()
        self.passphrase = passphrase
        self.salt = salt
        self.engine = SyncEngine(self.data_dir, self.db, self._cfg)
        self.engine.device = device
        self.cloud_dir = cloud_dir

    def _cfg(self):
        c = {"sync": {"dir": str(self.cloud_dir)}}
        if self.passphrase:
            c["sync"]["passphrase"] = self.passphrase
            c["sync"]["salt"] = self.salt or "a" * 32
        return c

    def create(self, content, ts=None):
        uid = new_uuid()
        conn = sqlite3.connect(self.db)
        conn.execute("INSERT INTO memos(uuid, content, created_at) VALUES(?,?,?)",
                     (uid, content, ts or int(__import__("time").time() * 1000)))
        conn.commit()
        row = conn.execute("SELECT * FROM memos WHERE uuid=?", (uid,)).fetchone()
        conn.close()
        memo = {"uuid": row[1], "content": row[2], "created_at": row[3], "pinned": bool(row[5])}
        self.engine.log_op("add", memo)
        return uid

    def update(self, uid, content, ts):
        conn = sqlite3.connect(self.db)
        conn.execute("UPDATE memos SET content=?, updated_at=? WHERE uuid=?", (content, ts, uid))
        conn.commit()
        conn.close()
        self.engine.log_op("update", {"uuid": uid, "content": content,
                                      "created_at": 0, "pinned": False}, id=uid, ts=ts, content=content)

    def delete(self, uid, ts):
        conn = sqlite3.connect(self.db)
        conn.execute("DELETE FROM memos WHERE uuid=?", (uid,))
        conn.commit()
        conn.close()
        self.engine.log_op("delete", id=uid, ts=ts)

    def count(self):
        conn = sqlite3.connect(self.db)
        n = conn.execute("SELECT COUNT(*) FROM memos").fetchone()[0]
        conn.close()
        return n

    def get(self, uid):
        conn = sqlite3.connect(self.db)
        row = conn.execute("SELECT content, updated_at FROM memos WHERE uuid=?", (uid,)).fetchone()
        conn.close()
        return row


def main():
    root = Path(tempfile.mkdtemp(prefix="memo_sync_test_"))
    A = Backend(root / "A", "desktop", root / "cloud")
    B = Backend(root / "B", "mobile", root / "cloud")

    # 1. 桌面写 3 条 → 手机拉取 → 一致
    u1 = A.create("桌面笔记一 #工作")
    u2 = A.create("桌面笔记二 #学习")
    u3 = A.create("桌面笔记三 #生活")
    A.engine.ensure_full_dump()
    B.engine.pull_and_merge()
    record("S01 桌面→手机", B.count() == 3, f"B={B.count()}")

    # 2. 手机写 1 条 → 桌面拉取 → 一致
    u4 = B.create("手机笔记一 #工作")
    A.engine.pull_and_merge()
    record("S02 手机→桌面", A.count() == 4, f"A={A.count()}")

    # 3. 双向各自新增后互相拉取
    u5 = A.create("桌面新 #随想")
    u6 = B.create("手机新 #随想")
    A.engine.pull_and_merge()
    B.engine.pull_and_merge()
    A.engine.pull_and_merge()
    B.engine.pull_and_merge()
    record("S03 双向并发", A.count() == 6 and B.count() == 6, f"A={A.count()} B={B.count()}")

    # 4. 冲突：双端改同一笔记，后写者胜（ts 大者）
    base = int(__import__("time").time() * 1000)
    ts_a = base + 1000
    ts_b = base + 1005
    A.update(u1, "桌面修改版", ts_a)
    B.update(u1, "手机修改版(后)", ts_b)
    A.engine.pull_and_merge()
    B.engine.pull_and_merge()
    a_content = A.get(u1)[0]
    b_content = B.get(u1)[0]
    record("S04 冲突后写者胜", a_content == "手机修改版(后)" and b_content == "手机修改版(后)",
           f"A={a_content}")

    # 5. 冲突：本地较新则不被覆盖
    ts_c = base + 2000
    A.update(u2, "桌面最新版", ts_c)
    B.update(u2, "手机旧版", base + 1000)
    A.engine.pull_and_merge()
    record("S05 本地较新不被覆盖", A.get(u2)[0] == "桌面最新版", f"A={A.get(u2)[0]}")

    # 6. 删除同步（墓碑）
    A.delete(u3, base + 3000)
    B.engine.pull_and_merge()
    record("S06 删除同步", B.get(u3) is None, f"B 中 u3={B.get(u3)}")

    # 7. 幂等重放：重复拉取无副作用
    n_before = B.count()
    for _ in range(3):
        B.engine.pull_and_merge()
    record("S07 幂等重放", B.count() == n_before, f"B={B.count()}")

    # 8. 新设备全量重建：新引擎 C 从日志恢复全部
    C = Backend(root / "C", "newphone", root / "cloud")
    C.engine.ensure_full_dump()  # C 的日志为空，不 dump（C 是全新）
    C.engine.pull_and_merge()
    # C 只能看到 desktop.jsonl + mobile.jsonl 的内容
    record("S08 新设备重建", C.count() >= 5, f"C={C.count()}")

    # ---------- 加密场景 ----------
    root2 = root / "enc"
    (root2 / "cloud").mkdir(parents=True)
    SA = Backend(root2 / "A", "desktop", root2 / "cloud", passphrase="secret-123")
    SB = Backend(root2 / "B", "mobile", root2 / "cloud", passphrase="secret-123")

    # S09 带口令双向同步
    SA.create("加密笔记一 #密文")
    SA.create("加密笔记二 #密文")
    SA.engine.ensure_full_dump()
    SB.engine.pull_and_merge()
    # S10 云端日志是密文（不含明文内容）
    raw = (root2 / "cloud" / "desktop.jsonl").read_text(encoding="utf-8")
    record("S09 加密双向同步", SB.count() == 2, f"B={SB.count()}")
    record("S10 云端密文", "加密笔记一" not in raw and "密文" not in raw, f"明文出现: {'加密笔记一' in raw}")

    # S11 错误口令无法读取（解密失败，不同步）
    SW = Backend(root2 / "C", "wrong", root2 / "cloud", passphrase="wrong-pass")
    applied, fail = SW.engine.pull_and_merge()
    record("S11 错误口令拒绝", applied == 0 and fail > 0, f"applied={applied} fail={fail}")

    # S12 明文 → 密文转换：先明文写，再设口令追加
    root3 = root / "conv"
    (root3 / "cloud").mkdir(parents=True)
    P1 = Backend(root3 / "A", "desktop", root3 / "cloud")
    P1.create("明文时代 #老数据")
    P1.passphrase = "new-pass"
    P1.salt = "b" * 32
    P1.create("加密时代 #新数据")
    raw3 = (root3 / "cloud" / "desktop.jsonl").read_text(encoding="utf-8")
    lines3 = raw3.strip().splitlines()
    record("S12 明文→密文转换", "老数据" not in raw3 and len(lines3) == 3 and lines3[0].startswith("#salt="),
           f"行数={len(lines3)} 头={lines3[0][:14] if lines3 else ''} 明文残留={'老数据' in raw3}")

    # S13 转换后仍可完整同步（新设备用新口令可读全部）
    P2 = Backend(root3 / "B", "mobile", root3 / "cloud", passphrase="new-pass", salt="b" * 32)
    P2.engine.pull_and_merge()
    record("S13 转换后同步完整", P2.count() == 2, f"B={P2.count()}")

    shutil.rmtree(root, ignore_errors=True)
    passed = sum(1 for _, ok, _ in results if ok)
    print(f"\n=== 同步引擎结果: {passed}/{len(results)} 通过 ===")
    for tid, ok, note in results:
        if not ok:
            print(f"  未通过: {tid} {note}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
