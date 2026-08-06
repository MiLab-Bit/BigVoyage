# 常量单一真源（constants.md）· L1

> **本文件是全库唯一 L1 常量真源**（Phase B / N1 已决，2026-08-05 迁移自 `数据层/历史-A轮基础数据/constants.md`）。
> 所有文档凡引用 `constants.md`，一律指向本路径 **`数据层/constants.md`**。旧路径已改为跳转桩，不得再作真源引用。
>
> **优先级**：`RULESET_LOCK.md`（L0 冻结真值）＞ 本文件（L1 设计旋钮）＞ 散文文档。
> 若本文件与 `数据层/data-spec/RULESET_LOCK.md` 冲突，**一律以 RULESET_LOCK 为准**并回写本文件。
> 跨文档议题状态见 **`汇编与报告/裁决登记册.md`**（一议题一 ID 一状态）。
>
> 标注 `PLAYTEST_KNOB` 的字段为 playtest 期可调，其余为设计锁定值。
> 标注 `PHASE: P1+` 的字段 = **值已冻结、机制 Demo 不实装**（A-12 / 裁决登记册 [N4] 已决），电路不实现。

---

## 0. 与 L0 冻结表的分工（必读）

| 层 | 文件 | 管什么 |
|---|---|---|
| **L0** | `数据层/data-spec/RULESET_LOCK.md` | 进 `ruleset_hash` / `econ_ruleset_hash` 的**冻结真值**（战斗 + 经济常量终表、双 hash） |
| **L0 索引** | `00-口径冻结表_SSOT.md` | L0 的索引/摘要 + 铁律，供跨文档"有处可指" |
| **L1（本文件）** | `数据层/constants.md` | 设计侧全量旋钮（含未进 hash 的商业化/社交/演出参数） |
| **L2** | `数据层/*.json`、`数据层/data-spec/*.json` | 数据表（卡牌/岛屿/守卫/舰船/邻接） |

**下列常量的真值不在本文件，在 L0 `RULESET_LOCK.md`**（此处仅列出指针，避免两地各写一份而漂移）：

| 常量 | 终值 | 真源 |
|---|---|---|
| `SEG_DECAY` | 0.40 | `RULESET_LOCK.md §2`（D3） |
| `ARMOR_CAP` | 0.80 | `RULESET_LOCK.md §2`（C-5） |
| `DEF_COEF` | 0.30 | `RULESET_LOCK.md §2`（护甲方案 1） |
| `LVL_STEP` | 0.05 | `RULESET_LOCK.md §2`（D2） |
| `DoT 护甲通道` | `max(1, round(baseAtk×dotRate×restraint − target.def×DEF_COEF))` | `RULESET_LOCK.md §2`（D13②） |
| `STAMINA_COST_POI` | **6** | `RULESET_LOCK.md §3`（item-3 / C-1） |
| `ISLAND_DAILY_YIELD` / `ADJ_BONUS` / `DEV_STEP` / `DECAY_SLOPE` | 120 / 0.25 / 0.25 / 0.06 | `RULESET_LOCK.md §3` |
| `INFLATION_DENOMINATOR` / `REFERENCE_PLAYER` | 滚动口径 / `{invest_rate:0.80}` | `RULESET_LOCK.md §3`（D1） |
| `STAT_TABLE_VERSION` | 见 `data-spec/card_id_stability.md` | `RULESET_LOCK.md §2`（A-11） |

---

## 战斗
- `RESTRAINT = 1.3`              // 克制方最终伤害系数（≡ 文案「约 +30%」；硬约束）
- `RESTRAINT_DISADV = 1/1.3`     // 被克方最终伤害系数（≈0.76923；对称环）
- `DOT_APPLIES_RESTRAINT = true` // DoT 结算同样乘 restraintCoef
- `TRUE_DMG_IGNORES_ARMOR = true`// **PHASE: P1+（Demo 不实装）** 真实伤害仅无视护甲/typeCoef，仍乘 restraintCoef（禁止无视克制）
- `TRUE_DMG_ROUND_CAP_RATIO = 0.08` // **PHASE: P1+（Demo 不实装）** 单目标单回合真实伤害 ≤ maxHP×此值
- `TYPE_COEF`                    // 伤害类型 × 护甲 系数表（数值写进代码常量；设计定义见《战斗设计》文档）
- `WIND_BONUS_SEGMENT = 20`      // 疾风 spd 每超 20 额外 +1 段，上限 +2
- `GUARD_HP_LIGHT = 800`         // 轻 PVE 守卫血量
- `GUARD_HP_HEAVY = 2400`        // 重守卫血量
- `BOSS_HP = 5000`               // 海域 Boss 血量

## 舰队 / COST
- `FLEET_CAPACITY = 10`           // Ship.capacity 默认 COST 上限
- `FLEET_SLOTS = 5`               // 槽位数
- `COST_BY_RARITY = {R:1, SR:2, SSR:3, UR:4}`

## 经济（demo 切片，顶向下校准，PLAYTEST_KNOB）
- `STAMINA_MAX = 120`             // 体力上限（日行动预算）
- `STAMINA_COST_POI = 6`          // **L0 冻结值**（item-3 / C-1；真源 `RULESET_LOCK.md §3`）。旧口径 `=1` 已作废，见裁决登记册 [B1]
- `STAMINA_REFRESH = daily_00_clear` // 正式口径：每日 0 点刷新并清空未用完体力（SSOT）
- `STAMINA_REGEN_PER_MIN = 1`     // DEMO_ONLY 本地联调加速；非正式服口径
- `SEASON_DAYS = 90`              // 正式赛季日历天数 = 6-18-30-30-6 五阶段（见裁决登记册 [B2]）；经济压测可用 30 步压缩模型
- `SEASON_UP_POOL_DAYS = 21`      // UP 池轮换；90 天 ≈ 4 轮
- `RESOURCE_MODEL = layered`     // Demo=strategic 单池；全量=wood/rope/strategic_ore/spice
- `POI_DROP_CREW_RATE = 1/480`    // 船员卡掉落率；**冻结值**（进 `econ_ruleset_hash`）。语义 = **最终逐次概率（Reading 2，登记册 [B4] 已决，2026-08-06 采 A）**——单次独立伯努利结算口径；`poi_yield.weight` 仅作开箱构成份额（统计口径）。**禁止**使用过期 1/20
- `POI_DROP_SHIP_RATE = 1/960`    // 船图纸掉落率；同上，语义 = **最终逐次概率（Reading 2，[B4] 已决）**；**禁止**使用过期 1/40
- `D_STAMINA_TARGET = 700`        // 顶向下假设日均 stamina sink（辅助商业化，非主轴）
- `D_GACHA_TARGET = 3000`         // 顶向下假设日均 gacha sink（**主商业化**）
- `PAID_TIER_PENETRATION = 0.30`  // 付费档渗透率假设（对账用）

## 商业化护栏（角色池对齐主文档 §12.3 / 方案 C）
- `PITY_SOFT = 70`                // 角色池小保底（50/50 UP）
- `PITY_HARD = 140`               // 角色池大保底（70+70）
- `PITY_WEAPON_SOFT = 60`         // 舰装/武器池小保底
- `PITY_WEAPON_HARD = 120`        // 舰装/武器池大保底
- `PULL_COST_CRYSTAL = 160`       // 单抽消耗航海晶
- `C6_ANCHOR_CNY = 15000`         // 满命锚定（方案 C）
- `RESOURCE_SKIN_CAP_BONUS = 0.30`// **资源向**皮肤/岛屿装饰：产出或仓容加成上限 +30%；**不进战斗公式**（外观皮肤仍为 0 战力 0 资源）

## 链（demo mock）
- `CHAIN_MOCK = true`             // demo 用本地确定性 hash 替代 Aleo/zk
- `HASH_ALGO = "sha256"`          // 纯函数日志承诺哈希算法

## 战斗护栏（失效边界，设计锁定值，非 PLAYTEST_KNOB，改动需 team-lead 评审）
- `MAX_STUN_ROUND = 3`            // **PHASE: P1+（Demo 不实装）** 单目标累计控制回合上限，超则免疫（防 permastun）
- `MAX_DOT_STACK = 5`             // 同目标燃烧层数上限，超不增伤（防无限 DoT）
- `MAX_SHIELD_MULT = 2.0`         // **PHASE: P1+（Demo 不实装）** 能量盾量 ≤ 本体 hp ×2（防盾比血厚）
- `MAX_EXTRA_HIT = 2`             // 疾风额外段上限（阈值触发不超）
- `GUARD_MAX_ROUND = 30`          // 单场回合上限，超时按剩余 hp 比例判（防互奶不死）
- `STAT_CAP = {atk:200, def:200}` // 单卡数值上限（防数值膨胀碾压克制）
- `SAME_SYS_SOFT_CAP = 4`         // 同体系卡 ≤4/5 槽，强制搭配（与 COST 双约束）

> ⚠ **`PHASE: P1+` 三项的语义（A-12 已决，见裁决登记册 [N4]）**：`MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*`
> = **值已冻结（进 `ruleset_hash`，改则旧战报失效）但机制在 Demo 不实装、电路不实现**。
> 不得据本表要求"代码补实现"——治理见 `数据层/data-spec/frozen_constants_implementation.md`。

## 舰装系统（§12.3.4）
- `FLAGSHIP_SLOTS = 3`            // 每编队 1 旗舰开 3 槽：武器/装甲/神器（舰装不进 COST，见 §4.5）
- `GEAR_STAT_CAP = 0.10`          // 单舰装属性增幅上限 10%（< 命座 20% 上限，确保舰装不碾压角色养成，§12.5 红线 2）

## 链上 / 软硬币桥接（§12.4.5）
- `SOFT_TO_HARD_RATE = 150`       // 150 琥珀币 = 1 航海晶（单向软→硬，反向永久关闭，防双通胀）
- `SOFT_EXCHANGE_DAILY_CAP = 3`   // 每日兑换上限 3 航海晶（= 450 琥珀币 sink），自然日 0 点刷新

## 数值公式（7.2.4 单一真源）
- `SKILL_SCORE_WEIGHTS = {atk: 0.30, def: 0.25, spd: 0.20, hp: 0.25}`  // 卡牌平衡评分权重
- `SKILL_SCORE_SCALE = 200`       // 评分基准（STAT_CAP 量级）
- `SKILL_SCORE_TABLE = {S:[90,100], A:[75,89], B:[60,74], C:[45,59], D:[0,44]}`  // 卡牌平衡评级分档，PLAYTEST_KNOB
- `BREAKTHROUGH_MAX = 6`          // 角色突破上限
- `SYSTEM_SKILL_THRESHOLD_BASE = 3`     // 体系技触发基础回合阈值
- `BREAKTHROUGH_THRESHOLD_REDUCE = 1`   // 每 +1 突破使体系技阈值 -1 回合（下限 1），呼应 §8.2 霜铁之王（曾用名巨岩要塞）
- `CONSTELLATION_MAX = 6`         // 命座上限 C6
- `CONSTELLATION_C1_STRONG = true`// C1 即强（接 §12.3.2），对标原神但 SLG 抽到 C1 即成型

## 环境与赛季进阶（§11.1.2）
- `ENV_BIAS_SEASON_ADVANCE = {ironwall: 1.25}`  // 冻洋进阶态 env_bias（开场 ×1.15 → ×1.25 / +25%），不破 RESTRAINT 克制环

## 社交 / 地缘（§9）
- `ALLIANCE_WITHDRAW_CAP = 5000`  // 联盟仓库单日提现上限（琥珀币），PLAYTEST_KNOB
- `WAR_CD = 72`                    // 联盟宣战冷却（小时），赛季中限次，PLAYTEST_KNOB
- `ALLIANCE_AID_CLAIM_CD = 24`    // 联盟援产每日申领冷却（小时），呼应 §9.3.3

---

## 变更记录

| 日期 | 变更 | 依据 |
|---|---|---|
| 2026-08-05 | 自 `历史-A轮基础数据/constants.md` 迁移为唯一 L1 真源；补 §0 与 L0 的分工表；`STAMINA_COST_POI=6` 显式化；三项护栏加 `PHASE: P1+` 标记；`POI_DROP_*` 冻结值注明、语义解释**待裁决（[B4]）** | 裁决登记册 [N1] / [B1] / [N4] / [B4] |
| 2026-08-06 | `POI_DROP_*` 语义回写为**已决（[B4] 采 A Reading 2）**：1/480 / 1/960 = 最终逐次概率（结算口径），数值未动 | 裁决登记册 [B4] |
