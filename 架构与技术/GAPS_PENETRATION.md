# GAPS_PENETRATION · Aleo / Godot 真机技术穿刺计划

> **建表**：2026-08-02 · 主理人锁链收尾
> **目的**：P1 启动前用 1~2 天真机穿刺，把知识缺口 G-01 / G-03 / G-04 / G-05 / G-06 从「量级估算」回填为「已验证数字」。
> **G-02（POI 掉落随机源）已关闭**：见 `addendum-01-verifiable-randomness.md`（Aleo `ChaCha` 仅 finalize、不抗提议者，需 commit-reveal 加固）。
> **负责人**：BV-Eng（程基岩） · **排期**：P1 启动前，不晚于 Phase 3 开赛 Demo 前。

---

## 穿刺总原则

1. 所有数字**必须来自真机**（`snarkvm` CLI + `leo` toolchain / Aleo testnet / Godot 4.7 Web export），不得沿用 `battle-core-zk-readiness-audit.md` §3 的量级估算。
2. 每个缺口回填后，**更新源头文档的数字并标注「已验证」**，同时回填 `control-manifest.md` 的 G 状态行。
3. 任何缺口若**否定**了既有架构假设（如 G-01 证明百万约束不可证明），立即升红灯并回主理人重议 ADR-003 分层策略。

---

## 缺口清单与穿刺方法

| 缺口 | 验证什么 | 真机方法 | 成功判据 / 回填目标 | 阻断决策 |
|---|---|---|---|---|
| **G-01** | Aleo snarkVM 单 transition 约束硬上限；wasm 环境证明耗时 | 用降规格电路（DUEL_SLOTS=3, DUEL_MAX_ROUND=8, MAX_EXTRA_HIT=1，约 66k 约束）跑 `leo` 编译 + `snarkvm` 证明，记录约束数与 wasm 证明耗时/内存 | 拿到可引用的约束数 + 浏览器 wasm 实测耗时；若 66k 仍不可接受 → 触发 ADR-003 进一步降规格 | P2 裁决战规格能否落地 |
| **G-03** | Leo 单 transition 可消费 record 数上限（5 卡编队） | 写最小 Leo 程序一次消费 5 个 record；若触上限 → 改「编队 record」聚合（5 卡封装 1 Fleet record） | 确定 5 卡编队是否需聚合；回填 ADR-001 | 5 卡编队可行性 |
| **G-04** | Aleo 实际 fee 与出块间隔 | testnet 实测单笔 transition fee、平均出块间隔 | 回填 `claim` 频率 / 批量策略 / 日产结算粒度（批量 ≤ STAMINA_MAX=120）；确认每日批量结算成本可接受 | 批量结算经济可行性 |
| **G-05** | Godot 4.7 Web 导出 + JS 互操作稳定性 | 跑比赛 Demo 主路径（方案 B）Web 导出，记录加载/互操作崩溃率 | 确认 Web Demo 主路径稳定；否则回退方案 A（桌面） | 比赛演示主路径 |
| **G-06** | record 能否在 finalize/async 内产出 | 最小 Leo 程序在 finalize 内尝试产出 record，验证 stdlib 行为 | 确定 POI 掉落是否必须两阶段；若否 → 简化掉落流程 | 两阶段是否可简化 |

---

## 交付物

- 每个缺口一份 `out_gNN.txt` 真机读数（放 `design/_scratch/` 或工程仓库）。
- `control-manifest.md` G 状态行从「无可靠数据」更新为「已验证 + 数值」。
- 若任一缺口否定既有假设，提交 ADR 修订议案给主理人。

---

## 不在本计划（已关闭 / 非 Aleo）

- **G-02** 可验证随机源：已关闭（补遗 01）。
- A-13 掉落随机数客户端红线：已写入 `control-manifest.md`，与 G-02 门禁替换。
