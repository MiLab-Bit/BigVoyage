# A-01 · 链上裁决战（on-chain duel）规格

> **作者**：游承峰（主理人） · **日期**：2026-08-02 · **关联**：`COMPILATION-REPORT.md §4`（A-01 行） / `10-经济 §8 A-01` / `GDD-03 §6.6` / `adr-003-zk-battle-verification-strategy.md`
> **状态**：✅ **裁决已确认（降规格）**；本文件将其落成**可合入工程的数据/链上接口规范**。
> **性质**：新玩法模式（Should 级 zk 亮点）；Demo 可用"演示模式"代替完整玩法。

---

## 0. 一句话

链上裁决战 = 把"主线战斗核"原样搬到链上，但**强制降规格**（3 槽 / COST≤6 / 8 回合），既是为了 Aleo 电路约束，也是策划**主动要求的独立 meta**（玩家不能把主线三张最强 UR 直接搬来）。

---

## 1. 降规格参数（已冻，进 `ruleset_hash` 体系，复用战斗终表）

```
DUEL_SLOTS          = 3        # 链上裁决战编队槽数（主线 FLEET_SLOTS=5）
DUEL_CAPACITY(COST) ≤ 6        # 3 张 UR = COST12 > 6 → 无法直接搬主线最强三卡
DUEL_MAX_ROUND      = 8        # 回合上限（主线 GUARD_MAX_ROUND=30）
DUEL_SAME_SYS_CAP   = 2        # 同体系最多 2 张（主线 SAME_SYS_SOFT_CAP=4）
MAX_EXTRA_HIT       = 1        # 疾风多段额外段数收紧（主线=2）
```

`bv_engine.verify` 实测：合法编队 **740 种**（3 槽满编 552 种），TTK 中位 **6.5 回合**，**63% 在 8 回合内自然分胜负**，其余按剩余 HP% 判（平局归守方）。

> **关键设计点**：`COST ≤ 6` 使裁决战自带独立构筑空间——UR 在主线靠数值压场，裁决战里 UR 单卡 COST4 已占 2/3 预算，必须搭配 R/SR，反而逼出"机制构筑"（呼应 R1 的 UR 独占效果）。

---

## 2. 链上两段结构（强制，由 Aleo 约束决定）

| 段 | 程序 | 输入 | 行为 | 输出 |
|---|---|---|---|---|
| **transition** | `submit_duel(fleet_hash, env_hash, seed_commit)` | 玩家编队（查 `CrewCard` record 验证归属）、环境表 hash、`seed` 的 commitment（而非裸 seed） | 校验编队合法性（COST/同体系/槽数）、扣体力、记录对战请求 | 对战 ticket（含 `ruleset_hash`） |
| **finalize** | `resolve_duel(ticket)` | ticket + 链上可读的编队数据 + `ChaCha` 决定性随机（仅 finalize 可用） | 跑 `ResolveBattle` 确定性核 → 出 winner/rounds/log | 战报 record（绑定 `ruleset_hash` / 编队 / env / seed / winner / rounds / **log 全文 Merkle**） |

**为什么两段**：Aleo `ChaCha` 随机数**只能在 finalize 调用**（补遗 01 / O-2 关闭）。链下无法作弊改结果，因为结果由 finalize 内确定性核 + 链上随机算出，战报可任意第三方复算验证。

---

## 3. 战报 record 与局部开示

```
struct DuelReport {
    ruleset_hash: field,        // 战斗常量版本（同主线）
    fleet_a_hash: field,        // 攻方编队（CrewCard 集合 commitment）
    fleet_b_hash: field,        // 守方编队
    env_hash: field,            // 环境表（season/island tier）
    seed_commit: field,         // 随机源 commitment
    winner: bool,               // A 胜?
    rounds: u8,
    log_merkle_root: field,     // 逐回合 log 的 Merkle 根
    log_merkle_proof: Vec<...>, // 争议时只披露被质疑的回合（护编队隐私）
}
```

> 全宽输出、禁止截断（BLK-2 已修 v0.4）。Merkle 是为支持**局部开示**：争议时只披露被质疑的那几条，保住编队隐私。

---

## 4. 与占岛 / 护岛经济的接口

| 接口 | 方向 | 说明 |
|---|---|---|
| 裁决战胜 → 岛屿易主 | duel → 占岛 | 攻岛守卫战即一种"预设编队的裁决战"（FR_12 Boss 岛）。占岛 D4 验收 = 打赢守卫 → 岛屿归属变更原子事件（GDD-02 G5）。 |
| 岛屿日产 | 占岛 → 经济 | 占岛后 `ISLAND_DAILY_YIELD=120` 开始累积（A-07，闸门 C 已解设计侧）。 |
| 裁决战奖励 | duel → $TIDE | 比赛名次奖励走 `SEASON_POOL=5000` 划拨（net_issuance≤0 结构性成立，A-08）。**不在回路内 mint**，避免通胀护栏被破。 |
| 体力 | 通用 | `STAMINA_COST_RAID=8` 攻岛 / 裁决战共用体力池（GDD-02 §3），`STAMINA_MAX=120` 为每日天花板。 |

---

## 5. 与既有决策的衔接

- **A-04（无随机）**：主线战斗"一切可计算、同编队必同结果"。**裁决战同样适用**——`seed` 仅作战报承诺字段，不影响 `ResolveBattle` 确定性输出。UI 须明示"本战无随机数"。
- **A-11（card_id 稳定性）**：编队验证查 `CrewCard` record（u16 + 身份永冻），改卡不破旧战报。
- **ruleset_hash**：裁决战复用主线 `ruleset_hash`（同字段集），不另立；降规格差异（DUEL_*）走**编队合法性校验层**，不进战斗常量。
- **ADR-003**：裁决战全证明（L3）是 P2 比赛核心 zk 亮点，依赖本降规格落地。

---

## 6. 工程合入待办（WS-A）

1. 新增 `submit_duel` / `resolve_duel` 两个 transition/finalize 对。
2. 编队合法性电路：COST≤6 / 同体系≤2 / 槽数=3（复用主线合法性，加 DUEL 维度）。
3. 战报 record 结构按 §3 落 Leo struct；log Merkle 树在 finalize 内构建。
4. Demo 演示模式：可先不做完整 UI，用"预设对手 + 一键开战 + 结果页"代替编队页。

> **下一步**：策划补裁决战 UX（编队页 + 对战页 + 结算页）属 Should；不阻塞 Phase 3 进入。
