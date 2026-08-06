# -*- coding: utf-8 -*-
"""Demo P0 素材批量生成 → client/assets/
图像：Pollinations（免费）
音乐：AceMusic（.env key，控制次数）
可重复运行：已存在文件跳过。
"""
from __future__ import annotations
import json
import os
import sys
import time
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # 大航海/
CLIENT = ROOT / "client"
ASSETS = CLIENT / "assets"
MOD_IMG = ROOT / "tools" / "aigc_modules" / "aigc_music_image" / "image"
MOD_MUS = ROOT / "tools" / "aigc_modules" / "aigc_music_image" / "music"

sys.path.insert(0, str(MOD_IMG))
sys.path.insert(0, str(MOD_MUS))

from pollinations_client import PollinationsClient  # noqa: E402
from music_client import AceMusicClient  # noqa: E402

STYLE = (
    "Dark mythic epic fantasy maritime strategy game concept art, painterly oil, "
    "somber cinematic lighting, no neon, no cute chibi, no modern UI chrome, "
    "no readable text, no watermark, "
)

SYS_PALETTE = {
    "flame": "dominant palette ember orange #FF6B2C, soot black, scorched metal",
    "ironwall": "dominant palette cold iron silver #B8BFC6, frost, rivets, no warm colors",
    "wind": "dominant palette storm cyan #5FC6D6, motion streaks, feather-like trails, no bird wings",
    "tide": "dominant palette abyss purple #7B5FC6, deep sea ink, concentric ripples, no trident crown",
}

CARD_PROMPTS = {
    "FLAME_R_01": ("火药学徒", "flame", "young powder apprentice at forge, sparks, soot face, half-body portrait"),
    "FLAME_R_02": ("燎帆炮手", "flame", "cannon gunner beside burning sail, powder smoke, half-body"),
    "FLAME_SR_01": ("烈焰船匠", "flame", "shipwright with molten tools, workshop glow, half-body"),
    "FLAME_SSR_01": ("赤焰龙女", "flame", "fierce woman with ember-lit eyes, sea of fire behind, bust portrait, NOT a dragon"),
    "FLAME_UR_01": ("祝融之裔", "flame", "mysterious silhouette back view facing burning horizon, catastrophic warm light, mythic, no face"),
    "IRON_R_01": ("铁砧卫", "ironwall", "heavy anvil guard with tower shield, frost metal, half-body"),
    "IRON_R_02": ("玄铁壁垒", "ironwall", "wall guardian interlocking shields, riveted armor, half-body"),
    "IRON_SR_01": ("铁壁督战", "ironwall", "frost commander with banner of iron, cold breath, half-body"),
    "IRON_SSR_01": ("山岳守望", "ironwall", "immovable mountain sentinel fused with stone wall, half-body"),
    "IRON_UR_01": ("霜铁之王", "ironwall", "figure merging into fortress wall of frost iron, no warm colors, mythic, no crown"),
    "WIND_R_01": ("信风斥候", "wind", "scout with wind-scarves, motion blur, half-body, no feathered wings"),
    "WIND_R_02": ("疾羽弓手", "wind", "archer with streamer arrows, gale lines, half-body"),
    "WIND_SR_01": ("疾风游骑", "wind", "cavalry rider on wave of wind, cyan trails, half-body"),
    "WIND_SSR_01": ("长风破阵", "wind", "breaker warrior mid dash shattering formation, storm cyan, half-body"),
    "WIND_UR_01": ("追风之翼", "wind", "fragmented afterimage of a stormrunner, broken motion trails as metaphor wings, no bird wings"),
    "TIDE_R_01": ("潮歌祭司", "tide", "tide priestess with glowing ripple amulet, purple abyss, half-body"),
    "TIDE_R_02": ("渊潮使", "tide", "envoy of deep current, ink-dark water, half-body"),
    "TIDE_SR_01": ("深渊回响", "tide", "enchanter surrounded by echo rings, purple bioluminescence, half-body"),
    "TIDE_SSR_01": ("海皇低语", "tide", "silencer whispering into black water, eerie purple, half-body, no trident"),
    "TIDE_UR_01": ("波塞冬·深渊之主", "tide", "unformed colossal sea presence rising as silhouette, mythic abyss, no muscular merman, no crown"),
}


def ensure_dirs():
    for p in [
        ASSETS / "art" / "characters",
        ASSETS / "art" / "env",
        ASSETS / "art" / "icons",
        ASSETS / "art" / "ships",
        ASSETS / "art" / "ui",
        ASSETS / "art" / "map",
        ASSETS / "audio" / "music",
        ASSETS / "audio" / "sfx",
    ]:
        p.mkdir(parents=True, exist_ok=True)


def skip_or(path: Path) -> bool:
    return path.exists() and path.stat().st_size > 2000


def gen_image(client: PollinationsClient, prompt: str, dest: Path, *,
              w=768, h=768, seed=42, model="flux"):
    if skip_or(dest):
        print(f"[skip] {dest.name}")
        return {"ok": True, "skipped": True, "file": str(dest)}
    full = STYLE + prompt
    tmp_name = dest.stem + "_tmp"
    r = client.generate(full, width=w, height=h, seed=seed, model=model,
                        filename=tmp_name, nologo=True)
    src = Path(r["file"])
    # pollinations may pick jpg/png
    if src.suffix.lower() != dest.suffix.lower():
        dest = dest.with_suffix(src.suffix)
    shutil.copy2(src, dest)
    print(f"[img] {dest} ({dest.stat().st_size})")
    return {"ok": True, "file": str(dest)}


def image_jobs():
    jobs = []
    # Environments
    jobs.append(("art/env/env_boot_frozen.jpg", 1440, 900, 101,
                 "frozen dark ocean under aurora of cold steel, sunken temple spires, "
                 "title-safe empty center, mythic seascape, " + SYS_PALETTE["ironwall"]))
    jobs.append(("art/env/env_map_frozen_sea.jpg", 1920, 1080, 102,
                 "top-down strategic sea chart of frozen ocean archipelago, twelve islands as dark silhouettes, "
                 "ink cartography meets oil painting, mist, " + SYS_PALETTE["ironwall"]))
    jobs.append(("art/env/env_battle_deck.jpg", 1440, 900, 103,
                 "wooden warship deck in frozen storm, mythic naval battle atmosphere, wide cinematic, "
                 "space for 2D fighters in foreground, " + SYS_PALETTE["ironwall"]))
    # System icons
    for sys, shape, seed in [
        ("flame", "triangle emblem of fire", 201),
        ("ironwall", "hex shield emblem of iron", 202),
        ("wind", "diamond emblem of gale", 203),
        ("tide", "circle ripple emblem of tide", 204),
    ]:
        jobs.append((f"art/icons/icon_sys_{sys}.png", 512, 512, seed,
                     f"game UI emblem icon, {shape}, flat-ish heraldic, centered, dark background, {SYS_PALETTE[sys]}"))
    # UI
    jobs.append(("art/ui/ui_panel_dark.jpg", 1024, 1024, 301,
                 "seamless dark ornate metal UI panel texture, subtle frost etchings, game interface, "
                 "no text, " + SYS_PALETTE["ironwall"]))
    jobs.append(("art/ui/ui_card_frame.png", 768, 1152, 302,
                 "vertical trading card frame ornate dark metal, empty center for portrait, "
                 "mythic maritime, no text"))
    jobs.append(("art/map/island_marker.png", 256, 256, 303,
                 "isometric tiny frozen island marker icon for strategy map, centered, transparent feel dark bg"))
    # Ships
    jobs.append(("art/ships/ship_raft.png", 768, 512, 401,
                 "side view small raft warship, mythic fantasy, dark sea spray, game sprite style"))
    jobs.append(("art/ships/ship_iron.png", 768, 512, 402,
                 "side view heavy ironclad frost warship, riveted plates, game sprite style, " + SYS_PALETTE["ironwall"]))
    jobs.append(("art/ships/ship_wind.png", 768, 512, 403,
                 "side view sleek wind-runner sailship, cyan streamers, game sprite style, " + SYS_PALETTE["wind"]))
    # Cards
    for cid, (name, sys, desc) in CARD_PROMPTS.items():
        seed = 1000 + abs(hash(cid)) % 9000
        jobs.append((f"art/characters/char_{cid}_bust.jpg", 640, 896, seed,
                     f"character bust portrait of '{name}', {desc}, {SYS_PALETTE[sys]}, "
                     f"vertical composition, dark mythic maritime"))
    return jobs


def music_jobs():
    return [
        ("audio/music/bgm_boot.mp3",
         "Dark mythic maritime prologue, low brass and frozen choir pads, sparse percussion, "
         "cinematic game title, no vocals, somber epic", 18),
        ("audio/music/bgm_map_frozen.mp3",
         "Ambient strategy map music, frozen ocean, soft strings, distant ice cracks, "
         "slow tempo loopable feel, instrumental, dark fantasy game", 30),
        ("audio/music/bgm_battle.mp3",
         "Naval battle music, driving drums, cold brass, tension, instrumental, "
         "dark mythic epic game combat, no melody too cheerful", 30),
        ("audio/music/bgm_victory.mp3",
         "Short victory fanfare restrained and solemn, mythic maritime, instrumental", 12),
    ]


def main():
    ensure_dirs()
    # point pollinations output to temp under batch
    out_tmp = Path(__file__).resolve().parent / "_tmp_out"
    out_tmp.mkdir(exist_ok=True)
    img = PollinationsClient(out_dir=str(out_tmp), retries=4, timeout=240)

    report = {"images": [], "music": [], "errors": []}
    jobs = image_jobs()
    print(f"=== IMAGE JOBS {len(jobs)} ===")
    for rel, w, h, seed, prompt in jobs:
        dest = ASSETS / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            # prefer jpg for photos; png for icons/ships if requested
            model = "flux"
            if "icon_" in rel or "island_" in rel:
                model = "flux"
            r = gen_image(img, prompt, dest, w=w, h=h, seed=seed, model=model)
            report["images"].append(r)
        except Exception as e:
            print(f"[ERR img] {rel}: {e}")
            report["errors"].append({"file": rel, "err": repr(e)})
            time.sleep(2)

    print("=== MUSIC JOBS ===")
    try:
        mus = AceMusicClient()
    except Exception as e:
        print(f"[ERR mus] client init: {e}")
        report["errors"].append({"file": "music_client", "err": repr(e)})
        mus = None
    for rel, prompt, dur in music_jobs():
        dest = ASSETS / rel
        if skip_or(dest):
            print(f"[skip] {dest.name}")
            report["music"].append({"ok": True, "skipped": True, "file": str(dest)})
            continue
        if mus is None:
            break
        try:
            r = mus.generate(prompt, duration=dur, instrumental=True, vocal_language="en")
            audio = r.get("audio")
            if not audio:
                raise RuntimeError(f"no audio bytes keys={list(r.keys())}")
            AceMusicClient.save(audio, str(dest))
            print(f"[mus] {dest} ({dest.stat().st_size})")
            report["music"].append({"ok": True, "file": str(dest)})
            time.sleep(1)
        except Exception as e:
            print(f"[ERR mus] {rel}: {e}")
            report["errors"].append({"file": rel, "err": repr(e)})

    manifest = ASSETS / "manifest_demo.json"
    manifest.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"DONE errors={len(report['errors'])} → {manifest}")
    return 0 if not report["errors"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
