# 00 · 总则与 Godot 4.7 适配

> 全需求文档共用约定。实施前先读本文件。

---

## 1. 引擎与渲染

| 项 | 锁定 |
|---|---|
| 引擎 | **Godot 4.7** · `config/features` 含 `Forward Plus` |
| 主分辨率 | **1440×900**（`client/project.godot`）；设计稿基准可按 **1920×1080** 再缩放 |
| 拉伸 | `canvas_items` + `aspect=expand` |
| 战斗演出 | **2D**（规格层锁定）：`Node2D` / `Sprite2D` / `AnimatedSprite2D` / `GPUParticles2D` |
| 海图 | **2D** 为主（`TileMap`/`Sprite2D`）；可选轻量 3D 海面舞台见 `05-3D美术` |
| UI | **Control** 树 + `Theme` / `StyleBox`；禁止用 Unity UGUI / Web DOM 当主方案 |
| 着色器 | Godot **Shader**（`canvas_item` / `spatial`）+ `WorldEnvironment` 做 env_bias |
| 音频 | **Godot AudioServer**（桌面）；Web 导出用 WebAudio 桥接同一事件 ID |
| 中间件 | **不使用** Wwise/FMOD（G2 已否 Unity 轨） |

---

## 2. 视觉铁律（全局）

1. 风格：**暗黑神话史诗 / 神话写实**；反例板 R-01~R-08 任一命中 = 打回。  
2. 四体系色板冻结（主色）：烈焰 `#FF6B2C` / 铁壁 `#B8BFC6` / 疾风 `#5FC6D6` / 潮汐 `#7B5FC6`。  
3. 体系识别必须 **色 + 形状码 + 纹理**：▲烈焰 / ▣铁壁 / ◆疾风 / ●潮汐。  
4. 卡牌主键 = `cards.json.id`（如 `FLAME_R_01`），禁止自创卡名文件名。  
5. 真名显示规则见设定集 §0.6（玩家见真名；ID 永不暴露）。

---

## 3. 资产仓库建议布局（Godot `res://`）

```
client/
├── assets/
│   ├── art/
│   │   ├── characters/     # char_<ID>_illu / _head / _bust
│   │   ├── cards/          # ui_card_<ID>
│   │   ├── icons/          # icon_* / 体系徽标
│   │   ├── ships/          # ship_* 侧/俯/损
│   │   ├── env/            # env_<sea>_* 海图/概念
│   │   ├── vfx/            # vfx_* 贴图/序列
│   │   └── ui/             # 九宫格/面板纹样
│   ├── audio/
│   │   ├── sfx/            # 按前缀分子目录
│   │   ├── music/          # bed/stems/cutscene
│   │   └── vo/             # vo_<lang>_...
│   └── models3d/           # 仅舞台网格（海面/雾体积占位）
├── shaders/
├── themes/
└── ...
```

导入约定（Godot）：
- 2D 贴图：`Texture2D`，sRGB 开，生成 mipmaps；UI 关 filter 或 Nearest 按组件定。  
- 压缩：PC 用 **BPTC/S3TC**；移动/Web 用 **ETC2/ASTC**（导出预设区分）。  
- 音频：SFX **Ogg Vorbis** 或 WAV（短音）；BGM **Ogg** 流式（`loop` + `Music` 总线）。

---

## 4. 优先级定义

| 级 | 含义 |
|---|---|
| **P0** | Demo 冻洋切片上线必须；缺则 D1–D5 / 支柱可读性断裂 |
| **P1** | 首版应含；可占位后补像素 |
| **P2** | 增强 / 全量赛季 |

---

## 5. 验收总闸

- 美术：美术圣经 §9.6 自检清单。  
- 音频：同 BattleLog 回放两次序列一致（seed 抖动可复现）。  
- UI：对比度 AA + 色盲三重编码；预测仪表盘 Must。  
- 引擎：资源均可被 `client` 直接引用，无 Unity 专用格式。
