# BigVoyage · 大航海 SLG

**Aleo 公链比赛项目** — 沉没的世界，由你的航线重建秩序。

出品：MiLab-Bit · 吟游诗人 Lab  

航海 SLG + **zk 可验证确定性战斗**：探索 / 占岛护岛 / 卡牌编队 / 护岛经济；链上承接战斗 commit（Poseidon / Leo），客户端为 **Godot 4.7**。

| | |
|---|---|
| 引擎 | Godot **4.7**（Forward+）· 工程在 [`client/`](client/) |
| 链 | Aleo Testnet · Sidecar + wallet-bridge · 见 [`chain/`](chain/) |
| 当前交付 | 可玩客户端（全海图 demo）+ 经营拆页 + 港主 LLM 可选 + 真链 commit 通路 |
| 机密 | **不入库** — 见 [`LOCAL_SECRETS.md`](LOCAL_SECRETS.md) |

---

## 快速开始

### 客户端

1. 安装 [Godot 4.7+](https://godotengine.org/)
2. 打开 [`client/project.godot`](client/project.godot) → **F5**
3. 说明：[`client/README.md`](client/README.md) · 架构：[`client/ARCHITECTURE.md`](client/ARCHITECTURE.md)

可选港主 LLM：复制 [`client/config/llm.example.json`](client/config/llm.example.json) → `client/config/llm.local.json`，填入 `api_key`（该文件已 gitignore）。

### 链（本机）

```powershell
# 详见 chain/SETUP_ALEO.md、chain/LIVE_STATUS.md
cd chain\wallet-bridge
npm install
npm run account          # 生成 dev_account.json（勿提交）
npm run fund-hint        # 打印地址 → https://faucet.aleo.org/
npm start                # :8788

# 另开终端启动 Sidecar（脚本见 tools/start_chain.ps1）
```

更多：[`chain/README.md`](chain/README.md) · [`LOCAL_SECRETS.md`](LOCAL_SECRETS.md)

---

## 仓库结构（以本仓实际路径为准）

```
BigVoyage/
├── client/                 Godot 4.7 客户端
├── chain/                  Aleo Leo / Sidecar / wallet-bridge
├── tools/                  启动脚本等（leo/godot 二进制本机自备）
├── 素材预览/               美术·BGM·SFX 预览包
├── 策划主文档/             主策划案
├── 世界观与叙事/
├── 玩法与系统/             GDD、玩法圣经、Demo 契约、角色设定…
├── 数值与经济/
├── 数据层/                 constants、data-spec、协同网矩阵…
├── 架构与技术/             Aleo ADR、链架构
├── 需求文档/               2D / 动画 / SFX / BGM / UI 需求包
├── 美术与音频/             美术圣经 · 音频圣经
├── 验收与QA/
├── 汇编与报告/             索引、裁决登记册、CHANGELOG
├── 00-口径冻结表_SSOT.md
├── 00-G2引擎冻结_Godot.md
├── 00-MDA-支柱-范围分层.md
├── 00-交接清单-HANDOFF.md
├── LOCAL_SECRETS.md        本地机密说明（钱包 / LLM）
└── README.md               ← 本文件（GitHub 首页）
```

> 旧文里的「`整合版/`」「`玩法与系统/GDD/`」等路径已废弃：GDD 文件直接在 [`玩法与系统/`](玩法与系统/) 下。

---

## GitHub 分支

| 分支 | 内容 |
|---|---|
| [`main`](https://github.com/MiLab-Bit/BigVoyage) | 完整工程 + 策划文档 + 素材预览 |
| [`docs/design`](https://github.com/MiLab-Bit/BigVoyage/tree/docs/design) | 纯策划归档（`docs/`） |
| [`assets/art`](https://github.com/MiLab-Bit/BigVoyage/tree/assets/art) | 美术预览（立绘～特效） |
| [`assets/audio`](https://github.com/MiLab-Bit/BigVoyage/tree/assets/audio) | BGM / SFX |
| [`assets/data`](https://github.com/MiLab-Bit/BigVoyage/tree/assets/data) | 数据层 JSON / 常数 |

---

## 建议阅读顺序

1. [`00-G2引擎冻结_Godot.md`](00-G2引擎冻结_Godot.md)  
2. [`00-口径冻结表_SSOT.md`](00-口径冻结表_SSOT.md)  
3. [`玩法与系统/支柱收口-构筑UR克制.md`](玩法与系统/支柱收口-构筑UR克制.md)  
4. [`00-MDA-支柱-范围分层.md`](00-MDA-支柱-范围分层.md)  
5. [`策划主文档/大航海SLG-策划案（设计用）.md`](策划主文档/大航海SLG-策划案（设计用）.md)  
6. [`玩法与系统/GDD-03-卡牌编队与战斗.md`](玩法与系统/GDD-03-卡牌编队与战斗.md)  
7. [`数值与经济/`](数值与经济/) · [`数据层/constants.md`](数据层/constants.md) · [`数据层/data-spec/RULESET_LOCK.md`](数据层/data-spec/RULESET_LOCK.md)  
8. [`架构与技术/README.md`](架构与技术/README.md) · [`chain/SETUP_ALEO.md`](chain/SETUP_ALEO.md)  
9. [`client/README.md`](client/README.md) · [`client/PRODUCT_ROADMAP.md`](client/PRODUCT_ROADMAP.md)

全量登记（路径以本 README / 实盘为准）：[`汇编与报告/文档索引清单.md`](汇编与报告/文档索引清单.md)  
裁决状态：[`汇编与报告/裁决登记册.md`](汇编与报告/裁决登记册.md)

---

## 文档速查

| 主题 | 路径 |
|---|---|
| 主策划案 | [`策划主文档/大航海SLG-策划案（设计用）.md`](策划主文档/大航海SLG-策划案（设计用）.md) |
| 世界观 | [`世界观与叙事/世界观圣经（完整版）.md`](世界观与叙事/世界观圣经（完整版）.md) |
| Demo 契约 | [`玩法与系统/Demo范围契约与验收标准.md`](玩法与系统/Demo范围契约与验收标准.md) |
| GDD 01–04 | [`玩法与系统/GDD-01-探索与POI.md`](玩法与系统/GDD-01-探索与POI.md) 等 |
| 船员设定 | [`玩法与系统/船员角色设定集.md`](玩法与系统/船员角色设定集.md) |
| 美术 / 音频规范 | [`美术与音频/美术圣经.md`](美术与音频/美术圣经.md) · [`美术与音频/音频圣经.md`](美术与音频/音频圣经.md) |
| 表现需求包 | [`需求文档/README.md`](需求文档/README.md) |
| 素材预览 | [`素材预览/`](素材预览/) |
| Playtest | [`验收与QA/设计侧Playtest验收框架.md`](验收与QA/设计侧Playtest验收框架.md) |
| 真机手册 | [`验收与QA/真机验证执行手册.md`](验收与QA/真机验证执行手册.md) |
| 交接 | [`00-交接清单-HANDOFF.md`](00-交接清单-HANDOFF.md) |
| 本地机密 | [`LOCAL_SECRETS.md`](LOCAL_SECRETS.md) |

历史整合说明（归档，可能含旧路径）：[`README-整合说明.md`](README-整合说明.md)

---

## 状态摘要（v1.25）

- 客户端：全海图可玩 · HUD / 经营拆页 · 舰队与战斗演出对齐主题  
- 链：`CHAIN_MOCK=false` · Leo Poseidon8 commit 经 Sidecar 可用 · 网络广播需 faucet credits  
- 机密：`llm.local.json`、`dev_account.json`、私钥 **从未提交**  

仅供展示与交流。未经授权请勿商用转售。
