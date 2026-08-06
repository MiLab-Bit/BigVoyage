# G2 · 引擎冻结裁决（Godot）

> **状态**：✅ **已决** · **日期**：2026-08-06 · **拍板**：用户确认「G2=Godot」
> **权威位阶**：与 `00-口径冻结表_SSOT.md` 同级决策闸；冲突时本文件仅管**引擎/客户端运行时**，战斗/经济常量仍以 `RULESET_LOCK` 为准。
> **工程落点**：`client/`（Godot 4.7 Forward+ · A 轮 main 恢复 + G2 标注）

---

## 1. 裁决

| 项 | 结论 |
|---|---|
| **客户端引擎** | **Godot 4.x（工程锁定 `4.7` Forward+）** |
| Unity | ❌ 否决（与现有 GDScript 战斗核 / Aleo ADR 割裂） |
| 纯 Web 原生客户端 | ❌ 否决作主客户端；**允许** Godot Web 导出作比赛演示轨 |
| 链 | **Aleo**（不变；见 `架构与技术/`） |
| 音频实现层 | **Godot AudioServer（桌面）+ WebAudio（Web 导出）**；事件 ID 真源仍为音频圣经 119 条 |
| 美术实现层 | 收敛 **Godot Shader / GPUParticles** 单轨；Unity URP 草案作废 |

---

## 2. 仓库布局（G2 落地后）

```
大航海/
├── client/                 ← Godot 工程（可 F5 运行）
├── 架构与技术/              ← Aleo ADR / 链上架构（已收回，引擎=Godot）
├── 数据层/ · 玩法与系统/ …  ← 设计真源（不变）
└── 00-G2引擎冻结_Godot.md   ← 本文件
```

- 设计数值真源：`数据层/`（含 `RULESET_LOCK` / `constants.md` / `cards.json`）
- 运行时数据副本：`client/data/*.json`（Demo 用；改口径须先改设计层再同步）

---

## 3. 工程立即约束（P0，不阻塞 G2 冻结本身）

| ID | 项 | 状态 |
|---|---|---|
| BLK-1 | 战斗核定点化（跨端一致） | ⚠ 代码仍浮点；设计已要求，工程待合入 |
| BLK-2 | 战报承诺禁截断 + 绑定编队/env/ruleset | ✅ G2 落地时已在 `client/systems/ResolveBattle.gd` 修截断；Poseidon 待链侧 |
| G-01~G-06 | Aleo 真机穿刺 | 仍按 `架构与技术/GAPS_PENETRATION.md` |

---

## 4. 下游回写清单

- [x] `00-口径冻结表_SSOT.md` 增 G2 节
- [x] `00-交接清单-HANDOFF.md` T2 → 已决
- [x] `README-整合说明.md` / `CHANGELOG` v1.4
- [x] 美术/音频圣经引擎段收敛 Godot
- [x] `架构与技术/` 收回整合版
- [x] `client/` Godot 工程落位
