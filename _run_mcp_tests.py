# -*- coding: utf-8 -*-
"""TC-C：MCP 自动化测试（stdio + HTTP + 与后端数据一致性，独立测试库）"""
import asyncio
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
DATA_DIR = Path(tempfile.mkdtemp(prefix="memo_mcp_test_"))
API_PORT = 8912
HTTP_PORT = 8913

results = []


def record(tid, ok, note=""):
    results.append((tid, ok, note))
    print(f"  {'PASS' if ok else 'FAIL'}  {tid}  {note}")


def api_req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(f"http://127.0.0.1:{API_PORT}" + path, data=data, method=method,
                               headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=5) as resp:
        return json.loads(resp.read())


# ---------- stdio ----------
async def test_stdio():
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    env = {**os.environ, "MEMO_DATA_DIR": str(DATA_DIR)}
    params = StdioServerParameters(command=PY, args=[str(BASE / "mcp_server.py")],
                                   cwd=str(BASE), env=env)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            record("TC-C01", sorted(names) == sorted(
                ["list_tags", "count_memos", "list_memos", "get_memo", "add_memo", "get_stats"]),
                f"{len(names)} 工具")

            # 写入种子
            await session.call_tool("add_memo", {"content": "MCP 集成 #工作/项目"})
            await session.call_tool("add_memo", {"content": "笔记研究 #学习"})
            await session.call_tool("add_memo", {"content": "昨天跑步 #生活", "created_at": "2026-08-08"})

            # TC-C02 list_tags
            r = await session.call_tool("list_tags", {})
            tags = json.loads(r.content[0].text)["tags"]
            record("TC-C02", any(t["name"] == "工作" and t["count"] >= 1 for t in tags), f"{len(tags)} tags")

            # TC-C03 count_memos 组合
            r = await session.call_tool("count_memos", {"tags": ["工作"]})
            record("TC-C03-标签", json.loads(r.content[0].text)["count"] == 1)
            r = await session.call_tool("count_memos", {"start_date": "2026-08-08", "end_date": "2026-08-08"})
            record("TC-C03-日期", json.loads(r.content[0].text)["count"] == 1)
            r = await session.call_tool("count_memos", {"query": "跑步"})
            record("TC-C03-关键词", json.loads(r.content[0].text)["count"] == 1)

            # TC-C04 list_memos 范围读取
            r = await session.call_tool("list_memos", {"tags": ["工作"]})
            d = json.loads(r.content[0].text)
            record("TC-C04-父级匹配", d["total"] == 1 and d["items"][0]["tags"] and "工作" in d["items"][0]["tags"])
            r = await session.call_tool("list_memos", {"start_date": "2026-08-08", "end_date": "2026-08-08", "limit": 5})
            record("TC-C04-日期筛选", json.loads(r.content[0].text)["total"] == 1)
            r = await session.call_tool("list_memos", {"limit": 1, "offset": 0})
            d = json.loads(r.content[0].text)
            record("TC-C04-分页", d["returned"] == 1 and d["total"] >= 3)
            r = await session.call_tool("list_memos", {"preview_length": 4})
            d = json.loads(r.content[0].text)
            record("TC-C04-截断", all(i["content"].endswith("…") for i in d["items"] if len(i["content"]) > 4),
                   f"预览样例: {d['items'][0]['content']!r}")

            # TC-C05 get_memo
            r = await session.call_tool("list_memos", {"limit": 1})
            mid = json.loads(r.content[0].text)["items"][0]["id"]
            r = await session.call_tool("get_memo", {"memo_id": mid})
            d = json.loads(r.content[0].text)
            record("TC-C05", d["id"] == mid and d["content"], f"id={mid}")
            r = await session.call_tool("get_memo", {"memo_id": 99999})
            record("TC-C05-不存在", "error" in json.loads(r.content[0].text))

            # TC-C06 add_memo（多级标签）
            r = await session.call_tool("add_memo", {"content": "新记录 #学习/笔记"})
            d = json.loads(r.content[0].text)
            record("TC-C06", d.get("id") and set(d["tags"]) == {"学习", "学习/笔记"}, f"tags={d.get('tags')}")

            # TC-C07 get_stats
            r = await session.call_tool("get_stats", {})
            d = json.loads(r.content[0].text)
            record("TC-C07", d["total"] >= 4 and "streak_days" in d and "this_week" in d, f"total={d['total']}")

            # TC-C09 一致性：MCP 写入 → 后端 API 可见
            await session.call_tool("add_memo", {"content": "一致性验证 #测试/一致性"})
            api = api_req("GET", "/api/memos?limit=10")
            found = any(i["content"].startswith("一致性验证") for i in api["items"])
            record("TC-C09", found, f"后端可见 {api['total']} 条")


# ---------- HTTP ----------
async def test_http():
    from mcp import ClientSession
    from mcp.client.streamable_http import streamablehttp_client

    async with streamablehttp_client(f"http://127.0.0.1:{HTTP_PORT}/mcp") as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            record("TC-C08", len(tools.tools) == 6, f"{len(tools.tools)} 工具")
            r = await session.call_tool("get_stats", {})
            record("TC-C08-调用", "total" in json.loads(r.content[0].text))


async def main_async():
    await test_stdio()

    env = {**os.environ, "MEMO_DATA_DIR": str(DATA_DIR)}
    proc = subprocess.Popen([PY, str(BASE / "mcp_server.py"), "--http", "--port", str(HTTP_PORT)],
                            cwd=str(BASE), env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        await asyncio.sleep(4)
        await test_http()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()


def main():
    env = {**os.environ, "MEMO_DATA_DIR": str(DATA_DIR)}
    # 后端（供 TC-C09）
    api = subprocess.Popen([PY, str(BASE / "service.py"), "--no-gui", "--port", str(API_PORT)],
                           cwd=str(BASE), env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):
        try:
            api_req("GET", "/api/health")
            break
        except Exception:
            time.sleep(0.5)
    else:
        print("后端启动失败")
        sys.exit(1)

    try:
        asyncio.run(main_async())
    finally:
        api.terminate()
        try:
            api.wait(timeout=5)
        except Exception:
            api.kill()
        shutil.rmtree(DATA_DIR, ignore_errors=True)

    passed = sum(1 for _, ok, _ in results if ok)
    print(f"\n=== MCP 结果: {passed}/{len(results)} 通过 ===")
    for tid, ok, note in results:
        if not ok:
            print(f"  未通过: {tid} {note}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
