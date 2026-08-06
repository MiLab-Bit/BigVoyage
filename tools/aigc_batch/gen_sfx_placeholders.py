# -*- coding: utf-8 -*-
"""P0 SFX 占位：按事件 ID 合成短 WAV（非最终拟音，ID 对齐需求文档）。"""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "client" / "assets" / "audio" / "sfx"

# (relpath, freq_hz, dur_s, kind) kind: tone|noise|sweep|thud
EVENTS = []

def add(prefix, names, base_f, kind="tone", dur=0.12):
    for i, n in enumerate(names):
        EVENTS.append((f"{prefix}/{n}.wav", base_f * (1.0 + 0.03 * i), dur, kind))

add("btl", [
    "sfx_btl_deploy_flame", "sfx_btl_deploy_ironwall", "sfx_btl_deploy_wind", "sfx_btl_deploy_tide", "sfx_btl_deploy_all",
    "sfx_btl_skill_flame", "sfx_btl_skill_ironwall", "sfx_btl_skill_wind", "sfx_btl_skill_tide",
    "sfx_btl_hit_flame", "sfx_btl_hit_ironwall", "sfx_btl_hit_wind", "sfx_btl_hit_tide",
    "sfx_btl_restraint_flame", "sfx_btl_restraint_ironwall", "sfx_btl_restraint_wind", "sfx_btl_restraint_tide",
    "sfx_btl_dot_burn", "sfx_btl_dot_tide", "sfx_btl_dot_stack",
    "sfx_btl_control_stun", "sfx_btl_control_silence", "sfx_btl_control_break",
    "sfx_btl_combo_wall", "sfx_btl_combo_lock", "sfx_btl_combo_burnchain", "sfx_btl_combo_tsunami",
    "sfx_btl_down_ur", "sfx_btl_end_victory", "sfx_btl_end_defeat",
    "sfx_btl_start", "sfx_btl_finisher", "sfx_btl_fortress", "sfx_btl_kill",
], 220.0, "thud", 0.14)

add("ui", [
    "sfx_ui_click", "sfx_ui_confirm", "sfx_ui_cancel", "sfx_ui_error", "sfx_ui_reward", "sfx_ui_levelup",
    "sfx_ui_slot_place", "sfx_ui_fleet_confirm", "sfx_ui_cost_warn",
    "sfx_ui_predict_ok", "sfx_ui_predict_warn",
    "sfx_ui_breakthrough", "sfx_ui_constellation", "sfx_ui_select", "sfx_ui_deny", "sfx_ui_ok",
], 520.0, "tone", 0.08)

add("nav", [
    "sfx_nav_chart_open", "sfx_nav_fog_reveal", "sfx_nav_set_sail", "sfx_nav_storm", "sfx_nav_compass",
    "sfx_nav_poi_found", "sfx_nav_collect", "sfx_nav_golden", "sfx_nav_enemy", "sfx_nav_boss",
    "sfx_nav_day_advance", "sfx_nav_island_capture",
], 180.0, "sweep", 0.2)

add("gacha", [
    "sfx_gacha_open", "sfx_gacha_spin", "sfx_gacha_tick", "sfx_gacha_sr", "sfx_gacha_ssr", "sfx_gacha_ur",
    "sfx_gacha_reveal", "sfx_gacha_skip", "sfx_gacha_multi", "sfx_gacha_pity", "sfx_gacha_card_flip",
    "sfx_gacha_beam", "sfx_gacha_close",
], 400.0, "tone", 0.15)

add("nar", [
    "sfx_nar_cutscene_start", "sfx_nar_chapter_title", "sfx_nar_leit_iron", "sfx_nar_leit_tide",
    "sfx_nar_leit_flame", "sfx_nar_leit_wind", "sfx_nar_boss_warden", "sfx_nar_boss_herald", "sfx_nar_choir",
], 150.0, "sweep", 0.35)


def synth(path: Path, freq: float, dur: float, kind: str, sr: int = 22050):
    n = int(sr * dur)
    frames = bytearray()
    for i in range(n):
        t = i / sr
        env = min(1.0, t * 40) * max(0.0, 1.0 - t / dur)
        if kind == "noise":
            # xorshift-ish
            v = ((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF * 2 - 1
            s = 0.25 * env * v
        elif kind == "sweep":
            f = freq * (1.0 + 1.5 * t / max(dur, 1e-3))
            s = 0.3 * env * math.sin(2 * math.pi * f * t)
        elif kind == "thud":
            f = freq * math.exp(-6 * t)
            s = 0.45 * env * math.sin(2 * math.pi * f * t)
            s += 0.15 * env * (((i * 1664525) & 255) / 255 - 0.5)
        else:
            s = 0.35 * env * math.sin(2 * math.pi * freq * t)
            s += 0.12 * env * math.sin(2 * math.pi * freq * 2 * t)
        s = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(s * 30000))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(frames)


def main():
    n = 0
    for rel, f, d, k in EVENTS:
        p = OUT / rel
        if p.exists() and p.stat().st_size > 200:
            continue
        synth(p, f, d, k)
        n += 1
    print(f"SFX wrote/skipped total_events={len(EVENTS)} newly={n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
