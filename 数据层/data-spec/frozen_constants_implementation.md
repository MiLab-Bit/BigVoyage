# A-12 · 冻结常量代码实现与僵尸常量治理

> **作者**：游承峰（主理人） · **日期**：2026-08-02 · **关联**：`10-经济 §8 A-12`（✅ 确认） / `COMPILATION-REPORT.md` D9 / `control-manifest.md:22-23` 红线 / `RULESET_LOCK.md §2`
> **状态**：✅ 决议已下；设计侧已落地为 `数据层/constants.md` 的 `PHASE: P1+` 标记（2026-08-05，裁决登记册 [N1]/[N4]）；Godot 仓库侧同名 `constants.md` 的标记为 WS-A 步骤。
> **性质**：文档治理（成本极低，收益=后续 agent 不再误读"已冻结但没用"的僵尸常量）。

---

## 1. 裁决（来自 `10-经济 §8`）

> **A-12**：代码行为**优先于** `数据层/constants.md`。`MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*` 在 Demo **不实装**，电路不实现。
> 但策划侧要求把它们从 Demo 的 `constants` 有效集中**移出**（标记 `PHASE: P1+`），而不是留在表里当"已冻结但没用"的僵尸常量——这正是本次两个 agent 都踩坑的原因。

**结论**：采纳。常量表必须带 `PHASE` 维度，区分"已实装 / 待实装 / 已废弃"。

---

## 2. 两维度分类（关键：解开 RULESET_LOCK ✅ 与 A-12 PHASE:P1+ 的表面矛盾）

| 维度 | 含义 | 改它 → hash 变？ |
|---|---|---|
| **VALUE_FROZEN（值冻结）** | 数值已定稿，未来改动 = `ruleset_hash` 变 = 旧战报失效 | ✅ 是 |
| **MECHANIC_PHASE（机制实装阶段）** | 该机制在当前 Demo 战斗核里是否实装 | ❌ 否（阶段标记不改 hash） |

- `RULESET_LOCK.md §2` 里的 `MAX_STUN_ROUND=3` / `MAX_SHIELD_MULT=2.0` / `TRUE_DMG_*` 标 **✅ = 值已冻结**（VALUE_FROZEN）。
- 但它们在 Demo 战斗核（`ResolveBattle.gd v0.4`）**未实装** → **MECHANIC_PHASE = P1+**。
- 二者不冲突：**值冻着等 P1 用，机制现在不上**。电路规格以代码实际行为为准（control-manifest 红线），故 Demo 电路不实现这三项。

---

## 3. `constants.md` 的 `PHASE` 标记 schema（给 Godot 仓库用）

每个常量条目加 `phase` 字段：

```json
{
  "MAX_STUN_ROUND":   { "value": 3,    "phase": "P1+",  "note": "Demo 不实装；电路以代码行为为准" },
  "MAX_SHIELD_MULT":  { "value": 2.0,  "phase": "P1+",  "note": "Demo 不实装" },
  "TRUE_DMG_IGNORES_ARMOR": { "value": true, "phase": "P1+", "note": "真伤机制 P1+；本期 TRUE_DMG 段未实装" },
  "TRUE_DMG_ROUND_CAP_RATIO": { "value": 0.08, "phase": "P1+", "note": "同 TRUE_DMG" },
  "SEG_DECAY":        { "value": 0.40, "phase": "LIVE", "note": "已实装 v0.4" },
  "DEF_COEF":         { "value": 0.30, "phase": "LIVE", "note": "减法模型已实装 v0.4" },
  "ARMOR_CAP":        { "value": 0.80, "phase": "LIVE", "note": "已实装" }
}
```

`phase` 取值：
- `LIVE` — 已实现，进战斗核，受 `ruleset_hash` 约束。
- `P1+` — 值已冻结，机制待 P1+ 实装；Demo 电路不实现。
- `DEPRECATED` — 已废弃，仅留作追溯，不参与 hash。

---

## 4. 本期 `PHASE: P1+` 僵尸常量清单（从有效集移出标记）

| 常量 | 值 | 原踩坑点 |
|---|---|---|
| `MAX_STUN_ROUND` | 3 | 控制链机制 Demo 不实装 |
| `MAX_SHIELD_MULT` | 2.0 | 护盾机制 Demo 不实装（注：TIDE_UR 独占渊盾将放宽此上限，见 `r1_ur_exclusive_effect.md`） |
| `TRUE_DMG_IGNORES_ARMOR` | true | 真伤机制 Demo 不实装 |
| `TRUE_DMG_ROUND_CAP_RATIO` | 0.08 | 同上 |

> ⚠ 若 R1 提案采纳（渊盾/真伤段），`MAX_SHIELD_MULT` 与 `TRUE_DMG_*` 的 `phase` 将随机制实装升为 `LIVE`，并触发 `ruleset_hash` 重新冻结。

---

## 5. 落地步骤（WS-A · Godot 仓库）

1. 给 `constants.md` 每个条目补 `phase` 字段（schema 见 §3）。
2. 上述 §4 四项标 `PHASE: P1+`，移出 Demo 有效集（保留值供 P1 引用）。
3. 战斗核 `resolve()` 显式 `assert`：凡 `phase != "LIVE"` 的常量不得被读取（防回潮）。
4. 电路规格以**代码实际行为**为准，不以 `constants.md` 为准（control-manifest 红线固化）。

---

## 6. 文档协同
- `RULESET_LOCK.md §2`：补注"✅ = 值已冻结；机制实装阶段见本文"避免误读。
- `COMPILATION-REPORT.md` A-12 行：`⚠ 待确认` → ✅ 已决。
- `PHASE3-PLAN.md` A-12：`P1 待做` → 决议已下（落地为 WS-A 步骤 5）。
