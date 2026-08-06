# 补遗 01 · 可验证随机源与 POI 掉落防刷

> v0.1 · 2026-08-02 · 程基岩（engineering-lead）
> 触发：team-lead 转来 O-2（design-strategist 经济数值校准 §8）——`seed_day` 客户端自选可被刷到出 UR
> 状态：**关闭知识缺口 G-02**（`aleo-onchain-architecture.md` §7）
> 影响：`aleo-onchain-architecture.md` §3.2 切分表「POI 探索与掉落判定 → 纯链下」一行**作废**，以本文为准

---

## 1. 威胁确认：O-2 成立，且比描述的更严重

design-strategist 的判断正确。补充两点精确化：

**攻击成本近乎为零。** 掉落判定若是 `f(seed_day, island_id, ...)` 的纯函数且 `seed_day` 由客户端提供，
玩家不需要逆向任何逻辑——**本地跑客户端自己的代码穷举 seed 即可**。
`POI_DROP_CREW_RATE = 1/480`，期望 480 次尝试出一张；本地循环毫秒级完成。

**这不是"部分失效"，是掉落经济彻底归零。** 而且危害面比一般作弊更大，因为按 ADR-001，
`crew_card` / `ship_blueprint` 是**上链 record**。链下刷出来的假掉落一旦铸成 record，
就成了**链上真资产**，可进二级市场流通——**污染的是真实经济，不可回滚**。

> 换句话说：这条漏洞会把「链下作弊」洗成「链上合法资产」。在所有已盘点的 9 个作弊面里，
> 这是唯一一个**能把假货变成真货**的。优先级应高于我原先排的 #6。

---

## 2. Aleo 实际提供什么（已核实）

查证 Leo 官方文档（`docs.leo-lang.org` stdlib v4.3.4 / `docs.aleo.org` finalize operations），确认：

### ✅ 有原生链上随机数

```leo
// Aleo instructions
rand.chacha [seed1] [seed2] into r as type;   // 最多 2 个可选 seed

// Leo stdlib（新）
std::rand::chacha_bool() / chacha_u128() / chacha_field() ...
// Leo（旧语法，随版本变化）
ChaCha::rand_u32()
```

支持输出类型：`address, bool, field, group, scalar, u8–u128, i8–i128`。

### ⚠ 但有三条硬约束

| # | 约束 | 原文依据 |
|---|---|---|
| **C1** | **只能在 finalize / async 上下文调用** | 「Every function here is a `final fn`」「A `final fn` may only be called from inside another `final fn` body or a `final {...}` async block」——**transition 内不可用** |
| **C2** | **对区块提议者不是不可预测的** | 「deterministic for a given block…**observable by the block proposer**. The proposer can observe the seed and selectively withhold or reorder transactions; randomness that must resist a malicious proposer needs a **commit-reveal scheme on top**」 |
| **C3** | **finalize 的输入与状态全部公开** | finalize 由全网验证者重算，无隐私 |

### 🔑 由 C1 导出的关键架构结论

**随机数在 finalize，record 铸造在 transition —— 两者不在同一执行上下文。**

因此**不可能**做到「一次调用内：掷随机 → 直接铸出 CrewCard record」。
**两阶段模式是被语言约束强制的，不是设计选择。**

> ⚠ 置信度说明：C1/C2/C3 有官方文档原文支撑，高置信。
> 「record 只能由 transition 输出、不能在 finalize 内产出」这一条，
> stdlib 文档未明文写死，我依据 Aleo 执行模型判断为真（finalize 只操作 mapping），
> **但建议实现前用一个最小 Leo 程序实测确认**。

---

## 3. 第二个约束：链上频次不可行

即使有随机数，也不能每次 POI 都上链：

```
STAMINA_MAX = 120，POI 探索 1 体力/次  → 每人每日最多 120 次 POI
POI_DROP_CREW_RATE = 1/480            → 期望 120/480 = 0.25 张船员卡/日
POI_DROP_SHIP_RATE = 1/960            → 期望 120/960 = 0.125 张船图纸/日
```

**为 0.375 个期望掉落，付出 120 笔链上交易/人/日——不可行。**
（fee 不论，出块延迟就让 POI 探索无法进行。）

⇒ **必须批量化。**

---

## 4. 方案对比

| 方案 | 做法 | 评价 |
|---|---|---|
| A · 客户端 seed | 现状 | ❌ O-2 漏洞本体 |
| B · 服务端权威随机 | 服务端掷随机并签名 | ✅ 精确、零延迟<br>❌ 引入中心化可信第三方，与 zk 去信任叙事冲突；服务端被攻破 = 无限铸 NFT |
| C · 每次 POI 上链掷 ChaCha | 每次探索一笔交易 | ✅ 完全杜绝客户端刷<br>❌ 120 笔/日/人，**不可行**（§3） |
| D · 区块哈希/高度当 seed | `seed = f(block.height)` | ❌ 全服同一区块内所有玩家同 seed；且玩家可等待有利区块再提交 = **换个刷法** |
| **E · 每日批量链上抽取（采用）** | 链下累积「探索票」→ 每日 1 笔交易链上 ChaCha 批量掷 | ✅ 1 笔/日/人，可行<br>✅ 客户端无法影响 seed<br>⚠ 票数需要约束 |
| F · commit-reveal 双方共同贡献熵 | 玩家先 commit 秘密，链上 ChaCha 后 reveal，`seed = ChaCha ⊕ secret` | ✅ 抗提议者操纵<br>❌ 多一轮交互；需处理"不 reveal"的惩罚 |

---

## 5. 采用方案：E 为主干，F 作为后续加固

### 5.1 两阶段结构（被 C1 强制）

```
── 阶段 1：链下累积（免费、即时）──────────────────────────
  玩家每次 POI 探索：
    · 扣 1 体力（链下）
    · 立即给 strategic 资源（链下，无 NFT 判定）
    · 生成一张「探索票」ticket = {island_id, poi_type, local_nonce}
    · 票进入本地累积链：ticket_chain = Poseidon(prev, ticket)
  ⇒ 玩家体验完全无延迟，与当前 Demo 一致

── 阶段 2：每日 1 笔链上抽取 ────────────────────────────
  transition daily_poi_draw(ticket_count: u8, ticket_chain_root: field) -> Future

  async function（链上，全网重算）:
    1. assert(ticket_count <= 120u8)                    // ← STAMINA_MAX 硬上限
    2. assert(last_draw_height[caller] + BLOCKS_PER_DAY <= block.height)
    3. for i in 0..MAX_DRAW:                            // 固定展开
         if i < ticket_count:
           let r: u32 = std::rand::chacha_u32();        // ← 客户端无法影响
           if r % 480u32 == 0u32 { crew_hits += 1 }
           if r2 % 960u32 == 0u32 { ship_hits += 1 }
    4. pending_drop[caller] = {crew_hits, ship_hits, expires_at}
    5. last_draw_height[caller] = block.height

── 阶段 3：领取（transition 铸 record）──────────────────
  transition claim_poi_drop(...) -> (CrewCard, Future)
  async function: assert(pending_drop[caller].crew_hits > 0); 递减
  ⇒ 断言失败则整笔交易 revert，record 不生效
```

### 5.2 为什么 `ticket_count ≤ 120` 就够了

这是本方案的核心，与 ADR-002 闸门 B3「日限即上限」是**同一个思想**：

> **不去验证玩家是否真的探索了 N 次，而是让「谎报的上限」= 「诚实玩家的上限」。**

`STAMINA_MAX = 120` 且 `daily_00_clear`（SSOT 冻结口径）⇒
一个诚实玩家一天最多也就 120 次 POI。链上把 `ticket_count` 卡死在 120，
则**最坏情况下的作弊者，产出恰好等于满勤玩家的产出**——
NFT 日增发上限不变，`crew_card` 的稀缺性与经济模型的发放假设**不受破坏**。

**O-2 由此关闭**：seed 不再由客户端提供，穷举无从谈起；
谎报票数的收益上界 = 正常游玩收益，无套利空间。

### 5.3 残留缺口与分级加固

| 残留 | 严重度 | 加固 | 阶段 |
|---|---|---|---|
| **挂机号可白嫖满额票数**（不玩也报 120） | 中——不破坏经济上限，但削弱"探索"的意义 | 阶段 1 的 `ticket_chain_root` 加 zk 证明：证明持有 N 张合法票且体力守恒 | P1.5 |
| **区块提议者可操纵**（C2）：验证者可模拟 finalize，对自己不利就重排/扣留 | 中——需**是验证者或与之勾结**，门槛远高于改 JSON | 方案 F：玩家在前一日 commit `hash(secret)`，次日 draw 时 reveal，`seed = ChaCha ⊕ secret` | P2 |
| **掉落结果公开**（C3）：finalize 公开 ⇒ 谁抽到什么全网可见，与 CrewCard record 私有性矛盾 | 低——但确实是隐私回退 | `pending_drop` 存**承诺** `Poseidon(card_id, blinding)`，claim 时在电路内证明知晓原像 | P1.5 |
| 玩家看到结果后拒绝 claim | 无 | 无需处理：体力已扣、票已消耗、无重抽机会，纯自损 | — |

---

## 6. 对既有文档的修订

| 文档 | 修订 |
|---|---|
| `aleo-onchain-architecture.md` §3.2 | 「POI 探索与掉落判定 → 纯链下（P0/P1）」**作废**。改为：**POI 探索链下；掉落判定 = 每日批量 async function（ChaCha）；record 铸造 = transition** |
| `aleo-onchain-architecture.md` §7 | **G-02 关闭**（有 `ChaCha::rand_*`，但仅 finalize，且不抗提议者）。新增 G-06：record 能否在 finalize 产出，待实测 |
| `onchain-offchain-economy-loop.md` §4.1 #6 | 「刷 POI 掉落 · **当前无防线**」→ 改为「**P1 · 每日批量链上 ChaCha + 票数≤STAMINA_MAX**」 |
| `onchain-offchain-economy-loop.md` §1 | **新增第 4 个闸门 D · POI 掉落抽取**（`daily_poi_draw` + `claim_poi_drop`）。跨层通道从 3 个变 4 个 |
| `control-manifest.md` | 新增红线：**掉落随机数永不来自客户端**；G-02 门禁解除，替换为 A-13 |
| `asset-ownership-boundary.md` §4 | 新增对齐假设 **A-13**（见下） |

---

## 7. 新增对齐假设（需策划确认）

| ID | 假设 | 若被推翻 |
|---|---|---|
| **A-13** | POI 掉落可接受「**探索即时给资源，NFT 掉落每日 1 次批量结算**」的体验模式；玩家不要求探索当下立刻看到 UR 掉落动画 | 若要求即时开箱反馈 → 只能退回方案 B（中心化服务端签名），放弃去信任性；或接受每次探索 1 笔链上交易（不可行） |
| **A-14** | `resources.json` 的 `poi_yield` 权重（crew 0.6 / resource 0.9 / ship 0.3 / crew_ur 0.05）与 `POI_DROP_CREW_RATE = 1/480` 的**关系需明确**：是「先按权重选类型、再按 1/480 判定」还是「1/480 是已含权重的最终概率」 | 直接影响 async function 内的判定逻辑与实际发放量。**当前两种读法都说得通，是数值口径缺口** |

> A-13 是**体验取舍**，请策划裁决。我的建议：把每日结算包装成航海叙事——
> 「返航清点货舱」，一次性开出当日全部收获。这比 120 次单抽的碎片反馈**更有仪式感**，
> 且天然解释了为什么结算在一天结束时。技术约束反而能变成体验亮点。

---

## 8. 一句话结论

**O-2 确认成立且危害被低估**（能把链下假货洗成链上真资产）。
**Aleo 有原生 `ChaCha` 随机数可彻底关闭它，但只能在 finalize 调用**，
这强制了「链下探索累积 → 每日链上批量抽 → transition 铸 record」的三段结构。
票数上限直接复用已冻结的 `STAMINA_MAX = 120`，使**谎报上限 = 诚实上限**，无套利空间。
残留的提议者操纵风险门槛高（需为验证者），列 P2 用 commit-reveal 加固。
**待策划确认 A-13（每日批量结算的体验可接受性）与 A-14（掉落率口径）。**
