"""Generates the app icon for iOS (Icon Composer .icon) and Android.

Run from the repository root: python3 tool/icon/gen.py
Needs rsvg-convert (brew install librsvg).
"""

import json
import math
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
CORAL = "#FF6B6B"
CORAL_LIGHT = "#FF9F68"
NAVY = "#2E3A87"
RING = "#E4E7F5"
GOLD = "#FECA57"
GOLD_DARK = "#F0A020"

# Artwork coordinates are on Apple's 1024 canvas, with the bounding box of
# calendar + coin centred.


def arc_arrow(cx, cy, r, start_deg, sweep_deg):
    a0 = math.radians(start_deg)
    a1 = math.radians(start_deg + sweep_deg)
    x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
    x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
    large = 1 if sweep_deg > 180 else 0
    arc = f"M{x0:.1f},{y0:.1f} A{r},{r} 0 {large} 1 {x1:.1f},{y1:.1f}"
    # Arrowhead: a triangle pointing along the tangent at the arc end.
    tx, ty = -math.sin(a1), math.cos(a1)
    nx, ny = math.cos(a1), math.sin(a1)
    size = 62
    tip = (x1 + tx * size, y1 + ty * size)
    left = (x1 + nx * size * 0.85, y1 + ny * size * 0.85)
    right = (x1 - nx * size * 0.85, y1 - ny * size * 0.85)
    head = "M{:.1f},{:.1f} L{:.1f},{:.1f} L{:.1f},{:.1f} Z".format(*tip, *left, *right)
    return arc, head


ARC, HEAD = arc_arrow(427, 535, 105, -70, 280)

CALENDAR = f"""
  <rect x="167" y="210" width="520" height="500" rx="72" fill="white"/>
  <path d="M239,210 H615 A72,72 0 0 1 687,282 V340 H167 V282 A72,72 0 0 1 239,210 Z" fill="{NAVY}"/>
  <rect x="267" y="168" width="40" height="96" rx="20" fill="{RING}"/>
  <rect x="547" y="168" width="40" height="96" rx="20" fill="{RING}"/>
  <path d="{ARC}" fill="none" stroke="{NAVY}" stroke-width="44" stroke-linecap="round"/>
  <path d="{HEAD}" fill="{NAVY}"/>
"""

YEN = """
  <path d="M607,572 L667,650 L727,572 M667,650 V760 M612,668 H722 M612,718 H722"
        fill="none" stroke="{color}" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>
"""

COIN = f"""
  <circle cx="667" cy="660" r="190" fill="{GOLD}"/>
  <circle cx="667" cy="660" r="150" fill="none" stroke="{GOLD_DARK}" stroke-width="18"/>
  {YEN.format(color=NAVY)}
"""

BACKGROUND = f"""
  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{CORAL_LIGHT}"/><stop offset="1" stop-color="{CORAL}"/>
  </linearGradient></defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
"""

# Themed (monochrome) icon: one opaque silhouette, details cut out.
MONO = f"""
  <defs><mask id="m">
    <rect width="1024" height="1024" fill="black"/>
    <rect x="167" y="210" width="520" height="500" rx="72" fill="white"/>
    <rect x="267" y="168" width="40" height="96" rx="20" fill="white"/>
    <rect x="547" y="168" width="40" height="96" rx="20" fill="white"/>
    <rect x="167" y="340" width="520" height="14" fill="black"/>
    <path d="{ARC}" fill="none" stroke="black" stroke-width="44" stroke-linecap="round"/>
    <path d="{HEAD}" fill="black"/>
    <circle cx="667" cy="660" r="214" fill="black"/>
    <circle cx="667" cy="660" r="190" fill="white"/>
    {YEN.format(color="black")}
  </mask></defs>
  <rect width="1024" height="1024" fill="white" mask="url(#m)"/>
"""


def svg(body, view_box="0 0 1024 1024"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}">{body}</svg>\n'


def render(svg_path, png_path, size):
    png_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(png_path), str(svg_path)],
        check=True,
    )


def ios():
    icon = ROOT / "ios/Runner/AppIcon.icon"
    if icon.exists():
        shutil.rmtree(icon)
    (icon / "Assets").mkdir(parents=True)
    (icon / "Assets/1_calendar.svg").write_text(svg(CALENDAR))
    (icon / "Assets/2_coin.svg").write_text(svg(COIN))
    spec = {
        "fill": {"linear-gradient": [f"srgb:{rgb(CORAL_LIGHT)},1.00000", f"srgb:{rgb(CORAL)},1.00000"]},
        "groups": [
            {"layers": [{"image-name": "2_coin.svg", "name": "2_coin", "glass": True}],
             "shadow": {"kind": "neutral", "opacity": 0.5}},
            {"layers": [{"image-name": "1_calendar.svg", "name": "1_calendar", "glass": True}],
             "shadow": {"kind": "neutral", "opacity": 0.5}},
        ],
        "supported-platforms": {"squares": "shared"},
    }
    (icon / "icon.json").write_text(json.dumps(spec, indent=2) + "\n")


def rgb(hex_color):
    return ",".join(f"{int(hex_color[i:i + 2], 16) / 255:.5f}" for i in (1, 3, 5))


# Android adaptive icons: 108dp canvas, artwork kept inside the 66dp safe zone.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def android(work):
    res = ROOT / "android/app/src/main/res"
    # The safe zone is a 66dp circle. The farthest artwork point (the calendar
    # corner) is about 457 units from the centre, so 457 maps to 33dp.
    side = 457 * 108 / 33
    origin = 512 - side / 2
    adaptive_box = f"{origin:.1f} {origin:.1f} {side:.1f} {side:.1f}"
    layers = {
        "ic_launcher_foreground": svg(CALENDAR + COIN, adaptive_box),
        "ic_launcher_background": svg(BACKGROUND, adaptive_box),
        "ic_launcher_monochrome": svg(MONO, adaptive_box),
    }
    for name, content in layers.items():
        path = work / f"{name}.svg"
        path.write_text(content)
        for density, scale in DENSITIES.items():
            render(path, res / f"mipmap-{density}/{name}.png", round(108 * scale))

    # Launchers before API 26 use a plain bitmap.
    legacy = work / "legacy.svg"
    legacy.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<defs><clipPath id="c"><rect width="1024" height="1024" rx="200"/></clipPath></defs>'
        f'<g clip-path="url(#c)">{BACKGROUND}'
        f'<g transform="translate(512,512) scale(0.86) translate(-512,-512)">{CALENDAR}{COIN}</g>'
        "</g></svg>\n"
    )
    for density, scale in DENSITIES.items():
        render(legacy, res / f"mipmap-{density}/ic_launcher.png", round(48 * scale))

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        "</adaptive-icon>\n"
    )


def main():
    work = ROOT / "build/icon"
    work.mkdir(parents=True, exist_ok=True)
    ios()
    android(work)


if __name__ == "__main__":
    main()
