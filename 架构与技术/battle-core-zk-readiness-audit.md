# ResolveBattle zk 就绪审计

> 版本 v0.1 · 2026-08-02 · 作者：程基岩（engineering-lead）
> 审计对象：`systems/ResolveBattle.gd`（branch `docs/design`，commit 4e90a37）
> 结论优先级：**本文件是后续所有链上架构决策的输入**。ADR-003 的取舍直接建立在这里的电路预算估算之上。

---

## 0. 一句话结论

`ResolveBattle` 的**结构**非常适合 zk（无 I/O、无副作用、回合上界固定、无实际随机数），
但**实现**目前有 5 项阻断 zk 落地的硬伤，其中 2 项（浮点、哈希承诺不完备）在**不上链的情况下也是 bug**。

---

## 1. 阻断项清单

### BLK-1 · 全链路浮点运算 —— 阻断等级：致命

**现状**

```gdscript
"atk": float(c["atk"]) * float(ship.get("atkMod", 1.0)),
u.atk *= GameData.env_mod_for(u.sys)
var armor_ratio := target.def / (target.def + 100.0)
var raw := attacker.atk * coef * tcoef * (1.0 - armor_ratio)
var dmg := max(1, int(round(raw)))
```

**问题**

1. **Aleo/Leo 没有浮点类型**。整条伤害链无法直接进电路。
2. 更严重的是：这在**链下也不安全**。GDScript `float` = IEEE-754 double，`RESTRAINT_DISADV = 1/1.3` 是无限循环二进制小数。
   连乘 `atk × coef × tcoef × (1-armor_ratio)` 后落在 `int(round())` 的 `.5` 边界上时，
   **不同 CPU（x86 80-bit 扩展精度 vs ARM）、不同 Godot 版本的编译优化，可能给出差 1 的伤害**。
   差 1 点伤害 → 可能改变某回合是否击杀 → 后续目标选择全部分叉 → **胜负翻转**。
3. 因此 D3 验收「同 seed 跑 100 次一致」**在单机成立，但不能证明跨端一致**。
   而跨端一致恰恰是链上可验证战斗的**前提**。

**修复方向**：全面定点化，见 §2。

---

### BLK-2 · 哈希承诺不完备 —— 阻断等级：致命（安全漏洞）

**现状**

```gdscript
var payload := "%s|%d|%d" % [winner, seed, log.size()]
var hash_s := payload.sha256_text().substr(0, 16)
```

**问题**

| 缺陷 | 后果 |
|---|---|
| 只承诺 `winner` / `seed` / `日志条数` | **没有承诺编队、env、日志内容**。攻击者可用完全不同的编队伪造一场「同 winner、同 seed、同条数」的战斗，哈希完全一致 |
| 截断到 16 hex = **64 bit** | 生日攻击约 2³² 次即可碰撞，笔记本分钟级 |
| `sha256` | Aleo 原生友好哈希是 **Poseidon**；SHA-256 在电路里约束数高一个数量级 |
| 未承诺规则版本 | 改了 `constants.md` 后，旧战报仍能"验证通过" |

**这是当前代码里最危险的一项**：`CHAIN_MOCK = true` 的 mock 如果就这样等比例放大到真链，等于没有防作弊。

**修复方向**：

```
commitment = Poseidon8(
    ruleset_hash,      // constants.md + cards.json 的版本哈希
    fleet_a_hash,      // 有序编队 ID 承诺
    fleet_b_hash,
    env_hash,          // 含 ship_id / hp_mult / env_bias
    seed,
    winner, rounds,
    log_merkle_root    // 全量日志 Merkle 根，非条数
)
```

全宽输出，禁止截断。日志用 Merkle 树是为了支持**局部开示**（争议时只披露被质疑的那几条，保住编队隐私）。

> ★ **已修（2026-08-02 锁链，v0.4）**：见 `engineering/ResolveBattle.gd`。承诺改为全宽 `sha256_text()`（禁截断），绑定 `ruleset_hash` / 编队哈希 / env 哈希 / seed / winner / rounds / **日志全文哈希**（不再是条数）。链上工程侧升级为 `Poseidon8` + 日志 **Merkle 根**（字段集不变）。详见 `design/data-spec/RULESET_LOCK.md §6`。

---

### BLK-3 · RNG 声明但从未使用 —— 阻断等级：设计歧义

**现状**

```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = seed
// ...此后 rng 在整个函数中再未被调用
```

**问题**

战斗结果**完全由 `(fleet_a, fleet_b, env)` 决定**，`seed` 只参与最终 hash 字符串，不影响任何一次伤害或目标选择。

**这是好消息也是坏消息：**

- ✅ **好消息（对 zk 极其有利）**：电路内**不需要**实现可验证随机数（VRF / commit-reveal）。
  随机数是 zk 游戏电路里最贵、最容易出安全漏洞的部分，这里直接绕过了。这是 BigVoyage 相对其他 zk 链游的**结构性优势**，应当在比赛叙事中主动强调。
- ❌ **坏消息**：`seed` 提供不了任何不可预测性。玩家可离线穷举所有编队组合找最优解。
  对 PvE 护岛可接受（本来就是解谜）；一旦做 PvP，先手方可完全模拟对手编队 → 需要靠 **Aleo record 的天然隐私**（对手编队不可见）来补，而不是靠 seed。

**待决策**：`seed` 是否应真正影响战斗？→ 列入对齐假设 A-04（见确权边界文档）。
**工程建议**：保持"seed 不影响结果"，把不可预测性交给 record 隐私。改动最小、电路最省、叙事最顺。

---

### BLK-4 · 排序不稳定 —— 阻断等级：高（破坏确定性）

**现状**

```gdscript
order.sort_custom(func(x, y): return x.spd > y.spd)
```

**问题**

Godot 的 `sort_custom` 底层是 introsort（quicksort + heapsort 退化），**不是稳定排序**。
`spd` 相同的两个单位，其相对顺序取决于数组长度与 pivot 选择 —— 换 Godot 版本、换单位数量都可能改变。
`cards.json` 里 20 张卡出现 spd 撞值是大概率事件（4 体系 × 5 卡，数值往往取整）。

**行动顺序变了 → 谁先打谁 → 击杀顺序 → 胜负可能翻转。**

**修复方向**：显式全序，永不依赖库的稳定性。

```
排序键 = (spd DESC, side ASC, slot_index ASC)
```

`uid` 已含 side + index（`"%s%d_%s" % [side, i, cid]`），可直接作为 tiebreak，但建议用结构化三元组而非字符串比较（电路里字符串比较很贵）。

电路内实现：**固定比较网络**（10 元素 Batcher odd-even mergesort = 31 个比较器），不能用数据依赖的快排。

> ★ **已修（2026-08-02 锁链，v0.4）**：`order.sort_custom` 改为显式全序 `if spd 不同: spd 降序; elif side 不同: A<B; else: slot 升序`，永不依赖库稳定性。`_spawn_side` 新增 `slot` 字段作 tiebreak。详见 `design/data-spec/RULESET_LOCK.md §6`。

---

### BLK-5 · 依赖全局可变状态 —— 阻断等级：高（"纯函数"名不副实）

**现状**

```gdscript
GameData.constants.get("GUARD_MAX_ROUND", 30)
GameData.cards[cid]
GameData.ships.get(ship_id, {...})
GameData.env_mod_for(u.sys)
GameData.constants.get("TYPE_COEF", {})
```

**问题**

函数签名声称 `resolve(fleet_a, fleet_b, env, seed)` 是纯函数，实际上读了 4 个全局单例。
**同样的四个入参，在不同 `GameData` 状态下会给出不同结果** —— 这不是纯函数。

链上验证方需要能独立重算，就必须拿到全部 `GameData`。

**修复方向**：

1. 引入 `ruleset_hash = Poseidon(constants ‖ cards ‖ ships ‖ env_table)`，作为**显式入参**并进承诺；
2. 电路把这些值当 **public input**（或编译期常量 + 版本号校验）；
3. 客户端 `resolve()` 增加一个显式 `ruleset` 参数，`GameData` 只做默认值注入。

---

### 次级观察（非阻断，但电路必须精确复刻）

| 项 | 说明 |
|---|---|
| DoT tick 顺序写死 `for side in [units_b, units_a]` | **B 方先结算 DoT**。不对称，但确定；电路必须照抄，不能"优化"成对称 |
| `_apply_dot` 的 `source_sys` 被最后一次施加者覆盖 | 后续 DoT 克制系数随之改变，是有状态的隐式依赖 |
| `dots[uid].dmg = max(旧, 新)` | 取最大而非累加 |
| `_pick_target` 用严格 `>` 比较 | 同分时取数组中**第一个**，依赖 BLK-4 的稳定顺序 |
| 超时判定 `winner = "A" if ha >= hb else "B"` | **平局 HP 时 A 赢**，非 draw。`draw` 分支实际只在双方同时全灭时可达 |
| `hits` 计算 `int(u.spd / seg) - 1` | 整数除法；spd<20 时为 -1，被 `max(0, extra)` 兜住。定点化时注意这里是**整数除法不是定点除法** |
| 常量表里 `MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*` 已冻结但代码未实现 | 电路规格应以**代码实际行为**为准，不以 constants.md 为准；两者需先对齐 |

---

## 2. 定点化方案（建议）

### 2.1 标度

统一十进制定点 **SCALE = 10_000**（4 位小数），全程 `u64` 中间量，字段存储 `u32`。

| 量 | 原值 | 定点值 | 位宽依据 |
|---|---|---|---|
| `RESTRAINT` | 1.3 | `13000` | — |
| `RESTRAINT_DISADV` | 1/1.3 | **不预存常量**，用 `x * SCALE / 13000` | 见下 |
| DoT 系数 | 0.18 | `1800` | — |
| ironwall 护甲加成 | 0.08 | `800` | — |
| `atk` 上限 | STAT_CAP 200 × atkMod × env(≤1.25) | ≤ `3_750_000` | u32 足够 |
| `hp` 上限 | BOSS_HP 5000 × hp_mult | ≤ `1e8` 定点 | u32 边界，中间量用 u64 |
| 累计伤害 | ≤ 5000 × 30 回合 | u32 足够 | — |

> ⚠️ **对称性陷阱**：若把 `1/1.3` 预存为 `7692`，则 `13000 × 7692 / 10000² = 0.99996 ≠ 1`，克制环不再对称，
> 与 SSOT §2.8「对称环」冻结口径**冲突**。必须用除法 `dmg * SCALE / RESTRAINT` 保持精确语义。

### 2.2 舍入锁定

`int(round(x))` 在 GDScript 是 **half-away-from-zero**。电路内需显式实现：

```
round_div(n, d) = (2*n + d) / (2*d)      // 整数除法，d > 0，n >= 0
```

并在**每一处**产生小数的地方标注舍入方向。护甲比 `def/(def+100)` 是**向下取整**（原代码是浮点不取整，直接参与后续乘法）——
定点化时这里会引入与浮点版的**数值偏差**，必须由策划确认可接受（→ 对齐假设 A-02）。

### 2.3 除法在电路里的代价

zk 电路无原生除法。每次 `a / b` 需：witness 提供 `(q, r)`，约束 `a == q*b + r` 且 `r < b`（一个范围证明，约 32–64 约束）。
单次 `_strike` 至少 2 次除法（护甲比 + 舍入），被克时 3 次。**这是电路成本的主要来源。**

---

## 3. 电路预算估算

### 3.1 规模上界（按现行 SSOT 常量）

```
FLEET_SLOTS = 5           → 每方 ≤5 单位，全场 ≤10
GUARD_MAX_ROUND = 30
MAX_EXTRA_HIT = 2         → 单次行动 ≤3 段

每回合：DoT tick ≤10 + 行动 ≤10 单位 × ≤3 段 = ≤30 次 _strike
全场：  _strike ≤ 30 × 30 = 900 次
        DoT tick ≤ 300 次
        排序     30 次 × 31 比较器 = 930 比较器
```

zk 电路**必须完全展开循环**，且**死分支也要计入约束**（无法提前 break）。

### 3.2 约束数量级

| 组件 | 单次约束 | 次数 | 小计 |
|---|---|---|---|
| `_strike` 定点算术（3 乘 + 2~3 除 + 范围证明） | ~150 | 900 | ~135k |
| `_pick_target`（5 次比较 + 条件选择） | ~60 | 900 | ~54k |
| DoT tick（1 乘 1 除 + 层数 clamp） | ~90 | 300 | ~27k |
| 排序网络 | ~40/比较器 | 930 | ~37k |
| 日志 Merkle（1300 叶 Poseidon） | ~300/节点 | ~2600 | ~780k |
| **合计（保守）** | | | **≈ 1.0M+ 约束** |

> Merkle 日志承诺是最大头。若改为**增量 Poseidon 链式承诺**（running hash，无需树）可降到 ~1300 × 300 ≈ 390k，
> 但牺牲局部开示能力。这是一个明确的取舍点。

### 3.3 结论

**百万级约束的单一 transition，在 Aleo 当前证明系统（Varuna）下不现实**：
证明生成时间与内存都会超出普通玩家客户端（尤其浏览器 wasm）可承受范围。

→ **不能把整场战斗塞进一个 Leo transition。** 这直接决定了 ADR-003 的分层策略。

> ⚠️ **知识缺口 G-01**：Aleo snarkVM 当前版本的单 transition 约束硬上限、
> 以及 wasm 环境下百万约束的实际证明耗时，我**没有可靠的最新数据**。上表为量级估算，
> 需在真机（`snarkvm` CLI + `leo` toolchain）跑基准后修正。**不要把这些数字当成已验证结论。**

### 3.4 降规格「链上裁决战」的可行性

若为链上模式单独定义降规格（→ 对齐假设 A-01）：

```
DUEL_SLOTS = 3, DUEL_MAX_ROUND = 8, MAX_EXTRA_HIT = 1
→ _strike ≤ 8 × 6 × 2 = 96 次
→ 约束 ≈ 96×150 + 96×40 + 排序 8×10 + 链式承诺 ~150×300
      ≈ 14k + 4k + 3k + 45k ≈ 66k 约束
```

**约 1/15 的规模，进入可证明区间。**
这就是我推荐的路径：**不要把现有 30 回合战斗硬塞上链，而是设计一个规格天然适配电路预算的「链上裁决战」模式**——
它同时是玩法（高强度短决斗）和技术（可证明）的交集。详见 ADR-003。

---

## 4. 修复优先级

| 序 | 项 | 何时必须做 | 是否阻塞比赛 Demo |
|---|---|---|---|
| P0-1 | BLK-2 承诺不完备 | 2026-08-02 已修（v0.4，全宽绑定承诺） | ★ 已修 |
| P0-2 | BLK-4 排序不稳定 | 2026-08-02 已修（v0.4，显式全序） | ★ 已修 |
| P0-3 | BLK-5 全局状态 → `ruleset_hash` | 立刻（成本低，收益高） | 是 |
| P1-1 | BLK-1 定点化 | 接真链前 | 否（但决定 P2 能否做） |
| P1-2 | BLK-3 seed 语义定稿 | 做 PvP 前 | 否 |

> P0 三项**不依赖任何链上决策**，可立即在现有 Demo 分支修复，且能让 D3 验收从"单机一致"升级为"跨端一致"。
> 建议作为工程侧第一批 Story。

---

## 5. 需要补充的验证证据

当前 `tests/` 内容我尚未读取（本次仅取 `systems/ResolveBattle.gd`）。修复上述项时应补：

- `test_determinism_crossplatform`：固定 ruleset + 100 组随机编队，产出 golden hash 表，CI 在多 OS 跑
- `test_fixedpoint_parity`：定点版与浮点版逐场对比，输出差异分布（供策划判断能否接受）
- `test_commitment_binding`：构造"同 winner 同 seed 同条数、不同编队"的两场战斗，断言新承诺**不**相同（当前实现会 FAIL）
- `test_spd_tie_order`：构造全员同 spd 的编队，断言行动顺序稳定
