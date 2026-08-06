# BigVoyage · 链上架构文档索引

> v0.2 · 2026-08-06 · **G2=Godot 已冻结** · 文档收回整合版 `架构与技术/`
> 上游真源：本仓库 `00-口径冻结表_SSOT.md` / `数据层/constants.md` / Demo 基线
> 运行时工程：`client/`（Godot 4.7 · `systems/ResolveBattle.gd` 定点）
> 链上骨架：`../chain/`（`bv_commit` Leo + G-01 探针 + Sidecar 占位）
> 引擎裁决：`00-G2引擎冻结_Godot.md`

---

## 阅读顺序

| 序 | 文件 | 内容 | 读者 |
|---|---|---|---|
| 1 | **`battle-core-zk-readiness-audit.md`** | ResolveBattle 的 5 项 zk 阻断 + 定点化方案 + 电路预算估算。**后续所有决策的输入** | 主理人 / 工程 |
| 2 | `aleo-onchain-architecture.md` | zk 落地路径图、上链/链下计算切分、5 个 Leo 程序职责边界、证明生成与体验方案、阶段路线图 | 全体 |
| 3 | `asset-ownership-boundary.md` | 确权边界表 + **§4 依赖数值模型的对齐假设（A-01~A-12）** | **主理人 / 策划（交叉评审重点）** |
| 4 | `onchain-offchain-economy-loop.md` | 三闸门经济闭环、反作弊 9 面盘点、D5 双账本对账 | 主理人 / 策划 |
| 5 | `adr-001-asset-ownership-boundary.md` | 决策：三原则分层确权 | 主理人 |
| 6 | `adr-002-onchain-offchain-economy-loop.md` | 决策：三闸门单向 + 日限即上限 | 主理人 |
| 7 | `adr-003-zk-battle-verification-strategy.md` | 决策：B→F→D→E 分层递进（核心技术决策） | 主理人 / 工程 |
| 8 | `control-manifest.md` | 一页可执行规则 + 阻塞门禁 | 工程 |
| 9 | **`addendum-01-verifiable-randomness.md`** | 补遗：POI 掉落防刷（关闭 O-2 / G-02）。**修订了 2/4 号文档的对应章节** | 主理人 / 策划 |

---

## 三条核心结论

1. **`ResolveBattle` 结构适合 zk，实现不适合。** 5 项阻断中，承诺不完备（BLK-2）与排序不稳定（BLK-4）**在不上链的情况下也是 bug**，可立即修复。
2. **整场战斗不能上链**（~10⁶ 约束）。最高性价比的 zk 不是「证明战斗」，而是「证明输入合法」——3k 约束即可封死凭空造牌与超 COST 编队。
3. **分层递进 B→F→D→E**，每层独立可交付。比赛最小可交付 = P0 + P1。

---

## 需要主理人裁决 / 转策划的事项

### 阻塞级（未解除不得开工对应阶段）

| ID | 内容 | 卡住 |
|---|---|---|
| **A-01** | 链上「裁决战」能否降规格（3v3 / 8 回合）——需策划新增玩法模式 | ADR-003 的 P2 全部 |
| **A-02** | 定点化引入的数值偏差能否接受（Leo 无浮点，不可绕过） | P1 定点化 + P2 |
| **A-07** | `islands.json` **缺日产字段**，`yield_by_tier` 无数据来源 | 经济闭环闸门 C |
| **A-13** | POI 掉落改为「每日批量结算」的体验能否接受（补遗 01） | 经济闸门 D |
| **A-14** | `poi_yield` 权重与 `1/480` 的口径关系不明（补遗 01） | 闸门 D 判定逻辑 |

### 数据缺口（策划侧补齐）

- `islands.json` 无日产字段（D5「30 步不崩」当前亦无数据支撑）
- `TYPE_COEF` 表数值未给出
- `ships.json` **文件缺失**（代码已在读 `GameData.ships`）
- `env_mod_for()` 与 `season_mod` / `ENV_BIAS_SEASON_ADVANCE` 三者关系未明确

### 文档与代码不一致（A-12）

`MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*` 在 `constants.md` 已冻结，但 `ResolveBattle.gd` **未实现**。需裁决以谁为准。

### 玩法风险（A-10，非技术问题）

岛屿全局仅 12（Demo）/ 36（全量）个且唯一归属。多人环境下绝大多数玩家占不到岛，**护岛经济对他们失效**。需在多人化前解决。

---

## 知识缺口（我不掌握，需技术穿刺）

| ID | 内容 |
|---|---|
| G-01 | Aleo snarkVM 单 transition 约束硬上限、wasm 环境证明耗时 |
| ~~G-02~~ | ~~可验证随机源~~ → **已关闭**（补遗 01：有 `ChaCha`，仅 finalize，不抗提议者） |
| G-06 | record 能否在 finalize 内产出（需最小 Leo 程序实测） |
| G-03 | 单 transition 可消费 record 数上限（影响 5 卡编队） |
| G-04 | Aleo 实际 fee 与出块间隔（影响 claim 频率） |
| G-05 | Godot 4.7 Web 导出 + JS 互操作稳定性（影响比赛演示主路径） |

> **知识诚实声明**：文档中所有约束数（3k / 66k / 1.0M）、耗时、fee 相关表述均为**基于电路结构的量级估算，未经真机验证**。
> 建议 P1 启动前安排 1~2 天技术穿刺回填 G-01~G-05。**在此之前不得作为排期承诺依据。**

---

## 边界声明

本次交付**仅为架构与决策文档**。未写 Godot 代码、未部署任何链、未触碰 GitHub 仓库、未做 git 操作、未涉及美术。
