# Aleo 链上工程骨架（穿刺用）

> **状态**：骨架 / GAPS 探针 · **非**可部署生产程序  
> **上游**：`架构与技术/aleo-onchain-architecture.md` · ADR-003 · `control-manifest.md`  
> **前置**：战斗核 BLK-1 定点化（`client/systems/ResolveBattle.gd`）已开工；L3 决斗电路仍待规格降维

## 目录

```
chain/
├── README.md                 ← 本文件
├── gaps/                     ← 知识缺口探针记录（G-01…）
│   └── G-01_constraint_budget.md
├── programs/
│   └── bv_commit/            ← L1 承诺程序骨架（字段集对齐 RULESET）
│       ├── program.json
│       └── src/main.leo
└── sidecar/                  ← 本地 Sidecar 占位（dev：mock → 真链）
    └── README.md
```

## 分层对照（ADR-003）

| 层 | 职责 | 本目录对应 | Demo 可否 mock |
|---|---|---|---|
| L1 | 战果承诺（ruleset∥fleets∥env∥seed∥winner∥rounds∥log_root） | `programs/bv_commit` | ✅ 可 mock |
| L2 | 编队合法性 / 输入证明 | ⚠待定（P1） | ✅ |
| L2.5 | 挑战窗口 | ⚠待定 | ✅ |
| L3 | 3-slot / COST≤6 / ≤8 回合决斗电路 | 依赖定点核 + A-01 | Demo 可 mock |

## 本地工具链（未装则只读骨架）

```bash
# 安装后于 programs/bv_commit 执行
leo build
leo run commit_battle ...
```

## 红线

1. 承诺字段集与 `EngineLock.RULESET_HASH_DESIGN` / ResolveBattle payload **同序**；链侧 Poseidon8 替换 SHA-256 时必须重冻。
2. 禁止把完整 5v5×30 回合塞进单一 transition（见 G-01）。
3. Demo 默认 `CHAIN_MOCK=true`（`client/data/constants.json`）。
