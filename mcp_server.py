#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MEMO · MCP Server
让任意 AI Agent（Claude Desktop / Cherry Studio / Cline / Cursor / 自研 Agent 等）
通过 MCP 协议读取 / 写入本机笔记。

核心设计：读取必须按范围进行 —— 支持 tags（多级标签）、start_date / end_date（日期）、
query（关键词）筛选，配合 limit / offset 分页与 preview_length 截断，
避免把整个笔记库一次性灌给 AI。

用法：
    python mcp_server.py                          # stdio 模式（Claude Desktop 等 CLI 客户端）
    python mcp_server.py --http --port 8898       # Streamable HTTP（Cherry Studio / Cursor 等）
"""
import argparse
import sys
from datetime import datetime
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from memo_common import (
    compute_stats,
    db_session,
    insert_memo,
    normalize_ts,
    now_ms,
    parse_tags,
    resolve_data_dir,
)

BASE = Path(__file__).resolve().parent
# 数据目录：优先 MEMO_DATA_DIR（桌面版会设置），打包运行回退 %APPDATA%\memo\data
DATA_DIR = resolve_data_dir(BASE)
DB_PATH = DATA_DIR / "memo.db"


# MCP stdio 模式 stdout 被协议占用，日志一律走 stderr
def log(*a):
    print(*a, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# MCP Server
# ---------------------------------------------------------------------------
mcp = FastMCP(
    "memo",
    instructions=(
        "这是本机私有笔记库（类 flomo）。读取时务必用 tags / start_date / end_date / query 缩小范围，"
        "不要一次性拉取全部笔记。多级标签形如 工作/项目：按 工作 筛选会包含其全部子标签。"
        "日期格式 YYYY-MM-DD（含边界，按本地时区）。先 count_memos 探数量，再 list_memos 取数据。"
    ),
)


def _build_filters(tags, start_date, end_date, query):
    where, params = [], []
    for t in tags or []:
        where.append(
            "EXISTS (SELECT 1 FROM memo_tags mt WHERE mt.memo_id=m.id "
            "AND (mt.name=? OR mt.name LIKE ?))")
        params += [t, t + "/%"]
    if start_date:
        where.append("date(m.created_at/1000,'unixepoch','localtime') >= ?")
        params.append(start_date)
    if end_date:
        where.append("date(m.created_at/1000,'unixepoch','localtime') <= ?")
        params.append(end_date)
    if query:
        where.append("m.content LIKE ?")
        params.append("%" + query + "%")
    wsql = ("WHERE " + " AND ".join(where)) if where else ""
    return wsql, params


@mcp.tool(description="列出笔记库中所有标签及其使用次数（了解有哪些标签可用于筛选）")
def list_tags() -> dict:
    """返回所有标签（含多级标签的各级路径）与使用次数，按次数降序。"""
    with db_session(DB_PATH) as conn:
        rows = conn.execute(
            "SELECT name, count FROM tags WHERE count>0 ORDER BY count DESC, name").fetchall()
    return {"tags": [{"name": r["name"], "count": r["count"]} for r in rows]}


@mcp.tool(description="统计符合条件的笔记数量（读取前先用它探规模）")
def count_memos(
    tags: list[str] | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    query: str | None = None,
) -> dict:
    """按标签/日期/关键词统计条数。tags 为标签路径列表（如 ['工作', '学习']）；日期为 YYYY-MM-DD。"""
    wsql, params = _build_filters(tags, start_date, end_date, query)
    with db_session(DB_PATH) as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM memos m {wsql}", params).fetchone()["c"]
    return {
        "count": total,
        "filters": {
            "tags": tags, "start_date": start_date, "end_date": end_date, "query": query,
        },
    }


@mcp.tool(description="按条件读取笔记列表（推荐用标签或日期范围缩小结果，支持分页与截断）")
def list_memos(
    tags: list[str] | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    query: str | None = None,
    limit: int = 20,
    offset: int = 0,
    preview_length: int | None = None,
) -> dict:
    """按标签/日期/关键词筛选读取笔记，倒序分页返回。

    - tags: 标签路径数组（如 ['工作'] 或 ['工作/项目']），多级匹配子标签
    - start_date / end_date: YYYY-MM-DD，含边界
    - query: 正文关键词
    - limit: 每页条数（1-100，默认 20）
    - offset: 分页偏移
    - preview_length: 设置后只返回正文前 N 字（节省 token），不设置返回全文
    """
    limit = max(1, min(int(limit), 100))
    offset = max(0, int(offset))
    wsql, params = _build_filters(tags, start_date, end_date, query)
    with db_session(DB_PATH) as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM memos m {wsql}", params).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT m.id, m.content, m.created_at, m.pinned,
                       (SELECT GROUP_CONCAT(mt.name) FROM memo_tags mt WHERE mt.memo_id=m.id) AS tag_list
                FROM memos m {wsql}
                ORDER BY m.created_at DESC LIMIT ? OFFSET ?""",
            params + [limit, offset]).fetchall()
    items = []
    for r in rows:
        content = r["content"]
        if preview_length is not None and preview_length > 0:
            if len(content) > preview_length:
                content = content[:preview_length] + "…"
        items.append({
            "id": r["id"],
            "content": content,
            "created_at": r["created_at"],
            "created_date": datetime.fromtimestamp(r["created_at"] / 1000).strftime("%Y-%m-%d %H:%M"),
            "pinned": bool(r["pinned"]),
            "tags": [x for x in (r["tag_list"] or "").split(",") if x],
        })
    return {"total": total, "returned": len(items), "offset": offset, "items": items}


@mcp.tool(description="按 id 读取单条笔记的完整内容（含标签）")
def get_memo(memo_id: int) -> dict:
    """获取一条笔记全文。"""
    with db_session(DB_PATH) as conn:
        r = conn.execute("SELECT * FROM memos WHERE id=?", (int(memo_id),)).fetchone()
        if not r:
            return {"error": f"笔记 {memo_id} 不存在"}
        tags = [x[0] for x in conn.execute(
            "SELECT name FROM memo_tags WHERE memo_id=?", (r["id"],))]
        result = {
            "id": r["id"],
            "uuid": r["uuid"],
            "content": r["content"],
            "created_at": r["created_at"],
            "created_date": datetime.fromtimestamp(r["created_at"] / 1000).strftime("%Y-%m-%d %H:%M"),
            "pinned": bool(r["pinned"]),
            "tags": tags,
        }
    return result


@mcp.tool(description="写入一条新笔记，支持 #标签 与多级标签（如 #工作/日报）")
def add_memo(content: str, created_at: str | None = None) -> dict:
    """向笔记库写入一条内容。created_at 可选：ISO 时间或 YYYY-MM-DD，缺省为当前时间。"""
    content = (content or "").strip()
    if not content:
        return {"error": "content 不能为空"}
    ts = normalize_ts(created_at) if created_at else now_ms()
    with db_session(DB_PATH) as conn:
        # insert_memo 统一生成 uuid + 建标签索引（保证可参与云同步）
        mid = insert_memo(conn, content, ts)
        memo_uuid = conn.execute("SELECT uuid FROM memos WHERE id=?", (mid,)).fetchone()["uuid"]
    log(f"add_memo: id={mid} uuid={memo_uuid}")
    return {"id": mid, "uuid": memo_uuid, "content": content, "tags": sorted(parse_tags(content))}


@mcp.tool(description="笔记库统计：总数、连续记录天数、本周新增")
def get_stats() -> dict:
    """获取统计信息。"""
    with db_session(DB_PATH) as conn:
        stats = compute_stats(conn, days=0)  # 0：不需要逐日序列
    return {
        "total": stats["total"],
        "streak_days": stats["streak"],
        "this_week": stats["thisWeek"],
    }


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="MEMO MCP Server")
    ap.add_argument("--http", action="store_true",
                    help="以 Streamable HTTP 模式运行（默认 stdio）")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8898)
    args = ap.parse_args()

    log(f"MEMO MCP Server 启动，数据源: {DB_PATH}")
    if args.http:
        mcp.settings.host = args.host
        mcp.settings.port = args.port
        log(f"Streamable HTTP 模式: http://{args.host}:{args.port}/mcp")
        mcp.run(transport="streamable-http")
    else:
        log("stdio 模式（等待客户端连接）")
        mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
