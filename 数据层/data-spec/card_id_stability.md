# card_id_stability · A-11 卡 ID 稳定性执行规范

> **状态**：✅ 已决（采纳 `10-经济数值模型 §6` 反提案），可合入工程。
> **起草**：2026-08-02 · 主理人 · **解除 A-11「待确认」状态**（原 `COMPILATION-REPORT.md:71` ⚠ → 本文件闭合）
> **配套**：`aleo-onchain-architecture.md §4.1 CrewCard record` · `RULESET_LOCK.md`（stat_table_version 进 ruleset_hash）

---

## 0. 问题

链上战斗以 `ruleset_hash` 焊死常量；战报承诺绑定 `ruleset_hash` → `cards_hash`。
若平衡性调整改了已发卡的数值（甚至动了 `card_id` / `system` / `rarity`），则：
- 已铸 `CrewCard` record 语义漂移（record 内 `system`/`rarity` 与卡表分叉）；
- 旧战报无法用新 `ruleset_hash` 验证（旧战报全部失效）。

A-11 要求：**卡池只增不改，且平衡性调整不破旧战报。**

---

## 1. 三项承诺（身份进 record，属性查表）

```
承诺 1（身份 · 永不改）：card_id / system / rarity / cost
        → 这四项进 CrewCard record，是卡的"身份证"，一经发行永久冻结。
承诺 2（属性 · 可改）：atk / def / spd / hp
        → 不进 record，链上按 (card_id, level, breakthrough, constellation) + ruleset 推导。
        → 数值存"静态属性表"，平衡 patch 只改表，不改 card_id。
承诺 3（版本化）：stat_table_version
        → 静态属性表带版本号；改属性 = 发新版本（不改 card_id）。
        → stat_table_version 进 ruleset_hash；旧战报用旧版本验证，永不失效。
```

> 这与 `RULESET_LOCK.md` 的 `ruleset_hash` 同构：常量/表版本焊进 hash，旧战报永远可验。

---

## 2. 数据模型（落库形态）

### 2.1 `cards.json`（身份层 · 冻结）
```jsonc
{
  "schema": "cards.identity/v1",
  "cards": [
    {
      "card_id": 1,            // u16，稳定线索引（见 §3 映射表）；永不改
      "id": "FLAME_R_01",      // 人类可读别名，可随 name_ssot 调整，非线索引
      "system": 0,             // 0=flame 1=ironwall 2=wind 3=tide（冻结编码）
      "rarity": 0,             // 0=R 1=SR 2=SSR 3=UR（冻结编码）
      "cost": 1,               // COST_BY_RARITY = {R:1,SR:2,SSR:3,UR:4}（冻结）
      "identity": "点燃单体，持续灼烧",
      "skill": { "name": "余烬", "type": "dot", "desc": "..." },
      "synergy": "...", "strong_against": "ironwall", "countered_by": "tide"
    }
    // ... 其余 19 张，card_id 2..20
  ]
}
```
- **冻结字段**：`card_id` / `system` / `rarity` / `cost` / `identity` / `skill.name` / `skill.type`。
  （`skill.desc` / `synergy` 文案可随叙事微调，不影响数值与规则，不触发版本号。）
- 新增卡 = `card_id` 递增（21, 22, ...），**永不复用、永不删除**。

### 2.2 `stat_tables.json`（属性层 · 版本化）
```jsonc
{
  "schema": "cards.stats/v1",
  "versions": [
    {
      "stat_table_version": 1,
      "stats": {
        "1": { "atk": 40, "def": 25, "spd": 50, "hp": 200 },   // card_id=1 (FLAME_R_01)
        "2": { "atk": 45, "def": 22, "spd": 48, "hp": 190 },
        // ... 全 20 张初版基线
      }
    }
    // 平衡 patch：追加 { "stat_table_version": 2, "stats": { 改哪些改哪些 } }
    // 未列出的 card_id 继承上一版本数值（增量补丁语义）
  ]
}
```
- 平衡调整 = **追加一个新 version 对象**，只写变化的 `card_id`；未写的继承前版。
- `stat_table_version` 进 `ruleset_hash`（`RULESET_LOCK.md §2` 已补 `STAT_TABLE_VERSION`）。
- 战报记录其生成时的 `stat_table_version`，验证时用对应版本重算。

---

## 3. u16 映射表（初版 20 张）

| card_id(u16) | 字符串 ID | system(u8) | rarity(u8) | cost |
|---|---|---|---|---|
| 1 | FLAME_R_01 | 0 | 0 | 1 |
| 2 | FLAME_R_02 | 0 | 0 | 1 |
| 3 | FLAME_SR_01 | 0 | 1 | 2 |
| 4 | FLAME_SSR_01 | 0 | 2 | 3 |
| 5 | FLAME_UR_01 | 0 | 3 | 4 |
| 6 | IRON_R_01 | 1 | 0 | 1 |
| 7 | IRON_R_02 | 1 | 0 | 1 |
| 8 | IRON_SR_01 | 1 | 1 | 2 |
| 9 | IRON_SSR_01 | 1 | 2 | 3 |
| 10 | IRON_UR_01 | 1 | 3 | 4 |
| 11 | WIND_R_01 | 2 | 0 | 1 |
| 12 | WIND_R_02 | 2 | 0 | 1 |
| 13 | WIND_SR_01 | 2 | 1 | 2 |
| 14 | WIND_SSR_01 | 2 | 2 | 3 |
| 15 | WIND_UR_01 | 2 | 3 | 4 |
| 16 | TIDE_R_01 | 3 | 0 | 1 |
| 17 | TIDE_R_02 | 3 | 0 | 1 |
| 18 | TIDE_SR_01 | 3 | 1 | 2 |
| 19 | TIDE_SSR_01 | 3 | 2 | 3 |
| 20 | TIDE_UR_01 | 3 | 3 | 4 |

> 编码与 `aleo-onchain-architecture.md §4.1` 一致：`system` flame=0/ironwall=1/wind=2/tide=3；`rarity` R=0/SR=1/SSR=2/UR=3；`cost` 由 `COST_BY_RARITY` 推出。
> 字符串 ID 保留为 `id` 别名（人类可读 + 历史兼容），但**链上/战报/record 一律用 `card_id`(u16)**。

---

## 4. 合入规则（给工程）

1. `CrewCard` record 字段保持 `aleo-onchain-architecture.md §4.1`：`card_id`/`system`/`rarity`/`cost` + 养成态（level/breakthrough/constellation）+ `serial`。**属性不进 record。**
2. `cards.json` 身份层冻结；任何数值改动走 `stat_tables.json` 追加版本，绝不改 `card_id`。
3. `ResolveBattle` 读属性：按 `(card_id, stat_table_version)` 查静态表，再叠加养成推导。
4. `stat_table_version` 进 `ruleset_hash`；旧战报携带其版本号，验证时取对应版本。
5. **新增卡**：`card_id` 取当前最大值 +1；不复用、不删。

---

## 5. 与既有文档的一致性

- `10-经济数值模型.md:614~626` 反提案 → 本文采纳为执行规范。
- `COMPILATION-REPORT.md:71` A-11「⚠ 待确认」→ 本文闭合为「✅ 已决（反提案采纳）」。
- `PHASE3-PLAN.md` WS-C / A-11「P1 待做」→ 已落地本文件，移出待做。
- `RULESET_LOCK.md §2` → 已补 `STAT_TABLE_VERSION` 进 ruleset_hash 字段集。

> ⚠ 边界：本文件是**设计/数据层规范**，已落 data-spec 真源。Godot 工程 `cards.json` 当前仍是字符串 ID v0.3（`data_cards.json`），合入时需按 §2.1/§3 迁移为 u16 + 拆分 `stat_tables.json`——此迁移属 WS-A 合入步骤，不阻塞本文闭合。
