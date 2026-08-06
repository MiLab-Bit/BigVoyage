# 玩法压测纪要（v1.20）

命令：`tools\godot.cmd --headless --path client res://tests/Playtest.tscn`

## 本轮专项

| 项 | 改动 | 门禁 |
|---|---|---|
| AB_09 偏软 | 守卫升至 UR/SSR 铁船；接线 `boss_hp_mult`；渊海 boss 缩放↑ | 开局队 AB_09 胜率 ≤15% |
| 联航敌分 | 起分 180；败仗 +2；胜场不再给敌加分；日推仅征伐/高潮 +1~2 | bot 终局 lead ≥ -250（半数以上） |
| bot 贸易 | 每日优先搜最佳直航 + 三角（最多 2 笔） | 均交易 ≥8，且半数 bot ≥8 笔 |

## 全套结果

Playtest **PASS**；T3 **PASS**。

## 历史（v1.19）

战斗阶梯 / 科技增量 / 贸易校准 / LiveOps / 90 日 bot 骨架。
