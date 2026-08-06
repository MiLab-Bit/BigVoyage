#!/usr/bin/env python3
"""Sidecar: field map → leo run/execute · wallet-bridge · LiveOps"""
from __future__ import annotations

import json
import os
import secrets
import subprocess
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from field_mapper import map_commit_payload

HOST, PORT = "127.0.0.1", 8787
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
LEO_DIR = REPO / "programs" / "bv_commit"
OPS_DB = ROOT / "ops_state.json"
WALLET_DB = ROOT / "wallet_dev.json"
WALLET_BRIDGE = os.environ.get("WALLET_BRIDGE_URL", "http://127.0.0.1:8788")
HASH_ALG = "poseidon8_snarkvm_v1"

_lock = threading.Lock()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def _save_json(path: Path, obj) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")


def _find_leo() -> str | None:
    env = os.environ.get("LEO_BIN")
    if env and Path(env).exists():
        return env
    candidates = [
        REPO.parent / "tools" / "leo" / "leo.exe",
        Path(r"C:\tools\leo\leo.exe"),
        Path.home() / ".cargo" / "bin" / "leo.exe",
        Path.home() / ".cargo" / "bin" / "leo",
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    # PATH
    from shutil import which

    return which("leo")


def _leo_run_commit(mapped: dict) -> dict:
    leo = _find_leo()
    if not leo:
        return {"ok": False, "error": "leo_not_found", "hint": "Run tools/install_leo.ps1 or cargo install leo-lang"}
    if not LEO_DIR.exists():
        return {"ok": False, "error": "program_missing", "path": str(LEO_DIR)}
    args = [
        leo,
        "run",
        "commit_battle",
        mapped["ruleset_h"],
        mapped["fleets_h"],
        mapped["env_h"],
        mapped["seed"],
        mapped["winner"],
        mapped["rounds"],
        mapped["log_root"],
        mapped["season"],
    ]
    try:
        # version probe
        subprocess.run([leo, "--version"], capture_output=True, check=True, timeout=20)
    except Exception as e:
        return {"ok": False, "error": f"leo_crash_or_missing:{e}", "leo_bin": leo}
    try:
        proc = subprocess.run(
            args,
            cwd=str(LEO_DIR),
            capture_output=True,
            text=True,
            timeout=180,
        )
    except Exception as e:
        return {"ok": False, "error": f"leo_run_failed:{e}", "cmd": args}
    out = (proc.stdout or "") + "\n" + (proc.stderr or "")
    commit = _parse_commit_from_leo_output(out)
    return {
        "ok": proc.returncode == 0 and bool(commit),
        "returncode": proc.returncode,
        "commit": commit,
        "stdout": proc.stdout[-4000:] if proc.stdout else "",
        "stderr": proc.stderr[-2000:] if proc.stderr else "",
        "cmd": args,
        "hash_alg": HASH_ALG,
        "leo_bin": leo,
    }


def _parse_commit_from_leo_output(text: str) -> str:
    # Look for `commit: <digits>field` or similar
    import re

    m = re.search(r"commit:\s*([0-9]+)field", text)
    if m:
        return m.group(1)
    m = re.search(r"\b([0-9]{20,})field\b", text)
    if m:
        return m.group(1)
    return ""


def _wallet_bridge(path: str, payload: dict | None = None) -> dict:
    url = WALLET_BRIDGE.rstrip("/") + path
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = Request(url, data=data, method="GET" if payload is None else "POST")
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return {"ok": False, "error": f"wallet_bridge:{e}"}


class Handler(BaseHTTPRequestHandler):
    def _json(self, code: int, obj: dict) -> None:
        raw = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(raw)

    def _read(self) -> dict:
        n = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(n) if n else b"{}"
        try:
            return json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return {}

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/health":
            leo = _find_leo()
            wb = _wallet_bridge("/health")
            self._json(
                200,
                {
                    "ok": True,
                    "service": "bv-sidecar",
                    "hash_alg": HASH_ALG,
                    "leo_bin": leo,
                    "wallet_bridge": wb,
                    "ts": _now(),
                },
            )
            return
        if path == "/wallet":
            self._json(200, _wallet_bridge("/wallet/address"))
            return
        if path == "/ops/events":
            db = _load_json(OPS_DB, {"events": [], "announcements": []})
            self._json(200, {"ok": True, **db})
            return
        self._json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        data = self._read()
        if path == "/commit":
            mapped = map_commit_payload(data)
            leo_result = _leo_run_commit(mapped)
            # Also offer wallet-bridge execute (network or offline cmd)
            inputs = [
                mapped["ruleset_h"],
                mapped["fleets_h"],
                mapped["env_h"],
                mapped["seed"],
                mapped["winner"],
                mapped["rounds"],
                mapped["log_root"],
                mapped["season"],
            ]
            wb = _wallet_bridge(
                "/execute",
                {
                    "program": "bv_commit.aleo",
                    "function": "commit_battle",
                    "inputs": inputs,
                    "offline": not bool(data.get("broadcast", False)),
                },
            )
            commit = leo_result.get("commit") or ""
            self._json(
                200,
                {
                    "ok": bool(leo_result.get("ok") or wb.get("ok")),
                    "commit": commit,
                    "hash_alg": HASH_ALG,
                    "mapped": mapped,
                    "leo": leo_result,
                    "wallet_execute": wb,
                    "program": "bv_commit.aleo",
                    "island_id": data.get("island_id"),
                    "ts": _now(),
                    "note": "Fund wallet + leo build before broadcast=true",
                },
            )
            return
        if path == "/wallet/create":
            r = _wallet_bridge("/wallet/create", {})
            if r.get("ok"):
                _save_json(WALLET_DB, {"address": r.get("address"), "via": "provable_sdk", "ts": _now()})
            self._json(200, r)
            return
        if path == "/wallet/connect":
            r = _wallet_bridge("/wallet/address")
            self._json(200, {**r, "connected": bool(r.get("ok"))})
            return
        if path == "/ops/announce":
            with _lock:
                db = _load_json(OPS_DB, {"events": [], "announcements": []})
                db.setdefault("announcements", []).append(
                    {"msg": data.get("msg", ""), "ts": _now(), "author": data.get("author", "ops")}
                )
                _save_json(OPS_DB, db)
            self._json(200, {"ok": True})
            return
        if path == "/ops/event_upsert":
            with _lock:
                db = _load_json(OPS_DB, {"events": [], "announcements": []})
                ev = data.get("event") or data
                events = db.setdefault("events", [])
                eid = str(ev.get("id", ""))
                for i, e in enumerate(events):
                    if str(e.get("id")) == eid:
                        events[i] = ev
                        break
                else:
                    events.append(ev)
                _save_json(OPS_DB, db)
            self._json(200, {"ok": True})
            return
        self._json(404, {"ok": False, "error": "not_found"})

    def log_message(self, fmt: str, *args) -> None:
        print("[sidecar]", fmt % args)


if __name__ == "__main__":
    print(f"[sidecar] http://{HOST}:{PORT} hash={HASH_ALG} leo={_find_leo()}")
    HTTPServer((HOST, PORT), Handler).serve_forever()
