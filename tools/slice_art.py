#!/usr/bin/env python3
"""Slices the 4-up sprite sheets into single trimmed sprites.

Usage: slice_art.py <src_dir> <out_dir>

Every sheet is an RGBA canvas with several sprites on a transparent field.
Sprites are found as connected components of the alpha mask (after a small
dilation so glow fragments stay with their sprite), sorted in reading order,
cropped with a few pixels of padding and written as `<group>_<i>.png`.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

GROUPS = [
    ("orbs_a", "Neon_Energy_Orbs_Set_01", 4),
    ("orbs_b", "Neon_Energy_Orbs_Set_02", 4),
    ("orbs_rare", "Rare_Neon_Energy_Orbs_Set", 4),
    ("core", "Central_Digital_Core", 1),
    ("symbols", "Energy_Symbols_Set", 4),
    ("rings", "Energy_Rings_Set", 4),
    ("buildings", "Futuristic_Buildings_Set", 4),
    ("holo_city", "Holographic_City_Elements_Set", 4),
    ("neon_tower", "Neon_Central_Tower", 1),
    ("holo_portal", "Holographic_Portal", 1),
    ("crystal_trees", "Digital_Crystal_Trees_Set", 4),
    ("crystals", "Glowing_Crystals_Set", 4),
    ("data_tree", "Central_Data_Tree", 1),
    ("ancient_column", "Ancient_Digital_Column", 1),
    ("platforms", "Floating_Platforms_Set", 4),
    ("light_columns", "Light_Columns_Set", 4),
    ("altar", "Energy_Altar", 1),
    ("sky_portal", "Sky_Portal", 1),
    ("waves", "Digital_Waves_Set", 4),
    ("underwater", "Glowing_Underwater_Objects_Set", 4),
    ("sunken_tower", "Sunken_Digital_Tower", 1),
    ("data_archive", "Underwater_Data_Archive", 1),
    ("dunes", "Digital_Dunes_Set", 4),
    ("rocks", "Quantum_Rocks_Set", 4),
    ("obelisks", "Light_Obelisks_Set", 4),
    ("desert_core", "Quantum_Desert_Core", 1),
    ("memory_core", "Main_Memory_Core", 1),
    ("server_crystals", "Server_Crystals_Set", 4),
    ("archive_portal", "Archive_Portal", 1),
    ("final_structure", "Final_Holographic_Structure", 1),
    ("plants", "Digital_Plants_Set", 4),
    ("deco", "Futuristic_Decoration_Elements_Set", 4),
    ("destroyed", "Destroyed_City_Elements_Set", 4),
    ("restored", "Restored_City_Elements_Set", 4),
    ("light_deco", "Light_Decorative_Objects_Set", 4),
]

ALPHA_CUT = 90
SCALE = 4  # label on a 1/4 resolution mask
DILATE = 0  # in low-res pixels


def label(mask):
    """Connected components (8-neighbourhood) of a boolean array."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    parent = [0]

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    nxt = 1
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            neigh = []
            for dy, dx in ((-1, -1), (-1, 0), (-1, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and labels[yy, xx]:
                    neigh.append(labels[yy, xx])
            if not neigh:
                parent.append(nxt)
                labels[y, x] = nxt
                nxt += 1
            else:
                root = min(find(n) for n in neigh)
                labels[y, x] = root
                for n in neigh:
                    parent[find(n)] = root
    for i in range(1, nxt):
        pass
    flat = np.array([find(i) for i in range(nxt)])
    return flat[labels], nxt


def components(alpha):
    small = Image.fromarray((alpha > ALPHA_CUT).astype(np.uint8) * 255).resize(
        (alpha.shape[1] // SCALE, alpha.shape[0] // SCALE), Image.BILINEAR
    )
    small = small.filter(ImageFilter.MaxFilter(DILATE * 2 + 1))
    mask = np.array(small) > 40
    lab, _ = label(mask)
    boxes = []
    for value in np.unique(lab):
        if value == 0:
            continue
        ys, xs = np.nonzero(lab == value)
        area = len(ys)
        if area < 60:
            continue
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, area, int(value)))
    return boxes, lab


def drop_specks(crop, keep=0.06):
    """Removes small detached fragments (neighbour spill, stray sparkles)."""
    alpha = np.array(crop)[..., 3]
    small = Image.fromarray(((alpha > ALPHA_CUT) * 255).astype(np.uint8)).resize(
        (max(1, alpha.shape[1] // 4), max(1, alpha.shape[0] // 4)), Image.BILINEAR
    )
    small = small.filter(ImageFilter.MaxFilter(3))
    lab, _ = label(np.array(small) > 40)
    sizes = {int(v): int((lab == v).sum()) for v in np.unique(lab) if v}
    if not sizes:
        return crop
    top = max(sizes.values())
    ok = np.zeros(lab.shape, dtype=np.uint8)
    for v, n in sizes.items():
        if n >= top * keep:
            ok[lab == v] = 255
    ok = Image.fromarray(ok).filter(ImageFilter.MaxFilter(3))
    mask = np.array(ok.resize(crop.size, Image.BILINEAR)).astype(np.float32) / 255.0
    arr = np.array(crop).astype(np.float32)
    arr[..., 3] *= mask
    return Image.fromarray(arr.astype(np.uint8))


def reading_order(boxes):
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]) / 2)
    rows, current = [], [boxes[0]]
    for b in boxes[1:]:
        cy = (current[0][1] + current[0][3]) / 2
        height = current[0][3] - current[0][1]
        if abs((b[1] + b[3]) / 2 - cy) < height * 0.45:
            current.append(b)
        else:
            rows.append(current)
            current = [b]
    rows.append(current)
    out = []
    for row in rows:
        out.extend(sorted(row, key=lambda b: b[0]))
    return out


def quadrants(alpha):
    """2x2 fallback: split where the alpha projection is thinnest."""
    h, w = alpha.shape
    mask = (alpha > ALPHA_CUT).astype(np.int32)
    cols = mask.sum(axis=0)
    x0, x1 = int(w * 0.4), int(w * 0.6)
    xs = x0 + int(np.argmin(cols[x0:x1]))
    boxes = []
    for left in (True, False):
        part = mask[:, :xs] if left else mask[:, xs:]
        rows = part.sum(axis=1)
        y0, y1 = int(h * 0.4), int(h * 0.6)
        ys = y0 + int(np.argmin(rows[y0:y1]))
        for top in (True, False):
            bx0, bx1 = (0, xs) if left else (xs, w)
            by0, by1 = (0, ys) if top else (ys, h)
            boxes.append((bx0, by0, bx1, by1))
    # reading order: top-left, top-right, bottom-left, bottom-right
    boxes.sort(key=lambda b: (b[1], b[0]))
    return boxes


def main(src, out):
    src, out = Path(src), Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for key, stem, expect in GROUPS:
        path = src / f"{stem}_asset.webp"
        im = Image.open(path).convert("RGBA")
        alpha = np.array(im)[..., 3]
        masks = [None] * expect
        if expect == 1:
            ys, xs = np.nonzero(alpha > ALPHA_CUT)
            scaled = [(xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)]
        else:
            boxes, lab = components(alpha)
            boxes = sorted(boxes, key=lambda b: -b[4])[:expect]
            boxes = reading_order(boxes)
            scaled = [
                (b[0] * SCALE, b[1] * SCALE, b[2] * SCALE, b[3] * SCALE) for b in boxes
            ]
            if len(scaled) == expect:
                masks = []
                for b in boxes:
                    m = Image.fromarray(((lab == b[5]) * 255).astype(np.uint8))
                    m = m.filter(ImageFilter.MaxFilter(7))
                    masks.append(m.resize(im.size, Image.BILINEAR))
            else:
                scaled = quadrants(alpha)
                masks = [None] * expect
        flag = "" if len(scaled) == expect else "  <-- MISMATCH"
        print(f"{key:16s} found {len(scaled)} of {expect}{flag}")
        for i, (x0, y0, x1, y1) in enumerate(scaled):
            pad = 14
            piece = im
            if masks[i] is not None:
                arr = np.array(im).astype(np.float32)
                arr[..., 3] *= np.array(masks[i]).astype(np.float32) / 255.0
                piece = Image.fromarray(arr.astype(np.uint8))
            crop = piece.crop(
                (max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad))
            )
            crop = drop_specks(crop, 0.06 if masks[i] is not None else 0.2)
            # Trim to the visible pixels of this crop.
            a = np.array(crop)[..., 3]
            ys, xs = np.nonzero(a > 12)
            crop = crop.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            crop.save(out / f"{key}_{i}.png")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
