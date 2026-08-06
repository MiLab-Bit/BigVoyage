# -*- coding: utf-8 -*-
"""全量 BGM（规划 §3）AceMusic 直连，禁用坏代理。跳过已存在文件。"""
import os, sys
from pathlib import Path

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)
os.environ.pop("ALL_PROXY", None)
os.environ.pop("all_proxy", None)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "client" / "assets" / "audio" / "music"
MOD = ROOT / "tools" / "aigc_modules" / "aigc_music_image" / "music"
sys.path.insert(0, str(MOD))
from music_client import AceMusicClient  # noqa

OUT.mkdir(parents=True, exist_ok=True)

JOBS = [
    # P0 Demo 冻洋
    ("bgm_menu_main.mp3", "Dark mythic maritime main menu, sparse low strings, distant frozen choir pad, solemn epic game title loopable instrumental no vocals", 35),
    ("bgm_sea_frozen_bed.mp3", "Frozen ocean ambient bed, wind snow distant whale call, deep low strings, iron timpani heartbeat very soft, dark fantasy strategy map instrumental loopable", 35),
    ("bgm_sea_frozen_tense.mp3", "Tense stem layer for frozen sea, soft timpani ostinato, cold brass muted, rising dread instrumental loopable game music", 28),
    ("bgm_battle_frozen.mp3", "Frozen naval battle music, driving drums, cold brass ironwall motif descending fifths hammer, dark mythic epic instrumental combat loop", 35),
    ("bgm_battle_climax.mp3", "Battle climax stinger layer choir organ hit mythic maritime instrumental intense  short epic", 14),
    ("bgm_victory_short.mp3", "Short solemn warm victory resolve mythic maritime instrumental restrained fanfare", 12),
    ("bgm_defeat_short.mp3", "Short cold defeat resolve descending strings mythic maritime instrumental", 12),
    ("bgm_gacha_bed.mp3", "Low expectation gacha pool ambient dark metallic ticks soft choir pad instrumental loopable mysterious", 28),
    ("stinger_gacha_ssr.mp3", "SSR reveal stinger bright metallic chime short orchestral hit mythic game", 4),
    ("stinger_gacha_ur.mp3", "UR reveal stinger full orchestra choir organ mythic maritime awe short", 7),
    ("stinger_leit_flame.mp3", "Leitmotif flame brass ascending leap staccato short 2 seconds instrumental", 3),
    ("stinger_leit_ironwall.mp3", "Leitmotif ironwall timpani descending fifth hammer short instrumental", 3),
    ("stinger_leit_wind.mp3", "Leitmotif wind woodwind descending sixteenth run short instrumental", 3),
    ("stinger_leit_tide.mp3", "Leitmotif tide humming vocal-like wave stepwise short instrumental pad", 3),
    # P1 世界观
    ("bgm_sea_abyss_bed.mp3", "Abyss sea ambient purple deep water choir hum bioluminescent mystery dark fantasy instrumental loopable", 30),
    ("bgm_sea_abyss_battle.mp3", "Abyss naval battle dark choir drums purple tension mythic instrumental loop", 30),
    ("bgm_sea_hanhai_bed.mp3", "Warm monsoon golden hour harbor ambient silk trade wind brass soft major tint dark mythic still restrained instrumental loop", 30),
    ("bgm_sea_hanhai_battle.mp3", "Hanhai battle warm brass flame motif ascending leaps drums mythic instrumental loop", 30),
    ("bgm_sea_tradewind_bed.mp3", "Tradewind belt ambient storm cyan sails woodwind flutter distant waves instrumental loop", 30),
    ("bgm_sea_tradewind_battle.mp3", "Tradewind battle fast woodwind runs percussion chase mythic instrumental loop", 30),
    ("bgm_harbor_warm.mp3", "Rebuilt harbor golden hour warm but melancholic strings soft brass hope instrumental loop", 28),
    ("bgm_boss_warden.mp3", "Island warden boss music heavy iron drums fortress dread mythic instrumental loop", 32),
    ("bgm_boss_herald.mp3", "Sea emperor herald boss organ choir abyss tide motif overwhelming mythic instrumental", 32),
    ("bgm_cutscene_ch01.mp3", "Chapter one cutscene orchestral the great sinking narrative dark mythic maritime instrumental cinematic", 40),
]


def main():
    c = AceMusicClient()
    c.session.trust_env = False
    print("health", c.health(), flush=True)
    ok = fail = 0
    for name, prompt, dur in JOBS:
        dest = OUT / name
        if dest.exists() and dest.stat().st_size > 2000:
            print("skip", name, flush=True)
            ok += 1
            continue
        print("gen", name, flush=True)
        try:
            r = c.generate(prompt, duration=dur, instrumental=True, vocal_language="en", max_retries=3)
            AceMusicClient.save(r["audio"], str(dest))
            print("ok", name, len(r["audio"]), flush=True)
            ok += 1
        except Exception as e:
            print("fail", name, repr(e), flush=True)
            fail += 1
    # aliases for old Bgm.gd keys
    aliases = {
        "bgm_boot.mp3": "bgm_menu_main.mp3",
        "bgm_map_frozen.mp3": "bgm_sea_frozen_bed.mp3",
        "bgm_battle.mp3": "bgm_battle_frozen.mp3",
        "bgm_victory.mp3": "bgm_victory_short.mp3",
    }
    for alias, src in aliases.items():
        sp, ap = OUT / src, OUT / alias
        if sp.exists():
            ap.write_bytes(sp.read_bytes())
            print("alias", alias, "<-", src, flush=True)
    print(f"MUSIC FULL ok={ok} fail={fail}", flush=True)
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
