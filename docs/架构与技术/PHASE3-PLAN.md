# PHASE3-PLAN · BigVoyage Phase 3 启动与执行计划

> **起草**：2026-08-02 · 主理人（游承峰）
> **基线**：`COMPILATION-REPORT.md`（Phase 2 汇编，质量门 = CONCERNS→P0 全清零）、`RULESET_LOCK.md`（双 hash 冻结）、`GAPS_PENETRATION.md`（Aleo 穿刺）、`control-manifest.md`（编码红线 + 阻塞门禁）
> **状态**：Phase 2→3 质量门已通过（P0 全清零，`ruleset_hash`/`econ_ruleset_hash` 可冻）。本计划编排 Phase 3 的三条工作流、里程碑、待裁决项与诚实待补清单。

---

## 0. 入口闸门（已满足）

| 门 | 状态 | 依据 |
|---|---|---|
| P0 战斗/经济常量全决 | ✅ | `RULESET_LOCK.md` 终表；FR_12=11.96% 落区间，H-5=1.7×，D5 峰值 3.34%≤5% |
| 双 hash 冻结前置 | ✅ | `ruleset_hash=d8d175c3…` / `econ_ruleset_hash=3ee5c055…` |
| 工程交接包备齐 | ✅ | `engineering/ResolveBattle.gd`(v0.4) + `design/data-spec/guards.json`(FR_09=1.20) + `RULESET_LOCK.md §5` 合入指引 |
| Godot 仓库合入 | ⏳ **人工最后一步**（本 workspace 不含该工程） | 见 WS-A |
| Aleo 真机穿刺 | ⏳ 需 Aleo devnet / Leo 环境 | 见 WS-B |

---

## 1. 三条工作流（依赖不同资源，可并行）

| 流 | 内容 | 依赖 | 本 workspace 可做？ |
|---|---|---|---|
| **WS-A** | Godot 工程合入 v0.4 + 锁常量 | 你侧 `docs/design` 仓库（+ commit `4e90a37`） | ❌ 仅交付，需人工 |
| **WS-B** | G-01/03/04/05/06 Aleo 真机穿刺回填 | 真实 Aleo 环境（testnet / `leo` / `snarkvm` / Godot Web 导出） | ❌ 计划已建，执行需 env |
| **WS-C** | P1 设计项 + 开放平衡项收尾 | 无外部依赖，设计层可解 | ✅ 本 workspace 直接推进 |

> WS-C 是**当前唯一能立即动手、不卡资源**的流。WS-A/WS-B 可随时在你备好仓库/环境后并行启动。

---

## 2. 里程碑编排

```
M0  合入与复验（WS-A）
     └─ 用 v0.4 覆盖 systems/ResolveBattle.gd；guards.json 覆盖 assets/data/data/guards.json
        constants.json 补 DEF_COEF=0.30 / DOT_ARMOR=true / SEG_DECAY=0.40 / ARMOR_CAP=0.80 / LVL_STEP=0.05
        → 跑 test_commitment_binding / test_spd_tie_order / test_determinism_crossplatform（control-manifest 立即执行项）
M1  Aleo 穿刺回填（WS-B）
     └─ 1~2 天：G-01/03/04/05/06 各出 out_gNN.txt 真机读数 → 回填 control-manifest G 状态行 + 源头文档
        ⚠ 若任一缺口否定架构假设（如 G-01 证 66k 仍不可证）→ 升红灯，回主理人重议 ADR-003
M2  定点化 + 平衡（WS-C + 部分 WS-B 前置）
     └─ BLK-1 战斗核零浮点（SCALE=10000, u64 中间量）；A-12 对齐 MAX_STUN/MAX_SHIELD/TRUE_DMG 已冻未实现
        开放平衡（2026-08-02 诊断后）：原"烈焰主导策略"经 `r1_dominance_diagnostic.md` 证明为铁壁 B3 单点匹配误判（跨 12 守卫聚合 79.4%≈基线），**非全局主导**，撤销重平衡路径；仅剩 R1 验收判据重定义为守卫无关聚合
M3  Demo 主路径（WS-A∩WS-B∩WS-C）
     └─ 方案 B Web 导出 + 批量结算 + 证明后台生成；G-05 稳定则定方案 B，否则回退方案 A（桌面）
```

---

## 3. 待裁决 / 待澄清项（带责任人）

### 3.1 需用户 + 策划裁决（P1 启动前）
| 项 | 内容 | 卡住 | 责任人 |
|---|---|---|---|
| **D4~D7** | P1 养成/经济待决（见 `COMPILATION-REPORT §9`） | P1 经济联调 | 策划 + 工程 |
| **A-01** | 裁决战降规格 3v3 / 8 回合 | P2 全部 | ✅ **已决（2026-08-02）**：规范见 `data-spec/chain_duel_a01.md` |
| **A-02** | 定点化数值偏差能否接受 | P1 定点化 + P2 | 主理人 + 工程 |
| **A-13** | 每日批量结算掉落的体验可否接受 | 闸门 D 形态 | ✅ **已决（2026-08-02）**：规范见 `data-spec/daily_batch_drop_ux_a13.md` |
| **A-14** | `poi_yield` 权重与 `1/480` 口径关系 | 闸门 D 判定逻辑 | ✅ **已决（2026-08-02）**：Reading 2，校准见 `data-spec/drop_rate_calibration_a14.md` |

### 3.2 设计层可推进（WS-C，本 workspace 可解）
| 项 | 内容 | 落点 | 状态 |
|---|---|---|---|
| **A-01** | 链上裁决战（on-chain duel） | `data-spec/chain_duel_a01.md` | ✅ **已决（2026-08-02）**：两段结构 + 战报 record + 接口 |
| **A-05** | 装备 schema 定义 | `data-spec/gear_schema_a05.md` | ✅ **已决（2026-08-02）**：链下附属 schema + 合成口径（GEAR_STAT_CAP 待补 ruleset_hash） |
| **A-10** | 多人化岛屿稀缺性 | `data-spec/island_scarcity_a10.md` | ✅ **解法已定（2026-08-02）**：联盟共治数据结构 + 分配规则（P1 阻塞，Demo 不阻塞） |
| **A-11** | `card_id` 稳定性（改卡不破旧战报） | `data-spec/card_id_stability.md` | ✅ **已决（2026-08-02）**：身份进 record 永冻 + 属性查版本化静态表，`stat_table_version` 进 ruleset_hash |
| **A-12** | 代码 vs `constants.md`（`MAX_STUN_ROUND` 等已冻未实现） | ResolveBattle | ✅ 决议已下（落地 WS-A；治理见 `frozen_constants_implementation.md`） |
| **A-13** | 每日批量掉落 UX | `data-spec/daily_batch_drop_ux_a13.md` | ✅ **已决（2026-08-02）**：三段结构 + 返航清点 UX |
| **A-14** | 掉率 1/480 校准 | `data-spec/drop_rate_calibration_a14.md` | ✅ **已决（2026-08-02）**：Reading 2，不改冻结值 |
| **O-13** | 链上裁决战（on-chain duel） | ADR-003 | ✅ 同 A-01 |

### 3.3 开放平衡项（2026-08-02 诊断后已大幅收敛）
- **"烈焰主导策略"经诊断撤销**（原 R1 验证 FAIL 结论基于误判的死判据）：`r1_dominance_diagnostic.md` 证明——原 99.9% 是**对铁壁 B3 单点匹配**的固有结果（四系克制环仅烈焰克铁壁），跨全部 12 真实 FR 守卫聚合胜方含烈焰 = **79.4% ≈ 基线 75.8%** → **无全局主导策略**。
  - 三维/四维扫描 0 通过是判据缺陷表征，非平衡缺陷。
  - 剩 **R1 验收判据重定义**（守卫无关聚合，见 `r1_balance_verification.md §5.3`）：退役"对 FR12_A 测 ≤85%"，改用"跨全部 FR 守卫聚合 ≤~82% 且非铁壁类 ≤基线+10pp"——按此判据**当前设计已通过**，无需 `stat_table_version` 补丁、不触发 `ruleset_hash` 重冻。
  - R1 独占机制按 **UR 商业价值提案**正常合入（`r1_ur_exclusive_effect.md` 状态已更新），与"破主导"解耦。属 P1 平衡层文档修订，不阻塞 Phase 3。

---

## 4. ⚠ 诚实待补清单（不能含糊带过）

| # | 问题 | 现状 | 待办 |
|---|---|---|---|
| **H1** | **A-07 状态矛盾（已统一，2026-08-02）** | 真值：设计/数据层已解（`ISLAND_M` + `islands.patch.json` 含 `daily_yield_dev0` 全 12 岛），工程合入待 WS-A。report ✅ 设计已解 + control-manifest 闸门 C 改"设计已解/代码合入后解锁" 已对齐 | ✅ 已统一 |
| **H2** | **`00-口径冻结表_SSOT.md` 缺失（已补，2026-08-02）** | 已建 `design/00-口径冻结表_SSOT.md` 作索引，真值指向 `RULESET_LOCK.md`；control-manifest:3 引用已解析 | ✅ 已补 |
| **H3** | **BLK-1 / BLK-3 / BLK-5 未修** | v0.4 只修 BLK-2/4；BLK-1（定点化）、BLK-3（seed 语义）、BLK-5（GameData 全解耦，仅做半步承诺）仍 pending | 进 M2 |
| **H4** | **`MAX_STUN_ROUND`/`MAX_SHIELD_MULT`/`TRUE_DMG_*` 已冻未实现** | 已下决议（`frozen_constants_implementation.md`）：值冻结、机制 `PHASE:P1+` 不实装，constants.md 加 `PHASE` 标记 | ✅ 决议已下（落地 WS-A） |
| **H5** | **`islands.patch.json` 与 Godot 仓库合入** | patch 已写本 workspace，但 Godot `islands.json` 是否应用该 additive 字段未验证 | 随 WS-A 合入，并解决 H1 |

---

## 5. Phase 3 完成判据（DoD）

进入下一阶段（P2 / 参赛 Demo）前，以下必须全绿：

1. ✅ WS-A 合入完成，`test_commitment_binding` / `test_spd_tie_order` / `test_determinism_crossplatform` 全过。
2. ✅ WS-B 六个缺口全部回填真机数字，control-manifest G 行从"无可靠数据"更新为"已验证"；无红灯推翻 ADR。
3. ✅ BLK-1/3/5 关闭；战斗核零浮点 + 真纯函数（GameData 不读全局）。
4. ✅ A-12 冻结常量全部代码实现；A-11 card_id 稳定性落地（改卡不破旧战报）。
5. ✅ 开放平衡：烈焰主导经诊断**非全局问题**（跨 12 守卫聚合 79.4%≈基线）；R1 验收判据重定义为守卫无关聚合（当前已通过）。
6. ✅ H1/H2/H4 已澄清统一；SSOT 就位、A-12 僵尸常量治理决议已下。
7. ✅ Demo 主路径（方案 B 或 A）稳定，批量结算 + 后台证明跑通。

---

## 6. 立即可执行（不卡任何资源）

- **WS-C 起步**：A-11（card_id 稳定性）、A-12（冻结常量治理）、A-01/A-05/A-10/A-13/A-14（五份规范）、R1（UR 独占效果提案 + 烈焰主导诊断）**全部已落地**——本 workspace 设计/数据层 Phase 3 前置已清零。
- **H1/H2 澄清**：已统一 A-07 状态、补建 `00-口径冻结表_SSOT.md`——M0/M2 前置已就位。
- **R1 现状**：提案维持 UR 商业价值（已诊断无需为重平衡服务）；验收判据待重定义为守卫无关聚合（文档修订，不阻塞）。
