# 大航海 SLG · 链上经济模型（Machinations 可运行草稿）

> **SSOT**：硬参数以 `00-口径冻结表_SSOT.md` + `数据层/constants.md` 为准。本文 `$TIDE` = 主文档「航海晶」（同指）。  
> 配套文件：`大航海SLG-经济模型.mach`（Machinations 节点/连线草稿，导入 machinations.io 编辑器后核对节点 ID 与数值）  
> 目标：给技术同学一份可导入模拟的具体数值模型。**正式赛季=`SEASON_DAYS=90`**；下文 **30 步 = 压缩压测模型**（1 step≈3 日历日，或改跑 90 步外推），找通胀拐点。
> **资源分层**：压测按四分池（木/麻/战略/香料）展开；Demo 工程将其聚合为 `strategic` 单池（见 `resources.json` / SSOT §2.10）。  
> 研究依据：machinations.io 社区标杆（Sandbox 5% 交易费 + 20% 质押 6 月锁仓 / Illuvium 价值-玩法代币分离）+ 本游戏世界观资源表。  
> **v0.2 重校准（玩法决策 D2）**：体力 5→**120/天**；单次 POI 产出 **÷24**（总量守恒）；NFT 掉落 **1/480、1/960**（原 1/20、1/40 ÷24）；新增**付费补体力辅助 sink（d_stamina）**。  
> **v0.3 商业化统一（gacha-centric）**：主商业化 = **船员 gacha**（《商业化统一设计》v1.1）。gacha 为第一销毁 sink（d_gacha 3,000/天）；体力补充为辅助（d_stamina 700）；新增 d_skin / d_resource / d_recycle。  
> **v0.3.1（2026-07-29）**：头注对齐 SSOT；明确掉率禁止回写 1/20·1/40；主商业化轴不再表述为「付费补体力」。
> **v0.3.2（2026-07-29）**：赛季正式长度改为 90 天；30 步保留为压缩压测；资源分层对齐 Demo 单池 / 全量四分池。

---

## 0. 模拟假设（校准基线）

| 参数 | 值 | 说明 |
|---|---|---|
| 赛季长度 | **正式 90 天**；本表压测跑 **30 步压缩**（或改 90 步） | 1 赛季 |
| 注册玩家 | 5,000 | 单服上限 |
| DAU 占比 | 40% → 2,000 活跃/天 | 保守基线 |
| 体力（Stamina） | **120 行动/天/人**（决策 D2）；可付费补充（**辅助商业化**） | 每日 0 点刷新；付费补体力为 $TIDE/**航海晶** 辅助 sink（d_stamina≈700/天）。主 sink 为 d_gacha。模型按 120 校准，单次产出 ÷24 保总量守恒 |
| 每次 POI 行动平均产出 | 见下表 | 漂移 POI，航线半径内刷新 |

---

## 1. 资源层（链下为主）Sources / Sinks / Pools

### 1.1 单次 POI 行动产出（per action，个人）

| 资源 | 每次产出（v0.2 ÷24） | 说明 |
|---|---|---|
| 木材 Wood | 0.33（原 8 ÷24） | 基础 |
| 麻绳 Rope | 0.17（原 4 ÷24） | 基础 |
| 战略 Strategic（寒铁/星银/丝绸，按海域） | 0.083（原 2 ÷24） | 区域专属 |
| 香料 Spice | 0.042（原 1 ÷24） | 贸易 |
| 船员卡掉落 | 1/480 次（原 1/20 ÷24） | 上链 NFT |
| 船图纸掉落 | 1/960 次（原 1/40 ÷24） | 上链 NFT |

> 行动数：原 2000×5=10,000 → 现 2000×120=**240,000 行动/天**（×24）。单次产出 ÷24 后，§1.2 资源日总量与原 5/天 基线**守恒**（木仍 80,000/天等）；NFT 日掉落仍 ≈500/250 张。

### 1.2 每日聚合（×2000 活跃，240,000 行动/天；单次 ÷24 后总量守恒）

| 节点 | 数值/天 | 类型 |
|---|---|---|
| 木材 POI 总产 | 80,000 | Source |
| 麻绳 POI 总产 | 40,000 | Source |
| 战略 POI 总产 | 20,000 | Source |
| 香料 POI 总产 | 10,000 | Source |
| 船员卡掉落 | 500 张/天（≈45,000/90 天赛季；压缩 30 步模型记 15,000） | Source（限量） |
| 船图纸掉落 | 250 张/天（≈22,500/90 天赛季；压缩 30 步模型记 7,500） | Source（限量） |

### 1.3 护岛者产出（赛季峰值，假设全服约 **30 岛**被占）

| 节点 | 数值/天 | 类型 |
|---|---|---|
| 战略（护岛者岛产，见世界观第 4 表各岛专精） | 3,000 | Source → 护岛者金库 |
| 香料（种植 plantation） | 1,800 | Source → 护岛者金库 |
| 采集税（活跃玩家 5% 产出，上限 5%） | ≈7,500 资源单位 | Source → 护岛者金库 |

### 1.4 资源 Sinks（消耗）

| 节点 | 数值/天 | 类型 | 公式 |
|---|---|---|---|
| 船/船员升级烧木材 | 60,000 | Drain | 2000 人 × 30/人 |
| 船/船员升级烧麻绳 | 30,000 | Drain | 2000 人 × 15/人 |
| 船/船员升级烧战略 | 10,000 | Drain | 2000 人 × 5/人 |
| 船员训练烧木材 | 20,000 | Drain | 2000 人 × 10/人 |
| 船员训练烧麻绳 | 10,000 | Drain | 2000 人 × 5/人 |
| 岛屿开发烧战略 | 2,000 | Drain | 全服聚合 |
| 岛屿开发烧香料 | 1,000 | Drain | 全服聚合 |

> **资源平衡自检**：木材 入 80,000 / 出 80,000（平衡）；麻绳 入 40,000 / 出 40,000（平衡）；战略 入 20,000+3,000+7,500≈30,500 / 出 12,000（净 +18,500/天，稀有资源小幅累积，健康）；香料 入 10,000+1,800+税 / 出 1,000（净正，经贸易回流 $TIDE）。

---

## 2. 价值代币层 $TIDE（链上，上限 10,000,000）

### 2.1 初始分配（cap 10M）

| 池 | 初始量 | 说明 |
|---|---|---|
| 玩家流通（airdrop/play） | 5,000,000 | P_TIDE 初始 |
| 公司/基金会金库 | 2,000,000 | P_CO |
| 生态/赛季奖励池 | 2,000,000 | 分赛季铸造释放 |
| 质押锁仓 | 1,000,000 | P_STAKE 初始 |

### 2.2 $TIDE Sources

| 节点 | 数值/天 | 类型 | 公式 |
|---|---|---|---|
| 赛季奖励铸造释放 | 1,111（正式90天）/ 3,300（30步压缩放大） | Source | 100,000/赛季 ÷ 90 天；压缩模型可放大日均，经 6 月锁仓 vesting |
| 质押释放（20% APR） | 555 | Source | 1,000,000 × 0.20 ÷ 360 |

### 2.3 $TIDE Sinks

| 节点 | 数值/天 | 类型 | 分类 | 公式 |
|---|---|---|---|---|
| 高级铸造/重铸燃烧 | 300 | Drain（销毁） | 辅 | 全服聚合，可调 |
| 交易费（5% of 交易量） | 2,500 | Gate 分流 | 生态 | 假设日交易量 50,000 $TIDE |
| ├─ 公司/基金会（2.5%） | 1,250 | → P_CO | 生态 | 部分用于回购销毁 |
| └─ 护岛者（2.5%） | 1,250 | → P_ALLY | 生态 | 回流联盟 |
| 新质押锁仓 | 3,000 | Lockup | 锁仓 | 玩家新增质押，移出流通 |
| **gacha 招募令购买（主）** | **3,000** | Drain（销毁） | **主** | 购买招募令销毁；《商业化统一设计》§4 |
| 付费补体力消耗 | 700 | Drain（销毁） | 辅 | 由原 1,500 降权（非主付费点）；《商业化统一设计》§5 |
| 资源礼包购买 | 450 | Drain（销毁） | 辅 | 辅助便利项，非必须 |
| 皮肤/外观购买 | 350 | Drain（销毁） | 辅 | 纯 cosmetic，0 战力 |
| 赛季末回收 | 500 | Drain（销毁） | 辅 | 跨季 $TIDE 回收（玩法圣经 §3.5） |

> **$TIDE 净发行自检（v0.3 gacha-centric）**：Source 3,855/天 −（g_fee 2,500 + d_burn 300 + c_stake 3,000 + d_gacha 3,000 + d_stamina 700 + d_resource 450 + d_recycle 500 + d_skin 350）≈ **−6,945/天 净回收（强通缩）**。
> **解读**：gacha 成为主 sink 后，反通胀目标超额达成；通缩由法币 onramp 持续买入支撑。监控：免费玩家 $TIDE 获取（赛季奖励**正式约 1,111/天**；30 步压缩模型曾用 3,300/步作压力放大 + POI 间接）；若新玩家 $TIDE 过紧 → 上调赛季铸造或下调 gacha sink。幅度为 playtest 调参旋钮。
> **红色警报对策**：若净发行意外转正 → ① 上调 Burn 至 1,000/天；② 公司金库 2.5% 交易费 50% 直接销毁；③ 降低 gacha sink 或赛季铸造速率。目标：净发行 ≤ 0。

### 2.4 双循环可视化（文字版，对照 .mach 文件）

```
[资源循环]
S_POI ──(150,000/天)──▶ G_POI分配门 ─┬─▶ Wood  80,000 ─▶ D_升级60k + D_训练20k
                                     ├─▶ Rope  40,000 ─▶ D_升级30k + D_训练10k
                                     ├─▶ Strat 20,000 ─▶ D_升级10k + D_开发2k
                                     └─▶ Spice 10,000 ─▶ D_开发1k
S_Island(护岛者) ──▶ P_ALLY(金库) 4,800/天
S_POI掉落 ──▶ P_NFT(船员卡/船) 上链

[$TIDE 循环]
S_Season 1,111（正式）/3,300（压缩） ─┐
S_StakeEmit 555 ─┼─▶ P_TIDE(流通 5M)
                       │
            ┌──────────┼───────────────┐
            D_Burn 300   G_Fee 2,500      C_Stake 3,000     D_Gacha 3,000
       (销毁)      ├─▶P_CO 1,250    └─▶ P_STAKE(锁仓)    (gacha·主销毁)
                   └─▶P_ALLY 1,250
       D_Stamina 700(辅)  D_Resource 450(辅)  D_Skin 350(辅)  D_Recycle 500(赛季末)
```

---

## 3. Machinations 节点清单（导入用）

| 节点 ID | 类型 | 标签 | 初始值 |
|---|---|---|---|
| p_wood | Pool | 木材 Wood | 200,000 |
| p_rope | Pool | 麻绳 Rope | 100,000 |
| p_strat | Pool | 战略 Strategic | 50,000 |
| p_spice | Pool | 香料 Spice | 30,000 |
| p_tide | Pool | $TIDE 流通 | 5,000,000 |
| p_stake | Pool | $TIDE 质押锁仓 | 1,000,000 |
| p_ally | Pool | 护岛者金库 | 0 |
| p_co | Pool | 公司/基金会金库 | 2,000,000 |
| p_nft | Pool | 船员卡/船(链上) | 0 |
| s_poi | Source | POI采集(每日) | — |
| s_island | Source | 护岛者产出 | — |
| s_season | Source | 赛季奖励铸造 | — |
| s_stakeemit | Source | 质押释放 | — |
| d_upgrade | Drain | 船/船员升级燃烧 | — |
| d_dev | Drain | 岛屿开发燃烧 | — |
| d_burn | Drain | $TIDE燃烧(高级铸造) | — |
| d_stamina | Drain | 付费补体力消耗(辅助sink) | — |
| d_gacha | Drain | gacha招募令购买(主sink) | — |
| d_resource | Drain | 资源礼包购买(辅助sink) | — |
| d_skin | Drain | 皮肤/外观购买(辅助sink) | — |
| d_recycle | Drain | 赛季末回收 | — |
| g_poi | Gate | POI分配门(dice) | — |
| g_fee | Gate | 交易费分配(deterministic) | — |
| c_stake | Converter | 质押锁仓 | — |
| c_craft | Converter | 造船(木+绳+铁) | — |

### 连线与速率（connection from → to, amount/天）

| 连线 | from | to | amount |
|---|---|---|---|
| POI→门 | s_poi | g_poi | 150,000 |
| 门→木材 | g_poi | p_wood | 80,000 |
| 门→麻绳 | g_poi | p_rope | 40,000 |
| 门→战略 | g_poi | p_strat | 20,000 |
| 门→香料 | g_poi | p_spice | 10,000 |
| 木材→升级 | p_wood | d_upgrade | 60,000 |
| 木材→训练 | p_wood | d_upgrade | 20,000 |
| 麻绳→升级 | p_rope | d_upgrade | 30,000 |
| 麻绳→训练 | p_rope | d_upgrade | 10,000 |
| 战略→升级 | p_strat | d_upgrade | 10,000 |
| 战略→开发 | p_strat | d_dev | 2,000 |
| 香料→开发 | p_spice | d_dev | 1,000 |
| 护岛者→金库 | s_island | p_ally | 4,800 |
| 流通→费门 | p_tide | g_fee | 2,500 |
| 费→公司 | g_fee | p_co | 1,250 |
| 费→联盟 | g_fee | p_ally | 1,250 |
| 流通→质押 | p_tide | c_stake | 3,000 |
| 质押→锁仓 | c_stake | p_stake | 3,000 |
| 流通→燃烧 | p_tide | d_burn | 300 |
| 流通→gacha(主) | p_tide | d_gacha | 3,000 |
| 流通→付费体力(辅) | p_tide | d_stamina | 700 |
| 流通→资源礼包(辅) | p_tide | d_resource | 450 |
| 流通→皮肤(辅) | p_tide | d_skin | 350 |
| 流通→赛季回收(辅) | p_tide | d_recycle | 500 |
| 赛季→流通 | s_season | p_tide | 3,300 |
| 质押释放→流通 | s_stakeemit | p_tide | 555 |

---

## 4. 烟雾测试清单（技术同学跑模拟时核对）

1. **资源通胀率** = (ΣSource − ΣDrain) / Pool 初始。木材/麻绳应 ≈ 0%；战略/香料应 ≤ 小幅正。若 > 5%/天 → 调高对应 Drain。
2. **$TIDE 净发行** = (s_season + s_stakeemit) − (g_fee + d_burn + c_stake + d_gacha + d_stamina + d_resource + d_recycle + d_skin)。v0.3 gacha-centric 后净发行 ≈ −6,945/天（强通缩，见 §2.3）。
3. **护岛者金库累积**：p_ally 应随赛季增长，验证「占岛有正反馈」诱导占岛行为。
4. **红度/鲸鱼集中度**：模拟 1% 玩家占 30% 资源时，金库与流通是否极化（对策：税收上限 5% + 多 sink）。
5. **赛季回收**：d_recycle（未在本基础模型单列）应在赛季末回收部分 $TIDE，建议在编辑器补一个 Drain 接 p_tide。

> 本模型为「可运行草稿」：导入 `.mach` 后，先用以上基线跑 30 步，再分别拉高 DAU（60%/80%）、拉低掉落率、拉高燃烧，观察拐点。数值均为可评审初值，需结合战斗平衡联调。


---

## 附录：`.mach` 草稿（Machinations 节点 / 连线 XML，完整版）

> 以下为可直接导入 machinations.io 的 `.mach` 源文件全文。属性名若与编辑器有差异，以本附录数值为准，或参考上文第 3 节节点清单表格重建。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  大航海 SLG · 链上经济模型 Machinations 草稿 v1.0
  ====================================================================
  导入说明：
  1) 在 machinations.io 新建 diagram，或将本文件作为 .mach 导入。
  2) 若编辑器对属性名有差异（如 id/nodeID、from/to），请按编辑器提示
     在节点面板重命名/重连；本草稿的「逻辑与数值」以下方为准，并已
     在《大航海SLG-经济模型-Machinations.md》第 3 节列成表格，可据此重建。
  3) 时间步 = 1 天，运行 30 步 = 1 个赛季。
  节点类型：source=产生器 / drain=消耗器 / pool=池 / gate=门 /
           converter=转换器 / delay=延迟
  时间步(step)=1天，模拟30步=1赛季。
  ====================================================================
-->
<machinations version="1.0">
  <nodes>
    <!-- ===================== Pools (存量) ===================== -->
    <pool id="p_wood"  label="木材 Wood"          x="80"  y="80"  start="200000"/>
    <pool id="p_rope"  label="麻绳 Rope"          x="80"  y="180" start="100000"/>
    <pool id="p_strat" label="战略 Strategic"      x="80"  y="280" start="50000"/>
    <pool id="p_spice" label="香料 Spice"         x="80"  y="380" start="30000"/>
    <pool id="p_tide"  label="$TIDE 流通"          x="600" y="80"  start="5000000"/>
    <pool id="p_stake" label="$TIDE 质押锁仓"      x="600" y="200" start="1000000"/>
    <pool id="p_ally"  label="护岛者金库"          x="600" y="320" start="0"/>
    <pool id="p_co"    label="公司/基金会金库"     x="600" y="440" start="2000000"/>
    <pool id="p_nft"   label="船员卡/船(链上)"     x="320" y="520" start="0"/>

    <!-- ===================== Sources (产生器) ===================== -->
    <source id="s_poi"       label="POI采集(每日)"      x="80"  y="500"/>
    <source id="s_island"    label="护岛者产出"         x="320" y="80"/>
    <source id="s_season"    label="赛季奖励铸造"       x="600" y="580"/>
    <source id="s_stakeemit" label="质押释放(20%APR)"   x="600" y="640"/>

    <!-- ===================== Drains (消耗器) ===================== -->
    <drain id="d_upgrade" label="船/船员升级燃烧"   x="320" y="200"/>
    <drain id="d_dev"     label="岛屿开发燃烧"      x="320" y="300"/>
    <drain id="d_burn"    label="$TIDE燃烧(高级铸造)" x="860" y="80"/>
    <drain id="d_gacha"   label="gacha招募令购买(主)"  x="1000" y="80"/>
    <drain id="d_stamina" label="付费补体力消耗(辅)"    x="860" y="200"/>
    <drain id="d_resource" label="资源礼包购买(辅)"      x="1000" y="200"/>
    <drain id="d_skin"    label="皮肤/外观购买(辅)"     x="860" y="320"/>
    <drain id="d_recycle" label="赛季回收"          x="1000" y="320"/>

    <!-- ===================== Gates (门) ===================== -->
    <gate id="g_poi" label="POI分配门(dice)"      x="200" y="500" type="dice"/>
    <gate id="g_fee" label="交易费分配(det)"      x="740" y="440" type="deterministic"/>

    <!-- ===================== Converters (转换器) ===================== -->
    <converter id="c_stake" label="质押锁仓"   x="740" y="200"/>
    <converter id="c_craft" label="造船(木+绳+铁)" x="320" y="400"/>
  </nodes>

  <connections>
    <!-- POI 产生 → 分配门 → 各资源池 -->
    <connection from="s_poi"   to="g_poi"   amount="150000"/>
    <connection from="g_poi"   to="p_wood"  amount="80000"/>
    <connection from="g_poi"   to="p_rope"  amount="40000"/>
    <connection from="g_poi"   to="p_strat" amount="20000"/>
    <connection from="g_poi"   to="p_spice" amount="10000"/>

    <!-- 木材消耗：升级60k + 训练20k -->
    <connection from="p_wood"  to="d_upgrade" amount="60000"/>
    <connection from="p_wood"  to="d_upgrade" amount="20000"/>
    <!-- 麻绳消耗：升级30k + 训练10k -->
    <connection from="p_rope"  to="d_upgrade" amount="30000"/>
    <connection from="p_rope"  to="d_upgrade" amount="10000"/>
    <!-- 战略消耗：升级10k + 开发2k -->
    <connection from="p_strat" to="d_upgrade" amount="10000"/>
    <connection from="p_strat" to="d_dev"     amount="2000"/>
    <!-- 香料消耗：开发1k -->
    <connection from="p_spice" to="d_dev"     amount="1000"/>

    <!-- 护岛者产出 → 金库 -->
    <connection from="s_island" to="p_ally" amount="4800"/>

    <!-- $TIDE 交易费分流 -->
    <connection from="p_tide" to="g_fee" amount="2500"/>
    <connection from="g_fee"  to="p_co"   amount="1250"/>
    <connection from="g_fee"  to="p_ally" amount="1250"/>

    <!-- $TIDE 质押锁仓 -->
    <connection from="p_tide"  to="c_stake" amount="3000"/>
    <connection from="c_stake" to="p_stake" amount="3000"/>

    <!-- $TIDE 燃烧(销毁) 与各 sink -->
    <connection from="p_tide" to="d_burn"    amount="300"/>
    <connection from="p_tide" to="d_gacha"   amount="3000"/>
    <connection from="p_tide" to="d_stamina" amount="700"/>
    <connection from="p_tide" to="d_resource" amount="450"/>
    <connection from="p_tide" to="d_skin"    amount="350"/>
    <connection from="p_tide" to="d_recycle" amount="500"/>

    <!-- $TIDE 来源：赛季铸造 + 质押释放 -->
    <connection from="s_season"    to="p_tide" amount="3300"/>
    <connection from="s_stakeemit" to="p_tide" amount="555"/>

    <!-- 赛季回收(建议启用)：从流通回收部分 -->
    <connection from="p_tide" to="d_recycle" amount="500"/>
  </connections>
</machinations>

```
