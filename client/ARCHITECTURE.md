# Client 代码骨架（Godot 4.7）

> Demo 竖切 · 素材可后置 · 结算与演出分离

## 分层

```
Boot / Main (scenes)          ← 场景壳
    ↓
ui/                           ← 面板与 HUD（可换皮）
    ↓
presentation/                 ← 战报演出、SFX 路由（不回流结算）
    ↓
systems/                      ← 纯规则：battle / map / economy / fleet
    ↓
core/                         ← FixedMath · DisplayNames
    ↓
data/*.json                   ← 冻结真源
```

autoload：`EngineLock` · `GameData` · `GameState` · `App` · `EventBus` · `ChainGateway` · `Juice` · `Sfx`

## D1–D5 映射

| 故事 | 入口 | 系统 |
|---|---|---|
| D1 海图 | `scenes/Main` | `systems/map/MapGraph` |
| D2 POI | Main / `PoiService` | `systems/economy/*` + `StaminaCosts` |
| D3 战斗 | `BattleFacade` → `ResolveBattle` | `systems/battle/*` |
| D4 占岛 | `GameState.capture_island` | EventBus `island_captured` |
| D5 经济 | `YieldService` / advance_day | `systems/economy/YieldService` |

## 链

`ChainGateway`（autoload）→ Demo mock → 日后 `../chain/sidecar`

## 素材槽（空目录）

`assets/{characters,ships,ui,sfx,bgm,vfx,map}/` — 对需求文档时再填；代码不依赖真实资源即可跑 Demo。

## 红线

1. `ResolveBattle` 零展示依赖；日志可带 `sfx` 键，由 `SfxRouter` 消费。
2. 随机：结算 seed 与演出抖动分离。
3. 改冻结常量 = 重冻 ruleset（须批准）。
