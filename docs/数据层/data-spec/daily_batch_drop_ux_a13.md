# A-13 · 每日批量掉落 UX（daily batch drop）

> **作者**：游承峰（主理人） · **日期**：2026-08-02 · **关联**：`COMPILATION-REPORT.md §4`（A-13 行） / `addendum-01-verifiable-randomness.md §7`（A-13） / `asset-ownership-boundary.md §4 A-13` / `G-02 已关闭`
> **状态**：✅ **裁决已确认（每日批量结算体验可接受）**；本文件落成**可合入的 UX + 链上对齐规范**。§3 掉落率口径已按《裁决登记册》[B4] 已决（2026-08-06 采 A Reading 2）生效。
> **性质**：体验规范；与 G-02 门禁替换（A-13 成为红线）协同。

---

## 0. 一句话

探索即时给资源，NFT 掉落**每日 1 次批量结算**——包装成航海叙事"返航清点货舱"，一次性开出当日全部收获。技术约束（随机数只在 finalize）反而变成体验亮点。

---

## 1. 三段结构（强制，由 Aleo 约束决定）

```
[链下] 探索 POI  → 即时给 strategic +500（POI_RESOURCE_BASE），累计"待结算探索次数"
   ↓（每日 1 次）
[transition] daily_poi_draw(today_poi_count)  → 提交当日探索票据（count，≤ STAMINA_MAX=120）
   ↓
[finalize]   ChaCha(ticket) 抽 N 张 NFT  → 出 draw_result（含 rng 轨迹）
   ↓
[transition] claim_poi_drop(draw_result)  → mint CrewCard / ShipBlueprint record
```

- **随机数红线（G-02 关闭后）**：掉落随机**永不来自客户端**，只在 finalize 用 `ChaCha`（补遗 01）。客户端不可预测/不可注入。
- **票据上限**：`today_poi_count ≤ STAMINA_MAX=120` → 谎报上限 = 诚实上限，无套利空间。

---

## 2. 玩家侧 UX 规范

| 环节 | 规范 | 反模式 |
|---|---|---|
| **探索中** | 即时显示"获得 战略资源 +500"；NFT 不即时弹，显示"货舱待清点：今日已探索 N 次" | 探索当下播 UR 掉落动画（破坏去信任） |
| **结算时刻** | 每日固定链上日（A-09）触发"返航清点"：1 次开箱动画，**逐张**展示当日 NFT（不揭示 RNG 过程） | 120 次单抽碎片反馈 |
| **空箱** | 当日无 NFT 也展示"清点完成，明日再战"（保留仪式感） | 静默无反馈 |
| **失败重试** | `daily_poi_draw` 用"日期+玩家"作幂等 id；若 `claim` 失败，次日同 id 可重放，**不重复发** | 重复领取 / 丢失 |

> **叙事包装**（补遗 01 建议）：把每日结算说成"夜晚返航、在灯下清点今日货舱"——天然解释为什么结算在一天结束时，且比 120 次单抽更有仪式感。

---

## 3. 掉落率口径（联动 A-14）

- `POI_DROP_CREW_RATE = 1/480`（冻结值）；本节按 **Reading 2** 语义（每次探索的 crew NFT 最终概率）撰写——**该语义已由《裁决登记册》[B4] 确认为已决口径（2026-08-06 采 A）**，详见 `drop_rate_calibration_a14.md`。
- 当日 NFT 数量 = `ChaCha` 对 `today_poi_count` 次独立伯努利（crew 1/480、ship 1/960）的抽样结果；资源总是给。`poi_yield.*.weight` 仅决定批量开箱的**构成展示**（统计口径），不改变单次概率。
- 批量结算不改变单次概率，只是把"开箱动画"延迟到一天结束——**概率与即时开箱完全等价**，玩家无损失。

---

## 4. 与闸门 D 的衔接

`addendum-01 §8` 新增的第 4 个跨层闸门 **D · POI 掉落抽取**（`daily_poi_draw` + `claim_poi_drop`）是本 UX 的链上承载。闸门 D 形态 = 每日批量；若策划曾要求"即时开箱"，则闸门 D 需退回中心化（放弃去信任）——**当前裁决否决此路**。

---

## 5. 工程合入待办（WS-A）

1. `daily_poi_draw` / `claim_poi_drop` 两个 transition/finalize 对（复用补遗 01 闸门 D 设计）。
2. 客户端"待清点"计数 UI + "返航清点"开箱动画。
3. 幂等 id = `(address, chain_day)`，防重复领取。
4. 红线写入 `control-manifest.md`：掉落随机仅 finalize。

> **边界**：本 UX 不阻塞 Phase 3 进入；但 G-02 门禁已替换为 A-13 红线，工程侧**必须**按此实现，否则去信任性失效。
