# Demo / 世界观资产包

> 规划真源：`需求文档/07-全量资产生产规划.md`  
> 覆盖快照：`coverage_report.json`

## 当前覆盖（生产后）

| 组 | 数量 | 路径 |
|---|---|---|
| 立绘 illu | 20 | `art/characters/char_*_illu.png` |
| 半身 bust | 20 | `art/characters/char_*_bust.png` |
| 头像 head | 20 | `art/characters/char_*_head.png` |
| 技能图标 | 20 | `art/icons/icon_*_skill.png` |
| 冻洋 12 岛概念+图标 | 12+12 | `art/env/islands/` |
| 叙事关键帧 | 6 | `art/narrative/`（大沉没/黄金彼岸/潮核/海皇/罗盘/港） |
| 海怪 | 6 | `art/creatures/` |
| 四海域海图/雾/天气 | 多 | `art/env/` |
| VFX 关键帧 | 6+ | `art/vfx/` |
| BGM | 24 曲+别名 | `audio/music/`（P0+P1 全表） |
| SFX 占位 | 84 wav | `audio/sfx/{btl,ui,nav,gacha,nar}/` |

## 通道

- 图像：Cursor 内置出图（Pollinations 曾 429）  
- 音乐：AceMusic 直连（禁坏代理）  
- SFX：程序合成占位（事件 ID 对齐需求文档，可换真人拟音）

运行时：`AssetDB` / `Bgm` / `Sfx`。
