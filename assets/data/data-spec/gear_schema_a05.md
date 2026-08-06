# A-05 · 舰装 schema（gear schema）

> **作者**：游承峰（主理人） · **日期**：2026-08-02 · **关联**：`COMPILATION-REPORT.md §4`（A-05 行） / `10-经济 §8 A-05` / `asset-ownership-boundary.md §4`（A-05） / `GDD-03`（装备槽）
> **状态**：✅ **裁决已确认（gear 不作为独立链上资产，链下附属）**；本文件落成**可合入的数据 schema + 与战斗核的合成口径**。
> **性质**：数据/schema 规范；P1+ 才实装，Demo 不实装。

---

## 0. 一句话

舰装（gear）**保持链下**，作为卡牌/旗舰的**附属数值来源**，不进 `CrewCard` record、不单独上链。它只在战斗结算时作为"属性加成"并入卡面，机制上等价于卡属性的**可替换增量子**。

---

## 1. 决策依据（为什么不上链）

`asset-ownership-boundary.md §4 A-05` 已分析：gear 上链会要求编队合法性电路**同时验证「卡归属 + 装备归属 + 装备关系」**，约束翻倍，而收益只是"gear 可交易"这个次要需求。Demo 根本不实装 gear（`GEAR_STAT_CAP=0.10` 是全量愿景），P1+ 即便做也建议链下。

---

## 2. 数据 schema（链下，`gear.json`）

```json
{
  "gear_id": "G_FLA_01",          // u16 稳定映射（同 A-11 身份永冻原则）
  "name": "焦炎炮",
  "slot": "weapon",               // weapon / armor / sail / core
  "rarity": "SR",
  "affixes": [                     // 派生属性，不进 record
    {"stat": "atk", "value": 0.06, "mode": "pct"},   // +6% atk
    {"stat": "dot_rate", "value": 0.03, "mode": "flat"} // +0.03 DoT 系数
  ],
  "level": 1,
  "max_level": 5,
  "gear_stat_cap": 0.10           // 单件总加成上限（派生自冻结常量 GEAR_STAT_CAP）
}
```

> **稳定性**：`gear_id` 同 `card_id_stability.md` 的"身份永冻"原则（id/name/slot/rarity 永冻，affix 数值走版本化查表）。gear 不是链上资产，故不进 `ruleset_hash`，但其**总加成上限 `GEAR_STAT_CAP` 是战斗常量**，进 `ruleset_hash`（见 §4）。

---

## 3. 与战斗核的合成口径

卡的有效战斗属性 = 卡面基础值 + 舰装加成（受 `GEAR_STAT_CAP` 封顶）：

```
effective_stat(card) = base_stat(card)
                     × (1 + Σ affix.pct for affix.stat == stat)
                     × (1 + min(GEAR_STAT_CAP, Σ affix.flat for affix.stat == stat))
```

- 加成在 `spawn2()`（编队实例化解算）时一次性并入，战斗核 `R()` 看到的已是终值——**舰装对战斗核透明**，不影响 `ruleset_hash` 的战斗常量集。
- `GEAR_STAT_CAP=0.10` 是硬上限：单件或合计加成超过 10% 的部分被截，防止舰装变成"第二数值膨胀源"破坏 P0 已校准的平衡（尤其 H-5 断层、FR_12 区间）。

---

## 4. 与冻结清单的衔接

| 项 | 是否进 `ruleset_hash` | 说明 |
|---|---|---|
| `GEAR_STAT_CAP = 0.10` | ✅ **应进**（当前未列，待补） | gear 实装后其上限是战斗常量，改则 hash 变。建议在 `RULESET_LOCK.md §2` 追加此行。 |
| `gear_id` / affix 数值 | ❌ 不进 | 链下数据，走版本化查表（同 A-11），旧战报用旧版本验证。 |
| 编队合法性（含装备关系） | ❌ 不在 zk 电路 | 链下校验即可，不进电路。 |

> **待办（WS-A / P1+）**：gear 实装时，① 在 `RULESET_LOCK.md §2` 追加 `GEAR_STAT_CAP`；② `spawn2()` 支持并入舰装加成；③ 给 `gear.json` 加 `stat_table_version`（同 A-11 机制）。

---

## 5. 风险与边界

- ⚠ 若未来策划想要"gear 可交易"→ 触发 A-05 推翻，需新增 `Gear` record + 装备关系上链 + 编队合法性电路重写（约束翻倍）。**当前不推荐**。
- Demo 不实装 gear，本 schema 仅作 P1+ 预留，不影响 Phase 3 进入。
