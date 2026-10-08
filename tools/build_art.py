#!/usr/bin/env python3
"""Builds assets/art and assets/audio from the raw design sheets.

Usage: build_art.py <assets_for_new_game dir> <assets dir>

* slices every sprite sheet (tools/slice_art.py),
* keeps only the sprites the game uses and writes them as trimmed webp,
* builds the six region backdrops (three are re-graded from the source art),
* copies the sound effects under short names.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).parent

USED = {
    "orbs_b": [0, 1, 2, 3],
    "orbs_rare": [0, 1, 2, 3],
    "orbs_a": [0, 1, 2, 3],
    "core": [0],
    "symbols": [0, 1, 2, 3],
    "rings": [0, 1, 2, 3],
    "buildings": [0, 1, 2],
    "holo_city": [0, 1, 2, 3],
    "neon_tower": [0],
    "holo_portal": [0],
    "crystal_trees": [0, 1, 2, 3],
    "crystals": [0, 1, 2, 3],
    "data_tree": [0],
    "ancient_column": [0],
    "platforms": [0, 1, 2, 3],
    "light_columns": [0, 1, 2, 3],
    "altar": [0],
    "sky_portal": [0],
    "waves": [0, 1, 2, 3],
    "underwater": [0, 1, 2, 3],
    "sunken_tower": [0],
    "data_archive": [0],
    "dunes": [0, 1, 2, 3],
    "rocks": [0, 1, 2],
    "obelisks": [0, 1, 2, 3],
    "desert_core": [0],
    "memory_core": [0],
    "server_crystals": [0, 1, 2, 3],
    "archive_portal": [0],
    "final_structure": [0],
    "plants": [0, 1, 3],
    "deco": [0, 2, 3],
    "destroyed": [0, 1, 2, 3],
    "restored": [0, 1, 2, 3],
    "light_deco": [0, 1, 2, 3],
}

MAX_SIDE = {"orbs_a": 300, "orbs_b": 300, "orbs_rare": 300, "symbols": 224, "core": 420, "platforms": 720}
DEFAULT_SIDE = 540

SOUNDS = {
    "Action_Error": "error",
    "Action_Success": "success",
    "Button_Click": "click",
    "Energy_Activation": "energy",
    "Level_Complete": "complete",
    "Main_Menu_Ambient": "ambient",
    "Menu_Close": "close",
    "Menu_Open": "open",
    "New_Area_Unlock": "area_unlock",
    "Object_Select": "select",
    "Orb_Transformation": "shift",
    "Orb_Unlock": "orb_unlock",
    "Reward_Collect": "reward",
    "Teleport": "teleport",
    "World_Restore": "restore",
}


def save_webp(img, path, quality=88):
    img.save(path, "WEBP", quality=quality, alpha_quality=100, method=6)


def shift_hue(img, lo, hi, target, sat=1.0, val=1.0, feather=14):
    """Moves hues in [lo, hi] (PIL 0..255 scale) towards `target`."""
    hsv = np.array(img.convert("HSV")).astype(np.float32)
    h = hsv[..., 0]
    inside = (h >= lo) & (h <= hi)
    edge = np.clip(np.minimum(h - lo, hi - h) / feather, 0, 1)
    weight = np.where(inside, edge, 0.0)
    centre = (lo + hi) / 2.0
    new_h = h + (target - centre) * weight
    hsv[..., 0] = np.mod(new_h, 255)
    hsv[..., 1] = np.clip(hsv[..., 1] * (1 + (sat - 1) * weight), 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * (1 + (val - 1) * weight), 0, 255)
    return Image.frombytes("HSV", img.size, hsv.astype(np.uint8).tobytes()).convert("RGB")


def backgrounds(src, out):
    def load(name):
        return Image.open(src / f"{name}_asset.webp").convert("RGB")

    neon = load("Neon_District_Background")
    forest = load("Crystal_Data_Forest_Background")
    core = load("Memory_Core_Background")
    mix = load("Cyber_Ocean_Quantum_Desert_Background")
    w, h = mix.size

    # Aurora Sky Temple: the sky and gold pyramids of the mixed backdrop with a
    # mirrored, softened sky floor below the horizon.
    horizon = int(h * 0.50)
    sky = mix.crop((0, 0, w, horizon))
    floor = sky.transpose(Image.FLIP_TOP_BOTTOM).resize((w, h - horizon))
    floor = floor.filter(ImageFilter.GaussianBlur(14))
    fade = np.linspace(0.95, 0.16, h - horizon)[:, None, None]
    floor = Image.fromarray((np.array(floor) * fade).astype(np.uint8))
    # drifting cloud banks over the floor: tinted noise, screened in
    rng = np.random.default_rng(7)
    noise = Image.fromarray((rng.random(((h - horizon) // 8, w // 8)) * 255).astype(np.uint8))
    noise = noise.resize((w, h - horizon), Image.BICUBIC).filter(ImageFilter.GaussianBlur(28))
    n = np.array(noise).astype(np.float32)
    n = np.clip((n - n.min()) / (n.max() - n.min()), 0, 1) ** 1.6
    tint = np.array([196, 168, 255], dtype=np.float32)
    clouds = n[..., None] * tint[None, None, :] * np.linspace(0.55, 0.18, h - horizon)[:, None, None]
    base = np.array(floor).astype(np.float32)
    floor = Image.fromarray(np.clip(255 - (255 - base) * (255 - clouds) / 255, 0, 255).astype(np.uint8))
    ramp = 280
    start = horizon - ramp
    aurora = Image.new("RGB", (w, h))
    lift = floor.crop((0, 0, w, ramp)).transpose(Image.FLIP_TOP_BOTTOM)
    aurora.paste(lift, (0, start))
    aurora.paste(floor, (0, horizon))
    sky_full = mix.crop((0, 0, w, horizon))
    fade_mask = np.ones((horizon, w), dtype=np.float32)
    fade_mask[start:] = np.linspace(1, 0, ramp)[:, None]
    aurora.paste(sky_full, (0, 0), Image.fromarray((fade_mask * 255).astype(np.uint8)))

    # Cyber Ocean: warm sand turns to glowing cyan water.
    ocean = shift_hue(mix, -30, 100, 152, sat=1.05, val=0.92, feather=20)
    # Quantum Desert: mirrored, water turns violet so the gold dunes lead.
    desert = shift_hue(mix.transpose(Image.FLIP_LEFT_RIGHT), 118, 178, 188, sat=1.0, val=0.82)

    for i, img in enumerate([neon, forest, aurora, ocean, desert, core]):
        save_webp(img, out / f"bg_{i}.webp", quality=82)


def main(src, assets):
    src, assets = Path(src), Path(assets)
    art = assets / "art"
    audio = assets / "audio"
    if art.exists():
        shutil.rmtree(art)
    art.mkdir(parents=True)
    audio.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(
            [sys.executable, str(HERE / "slice_art.py"), str(src / "gameplay/gameplay_assets"), tmp],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        total = 0
        for key, indices in USED.items():
            for i in indices:
                img = Image.open(Path(tmp) / f"{key}_{i}.png").convert("RGBA")
                side = MAX_SIDE.get(key, DEFAULT_SIDE)
                if max(img.size) > side:
                    k = side / max(img.size)
                    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
                save_webp(img, art / f"{key}_{i}.webp")
                total += 1
        print("sprites", total)

    backgrounds(src / "gameplay/gameplay_assets", art)

    for old, new in SOUNDS.items():
        shutil.copy(src / "sounds_assets" / f"{old}_sound_asset.mp3", audio / f"{new}.mp3")
    print("audio", len(SOUNDS))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
