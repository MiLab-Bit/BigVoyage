# A-14 · 掉率 1/480 口径校准（drop rate calibration）

> **作者**：游承峰（主理人） · **日期**：2026-08-02 · **关联**：`COMPILATION-REPORT.md §4`（A-14 行） / `10-经济 §9 C-7` / `addendum-01 §7 A-14` / `RULESET_LOCK.md §2`（POI_DROP_CREW_RATE 已冻）
> **状态**：✅ **生效（已决口径）**。本文主张 **Reading 2（1/480 = 最终逐次概率；`poi_yield` 权重 = 批量掉落构成份额）**，已由主理人拍板确认（《裁决登记册》**[B4]**，2026-08-06 采 A），由候选口径升为**唯一现行口径**。B 口径（行为用 weight 分域，Σweight=1.85≠1）作废。**冻结值 1/480 不受影响**（已进 `econ_ruleset_hash`），本次仅澄清语义，不触发重冻。
> **性质**：数值口径澄清 + 发放量校准；**不改冻结值，不触发重冻**。

---

## 0. 一句话

`resources.json` 的 `crew_card.drop_rate = 1/480` 与 `poi_yield.crew.weight = 0.6` 看似冲突（差 480 倍），本文主张 Reading 2：**两个不同维度**——前者是**每次探索的最终 crew NFT 概率**，后者是**一张成功掉落内部的类型构成份额**。**该口径已决（《裁决登记册》[B4]，2026-08-06 采 A），本文为生效规范。**

---

## 1. 两种读法（C-7 / Q8 / A-14 的歧义根）

| 读法 | 解释 | crew NFT 单次 POI 概率 | 发放量差异 |
|---|---|---|---|
| **Reading 1（权重门控）**（❌ 作废） | 先按 `poi_yield` 权重选类型，再按 1/480 判定 | `0.6 × 1/480 = 1/800` | 偏少（×0.6） |
| **Reading 2（最终概率）**（✅ **已决**） | `1/480` 已是含权重的最终逐次概率；`poi_yield` 权重 = 掉落**类型构成** | **1/480** | 基准（已采 Reading 2） |

**判据**：`resources.json` 的 `crew_card.drop_rate` 与 `data_constants.json` 的 `POI_DROP_CREW_RATE` **两处独立字段都等于 1/480**——这是强信号：1/480 是**最终概率**，不是"权重选定后再判定的条件概率"。Reading 1 会让 crew 实际掉率变成 1/800，与常量字段直接矛盾。**B 口径（行为用 weight 分域）因 `Σweight = 0.6+0.9+0.3+0.05 = 1.85 ≠ 1` 数学不自洽而作废（[B4] 已决）。**

---

## 2. 已决口径 Reading 2：口径重定义（《裁决登记册》[B4] 已决，2026-08-06 采 A）

```
每次 POI 探索（1 次，消耗 STAMINA_COST_POI=6）：
  ├─ 资源（必给）：strategic +POI_RESOURCE_BASE(500)        ← poi_yield.resource.weight=0.9 是"资源占掉落价值主导"的构成标记，非门槛
  ├─ crew NFT：伯努利(p = POI_DROP_CREW_RATE = 1/480)      ← 最终概率
  └─ ship NFT：伯努利(p = POI_DROP_SHIP_RATE = 1/960)      ← 最终概率

crew NFT 内部构成（仅当 crew 命中时）：
  ├─ 普通池 权重 0.6
  └─ UR 偏向池 权重 0.05  →  UR 偏向占比 = 0.05/(0.6+0.05) = 7.7%   ← poi_yield.crew_ur.weight
```

> **关键修正**：`poi_yield.*.weight` 不再是"逐次 POI 的概率门槛"，而是**一张成功掉落的"类型构成分配"**——用于批量结算时决定当日掉落里 crew/ship/resource/ur 的大致比例（统计口径），不影响单次概率。

---

## 3. 发放量校准

| 维度 | 计算 | 结果 |
|---|---|---|
| 单 POI crew NFT | 伯努利 1/480 | 1/480 ≈ 0.208% |
| 单 POI ship NFT | 伯努利 1/960 | 1/960 ≈ 0.104% |
| **单日（STAMINA_MAX=120 POI）crew** | 120 × 1/480 | **期望 0.25 张/人/日** |
| 单日 ship | 120 × 1/960 | 期望 0.125 张/人/日 |
| **单赛季（SEASON_DAYS=90）crew** | 90 × 0.25 | **期望 ~22.5 张/人** |
| crew 中 UR 偏向占比 | 0.05/(0.6+0.05) | **7.7%**（≈ 1.7 张 UR/赛季） |

> **结论（已决口径 Reading 2 下）**：POI 是**赛季级长尾 trickle**，足以在 90 天内凑齐 20 卡全集（含重复），但**绝不是"3 天集齐"**——主获取靠 gacha（`$TIDE`，net_issuance≤0）。

---

## 4. 诚实边界（重要）

- ⚠ 若 Demo 设计**意图**是"3 天集齐 20 卡"，则 1/480 的 POI 渠道**不可能达成**（需 ~34,560 POI ≈ 288 天），必须靠 gacha 或调高 `POI_DROP_CREW_RATE`。**当前冻结值 1/480 是按"POI 为长尾"设计的，与 gacha 主获取的定位自洽。** 若策划要 POI 提速，属改经济常量 → 触发 `econ_ruleset_hash` 重冻（与战斗常量同批）。
- `POI_DROP_CREW_RATE` **已在 `ruleset_hash`**（RULESET_LOCK §2:59）——本裁决**不改变其值**，只澄清语义，故**不触发重冻**。

---

## 5. 工程合入待办（WS-A）

1. ✅ **[B4] 已决（2026-08-06 采 A Reading 2）——已执行**：`resources.json` 的 `crew_card.drop_rate` 已加注释"最终逐次概率（结算口径）"；`poi_yield` 各 weight 已加注释"批量开箱构成份额（统计口径），非逐次门槛"。
2. `data_constants.json`：`POI_DROP_CREW_RATE` / `POI_DROP_SHIP_RATE` 注释同上。
3. 掉落逻辑（finalize `ChaCha`）：对每次 POI 独立伯努利判定（crew 1/480、ship 1/960），**不**用 `poi_yield.weight` 做逐次门控。
4. 批量结算（A-13）仅决定"何时开箱动画"，不改变单次概率。

> **边界**：不改冻结值，不阻塞 Phase 3 进入。
