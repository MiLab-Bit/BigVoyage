# data-spec · 数据层补丁提案

> v1.0 · 2026-08-02 · 文策渊（BV-Design2 / 任务 BV-DESIGN-02）
> **状态：提案，未合入工程。** 本目录是给工程合入 `assets/data/data/*.json` 的**补丁草案**，不是运行配置。
> 所有数值均有上游依据（GDD-04 §6.1 / GDD-03 §6.4 / `verify6.py` 实测快照），见各文件内 `_source` 字段。

## 本目录解决什么

| 文件 | 补的缺口 | 上游依据 | 链上影响 |
|---|---|---|---|
| `islands.patch.json` | `islands.json` 缺 `island_m` / `upkeep`（A-07 日产字段） | GDD-04 §6.1 终配表 | ✅ 链上纯函数静态输入（10-经济 §3.4） |
| `ships.json` | `ships.json` 完全缺失 | `verify6.py` 用的真实快照 | ⚠ 影响战斗结果，需 `ruleset_hash` 锁定（10-经济 §7） |
| `guards.patch.json` | `guards.json` 编成 / HP 缺口 | GDD-03 §6.4 + `verify6` 标定 | ⚠ 影响守卫战与日产前提 |

## 工程侧一致性待办（★ 已决项，非待裁决）

> 2026-08-02 · 用户已拍板，本目录已落库；下列条目是**工程侧尚未同步**的差异，合入时以本目录为准。

| # | 项 | 本目录（真源） | 工程侧现状 | 处置 |
|---|---|---|---|---|
| **Q5** | `FR_09.hp_mult` | **1.20** | `assets/data/data/guards.json` 若仍为 **1.35** 即为**不一致** | 以 1.20 合入。收窄 FR_06→FR_09 断崖；**纯数据补丁，不进 `ruleset_hash` 常量清单** |
| **护甲方案1** | `DEF_COEF` | **0.30**（减法模型保留） | `ResolveBattle` 无减法项（纯乘法 `×(1−armor_ratio)`） | 见下方 ⚠，需工程按 `GDD-03 §4.3` 补实现减法项；**此常量进 `ruleset_hash`** |

> ⚠ **`DEF_COEF` 与既有实现的差异（BV-Lock 复验时发现，务必转达工程）**：
> `10-经济 §6.1/§6.4` 的 DPR 解析模型用的是 `max(1, atk − def_t × DEF_COEF)`（减法，源自 `战斗设计.md §7.4`），
> 而 `ResolveBattle` v0.3 与全部仿真脚本（`verify6` / `bvd1_sim8` / `bv_engine`）**只有乘法减免、没有减法项**（等价 `DEF_COEF = 0`）。
> 用户决策"方案1（保持减法模型，系数 0.30）"= **把减法项确立为唯一真源并补进代码**，不是"改一个已存在的 0.5"。
> 该差异改变全部守卫战胜率，实测见 `_scratch/out_lock_b.txt`。

## 三个待主理人裁决的冲突（合入前必须清）

1. **守卫快照不一致**：GDD-03 §6.4 抽象表写「light = 2 单位」，但 `verify6.py` 实测标定用的是 **3 单位 light** 编成（本 `guards.patch.json` 采用后者，因其产出 93.6%/99.1% 胜率数据）。合入前需统一用哪一版。→ 见 `guards.patch.json._note`。
2. **维护费定值 vs 比例**：`islands.patch.json` 的 `upkeep` 是 **定值**（GDD-04 §6.2 推荐，选岛有差异）；11-经济 §5.3 验证比例制 0.40 也达标。二选一。→ 见 GDD-04 §6.2 / 跨文档冲突 C 项。
3. **船体 Schema 字段**：10-经济 §7 描述 `Blueprint` 含 `capacity(u8)`，但当前战斗模型以 `armor`（平铺入 def）+ `atkMod/defMod` 建模，无 `capacity`。合入前需工程明确 Schema。→ 见 `ships.json._schema_note`。

## 合入方式建议

- `islands.patch.json`：作为 `islands.json` 每岛的 **additive 字段**（不覆盖现有 `guard_hp` / `poi` / `tier`），`island_m` 为 u16 定点（位宽见 10-经济 §7 链上建议）。
- `guards.patch.json`：整文件替换 / 补全 `guards.json` 的 `FR_02~FR_12`（FR_01 为起点岛无守卫，不在此列）。
- `ships.json`：直接作为 `ships.json` 内容（当前缺失，无冲突）。

## 不在本目录（归属其他文档）

- 卡牌数值 / 技能：`cards.json` 已在工程，平衡结论见 `10-经济 §6` + `GDD-03 §4.7`。
- 岛屿 / 卡牌叙事文案（`desc` / `lore_tag` / `system_lore`）：见 `20-叙事与世界观框架接口.md §5`，由叙事侧填充，本目录只预留字段位。
