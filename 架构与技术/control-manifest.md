# 控制清单 · BigVoyage 链上接入

> 一页规则，程序员可立即执行。冲突时以 `00-口径冻结表_SSOT.md`（真值在 `design/data-spec/RULESET_LOCK.md`）为准。
> v0.1 · 2026-08-02 · 程基岩

---

## 立即执行（P0 · 不依赖任何链上决策）

- [ ] **承诺必须绑定全部输入**。`Poseidon8(ruleset_hash, fleet_a_h, fleet_b_h, env_h, seed, winner, rounds, log_root)`。
      **禁止截断输出**。现行 `payload = "winner|seed|log.size()"` + `substr(0,16)` 是安全漏洞，必须删除。
- [ ] **排序永不依赖库的稳定性**。全序键 `(spd DESC, side ASC, slot_index ASC)`。
- [ ] **`resolve()` 必须真纯函数**。`GameData.*` 全部改为显式 `ruleset` 入参，`GameData` 只做默认值注入。
- [ ] 补测试：`test_commitment_binding`（当前实现会 FAIL）、`test_spd_tie_order`、`test_determinism_crossplatform`（多 OS CI）。

## 编码红线

- [ ] **战斗核零浮点**。定点 `SCALE = 10_000`，中间量 `u64`，字段 `u32`。
- [ ] **`1/1.3` 禁止预存常量**。必须写 `x * SCALE / RESTRAINT`，否则克制环失去对称性，违反 SSOT §2.8。
- [ ] **每处舍入显式标注方向**。`round_div(n,d) = (2n+d)/(2d)`；护甲比 `def*SCALE/(def+100)` 向下取整。
- [ ] **战斗核不读全局、不写日志文件、不碰 UI**。
- [ ] **电路规格以代码实际行为为准，不以 `constants.md` 为准**。
      `MAX_STUN_ROUND` / `MAX_SHIELD_MULT` / `TRUE_DMG_*` 已冻结但代码未实现 —— 先对齐再实现（A-12）。

## Aleo 边界

- [ ] **重计算绝不放进 `async function`**（链上全网重算）。私有计算放 `transition`（客户端执行）。
- [ ] **整场 30 回合战斗不进单个 transition**（~10⁶ 约束，超预算）。
- [ ] **record 只存养成等级，不存推导属性**。平衡性 patch 不得要求重铸全网卡牌。
- [ ] **未同步的链下养成，不生效于链上战斗**。链上战斗以 record 内等级为准。
- [ ] **跨层价值流动只允许 4 个闸门**：`claim_island` / `exchange_soft_to_tide` / `claim_island_yield` / `daily_poi_draw`+`claim_poi_drop`。新增通道需过 ADR。
- [ ] **所有 mint 路径末尾断言** `supply.minted <= supply.burned + supply.genesis`。
- [ ] **掉落/抽卡随机数永不来自客户端**。必须用 finalize 内 `std::rand::chacha_*`。
      客户端提供的 `seed_day` 一律视为漏洞（可穷举刷 UR，且假掉落会铸成链上真 record）。
- [ ] **`ChaCha` 只能在 finalize 调用，record 只能由 transition 产出** ⇒ 随机铸造**必须两阶段**（draw → claim），
      claim 的 async function 断言失败时整笔交易 revert，record 不生效。
- [ ] **任何"链下累积、链上兑现"的数量入参，必须在链上卡死于设计上限**（票数 ≤ `STAMINA_MAX=120`、兑换 ≤ `SOFT_EXCHANGE_DAILY_CAP=3`）。
      原则：**不验证真实性，但让谎报上限 = 诚实上限**。

## 体验红线

- [ ] **玩家永不等待证明**。战斗结果即时展示，证明在动画窗口（3~8s）后台生成，确权异步。
- [ ] **证明/交易失败不丢状态**。持久化 witness，岛屿停留「结算中」，可重试。
- [ ] **「结算中」是可玩状态，不是 loading 转圈**。包装为航海叙事（消息随船传回）。
- [ ] 单场小战斗不上链，**批量提交**（返航结算时一次交易多个承诺）。

## 叙事红线

- [ ] **不得宣称 P0 的哈希 mock = 反作弊**。
- [ ] P1 可宣称的准确命题：「**使用你不拥有的卡牌、或违反编队规则 = 无法生成有效证明**」。
- [ ] 「伪造战斗过程 = 不可能」要到 P1.5（经济上不划算）/ P2（密码学上不可能）才成立。

## 阻塞门禁（未解除前不得开工对应阶段）

| 阻塞 | 内容 | 卡住 |
|---|---|---|
| A-01 | 裁决战能否降规格 3v3 / 8 回合 | P2 全部 |
| A-02 | 定点化数值偏差能否接受 | P1 定点化 + P2 |
| A-07 | 日产纯函数：设计/数据层已解（`ISLAND_M` + `islands.patch.json` 含 `daily_yield_dev0` 全 12 岛）；`claim_island_yield` 代码读该字段待 WS-A 合入 | 闸门 C（设计已解，代码合入后解锁） |
| G-01 | Aleo 单 transition 约束上限（**无可靠数据**） | P2 规格可行性 |
| ~~G-02~~ | ~~POI 掉落随机源~~ → **已关闭**，方案见补遗 01 | — |
| **A-13** | 每日批量结算掉落的**体验**可否接受（策划裁决） | 闸门 D 形态 |
| **A-14** | `poi_yield` 权重与 `1/480` 的口径关系不明 | 闸门 D 判定逻辑 |
| G-06 | record 能否在 finalize 内产出（需最小程序实测，穿刺计划见 `GAPS_PENETRATION.md`） | 两阶段是否可简化 |

## 知识诚实

- [ ] 所有约束数（3k / 66k / 1.0M）均为**未经真机验证的量级估算**，不得作为排期承诺。
- [ ] Aleo API / Leo 语法不确定时**标记缺口，不臆造**。
- [x] 2026-08-02 已建穿刺计划：`GAPS_PENETRATION.md`（G-01/G-03/G-04/G-05/G-06；G-02 随机源已关闭）。P1 启动前 1~2 天执行回填。
