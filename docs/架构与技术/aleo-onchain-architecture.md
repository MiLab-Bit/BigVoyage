# BigVoyage · Aleo 链上接入架构

> 版本 v0.1 · 2026-08-02 · 作者：程基岩（engineering-lead）
> 前置阅读：`battle-core-zk-readiness-audit.md`（电路预算依据）
> 相关决策：ADR-001 确权边界 / ADR-002 经济闭环 / ADR-003 zk 战斗验证策略
> 引擎：✅ **Godot 4.7 Forward+（G2 已冻结 2026-08-06）** · 链：Aleo（Leo 语言）
> 数值口径来源：`docs/00-口径冻结表_SSOT.md` v1.1 + `docs/数据层/constants.md`

---

## 1. 架构立场（三句话）

1. **战斗核是入口，但整场战斗不上链。** `ResolveBattle` 的纯函数属性给了我们哈希承诺能力，但完整 30 回合战斗约 10⁶ 约束，超出单 transition 预算（审计 §3）。
2. **最高性价比的 zk 不是"证明战斗"，而是"证明输入合法"。** 用 Aleo record 证明「这些卡确实归我」+「编队满足 COST≤10 / 槽≤5 / 同体系≤4」，约束数以千计，却挡住了链游最大的作弊面——凭空造牌。
3. **分层交付：承诺 → 输入证明 → 裁决战全证明。** 每层独立可交付，任一层停下都是完整故事。

---

## 2. zk 战斗验证落地路径图

```
┌─────────────────────────── 链下 · Godot 4.7 客户端 ───────────────────────────┐
│                                                                              │
│  [1] 玩家编队           [2] ResolveBattle 纯函数            [3] 战报日志       │
│  fleet_a / fleet_b  ──►  resolve(a, b, env, seed,     ──►   log: Array        │
│  env / seed              ruleset)                            {start,hit,      │
│                          ※ 定点整数版（BLK-1 修复后）          dot,kill}        │
│                          ※ 稳定排序（BLK-4 修复后）                            │
│                                │                                │            │
│                                ▼                                ▼            │
│                    [4] 结果 (winner, rounds)        [5] 日志链式/Merkle 承诺   │
│                                │                        log_root              │
│                                └──────────┬─────────────────┘                │
│                                           ▼                                   │
│                        [6] battle_commitment = Poseidon8(                     │
│                              ruleset_hash, fleet_a_h, fleet_b_h,              │
│                              env_h, seed, winner, rounds, log_root)           │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼ L1 承诺层                 ▼ L2 输入证明层              ▼ L3 规则证明层
  ─────────────────           ─────────────────           ─────────────────
  链上只存 commitment          zk 证明「编队合法且              zk 证明「该战报
  + winner + 时间戳            卡牌归我」                      逐条符合规则」
                                                              （仅裁决战规格）
  防篡改 ✅                    防凭空造牌 ✅                    防伪造胜利 ✅
  防作弊 ❌                    防超 COST 编队 ✅
  ~0 约束                      ~3k 约束                        ~66k 约束
  【阶段 P0】                  【阶段 P1】                      【阶段 P2】
```

**关键判断：L2 的性价比远高于 L3。**
链游实际作弊分布中，「用不拥有的强卡」「超出 COST 上限编队」占绝大多数，且是**低门槛作弊**；
「精确伪造一份自洽的 900 条战报日志」需要攻击者完整逆向规则引擎，门槛高得多。
L2 只要 ~3k 约束就能封死前者，而 L3 要 66k~1M 约束才能封死后者。**先做 L2。**

---

## 3. 计算切分：什么上链、什么留本地

### 3.1 三类执行环境

Aleo 的执行模型需要先厘清（这决定了切分方式）：

| 环境 | Leo 对应 | 特性 | 成本 |
|---|---|---|---|
| **transition（链下执行 + 生成证明）** | `transition` 函数体 | 输入输出可私有，消费/产生 record；**计算发生在玩家本机** | 玩家 CPU/内存；约束数决定耗时 |
| **finalize / async function（链上公开执行）** | `async function` | 读写 `mapping`，**全网节点重算**，全部公开 | 链上 fee；必须极轻量 |
| **纯链下（无证明）** | Godot / 服务端 | 无任何可验证性 | 免费 |

> ⚠️ 常见误解：「上链」不等于「链上算」。Aleo 的私有计算发生在**客户端 transition**，
> 链上 `async function` 只做公开状态变更与轻量校验。**任何重计算都不能放进 async function。**

### 3.2 切分表

| 计算 | 归属 | 理由 |
|---|---|---|
| 完整 30 回合战斗模拟 | **纯链下** | ~10⁶ 约束，超预算（审计 §3.3） |
| 战报承诺哈希计算 | **纯链下**，结果作为 transition 入参 | Poseidon 在链下算，链上只存 32 字节 |
| 编队合法性（COST≤10 / 槽≤5 / 同体系≤4） | **transition（P1）** | ~3k 约束，极便宜，价值极高 |
| 卡牌所有权 | **transition（P1）** | record 消费即证明所有权，Aleo 原生能力，近乎零额外成本 |
| 裁决战（3v3 / 8 回合）逐回合状态转移 | **transition（P2）** | ~66k 约束，可行 |
| 岛屿归属仲裁（谁先占） | **async function** | 需要全局公开状态与顺序，必须链上 |
| `$TIDE` mint / burn 与净发行守恒 | **async function** | 经济护栏必须链上强制 |
| 承诺写入 + 挑战期计时 | **async function** | 需要 block height 作时间源 |
| POI 探索（体力扣减、资源产出） | **纯链下** | 高频、即时反馈 |
| **POI 的 NFT 掉落判定** | **async function（每日批量，ChaCha）** | ⚠ **已修订**（见 `addendum-01-verifiable-randomness.md`）。原「纯链下」判断作废——客户端 seed 可被穷举刷 UR，且假掉落会铸成链上真 record |
| POI 掉落的 record 铸造 | **transition（claim）** | ChaCha 仅 finalize 可用、record 仅 transition 可产出 ⇒ 强制两阶段 |
| `strategic` 资源累积（日产 20000） | **纯链下** | 高频、低价值、上链不经济 |
| 体力 / 琥珀币 | **纯链下** | SSOT 明确琥珀币「不链上流通」 |
| 卡牌养成（升星 / 命座 / 舰装） | **纯链下状态 + record re-mint** | 见 ADR-001 §取舍 |
| UI / 战斗表现 / 音效 | **纯链下** | — |

---

## 4. Leo 程序职责边界

拆成 5 个独立 program，边界按**变更频率**与**信任域**划分，避免单程序膨胀。

```
bigvoyage_card.aleo        船员卡 / 船图纸 —— record（私有）
bigvoyage_island.aleo      岛屿所有权     —— mapping（公开）
bigvoyage_battle.aleo      战报承诺 + 验证 —— mapping + transition
bigvoyage_token.aleo       $TIDE 航海晶   —— record + mapping（供应量）
bigvoyage_economy.aleo     护岛日产 claim / 软硬币兑换 —— async function
```

### 4.1 `bigvoyage_card.aleo`

```leo
record CrewCard {
    owner: address,
    card_id: u16,          // 对应 cards.json
    system: u8,            // 0=flame 1=ironwall 2=wind 3=tide
    rarity: u8,            // 0=R 1=SR 2=SSR 3=UR → COST_BY_RARITY
    // 养成态内嵌（见 ADR-001）
    level: u8,
    breakthrough: u8,      // ≤ BREAKTHROUGH_MAX = 6
    constellation: u8,     // ≤ CONSTELLATION_MAX = 6
    // 属性由 (card_id, level, breakthrough, constellation) + ruleset 推导，不冗余存储
    serial: field,         // 防重放/唯一性
}

record ShipBlueprint { owner: address, ship_id: u16, serial: field }
```

**职责**：mint（来自 POI/gacha）、transfer、养成 re-mint（consume 旧 record → 产出新 record）、销毁。
**不负责**：属性计算（放 ruleset，链下推导；争议时在电路内重算）。

> 设计要点：**属性不存进 record，只存养成等级**。否则玩家可篡改客户端伪造高属性 record？
> ——不能，record 只能由 program 的 transition 产生。但存等级而非属性能让 ruleset 调整（平衡性 patch）不需要重铸全网卡牌。

### 4.2 `bigvoyage_island.aleo`

```leo
mapping island_owner: u8 => address;        // FR_01..FR_12 → owner
mapping island_claimed_at: u8 => u32;       // block height，用于挑战期与日产计算
mapping island_guard_defeated: u8 => field; // 占岛所依据的 battle_commitment

async transition claim_island(island_id: u8, commitment: field, ...) -> Future
```

**职责**：岛屿归属的**唯一权威**。12（Demo）/ 36（全量）个稀缺位置，必须公开可见（海图要显示谁占了岛）。
**冲突解决**：同一岛多人同时 claim → 链上按交易顺序，先到先得；后到者交易 revert。

### 4.3 `bigvoyage_battle.aleo`

```leo
mapping battle_record: field => BattleMeta;   // commitment => {winner, block, challenger, status}

// P0：仅承诺
async transition commit_battle(commitment: field, winner: u8, island_id: u8) -> Future

// P1：承诺 + 编队合法性 + 卡牌所有权（消费 record 再返还）
transition commit_battle_verified(
    c1: CrewCard, c2: CrewCard, c3: CrewCard, c4: CrewCard, c5: CrewCard,
    slot_mask: u8,          // 哪些槽位有效，支持不满编
    env_h: field, seed: u64, winner: u8, rounds: u8, log_root: field
) -> (CrewCard, CrewCard, CrewCard, CrewCard, CrewCard, Future)
// 电路内断言：Σ COST_BY_RARITY[rarity] ≤ 10
//              popcount(slot_mask) ≤ 5
//              任一 system 计数 ≤ 4
//              commitment == Poseidon8(...)

// P1.5：挑战期
async transition challenge_battle(commitment: field) -> Future
// P2：裁决战全证明
transition prove_duel(witness: DuelTranscript, ...) -> Future
```

### 4.4 `bigvoyage_token.aleo`

```leo
record TideToken { owner: address, amount: u64 }
mapping total_minted: u8 => u64;
mapping total_burned: u8 => u64;
// 护栏：net_issuance ≤ 0 ⇒ 断言 total_minted ≤ total_burned + genesis_supply
```

对齐 `resources.json` 的 `"net_issuance": "<=0"`。**这条经济护栏用链上断言强制，而不是靠数值表自觉**——
这是「把经济纪律写进代码」的最佳示范，也是比赛叙事的加分项。

### 4.5 `bigvoyage_economy.aleo`

```leo
mapping last_claim_height: (address, u8) => u32;    // 护岛日产防重复领取
mapping soft_exchange_today: (address, u32) => u8;  // SOFT_EXCHANGE_DAILY_CAP = 3

async transition claim_island_yield(island_id: u8, ...) -> Future
// 断言：island_owner[island_id] == self.caller
//       current_height - last_claim_height ≥ 一日区块数
//       产出 = f(island_tier, 持有天数)，受日产上限约束
```

---

## 5. 证明生成与验证方案

### 5.1 客户端集成路径（Godot 4.7 无官方 Aleo SDK）

三条路，按阶段推进：

| 方案 | 做法 | 优点 | 缺点 | 建议阶段 |
|---|---|---|---|---|
| **A · Sidecar 进程** | Godot 通过 HTTP/stdio 调本机 Rust CLI（snarkVM / Leo toolchain） | 实现最快，复用官方 Rust 栈，调试方便 | 需分发额外可执行文件，桌面端限定 | **P1（开发/内测）** |
| **B · Web + wasm SDK** | Godot Web 导出 + JS 互操作调 Aleo wasm SDK，钱包用 Leo Wallet / Puzzle | 比赛评审一键打开，无需安装；钱包生态现成 | 浏览器内证明耗时/内存受限；Godot Web 导出体积 | **P1/P2（比赛演示主路径）** |
| **C · GDExtension 封装** | Rust GDExtension 直接绑定 snarkVM | 原生体验，无进程边界 | 工作量最大，跨平台编译矩阵麻烦 | P2+（若做正式发行） |

**推荐**：**A 做开发，B 做比赛演示**。C 暂不投入。

### 5.2 证明生成的体验权衡

zk 证明生成是**秒级到分钟级**的操作，绝对不能卡在战斗结算的关键路径上。

```
玩家点击「挑战护岛者」
    │
    ├─► [0ms]     本地 ResolveBattle 跑完（纯函数，微秒级）
    ├─► [即时]     战斗动画播放（3~8 秒，Juice/Sfx）
    │                 ▲
    │                 └── 证明生成在此窗口内后台并行进行
    ├─► [动画结束]  展示胜负结果（此时结果已确定，UI 无需等待）
    │
    └─► [后台]     证明就绪 → 提交上链 → 海图上岛屿状态从
                   「结算中（半透明旗帜）」→「已确权（实心旗帜）」
```

**设计原则**：

1. **结果即时，确权异步。** 玩家永远不等待证明。战斗动画天然提供了 3~8 秒的掩蔽窗口。
2. **失败可重试，状态不丢。** 证明失败/交易失败 → 岛屿停留在「结算中」，客户端持久化战报 witness，可重试。
3. **批量提交。** 单次 POI/小战斗不上链；玩家可累积多场，在「返航」时批量提交（一次交易多个承诺），显著摊薄 fee 与证明开销。
4. **「结算中」是可玩的状态，不是 loading。** 让链的延迟成为航海叙事的一部分——「消息正在随船传回」。

### 5.3 验证侧

- **L1/L2**：验证由 Aleo 全网节点在交易上链时自动完成，无需自建验证服务。
- **争议开示**：挑战发起后，被挑战方需在窗口内提交日志的 Merkle 局部开示或完整证明。
  这要求日志承诺用 **Merkle 树**而非链式哈希（审计 §3.2 提到的取舍）——为了可挑战性，接受多出的约束。
- **索引服务**：海图需要展示全服岛屿归属、战报流水。链上 mapping 逐个查询太慢 →
  需要一个**链下索引器**（订阅 Aleo 区块 → 建 PostgreSQL 视图 → 供客户端查询）。这是纯读服务，不影响信任模型。

---

## 6. 阶段路线图

| 阶段 | 内容 | 交付形态 | 依赖 |
|---|---|---|---|
| **P0 · 承诺规范化** | 修复审计 P0 三项（BLK-2/4/5）；承诺格式定稿；仍 `CHAIN_MOCK=true` | Demo 内可跑，跨端确定性可验证 | 无链依赖，**立即可做** |
| **P1 · 确权上链** | `card` / `island` / `token` 三程序；编队合法性 + 所有权证明（L2）；testnet 部署；Sidecar 集成 | 真链 testnet 可交互 | 定点化（BLK-1）非必需 |
| **P1.5 · 乐观验证** | 承诺 + 挑战期；欺诈争议流程 | 完整反作弊叙事 | P1 |
| **P2 · 裁决战全证明** | 降规格 3v3/8 回合电路（L3）；Web + wasm 演示 | 比赛核心 zk 亮点 | 定点化 + 策划定规格（A-01） |

**比赛最小可交付 = P0 + P1**。P1.5/P2 是加分项，按剩余时间取舍。

---

## 7. 风险与知识缺口

| ID | 项 | 影响 | 处置 |
|---|---|---|---|
| **G-01** | Aleo snarkVM 单 transition 约束硬上限、wasm 环境证明耗时 —— **我没有可靠的最新数据** | 直接决定 P2 裁决战规格能否落地 | 必须真机基准：`leo` toolchain 跑降规格电路测耗时。**在此之前 §3 的数字只是量级估算** |
| ~~G-02~~ | ~~可验证随机源（POI 掉落 1/480、1/960）~~ | **已关闭** | ✅ 已核实 Aleo 有原生 `std::rand::chacha_*` / `rand.chacha`，但**仅 finalize 上下文可用**，且**不抗区块提议者**（官方文档明示需 commit-reveal 加固）。方案见 `addendum-01-verifiable-randomness.md` |
| **G-06** | record 能否在 finalize/async 内产出（stdlib 文档未明文写死） | 决定 POI 掉落是否必须两阶段 | 我判断为**否**（finalize 只操作 mapping），但需用最小 Leo 程序实测确认 |
| **G-03** | Leo 语言当前版本语法与 record 上限（单 transition 可消费 record 数） | 5 张卡的编队需一次消费 5 个 record，可能触及上限 | 若受限，改为「编队 record」聚合：一次性把 5 卡封装成 Fleet record |
| **G-04** | Aleo 交易 fee 实际水平与出块间隔 | 决定 claim 频率、批量策略、日产结算粒度 | 需实测 testnet |
| **G-05** | Godot 4.7 Web 导出 + JS 互操作的稳定性 | 影响比赛演示主路径（方案 B） | 早期做技术穿刺 |
| R-06 | 定点化会改变战斗数值结果 | 已有平衡性数据可能失效 | 需策划确认容忍度 → 对齐假设 A-02 |
| R-07 | 岛屿是全局稀缺资源（12/36 个） | 多人竞争下绝大多数玩家占不到岛 → 护岛经济对多数人失效 | **策划侧问题**，需在多人化前解决（分服？岛屿分层？） |

> **知识诚实声明**：G-01/G-02/G-03/G-04 涉及 Aleo 生态的具体参数与能力边界，超出我可靠掌握的范围。
> 本文档中所有约束数、耗时、fee 相关表述均为**待验证估算**，不得作为排期承诺依据。
> 建议在 P1 启动前安排 1~2 天技术穿刺专门消解这四项。
