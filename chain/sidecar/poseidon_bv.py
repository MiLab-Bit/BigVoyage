"""LEGACY poseidon8_soft_v1 — DO NOT use for new commits.

Authoritative path: snarkVM Poseidon8 via `leo run commit_battle`
(see HASH_FREEZE.md · poseidon8_snarkvm_v1). This module remains only so
old receipts / offline tools can still verify soft_v1 digests.
"""
from __future__ import annotations

import warnings

warnings.warn(
    "poseidon_bv soft_v1 is obsolete; use leo Poseidon8 / field_mapper",
    DeprecationWarning,
    stacklevel=2,
)

MOD = (1 << 61) - 1  # soft field — NOT BN254
HASH_ALG = "poseidon8_soft_v1"


def commit_battle(_payload: dict) -> str:
    raise RuntimeError(
        "soft_v1 commits disabled. Call Sidecar /commit (leo run) for poseidon8_snarkvm_v1."
    )
