# 03-01 · SFX 事件清单与 Godot AudioServer 接入

> 完整逐条定义以音频圣经 §5 为准；本文给出**工程绑定规格**与分组交付量。  
> G2：桌面 = AudioServer；Web 导出 = 同 ID 映射 WebAudio（事件表不分裂）。

---

## 1. Godot 总线树（必须同名创建）

在「音频」面板创建总线（Bus）：

```
Master
├─ Music
│   ├─ Music_Bed
│   ├─ Music_Stems
│   └─ Music_Cutscene
├─ SFX
│   ├─ SFX_Battle
│   ├─ SFX_Gacha
│   ├─ SFX_UI
│   └─ SFX_World          ← 唯一可用 AudioStreamPlayer2D 的总线
├─ Ambience
│   ├─ Ambience_Sea
│   └─ Ambience_Zone
└─ VO
    ├─ VO_Leader
    ├─ VO_Compass
    └─ VO_System
```

相对电平 / ducking：照音频圣经 §7.2–§7.3（PC 综合 **−18 LUFS**，TP ≤ −1 dBTP）。  
Godot：用 `AudioEffectCompressor` / 侧链或脚本做 duck（VO/Gacha 压 Music）。

---

## 2. 事件分组与交付量

| 组 | 前缀 | 条数 | P0 约 | 总线 | Demo |
|---|---|---|---|---|---|
| 战斗 | `sfx_btl_*` | 47 | ~30 | SFX_Battle | **P0 全开关键子集** |
| UI | `sfx_ui_*` | 26 | ~16 | SFX_UI | P0 |
| 海图 | `sfx_nav_*` | 19 | ~12 | SFX_World 或 UI | P0 |
| Gacha | `sfx_gacha_*` | 14 | 13 | SFX_Gacha | P0 仪式链 |
| 叙事 | `sfx_nar_*` | 13 | ~8 | SFX / Music_Cutscene | P1 |
| **合计** | | **119** | ~90 | | |

文件命名：`res://assets/audio/sfx/<prefix>/<event_id>_v01.ogg`  
变体：`_a` `_b`…；选择用 `seed` 派生，禁止 `randf()` 无种子。

---

## 3. 战斗 SFX 清单（47）· 寄生 BattleLog

### deploy（5）
`sfx_btl_deploy_flame|ironwall|wind|tide` · `sfx_btl_deploy_all`（P0）

### skill（5）
`sfx_btl_skill_flame|ironwall|wind|tide`（P0）· `sfx_btl_skill_charge`（P1）

### hit（6）
`sfx_btl_hit_flame|ironwall|wind|tide`（P0）· `sfx_btl_hit_shield|armor`（P1）  
同发 ≤12。

### restraint（5）· 支柱可读
`sfx_btl_restraint_flame|ironwall|wind|tide`（P0）· `sfx_btl_restraint_hi`（P1）  
`restraints=true` 时：克方凸显、被克 −6dB/低通（可用总线 EQ 临时做）。

### dot（3）
`sfx_btl_dot_burn`（P0 节拍循环）· `sfx_btl_dot_tide` · `sfx_btl_dot_stack`

### control（3）
`sfx_btl_control_stun`（P0）· `silence` · `break`

### combo（5）
`sfx_btl_combo_wall|lock|burnchain|tsunami`（P0）· `hint`（P1）

### down / end（7）
`sfx_btl_down_*`（4 体系 P1 + `down_ur` P0）· `end_victory|defeat`（P0）

### 辅助（8）
`start` `finisher` `fortress`（P0）· `turn` `extra_hit` `heal`（P1）· `pause` `scrub`（P2）

---

## 4. UI（26）· 编队/预测 Must

P0 必交：  
`click` `confirm` `cancel` `error` `reward` `levelup`  
`slot_place` `fleet_confirm` `cost_warn`  
`predict_ok` `predict_warn`  
`breakthrough` `constellation`  

其余见音频圣经 §5.2。

---

## 5. 海图 nav（19）

P0：`chart_open` `fog_reveal` `set_sail` `storm` `compass` `poi_found` `collect` `golden` `enemy` `boss`  
World 总线可用 `AudioStreamPlayer2D` 挂岛屿节点（距离 0–30m 线性）。

---

## 6. Gacha（14）· 全部仪式链 P0（除 dupe=P1）

见 `02-动画演出/03-Gacha仪式.md` 对照表。

---

## 7. 叙事（13）

P0：`cutscene_start` `chapter_title` `leit_iron|tide|flame|wind` `boss_warden` `boss_herald` `choir`  
Leitmotif 与角色绑定，勿串体系。

---

## 8. Godot 代码接口（建议）

```gdscript
# autoload Sfx.gd
func play(event_id: String, opts := {}) -> void:
    # opts: bus, seed, pos(Vector2), volume_db
    # 查表 AudioStream；变体 = hash(seed, event_id, n) % variants
```

战斗：`BattlePresenter` 每消费一条 log 调用 `Sfx.play(...)`。  
禁止在 SFX 内改 `GameState` / 结算。

---

## 9. 技术规格

| 项 | 规格 |
|---|---|
| 采样 | 48 kHz |
| 交付 | 干声或轻度处理；母带前峰值留白 |
| 格式 | Ogg Vorbis（SFX 96–128 kbps）或短 WAV |
| 内存 | PC 音频常驻 ≤512MB；长环境流式 |
| 抖动 | pitch ±50 cents、时长 ±5%，**仅 seed PRNG** |

---

## 10. VO（并入音频需求，非 SFX 表）

| 角色 | 句数预算（/语言） | P |
|---|---|---|
| 三海领袖×3 | ~50 各 | P1 |
| 罗盘 | ~30 | P1 |
| 先驱 | ~20 | P1 |
| 系统播报 | ~40 | P0 关键条 |
| 守卫王 | ~20 | P2 |

`vo_<lang>_<char>_<lineId>` · 48k/24bit 干声 · 中英双份。总线 VO_*，播放时 duck Music −6dB。
