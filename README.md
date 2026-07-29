# BigVoyage · 大航海 SLG

**Aleo 公链比赛项目** — 沉没的世界，由你的航线重建秩序。

出品 / 制作：MiLab-Bit · 吟游诗人Lab  

本仓库是面向 **Aleo** 的链游 SLG 比赛作品：用 **zk 可验证的确定性战斗** + 航海资源闭环，把「资产确权 / 战报可验证 / 反作弊」做成玩法叙事的一部分。当前交付为 **Godot 冻洋 Demo 切片**（12 岛 · D1–D5）；真链接入按策划阶段推进，Demo 内战斗结算为本地确定性 hash mock。

引擎：[Godot](https://godotengine.org/) **4.7**（Forward+）· 1440×900  

---

## 比赛定位（一句话）

| 维度 | 说明 |
|---|---|
| 赛道 | Aleo 公链 · zk 应用 / 链游 |
| 玩法 | 航海 SLG：探索 POI → 占岛护岛 → 卡牌编队战斗 → 护岛经济 |
| 链叙事 | 战斗纯函数 `ResolveBattle` → 日志可哈希承诺 → 可接 Aleo zk 证明与资产确权 |
| Demo 边界 | 单海冻洋 · 12 岛 · 20 卡 · **不接真链**（见 `docs/design` Demo 契约） |

---

## 本地运行

1. 安装 [Godot 4.7+](https://godotengine.org/)（Standard / Forward+）  
2. 打开本仓库根目录的 `project.godot`  
3. 按 **F5** 运行（入口：`scenes/Boot.tscn` → 海图）

无需额外资源包：音效为程序生成，数据来自 `data/*.json`。

### Demo 手感路径

| 步骤 | 操作 |
|---|---|
| D1 海图 | 右键拖拽 / 滚轮缩放 / 点岛 |
| D2 POI | 出生岛「探索 POI」 |
| D3 出航 | 选相邻岛 → 出航 |
| D4 编队/战斗 | 编队塞烈焰 → 挑战护岛者 |
| D5 经济 | 「跳 30 日」收护岛日产 |

快捷键：**空格** = 过一天。存档：`user://voyage_save.json`。

---

## 仓库分支（与资产层）

| 分支 | 内容 |
|---|---|
| [`main`](https://github.com/MiLab-Bit/BigVoyage/tree/main) | Godot Demo 可运行工程 |
| [`docs/design`](https://github.com/MiLab-Bit/BigVoyage/tree/docs/design) | 纯策划设计文档（SSOT / 世界观 / 玩法 / 数值） |
| [`assets/data`](https://github.com/MiLab-Bit/BigVoyage/tree/assets/data) | 数据层资产（卡牌 / 岛屿 / 常数 JSON 等） |
| [`assets/art`](https://github.com/MiLab-Bit/BigVoyage/tree/assets/art) | 美术资产（当前为 Demo 图标与说明） |
| [`assets/audio`](https://github.com/MiLab-Bit/BigVoyage/tree/assets/audio) | 声音资产说明（Demo 为程序生成 SFX） |

策划真源索引：`docs/design` 下的 `00-口径冻结表_SSOT.md`。

---

## 工程结构（main）

```
autoload/   GameData · GameState · Juice · Sfx
systems/    ResolveBattle（确定性战斗核）
ui/         Main · FleetPanel · BattleOverlay
scenes/     Boot → Main
data/       cards / islands / guards / constants …
```

口径要点：克制 ×1.3；编队 COST≤10、槽位≤5、同体系≤4；体力按日刷新；Demo 非目标含真链、充值、三洋、联盟。

---

仅供展示与交流。未经授权请勿商用转售。
