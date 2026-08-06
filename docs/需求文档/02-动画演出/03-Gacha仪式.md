# 02-03 · Gacha 仪式动画需求（Godot）

> 主付费点。上游：音频圣经 §5.4 · 商业化统一设计 · 美术稀有度色。  
> **UR 揭晓仪式不可跳过**（可访问性：提供减弱动效档，但不可无反馈）。

---

## 1. 流程阶段

| 阶段 | 动画 | 同步 SFX | 时长引导 |
|---|---|---|---|
| 开池 | 卡池界面铜扉打开 | `sfx_gacha_open` | 0.5s |
| 扣费 | 晶石吸入槽 | `sfx_gacha_coin` | 0.3s |
| 单抽 | 短卡背旋转 | `sfx_gacha_pull_single` | ~1.5s |
| 十连 | 十张卡背分批揭晓 | `sfx_gacha_pull_multi` | ~3s+ |
| 揭晓 N/R | 平铺/轻扬翻面 | `reveal_n` / `reveal_r` | 分层 |
| 揭晓 SR | 中光柱+边框 | `reveal_sr` | 中仪式 |
| 揭晓 SSR | 打断 BGM + 强光 | `reveal_ssr` | 强仪式 |
| 揭晓 UR | 全屏史诗+Leitmotif+立绘 | `reveal_ur` | 满级，**不可跳过** |
| 保底 | 额外金边提示 | `sfx_gacha_pity` | — |
| C1 | 徽标点亮+专属 stinger | `sfx_gacha_c1` | 1–2s |
| 重复 | 卡化碎片/资源 | `sfx_gacha_dupe` | 正向 |
| 充值成功 | 晶石雨+暖光 | `sfx_gacha_recharge_ok` | duck 音乐 |

---

## 2. 视觉资产需求

| 资产 | 说明 | P |
|---|---|---|
| 卡背通用 | `ui_gacha_cardback` 体系可变色 | P0 |
| 光柱/粒子 | SR/SSR/UR 三档强度 | P0 |
| UR 全屏边框 | 虹紫金 + 神话纹样 | P0 |
| 十连布局 | 2×5 或扇形位 | P0 |
| C1 点亮帧 | 4 体系各 1 | P0 |

Godot：`AnimationPlayer` 状态机（Idle→Pull→Reveal_*）；粒子 `GPUParticles2D`；UI 全在 `CanvasLayer`。

---

## 3. 验收

- [ ] 稀有度越高，时长与声部越多（可感知分层）  
- [ ] 充值成功必有正向动画+音  
- [ ] 结果由服务器/开包逻辑决定，动画**只表现**  
- [ ] 同结果重播（含 seed）光效变体一致  
