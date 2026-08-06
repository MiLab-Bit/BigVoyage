# 口径冻结表 · SSOT（Single Source of Truth）

> **用途**：全仓库唯一的「口径冻结」裁决锚点。任何文档（`GDD-*` / `10-经济` / `11-经济` / `architecture/*` / `design/README.md`）凡写"冲突以 SSOT 为准"，均指向本文件。
> **创建日期**：2026-08-02 · **创建人**：游承峰（主理人）· 解决 `control-manifest.md` 引用悬空问题（H2）。
> **版本**：v1.1（口径基线，下游对齐目标）· **末次更新**：2026-08-02（创建；Phase B 对齐不改冻结值，见 CHANGELOG v1.1）
> **详细真值 + 双 hash + 合入指引**：见 **`design/data-spec/RULESET_LOCK.md`**（本文件是其索引/摘要，真值在 RULESET_LOCK）。

---

## 0. 铁律

> **冲突时以本 SSOT（即 `RULESET_LOCK.md` 真值）为准。**
> 凡改任一战斗/经济常量 → `ruleset_hash` / `econ_ruleset_hash` 变 → **旧战报不可验证** → 必须重新走「冻结 + 电路升级」流程。
> 任何"设计文档想改冻结常量"的诉求，一律先回到本 SSOT 比对 hash，不准就地魔改。

---

## 1. 链上常量真值摘要（摘抄自 `RULESET_LOCK.md`）

### 1.1 双 hash（design-layer blake2b-256 摘要；链上用 Poseidon 同字段集复现）
| 项 | 值 |
|---|---|
| `ruleset_hash` | `d8d175c3d70c0d389e22ee1a06cbbd8a87d1e78e15379e37cbe9a07be94fefb5` |
| `econ_ruleset_hash` | `3ee5c05592404f4c8c7f5cb893b7721ff911208733c515fdc98dccc7def4a42e` |
| `cards_hash` | `5acbc0ef06de328e0bf10d19524665cd17fe64fe59821636ce1e0db82c4d5eb4` |
| `ships_hash` | `a89b819601fbea3d4df94edeaf9effb784ac3c627ddc70998a55b36efe84d1e1` |
| `guards_hash`（FR_09=1.20） | `5b41b7b5ea937bd6a2dcae4cb8e190d96067ceef2c91cfb499c430be827b59c4` |

### 1.2 战斗常量终表（进 `ruleset_hash`）
| 常量 | 终值 | 状态 |
|---|---|---|
| `SEG_DECAY` | 0.40 | ✅ |
| `ARMOR_CAP` | 0.80 | ✅ |
| `STAT_CAP` | {atk:200, def:200} | ✅ |
| `DEF_COEF` | 0.30 | ✅（减法模型保留） |
| `LVL_STEP` | 0.05 | ✅ |
| `DoT 护甲通道` | `max(1, round(baseAtk×dotRate×restraint − target.def×DEF_COEF))` | ✅（D13②） |
| `MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*` | 3 / 2.0 / 见 RULESET_LOCK | ⚠ **值已冻结；机制 PHASE: P1+ 不实装**（见 `frozen_constants_implementation.md`） |
| `STAT_TABLE_VERSION` | 见 `card_id_stability.md` | ✅ 进 `ruleset_hash`（A-11） |

### 1.3 经济常量终表（进 `econ_ruleset_hash`）
| 常量 | 终值 |
|---|---|
| `ISLAND_DAILY_YIELD` | 120 |
| `REFERENCE_PLAYER.invest_rate` | 0.80（D1 滚动口径） |
| `FR_09.hp_mult` | 1.20（Q5 数据补丁，不进 `ruleset_hash`） |

---

## 2. 本 SSOT 与 `RULESET_LOCK.md` 的关系
- **本文件**：索引 + 铁律 + 摘要，供全仓库交叉引用时"有处可指"。
- **`RULESET_LOCK.md`**：真值详表 + 双 hash 字段集 + Godot 合入指引（WS-A）。改常量以它为准。
- 两者 hash/值必须一致；若发现漂移，以 `RULESET_LOCK.md` 最新锁定日期为准并回写本文件。

---

## 3. G2 引擎冻结（2026-08-06）

| 项 | 值 |
|---|---|
| **引擎** | ✅ **Godot 4.7 Forward+**（用户拍板） |
| 裁决全文 | `00-G2引擎冻结_Godot.md` |
| 工程根 | `client/` |
| 链上架构 | `架构与技术/`（已收回；引擎字段一律 Godot） |
| 否决 | Unity 主客户端 · 纯 Web 原生主客户端 |

> 改引擎 = 改 G2，须用户重新拍板。不因引擎冻结而改动 `ruleset_hash` / `econ_ruleset_hash`。

---

## 4. 待澄清（不阻塞，Phase 3 前收）
- `control-manifest.md:3` 原句已改为引用本 SSOT；若其他文档仍写"SSOT"而无具体文件，一律指向本文件。
- A-07 状态：设计/数据层已解（`ISLAND_M` + `islands.patch.json` 含 `daily_yield_dev0` 全 12 岛），`claim_island_yield` 代码合入待 WS-A（见 `架构与技术/control-manifest.md` 闸门 C）。
