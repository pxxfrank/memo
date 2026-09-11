# -*- coding: utf-8 -*-
"""TC-A：后端 API 自动化测试（独立测试库 + 独立端口，测完清理）"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import os
import urllib.request
import urllib.parse
from pathlib import Path

BASE = Path(__file__).resolve().parent
PY = os.environ.get("MEMO_PYTHON", str(BASE / ".venv" / "Scripts" / "python.exe"))
PORT = 8911
DATA_DIR = Path(tempfile.mkdtemp(prefix="memo_test_"))
BASE_URL = f"http://127.0.0.1:{PORT}"

results = []  # (id, ok, note)


def record(tid, ok, note=""):
    results.append((tid, ok, note))
    print(f"  {'PASS' if ok else 'FAIL'}  {tid}  {note}")


def req(method, path, body=None, raw=False):
    data = None
    headers = {}
    if body is not None:
        if isinstance(body, (dict, list)):
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        else:
            data = body.encode("utf-8")
            headers["Content-Type"] = "application/x-www-form-urlencoded"
    r = urllib.request.Request(BASE_URL + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r, timeout=5) as resp:
            content = resp.read()
            return resp.status, (content.decode("utf-8") if raw else json.loads(content))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8", "replace"))


def q(s):
    return urllib.parse.quote(s, safe="")


def main():
    env = {**os.environ, "MEMO_DATA_DIR": str(DATA_DIR)}
    proc = subprocess.Popen(
        [PY, str(BASE / "service.py"), "--no-gui", "--port", str(PORT)],
        cwd=str(BASE), env=env,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # 等待就绪
    for _ in range(40):
        try:
            s, d = req("GET", "/api/health")
            if s == 200 and d.get("ok"):
                break
        except Exception:
            time.sleep(0.5)
    else:
        print("后端启动失败"); sys.exit(1)

    # 种子数据
    req("POST", "/api/memos", {"content": "完成吃豆豆游戏 #工作/项目/游戏"})
    req("POST", "/api/memos", {"content": "研究标签体系 #学习/笔记"})
    req("POST", "/api/memos", {"content": "跑步 5 公里 #生活/运动", "created_at": "2026-08-08 21:30"})

    # TC-A01 健康检查
    s, d = req("GET", "/api/health")
    record("TC-A01", s == 200 and d.get("ok") is True, f"status={s}")

    # TC-A02 创建笔记
    s, d = req("POST", "/api/memos", {"content": "新的想法 #测试"})
    new_id = d.get("id")
    record("TC-A02", s == 201 and new_id and d["content"] == "新的想法 #测试"
           and isinstance(d["created_at"], int) and d["created_at"] > 0, f"id={new_id}")

    # TC-A03 多级标签
    s, d = req("POST", "/api/memos", {"content": "开发日志 #工作/项目/游戏"})
    tags = d.get("tags", [])
    record("TC-A03", set(tags) == {"工作", "工作/项目", "工作/项目/游戏"}, f"tags={tags}")

    # TC-A04 补记时间
    s, d = req("POST", "/api/memos", {"content": "补记 #测试", "created_at": "2026-08-08 21:30"})
    import datetime
    expect = int(datetime.datetime(2026, 8, 8, 21, 30).timestamp() * 1000)
    record("TC-A04", d["created_at"] == expect, f"got={d['created_at']} expect={expect}")

    # TC-A05 列表倒序分页
    s, d = req("GET", "/api/memos?limit=2&offset=0")
    items = d["items"]
    order_ok = all(items[i]["created_at"] >= items[i + 1]["created_at"] for i in range(len(items) - 1))
    record("TC-A05", s == 200 and d["total"] >= 5 and len(items) == 2 and order_ok,
           f"total={d['total']} len={len(items)}")

    # TC-A06 标签筛选（父含子级）
    s, d = req("GET", "/api/memos?tag=" + q("工作"))
    ids_work = {i["id"] for i in d["items"]}
    s2, d2 = req("GET", "/api/memos?tag=" + q("工作/项目"))
    record("TC-A06", len(ids_work) >= 2 and ids_work >= {i["id"] for i in d2["items"]},
           f"工作={len(ids_work)} 工作/项目={len(d2['items'])}")

    # TC-A07 关键词搜索
    s, d = req("GET", "/api/memos?q=" + q("跑步"))
    record("TC-A07", d["total"] >= 1 and all("跑步" in i["content"] for i in d["items"]),
           f"total={d['total']}")

    # TC-A08 标签+搜索叠加
    s, d = req("GET", "/api/memos?tag=" + q("工作") + "&q=" + q("游戏"))
    record("TC-A08", d["total"] >= 1, f"total={d['total']}")

    # TC-A09 编辑
    s, d = req("PUT", f"/api/memos/{new_id}", {"content": "编辑后内容 #新标签"})
    record("TC-A09", s == 200 and d["content"] == "编辑后内容 #新标签"
           and "新标签" in d["tags"] and d["updated_at"] is not None, f"tags={d['tags']}")

    # TC-A10 置顶
    s, d = req("PUT", f"/api/memos/{new_id}", {"pinned": True})
    s2, d2 = req("GET", "/api/memos?limit=1")
    record("TC-A10", d["pinned"] is True and d2["items"][0]["id"] == new_id, f"first={d2['items'][0]['id']}")

    # TC-A11 删除
    s, d = req("DELETE", f"/api/memos/{new_id}")
    s2, d2 = req("GET", "/api/memos?limit=50")
    record("TC-A11", s == 200 and all(i["id"] != new_id for i in d2["items"]), "删除后不可见")

    # TC-A12 清空（先记录数量用于后续测试）
    s, d = req("DELETE", "/api/memos")
    s2, d2 = req("GET", "/api/stats")
    record("TC-A12", s == 200 and d2["total"] == 0, f"total={d2['total']}")

    # 重建数据供导出/统计
    req("POST", "/api/memos", {"content": "项目总结 #工作/项目"})
    req("POST", "/api/memos", {"content": "学习记录 #学习"})

    # TC-A13 标签列表
    s, d = req("GET", "/api/tags")
    m = {t["name"]: t["count"] for t in d["tags"]}
    record("TC-A13", m.get("工作", 0) >= 1 and m.get("学习") == 1, f"tags={m}")

    # TC-A14 统计
    s, d = req("GET", "/api/stats?days=30")
    record("TC-A14", "days" in d and len(d["days"]) == 30 and d["total"] >= 2
           and isinstance(d["streak"], int) and isinstance(d["thisWeek"], int),
           f"total={d['total']} streak={d['streak']} days={len(d['days'])}")

    # TC-A15 flomo 兼容（JSON + 表单）
    s1, d1 = req("POST", "/v1/memo", {"content": "JSON 写入 #兼容"})
    s2, d2 = req("POST", "/v1/memo", "content=表单写入+%23兼容")
    record("TC-A15", s1 == 201 and s2 == 201 and "兼容" in d1["data"]["content"]
           and "兼容" in d2["data"]["content"], f"json={s1} form={s2}")

    # TC-A16 导出三种格式
    for fmt in ("json", "md", "csv"):
        s, d = req("GET", f"/api/export?format={fmt}", raw=True)
        record("TC-A16-" + fmt, s == 200 and len(d) > 50, f"{fmt} len={len(d)}")

    # TC-A17 导入闭环
    s, exp = req("GET", "/api/export?format=json", raw=True)
    memos = json.loads(exp)
    n_before = len(memos)
    req("DELETE", "/api/memos")
    s, d = req("POST", "/api/import", {"data": memos})
    s2, d2 = req("GET", "/api/stats")
    record("TC-A17", d["imported"] == n_before and d2["total"] == n_before,
           f"导出{n_before} 导入{d['imported']} 现存{d2['total']}")

    # TC-A18 配置读写
    s, d = req("POST", "/api/config", {"review_time": "08:00", "review_count": 5})
    s2, d2 = req("GET", "/api/config")
    record("TC-A18", d2.get("review_time") == "08:00" and d2.get("review_count") == 5, f"cfg={d2.get('review_time')}")

    # TC-A19 静态托管
    ok = True
    for p in ("/", "/manifest.json", "/sw.js"):
        s, _ = req("GET", p, raw=True)
        ok = ok and s == 200
    record("TC-A19", ok, "index/manifest/sw 均 200")

    # TC-A20 错误处理
    s1, d1 = req("POST", "/api/memos", {"content": "  "})
    s2, d2 = req("DELETE", "/api/memos/99999")
    s3, d3 = req("GET", "/api/memos/abc")
    record("TC-A20", s1 == 400 and s2 == 404 and s3 == 404,
           f"空content={s1} 删不存在={s2} 路由={s3}")

    # TC-A21 特殊字符
    evil = "<script>alert(1)</script> & \"quote\" #注入"
    s, d = req("POST", "/api/memos", {"content": evil})
    s2, d2 = req("GET", f"/api/memos?q={q('<script>')}")
    record("TC-A21", d["content"] == evil and d2["total"] >= 1, "原样存储且可检索")

    # 汇总
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except Exception:
        proc.kill()
    shutil.rmtree(DATA_DIR, ignore_errors=True)

    passed = sum(1 for _, ok, _ in results if ok)
    print(f"\n=== 后端 API 结果: {passed}/{len(results)} 通过 ===")
    for tid, ok, note in results:
        if not ok:
            print(f"  未通过: {tid} {note}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
