#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MEMO 云同步引擎（坚果云 · 变更日志方案，见 SYNC-DESIGN.md）

职责：
- 本地每次写操作追加一条变更日志到 {device}.jsonl（坚果云同步目录或本地）
- 定时拉取其他设备日志，按 id+ts 做 last-write-wins 合并（幂等可重放）
- 端到端加密：配置 sync.passphrase 后日志全密文（AES-256-GCM，PBKDF2 派生密钥），
  坚果云/账号泄露者只能看到密文；未配置口令时保持明文（兼容旧日志）
"""
import base64
import json
import os
import sqlite3
import sys
import threading
import time

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

from memo_common import new_uuid, parse_tags, rebuild_tag_counts, set_memo_tags

_ITERATIONS = 200_000


def log(msg):
    print(f"[sync] {msg}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# 端到端加密（AES-256-GCM）
# ---------------------------------------------------------------------------
class SyncCrypto:
    def __init__(self, passphrase, salt_hex=None):
        self.enabled = bool(passphrase)
        self.salt = None
        self.salt_hex = ""
        self.key = None
        if not self.enabled:
            return
        if salt_hex:
            self.salt = bytes.fromhex(salt_hex)
        else:
            self.salt = os.urandom(16)
        self.salt_hex = self.salt.hex()
        kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32,
                         salt=self.salt, iterations=_ITERATIONS)
        self.key = kdf.derive(passphrase.encode("utf-8"))

    def encrypt_line(self, text):
        """text → base64(nonce12 + tag16 + ciphertext)"""
        nonce = os.urandom(12)
        enc = Cipher(algorithms.AES(self.key), modes.GCM(nonce)).encryptor()
        ct = enc.update(text.encode("utf-8")) + enc.finalize()
        return base64.b64encode(nonce + enc.tag + ct).decode("ascii")

    def decrypt_line(self, line):
        """解密一行；非法/口令错误时抛异常"""
        raw = base64.b64decode(line.strip())
        nonce, tag, ct = raw[:12], raw[12:28], raw[28:]
        dec = Cipher(algorithms.AES(self.key), modes.GCM(nonce, tag)).decryptor()
        return (dec.update(ct) + dec.finalize()).decode("utf-8")


class SyncEngine:
    def __init__(self, data_dir, db_path, config_provider, device="desktop"):
        self.data_dir = data_dir
        self.db_path = db_path
        self.get_config = config_provider
        self._lock = threading.Lock()
        self._state_path = os.path.join(data_dir, "sync-state.json")
        self.device = device
        self._crypto = None  # 缓存
        self._crypto_key = None  # 缓存键（passphrase, salt）

    # ---------- 加密 ----------
    def _get_crypto(self):
        cfg = (self.get_config().get("sync", {}) or {})
        passphrase = cfg.get("passphrase") or ""
        salt = cfg.get("salt") or None
        # 缓存键含口令 + 盐指纹：改口令/换盐后即时重建密钥，无需重启
        fingerprint = (passphrase, salt)
        if self._crypto is not None and self._crypto_key == fingerprint:
            return self._crypto
        self._crypto = SyncCrypto(passphrase, salt)
        self._crypto_key = fingerprint
        return self._crypto

    # ---------- 路径 ----------
    def _sync_dir(self):
        cfg = self.get_config().get("sync", {}) or {}
        return cfg.get("dir") or os.path.join(self.data_dir, "sync")

    def _log_path(self, device):
        return os.path.join(self._sync_dir(), f"{device}.jsonl")

    # ---------- 日志读写（含加密转换） ----------
    def _read_lines(self, path):
        """读取日志全部行，密文/明文自动识别（解密失败按明文；# 开头的 salt 头跳过）"""
        if not os.path.exists(path):
            return [], 0
        crypto = self._get_crypto()
        fail = 0
        lines = []
        with open(path, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if not ln or ln.startswith("#"):
                    continue
                if crypto.enabled:
                    try:
                        lines.append(crypto.decrypt_line(ln))
                    except Exception:
                        lines.append(ln)  # 兼容明文/无法解密
                        fail += 1
                else:
                    lines.append(ln)
        return lines, fail

    def _rewrite(self, path, lines):
        """按当前加密模式重写日志（明文↔密文无损转换）"""
        crypto = self._get_crypto()
        with open(path, "w", encoding="utf-8") as f:
            if crypto.enabled:
                f.write(f"#salt={crypto.salt_hex}\n")  # salt 非敏感，明文随日志同步
            for text in lines:
                out = crypto.encrypt_line(text) if crypto.enabled else text
                f.write(out + "\n")
            f.flush()
            os.fsync(f.fileno())

    def _append(self, device, entry):
        path = self._log_path(device)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        crypto = self._get_crypto()
        text = json.dumps(entry, ensure_ascii=False)
        out = crypto.encrypt_line(text) if crypto.enabled else text
        with open(path, "a", encoding="utf-8") as f:
            if crypto.enabled and (not os.path.exists(path) or os.path.getsize(path) == 0):
                f.write(f"#salt={crypto.salt_hex}\n")  # 新建加密日志时写入 salt 头
            f.write(out + "\n")
            f.flush()
            os.fsync(f.fileno())

    # ---------- 写日志 ----------
    def log_op(self, op, memo=None, **kw):
        entry = {"op": op, "ts": int(time.time() * 1000), "dev": self.device}
        if memo is not None:
            entry.update({
                "id": memo["uuid"], "content": memo["content"],
                "created_at": memo["created_at"], "pinned": bool(memo["pinned"]),
            })
        entry.update(kw)
        with self._lock:
            # 加密模式与文件现状不一致时，先无损转换（明文→密文）
            path = self._log_path(self.device)
            if os.path.exists(path) and os.path.getsize(path) > 0:
                if self._get_crypto().enabled:
                    lines, _ = self._read_lines(path)
                    if lines and self._looks_plain(lines):
                        self._rewrite(path, lines)
            self._append(self.device, entry)

    @staticmethod
    def _looks_plain(lines):
        """启发式：首行是合法 JSON 文本 → 明文日志"""
        try:
            json.loads(lines[0])
            return True
        except Exception:
            return False

    def ensure_full_dump(self):
        """首次启用同步时，把存量数据 dump 为 add 日志（密文/明文随配置）"""
        with self._lock:
            path = self._log_path(self.device)
            if os.path.exists(path) and os.path.getsize(path) > 0:
                return
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                "SELECT uuid, content, created_at, pinned FROM memos ORDER BY created_at").fetchall()
            conn.close()
            for r in rows:
                self._append(self.device, {
                    "op": "add", "ts": (r["created_at"] or 1) - 1, "dev": self.device,
                    "id": r["uuid"], "content": r["content"],
                    "created_at": r["created_at"], "pinned": bool(r["pinned"]),
                })

    # ---------- 拉取合并 ----------
    def _load_state(self):
        try:
            with open(self._state_path, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def _save_state(self, state):
        with open(self._state_path, "w", encoding="utf-8") as f:
            json.dump(state, f, ensure_ascii=False, indent=1)

    def pull_and_merge(self):
        """拉取其他所有设备的日志并合并，返回 (应用条数, 解密失败条数)"""
        sync_dir = self._sync_dir()
        if not os.path.isdir(sync_dir):
            return 0, 0
        with self._lock:
            state = self._load_state()
            total = 0
            fail = 0
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            try:
                for fname in sorted(os.listdir(sync_dir)):
                    if not fname.endswith(".jsonl"):
                        continue
                    device = fname[:-6]
                    if device == self.device:
                        continue
                    lines, lfail = self._read_lines(os.path.join(sync_dir, fname))
                    fail += lfail
                    key = f"line_{device}"
                    start = int(state.get(key, 0))
                    if start > len(lines):
                        start = 0  # 远端被替换过，从头重放（幂等）
                    for ln in lines[start:]:
                        try:
                            entry = json.loads(ln)
                        except Exception:
                            fail += 1
                            continue
                        if self._apply(conn, entry):
                            total += 1
                    state[key] = len(lines)
            finally:
                conn.commit()
                conn.close()
            self._save_state(state)
            return total, fail

    def _local_ts(self, row):
        if row is None:
            return 0
        return (row["updated_at"] or row["created_at"] or 0)

    def _apply(self, conn, e):
        op, eid, ts = e.get("op"), e.get("id"), int(e.get("ts") or 0)
        if not eid:
            return False
        row = conn.execute("SELECT * FROM memos WHERE uuid=?", (eid,)).fetchone()

        if op == "delete":
            if row and ts > self._local_ts(row):
                conn.execute("DELETE FROM memos WHERE uuid=?", (eid,))
                conn.execute("DELETE FROM memo_tags WHERE memo_id=?", (row["id"],))
                rebuild_tag_counts(conn)
                return True
            return False

        if op == "pin":
            if row and ts > self._local_ts(row):
                conn.execute("UPDATE memos SET pinned=? WHERE uuid=?",
                             (1 if e.get("pinned") else 0, eid))
                return True
            return False

        if op in ("add", "update"):
            if row and ts <= self._local_ts(row):
                return False  # 本地更新/相同，跳过
            content = e.get("content") or (row["content"] if row else "")
            if not content:
                return False
            created = e.get("created_at") or (row["created_at"] if row else int(time.time() * 1000))
            pinned = 1 if e.get("pinned") else 0
            if row:
                conn.execute(
                    "UPDATE memos SET content=?, created_at=?, updated_at=?, pinned=? WHERE uuid=?",
                    (content, created, ts, pinned, eid))
                mid = row["id"]
            else:
                cur = conn.execute(
                    "INSERT INTO memos(uuid, content, created_at, updated_at, pinned) "
                    "VALUES(?,?,?,?,?)",
                    (eid, content, created, ts, pinned))
                mid = cur.lastrowid
            set_memo_tags(conn, mid, parse_tags(content))
            return True
        return False

    # ---------- 定时同步 ----------
    def loop(self, interval=15.0):
        while True:
            try:
                if self.get_config().get("sync", {}).get("dir"):
                    applied, failed = self.pull_and_merge()
                    if applied or failed:
                        log(f"pull_and_merge: applied={applied} failed={failed}")
            except Exception as e:
                # 同步长期失败需可感知（不再静默吞异常）
                log(f"loop error: {e}")
            time.sleep(interval)
