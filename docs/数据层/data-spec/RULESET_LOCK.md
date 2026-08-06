# RULESET_LOCK · 链上常量冻结清单

> **锁定日期**：2026-08-02 · **锁定人**：游承峰（主理人）
> **状态**：✅ P0 全部清零，`ruleset_hash` / `econ_ruleset_hash` 冻结前置条件已满足，可转工程锁链。
> **配套真源文件**：`engineering/ResolveBattle.gd`(v0.4) · `design/data-spec/guards.json`(锁定版)

---

## 0. 一句话

本文件是 Phase 2 → Phase 3 的**链上常量真值锚点**。任何改战斗/经济常量的后续提案，都必须先比对这里的 hash；
改了任一项 → hash 变 → 旧战报不可验证 → 必须重新走「冻结 + 电路升级」流程。

> ⚠ **摘要算法说明**：本文件的 `ruleset_hash` / `econ_ruleset_hash` 是 **design-layer 的 blake2b-256 摘要**
> （由 `design/_scratch/lock_hash.py` 算出），用于**人类可读的口径固化与 CI 一致性自检**。
> **链上工程侧须用 `Poseidon(constants ‖ cards ‖ ships ‖ env_table)` 对「同一字段集」复现**，
> 得到 on-chain `ruleset_hash`（进战报承诺、进电路 public input）。两者字段集一致即等价，算法不同是预期。

---

## 1. 冻结值（直接抄用）

| 项 | 值 |
|---|---|
| **`ruleset_hash`（design 摘要）** | `d8d175c3d70c0d389e22ee1a06cbbd8a87d1e78e15379e37cbe9a07be94fefb5` |
| **`econ_ruleset_hash`（design 摘要）** | `3ee5c05592404f4c8c7f5cb893b7721ff911208733c515fdc98dccc7def4a42e` |
| `cards_hash`（锁定卡表） | `5acbc0ef06de328e0bf10d19524665cd17fe64fe59821636ce1e0db82c4d5eb4` |
| `ships_hash`（锁定船表） | `a89b819601fbea3d4df94edeaf9effb784ac3c627ddc70998a55b36efe84d1e1` |
| `guards_hash`（锁定守卫，FR_09=1.20） | `5b41b7b5ea937bd6a2dcae4cb8e190d96067ceef2c91cfb499c430be827b59c4` |

---

## 2. 战斗常量终表（进 `ruleset_hash`）

| 常量 | 终值 | 出处 | 状态 |
|---|---|---|---|
| `SEG_DECAY` | **0.40** | D3 / §6.3 | ✅ 已决 |
| `ARMOR_CAP` | **0.80** | C-5 / FR_12=A | ✅ 已决 |
| `STAT_CAP` | **{atk:200, def:200}** | — | ✅ 已决（位宽建议留 u32，见 10-经济 §7.3 红线2） |
| `DEF_COEF` | **0.30** | 护甲方案1（减法模型保留） | ✅ 已决（P0-2） |
| `LVL_STEP` | **0.05** | D2 / §4.2 | ✅ 已决（C-3 关闭） |
| `DoT 护甲通道` | **`max(1, round(baseAtk×dotRate×restraint − target.def×DEF_COEF))`** | D13② | ✅ 已决（P0-3′） |
| `RESTRAINT` | 1.3 | — | ✅ |
| `RESTRAINT_DISADV` | 1/1.3 (= 0.7692…) | — | ✅（不预存常量，用除法保对称） |
| `DOT_APPLIES_RESTRAINT` | true | — | ✅ |
| `TRUE_DMG_IGNORES_ARMOR` | true | — | ✅ |
| `TRUE_DMG_ROUND_CAP_RATIO` | 0.08 | — | ✅ |
| `WIND_BONUS_SEGMENT` | 20 | — | ✅ |
| `MAX_EXTRA_HIT` | 2 | — | ✅ |
| `MAX_DOT_STACK` | 5 | — | ✅ |
| `MAX_STUN_ROUND` | 3 | — | ✅ |
| `MAX_SHIELD_MULT` | 2.0 | — | ✅ |
| `GUARD_MAX_ROUND` | 30 | — | ✅ |
| `SAME_SYS_SOFT_CAP` | 4 | — | ✅ |
| `FLEET_SLOTS` | 5 | — | ✅（链上裁决战建议 DUEL_SLOTS=3，见 ADR-003） |
| `FLEET_CAPACITY` | 10 | — | ✅ |
| `COST_BY_RARITY` | {R:1, SR:2, SSR:3, UR:4} | — | ✅ |
| `STAMINA_MAX` | 120 | — | ✅（批量结算票据 ≤ 此值，见补遗01） |
| `POI_DROP_CREW_RATE` | 1/480 | — | ✅（仅 finalize 随机，见补遗01 / G-02 已关闭） |
| `POI_DROP_SHIP_RATE` | 1/960 | — | ✅ |
| `POI_RESOURCE_BASE` | 500 | — | ✅ |
| `SEASON_DAYS` | 90 | — | ✅ |
| `TYPE_COEF` / `RING` / `SYSTEM_COLORS` | 见 `data_constants.json` | — | ✅（口径未变） |
| `STAT_TABLE_VERSION` | 见 `data-spec/card_id_stability.md §2.2` | A-11 | ✅ **进 `ruleset_hash`**（平衡 patch 改属性只发新版本，旧战报用旧版本验证，永不失效） |

> **实测锚点**：FR_12(Lv4, gm1.15) 胜率 **11.96%**（落回 5~15% 区间）；H-5 断层 9.8×→1.7×；克制环双靶 ≥1.00。
> 来源：`design/_scratch/lock_armor_c.py`（`bv_engine.py` 同口径）。
> **维度澄清（呼应 A-12）**：上表 ✅ = **值已冻结**（VALUE_FROZEN，改则 `ruleset_hash` 变）；机制是否实装见 `data-spec/frozen_constants_implementation.md`。如 `MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*` = `PHASE: P1+`（Demo 不实装），属"值冻着等 P1 用"，与"机制未上"不矛盾。

---

## 3. 经济常量终表（进 `econ_ruleset_hash`）

| 常量 | 终值 | 出处 | 状态 |
|---|---|---|---|
| `ISLAND_DAILY_YIELD` | 120 | — | ✅ 冻结 |
| `DEV_STEP` | 0.25 | — | ✅ |
| `ADJ_BONUS` | **0.25** | C-6 | ✅ 已决 |
| `DECAY_SLOPE` | 0.06 | — | ✅ |
| `MAX_CLAIM_DAYS` | 30 | — | ✅ |
| `TIDE_BY_TIER` | {start:0, light:1, heavy:3, boss:8} | — | ✅ |
| `SEASON_POOL` | 5000 | — | ✅（不 mint，net_issuance≤0 结构性成立） |
| `STAMINA_MAX` | 120 | — | ✅ |
| `STAMINA_COST_POI` | 6 | item-3 | ✅ 已决 |
| `INFLATION_DENOMINATOR` | **`rolling_prev_day_pool`（滚动口径）** | D1 | ✅ 已决（固定分母作废） |
| `REFERENCE_PLAYER` | **{invest_rate: 0.80}** | D1 | ✅ 已决 |

> **实测锚点**：D5 日通胀率峰值 **3.34%**（参考玩家 + refit + ADJ=0.25），阈值 5%，余量 33% PASS。
> 纯囤积（invest=0.00）14.56% 降级为监控指标，不阻塞。

---

## 4. 守卫数据快照（进 `ruleset` 数据层，不在常量清单）

`design/data-spec/guards.json` = 锁定版（FR_09 `hp_mult` **1.35 → 1.20**，Q5 已决）。
`guards_hash`（design 摘要）= `5b41b7b5…827b59c4`。
> ⚠ 守卫 HP 基数（`hp_mult`）**不进 `ruleset_hash` 常量清单**（它是数据值），但属 ruleset 数据快照，
> 改值同样影响旧战报可复算性 —— 须与常量同批发版。

---

## 5. 工程合入指引（Godot 仓库 `docs/design` 分支）

1. **战斗内核**：用 `engineering/ResolveBattle.gd`（v0.4）覆盖 `systems/ResolveBattle.gd`
   （原 commit `4e90a37`）。v0.4 含：减法扣甲级（DEF_COEF）、DoT 过甲（D13②）、BLK-4 稳定全序、BLK-2 全宽绑定承诺、ruleset_hash 显式入参。
2. **守卫数据**：用 `design/data-spec/guards.json` 覆盖 `assets/data/data/guards.json`（FR_09=1.20）。
3. **常量**：`constants.json` 须含 `SEG_DECAY=0.40` / `ARMOR_CAP=0.80` / `LVL_STEP=0.05` / `DEF_COEF=0.30` / `DOT_ARMOR=true`（其余见 `data_constants.json`）。
4. **链上**：`ruleset_hash` 用 Poseidon 同字段集复现；`econ_ruleset_hash` 同理；二者进战报承诺与电路 public input。

---

## 6. 已修阻断项（本仓库范围内）

| 项 | 状态 | 落点 |
|---|---|---|
| BLK-2（承诺不完备 / 64bit 截断） | ✅ 已修（v0.4） | `ResolveBattle.gd` 全宽 sha256 + 绑定 fleet/env/seed/winner/rounds/log 全文 |
| BLK-4（排序不稳定） | ✅ 已修（v0.4） | 显式全序 `(spd DESC, side ASC, slot ASC)` |
| 护甲减法级（DEF_COEF=0.30） | ✅ 已加 | `_strike` 内 `eff_atk = max(1, atk − def×DEF_COEF)` |
| DoT 护甲通道（D13②） | ✅ 已加 | `dot_dmg = max(1, round(atk×0.18 − def×DEF_COEF))` |

> BLK-1 定点化：✅ **client 已落地**（`FixedMath` SCALE=10000，2026-08-06 v1.7）；与 Python `bv_engine` 对拍 / A-02 偏差确认 / 是否重冻 ruleset **仍开放**。  
> 仍待 P1：BLK-3 seed 语义、BLK-5 GameData 全局态彻底解耦（承诺半步已做）、链侧 Poseidon8。

---

## 7. 知识缺口穿刺（P1 前）

见 `architecture/GAPS_PENETRATION.md`：G-01 / G-03 / G-04 / G-05 / G-06（G-02 随机源已关闭）。

---

## 8. 验收判据（守卫无关聚合 · R1 主导策略复核）

> **来源**：`design/data-spec/r1_dominance_diagnostic.md`（2026-08-02）。
> **背景**：原 R1 验收子判据"胜方含烈焰 ≤85%（对 FR_12 铁壁 B3 **单点**）"被证明**测量的是匹配克制（fire melts iron），而非全局主导策略**，故正式退役。

### 8.1 验收口径（取代原单点死判据）

1. **守卫无关聚合（GAA, Guard-Agnostic Aggregate）**：跨 `design/data-spec/guards.json` 全部 **12 个**真实 FR 守卫聚合，玩家胜方含烈焰占比 **≤ ~82%**（基线 = 全空间含烈焰 **75.8%**）。
2. **非铁壁守卫约束**：任一**非铁壁构型**守卫的胜方含烈焰占比 **≤ 基线 + 10pp（即 ≤ ~85.8%）**；**铁壁类守卫（仅被烈焰克制）豁免此上限** —— 属正常匹配设计，非主导。

### 8.2 当前实测（锁链全量口径，R1-on）

| 指标 | 值 | 判据 |
|---|---|---|
| 跨 12 守卫聚合 · 胜方含烈焰 | **79.4%** | ≤ 82% → ✅ PASS |
| 全空间基线 · 含烈焰 | 75.8% | — |
| 非铁壁守卫烈焰占比区间 | 68.3% ~ 86.0% | ≤ 85.8%（FR_12 外最高 FR_06 = 85.6%，临界 PASS）✅ |
| FR_12（铁壁 B3）烈焰占比 | 98.4% ~ 100% | 铁壁豁免 ✅ |

> "无全局主导策略"成立：跨真实守卫聚合 79.4% 仅高于基线 3.6pp；原"99.9% 必选"只是对铁壁 B3 单点匹配的误读。

### 8.3 结论与影响

- 当前设计**以守卫无关聚合判据 PASS**，**无需**任何 `stat_table_version` 属性补丁、**不触发** `ruleset_hash` 重冻。
- R1 提案回归其真实且独立的成立价值——治愈 UR 卡数值垫底（商业风险），与"破主导"解耦，按 `design/data-spec/r1_ur_exclusive_effect.md` 正常合入（属 P1 平衡层文档修订，不阻塞 Phase 3）。
- **本判据仅改验收口径，不改任何冻结常量**；`ruleset_hash` / `econ_ruleset_hash` 终表维持不变。
