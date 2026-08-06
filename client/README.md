# BigVoyage · Godot 客户端（代码骨架）

> **引擎**：Godot **4.7** Forward+ · 见 `ARCHITECTURE.md`  
> **素材**：`assets/*` 空槽，可后置对需求文档  
> **链**：`ChainGateway` mock → `../chain/`

## 运行

```bat
:: 编辑器 / 游玩
godot --path .

:: 冒烟
godot --headless --path . res://tests/Smoke.tscn

:: T3 机检（B1 / D3×100×3 / B4 / D-path）
godot --headless --path . res://tests/T3.tscn
:: 或 tests\run_t3.bat
```

CLI 在仓库 `../tools/godot.cmd`（4.7.1）。

## 目录骨架

```
client/
├── ARCHITECTURE.md          ← 分层与 D1–D5 映射
├── autoload/                EngineLock GameData GameState App EventBus ChainGateway Juice Sfx
├── core/                    FixedMath · DisplayNames（C-6）
├── themes/                  voyage_theme.tres · VoyageTheme.gd
├── systems/
│   ├── battle/              ResolveBattle · BattleFacade
│   ├── map/                 MapGraph
│   ├── economy/             StaminaCosts · PoiService · YieldService
│   ├── fleet/               FleetRules
│   └── gacha/               GachaFacade（展示用）
├── presentation/            BattleLogPresenter · SfxRouter
├── services/                save · chain（占位）
├── scenes/                  Boot → Main
├── ui/                      Main · Fleet · Battle · Codex · Gacha · Predict
├── data/                    冻结 JSON
├── assets/                  characters ships ui sfx bgm vfx map
└── tests/                   Smoke.tscn · T3.tscn
```

## Demo 路径（D1–D5）

| 步骤 | 操作 | 体力 |
|---|---|---|
| D1 | 海图点选 / 平移缩放 | — |
| D2 | 探索 POI | 6 |
| D3 | 出航相邻岛 | 1 |
| D4 | 编队 → 挑战护岛者 | 8 |
| D5 | 跳 30 日 | — |

## 约定

- UI → Facade/Service → 纯函数结算；演出不回流 seed  
- 新系统进 `systems/<域>/`，新面板进 `ui/`，素材进 `assets/`  
- 对素材时只填 `assets/` + `SfxRouter` / Theme，不改 `ResolveBattle`
