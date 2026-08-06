# 04-01 · BGM 曲目 / 状态机 / Godot 接入

> 曲风：暗黑神话史诗 · 航海。冷=小调稀疏；暖=大调铜管。  
> 签名：烈焰铜管 / 铁壁定音鼓 / 疾风木管 / 潮汐人声。

---

## 1. Intensity 状态机（锁定）

| I | 名 | 内容 | 场景 |
|---|---|---|---|
| 0 | 平静 | 仅 Bed | 菜单、港口、编队、空旷海 |
| 1 | 紧张 | Bed+轻 Stems | 读敌情、近岛、预警 |
| 2 | 战斗 | Bed+全 Stems | 对局 3–8 round |
| 3 | 高潮 | +合唱/管风琴 | combo/决胜/Boss/UR 池 |

**转移**（确定性输入）：见音频圣经 §4.2。  
硬上限：进战 ramp **≤5s**；结束回 Bed **≤2s**。

Godot 建议：`MusicDirector` autoload + `AnimationPlayer` 或脚本 crossfade 多 `AudioStreamPlayer`（Bed/Stems/Cutscene 分总线）。

---

## 2. 曲目交付清单

### 2.1 Demo 冻洋（P0）

| 曲 ID | 用途 | 形态 | 时长引导 | 总线 |
|---|---|---|---|---|
| `bgm_menu_main` | 主菜单 | 可循环 Bed | 2:00+ | Music_Bed |
| `bgm_sea_frozen_bed` | 冻洋海图 I=0 | 风雪+远鲸+低频弦 | 循环 | Music_Bed |
| `bgm_sea_frozen_tense` | I=1 stem | 定音鼓动机轻层 | 循环层 | Music_Stems |
| `bgm_battle_frozen` | I=2 | 节奏组+铁壁/烈焰动机可切层 | 循环 | Music_Stems |
| `bgm_battle_climax` | I=3 one-shot/层 | 合唱+管风琴 stinger 可层叠 | 8–16s | Music_Stems |
| `bgm_victory_short` | 胜 | 暖收束 | 8–12s | Music_Cutscene |
| `bgm_defeat_short` | 负 | 冷收束 | 8–12s | Music_Cutscene |
| `bgm_gacha_bed` | 卡池底噪 | 低期望感循环 | 循环 | Music_Bed |
| `stinger_gacha_ssr` | SSR 揭晓 | 打断 | 2–4s | Music_Stems |
| `stinger_gacha_ur` | UR 揭晓 | 满编制 | 4–8s | Music_Cutscene |
| `stinger_leit_iron|flame|tide|wind` | 角色 Leitmotif | 1–2s | — | Music_Stems |

### 2.2 全量扩展（P1–P2）

| 曲 ID | 海域/场景 |
|---|---|
| `bgm_sea_abyss_bed` / `_battle` | 渊海 |
| `bgm_sea_hanhai_bed` / `_battle` | 瀚海（偏暖） |
| `bgm_sea_tradewind_bed` / `_battle` | 信风 |
| `bgm_harbor_warm` | 重建港口黄金时 |
| `bgm_boss_warden` | 守卫王 |
| `bgm_boss_herald` | 海皇先驱 |
| `bgm_cutscene_ch01`… | 章节线性管弦（可按章） |
| `stinger_c1_<sys>` | C1 四体系变奏 |

---

## 3. Stem 分层规格（战斗曲）

每首战斗曲至少分轨交付（Ogg 或多文件）：

| Stem | 内容 | 淡入（0→2） |
|---|---|---|
| `perc` | 节奏组 | 0–0.5s |
| `motif` | 体系动机 | 0.5–1.5s |
| `orch` | 弦乐/铜管铺底 | 1.5–≤5s |
| `choir`（可选） | 高潮层 | I=3 即时 |

Godot：4 个 `AudioStreamPlayer` 挂 `Music_Stems`，按参战体系混合 `motif_flame|iron|wind|tide` 音量。

---

## 4. 体系动机（作曲必遵）

| 体系 | 动机名 | 语义（简） |
|---|---|---|
| 烈焰 | 燎原 | 上行跳进，铜管顿音+弯音 |
| 铁壁 | 锚定 | 下行五度锤击 |
| 疾风 | 掠影 | 下行级进十六分 |
| 潮汐 | 潮涌 | 波浪级进人声哼鸣 |

谱面示意见音频圣经 §3.4；DAW 工程为真源。

---

## 5. 技术规格

| 项 | PC | Web/移动 |
|---|---|---|
| 格式 | Ogg 192 kbps | Ogg 128 kbps |
| 循环 | 无缝 loop 点标注 | 同 |
| 采样 | 48 kHz | 48 kHz |
| stem 同发 | ≤8 | ≤4–6 |

---

## 6. 验收

- [ ] 同 BattleLog 两次播放：状态转移时刻一致  
- [ ] 进战 ≤5s 听到完整战斗铺底  
- [ ] Gacha UR 打断音乐且仪式结束正确回 Bed  
- [ ] 无电子舞曲主导 / 卡通 BGM  
