# -*- coding: utf-8 -*-
"""端到端：两个 service 实例 + 共享坚果云目录，验证 API 层的同步集成"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

BASE = Path(__file__).resolve().parent
PY = r"C:\Python314\python.exe"
ROOT = Path(tempfile.mkdtemp(prefix="memo_e2e_"))
CLOUD = ROOT / "cloud"
A_DIR, B_DIR = ROOT / "A", ROOT / "B"
A_PORT, B_PORT = 8916, 8917

results = []


def record(tid, ok, note=""):
    results.append((tid, ok, note))
    print(f"  {'PASS' if ok else 'FAIL'}  {tid}  {note}")


def req(port, method, path, body=None, raw=False):
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    r = urllib.request.Request(f"http://127.0.0.1:{port}" + path, data=data, method=method,
                               headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=5) as resp:
        c = resp.read()
        return json.loads(c) if not raw else c


def start(port, data_dir, device="desktop"):
    env = {**os.environ, "MEMO_DATA_DIR": str(data_dir)}
    logf = open(str(ROOT / f"backend-{port}.log"), "w", encoding="utf-8")
    p = subprocess.Popen([PY, str(BASE / "service.py"), "--no-gui", "--port", str(port),
                          "--device", device],
                         cwd=str(BASE), env=env,
                         stdout=logf, stderr=subprocess.STDOUT)
    for _ in range(40):
        try:
            req(port, "GET", "/api/health")
            return p
        except Exception:
            time.sleep(0.5)
    raise RuntimeError("后端启动失败")


def main():
    A = start(A_PORT, A_DIR, "desktop")
    B = start(B_PORT, B_DIR, "mobile")
    try:
        # 配置两端同步目录（坚果云共享目录）
        req(A_PORT, "POST", "/api/config", {"sync": {"dir": str(CLOUD)}})
        req(B_PORT, "POST", "/api/config", {"sync": {"dir": str(CLOUD)}})
        time.sleep(0.5)

        # 桌面写 2 条 → 手机同步
        m1 = req(A_PORT, "POST", "/api/memos", {"content": "桌面端笔记 A #同步"})
        m2 = req(A_PORT, "POST", "/api/memos", {"content": "桌面端笔记 B #同步/测试"})
        assert m1.get("uuid") and m2.get("uuid"), "API 应返回 uuid"
        record("E01 API 返回 uuid", True, f"uuid={m1['uuid'][:8]}…")
        time.sleep(0.3)  # 模拟坚果云同步延迟
        try:
            n = req(B_PORT, "POST", "/api/sync/now")["applied"]
            items = req(B_PORT, "GET", "/api/memos?limit=10")["items"]
            record("E02 桌面→手机", len(items) == 2 and all(i["uuid"] for i in items),
                   f"B 收到 {len(items)} 条, 应用 {n} 条")
        except Exception as e:
            record("E02 桌面→手机", False, f"异常: {e}")
            print(open(str(ROOT / f"backend-{B_PORT}.log"), encoding="utf-8").read()[-1500:])
            raise

        # 手机写 1 条 → 桌面同步
        m3 = req(B_PORT, "POST", "/api/memos", {"content": "手机端笔记 C #同步"})
        time.sleep(0.3)
        req(A_PORT, "POST", "/api/sync/now")
        items = req(A_PORT, "GET", "/api/memos?limit=10")["items"]
        record("E03 手机→桌面", len(items) == 3 and any(i["uuid"] == m3["uuid"] for i in items),
               f"A 收到 {len(items)} 条")

        # 手机端删除桌面创建的笔记 → 桌面同步删除
        req(B_PORT, "DELETE", f"/api/memos/{m1['id']}")
        time.sleep(0.3)
        req(A_PORT, "POST", "/api/sync/now")
        items = req(A_PORT, "GET", "/api/memos?limit=10")["items"]
        record("E04 删除同步", all(i["uuid"] != m1["uuid"] for i in items),
               f"A 剩余 {len(items)} 条")

        # 手机编辑 → 桌面同步更新
        req(B_PORT, "PUT", f"/api/memos/{m2['id']}", {"content": "手机端修改后的内容 #同步/改"})
        time.sleep(0.3)
        req(A_PORT, "POST", "/api/sync/now")
        items = req(A_PORT, "GET", "/api/memos?limit=10")["items"]
        updated = next(i for i in items if i["uuid"] == m2["uuid"])
        record("E05 编辑同步", updated["content"] == "手机端修改后的内容 #同步/改",
               f"A 中内容={updated['content'][:12]}…")

        # 标签同步验证（B 端标签来自 A 的写入）
        tags_b = req(B_PORT, "GET", "/api/tags")["tags"]
        record("E06 标签同步", any(t["name"] == "同步" for t in tags_b), f"B 标签={[t['name'] for t in tags_b]}")
    finally:
        A.terminate()
        B.terminate()
        try:
            A.wait(timeout=5)
            B.wait(timeout=5)
        except Exception:
            A.kill()
            B.kill()
        shutil.rmtree(ROOT, ignore_errors=True)

    passed = sum(1 for _, ok, _ in results if ok)
    print(f"\n=== 端到端同步结果: {passed}/{len(results)} 通过 ===")
    for tid, ok, note in results:
        if not ok:
            print(f"  未通过: {tid} {note}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
