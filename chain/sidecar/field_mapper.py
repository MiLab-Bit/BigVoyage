"""design hex / ints → Aleo snarkVM field (BN254 Fr)"""
from __future__ import annotations

# BN254 scalar field modulus (Aleo / snarkVM)
FIELD_MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617


def hex_to_field(hex_str: str) -> int:
    h = hex_str.strip()
    if h.startswith(("0x", "0X")):
        h = h[2:]
    if not h:
        h = "0"
    if len(h) > 64:
        h = h[-64:]
    h = h.zfill(64)
    n = int(h, 16)
    return n % FIELD_MODULUS


def int_to_field(v: int) -> int:
    return int(v) % FIELD_MODULUS


def field_to_leo(v: int) -> str:
    """Leo CLI literal: <decimal>field"""
    return f"{int_to_field(v)}field"


def winner_code(winner: str | int) -> int:
    if winner in (1, "1", "A", "a"):
        return 1
    if winner in (2, "2", "B", "b"):
        return 2
    return 0


def map_commit_payload(data: dict) -> dict:
    """Map HTTP/JSON commit body → Leo transition inputs."""
    ruleset = data.get("ruleset_hash") or data.get("ruleset_h") or data.get("hash") or "0"
    fleets = data.get("fleets_h") or data.get("hash") or "0"
    env = data.get("env_h") or "0"
    log_root = data.get("log_root") or data.get("hash") or "0"
    return {
        "ruleset_h": field_to_leo(hex_to_field(str(ruleset))),
        "fleets_h": field_to_leo(hex_to_field(str(fleets))),
        "env_h": field_to_leo(hex_to_field(str(env))),
        "seed": f"{int(data.get('seed', 0))}u64",
        "winner": f"{winner_code(data.get('winner', 0))}u8",
        "rounds": f"{int(data.get('rounds', 0))}u8",
        "log_root": field_to_leo(hex_to_field(str(log_root))),
        "season": f"{int(data.get('season', 1))}u32",
        "fields_decimal": {
            "ruleset_h": hex_to_field(str(ruleset)),
            "fleets_h": hex_to_field(str(fleets)),
            "env_h": hex_to_field(str(env)),
            "log_root": hex_to_field(str(log_root)),
        },
    }
