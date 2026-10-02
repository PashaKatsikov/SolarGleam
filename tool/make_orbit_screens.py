#!/usr/bin/env python3
"""Generate Solar Gleam gray-flow screens (Notifications + No-Wifi).

Baked-in headline + subtitle + emblem; the lower region is left clear for the
Flutter gold buttons overlaid by notify_gate.dart / no_signal_page.dart.
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT_DIR = "assets/fonts"
OUT_DIR = "assets/orbit_screens"
os.makedirs(OUT_DIR, exist_ok=True)

CINZEL = os.path.join(FONT_DIR, "Cinzel.ttf")
RAJD = os.path.join(FONT_DIR, "Rajdhani-Bold.ttf")

NIGHT_TOP = (16, 11, 30)       # warm indigo
NIGHT_BOT = (5, 3, 9)          # near-black
GOLD = (240, 193, 75)          # GleamColors.gold
GOLD_LIGHT = (255, 241, 201)   # goldLight
GOLD_DEEP = (200, 136, 43)     # goldDeep
IVORY = (255, 246, 228)

S = 2  # supersample


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        c = lerp(NIGHT_TOP, NIGHT_BOT, y / h)
        for x in range(w):
            px[x, y] = c
    return img


def radial_glow(w, h, cx, cy, radius, color, strength=1.0):
    glow = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(glow)
    steps = 48
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(255 * strength * (1 - i / steps) ** 1.6)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.12))
    layer = Image.new("RGB", (w, h), color)
    return layer, glow


def add_stars(img, count):
    d = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    rnd = random.Random(7)
    for _ in range(count):
        x = rnd.randint(0, w)
        y = rnd.randint(0, int(h * 0.72))
        r = rnd.choice([1, 1, 1, 2, 2, 3]) * S
        a = rnd.randint(60, 190)
        tint = rnd.choice([(255, 255, 255), GOLD_LIGHT, GOLD])
        d.ellipse([x - r, y - r, x + r, y + r], fill=tint + (a,))


def glow_layer(size, draw_fn, blur, color):
    """Return an RGBA emblem glow given a mask-drawing callback."""
    mask = Image.new("L", size, 0)
    draw_fn(ImageDraw.Draw(mask))
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(mask)
    return layer


def draw_bell(base, cx, cy, scale):
    """Stylised ringing bell emblem, gold."""
    w, h = base.size
    r = scale
    # halo rings suggesting sound
    halo = glow_layer(
        (w, h),
        lambda d: [
            d.arc([cx - r * k, cy - r * k, cx + r * k, cy + r * k],
                  210, 330, fill=255, width=int(6 * S))
            for k in (1.9, 2.4, 2.9)
        ],
        6 * S, GOLD,
    )
    base.alpha_composite(halo)

    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    top = cy - r
    # bell dome + flare as a smooth polygon
    pts = []
    for t in range(0, 181, 6):
        ang = math.radians(t)
        bx = cx - r * 0.95 * math.cos(ang)
        by = top + r * 0.35 + r * 0.7 * (1 - math.sin(ang)) * 0.5
        pts.append((bx, by))
    # widen skirt
    skirt_y = cy + r * 0.78
    pts = ([(cx - r * 1.02, skirt_y)] + pts + [(cx + r * 1.02, skirt_y)])
    bd.polygon(pts, fill=GOLD)
    # rim
    bd.rounded_rectangle(
        [cx - r * 1.12, skirt_y - r * 0.06, cx + r * 1.12, skirt_y + r * 0.14],
        radius=int(r * 0.12), fill=GOLD_LIGHT)
    # handle
    bd.ellipse([cx - r * 0.16, top - r * 0.14, cx + r * 0.16, top + r * 0.18],
               outline=GOLD_LIGHT, width=int(9 * S))
    # clapper
    bd.ellipse([cx - r * 0.17, skirt_y + r * 0.16,
                cx + r * 0.17, skirt_y + r * 0.5], fill=GOLD_DEEP)
    # inner shade for depth
    bd.polygon([(cx + r * 0.1, top + r * 0.4),
                (cx + r * 0.95, skirt_y),
                (cx + r * 0.3, skirt_y)], fill=GOLD_DEEP + (120,))
    base.alpha_composite(body)


def draw_wifi_off(base, cx, cy, scale):
    """Wifi arcs with a diagonal slash, gold."""
    w, h = base.size
    r = scale
    halo = glow_layer(
        (w, h),
        lambda d: [
            d.arc([cx - r * k, cy - r * k + r * 0.5,
                   cx + r * k, cy + r * k + r * 0.5],
                  210, 330, fill=255, width=int(22 * S))
            for k in (0.5, 0.95, 1.4)
        ],
        7 * S, GOLD,
    )
    base.alpha_composite(halo)

    arcs = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arcs)
    for k, col in ((1.4, GOLD_DEEP), (0.95, GOLD), (0.5, GOLD_LIGHT)):
        ad.arc([cx - r * k, cy - r * k + r * 0.5,
                cx + r * k, cy + r * k + r * 0.5],
               210, 330, fill=col, width=int(22 * S))
    # base dot
    dot = r * 0.14
    ad.ellipse([cx - dot, cy + r * 0.5 - dot, cx + dot, cy + r * 0.5 + dot],
               fill=GOLD_LIGHT)
    # diagonal slash
    sl = r * 1.5
    ad.line([cx - sl, cy - sl + r * 0.5, cx + sl, cy + sl + r * 0.5],
            fill=NIGHT_BOT, width=int(34 * S))
    ad.line([cx - sl, cy - sl + r * 0.5, cx + sl, cy + sl + r * 0.5],
            fill=GOLD_LIGHT, width=int(14 * S))
    base.alpha_composite(arcs)


def wrap(draw, text, font, max_w):
    words = text.split()
    lines, cur = [], ""
    for word in words:
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=font) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def draw_text_block(img, headline, subtitle, head_top_frac,
                    head_scale, sub_scale):
    w, h = img.size
    d = ImageDraw.Draw(img, "RGBA")
    max_w = w * 0.86
    head_font = ImageFont.truetype(CINZEL, int(w * head_scale))
    sub_font = ImageFont.truetype(RAJD, int(w * sub_scale))

    head_lines = wrap(d, headline, head_font, max_w)
    sub_lines = wrap(d, subtitle, sub_font, max_w)

    y = h * head_top_frac
    line_gap = int(w * 0.018)
    for line in head_lines:
        tw = d.textlength(line, font=head_font)
        x = (w - tw) / 2
        # soft glow
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.text((x, y), line, font=head_font, fill=GOLD + (255,))
        glow = glow.filter(ImageFilter.GaussianBlur(10 * S))
        img.alpha_composite(glow)
        d.text((x, y), line, font=head_font, fill=GOLD_LIGHT)
        asc, desc = head_font.getmetrics()
        y += asc + desc + line_gap

    y += int(w * 0.03)
    for line in sub_lines:
        tw = d.textlength(line, font=sub_font)
        x = (w - tw) / 2
        d.text((x, y), line, font=sub_font, fill=IVORY + (235,))
        asc, desc = sub_font.getmetrics()
        y += asc + desc + int(line_gap * 0.6)


def render(kind, orient):
    if orient == "portrait":
        W, H = 1080 * S, 1920 * S
        icon_cy_frac, head_frac, icon_scale = 0.30, 0.47, 0.14
        head_scale, sub_scale = 0.062, 0.040
    else:
        W, H = 1920 * S, 1080 * S
        icon_cy_frac, head_frac, icon_scale = 0.19, 0.34, 0.13
        head_scale, sub_scale = 0.044, 0.028
        if kind == "nowifi":
            # The slash extends far below the arcs; give the headline room.
            icon_cy_frac, head_frac, icon_scale = 0.15, 0.47, 0.115

    base = vgradient(W, H).convert("RGBA")
    cx = W / 2
    cy = H * icon_cy_frac

    # warm glow behind emblem
    layer, mask = radial_glow(W, H, cx, cy, min(W, H) * 0.42, GOLD, 0.5)
    base.paste(layer, (0, 0), mask)

    add_stars(base, 150 if orient == "portrait" else 180)

    scale = min(W, H) * icon_scale
    if kind == "notify":
        draw_bell(base, cx, cy, scale)
        headline = "ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS"
        subtitle = "Stay tuned for special offers and rewards"
    else:
        draw_wifi_off(base, cx, cy, scale)
        headline = "NO INTERNET CONNECTION"
        subtitle = "Check your connection and try again"

    draw_text_block(base, headline, subtitle, head_frac, head_scale, sub_scale)

    out = base.convert("RGB").resize((W // S, H // S), Image.LANCZOS)
    path = os.path.join(OUT_DIR, f"{kind}_{orient}.webp")
    out.save(path, "WEBP", quality=90, method=6)
    print("wrote", path, out.size)


for kind in ("notify", "nowifi"):
    for orient in ("portrait", "landscape"):
        render(kind, orient)
print("done")
