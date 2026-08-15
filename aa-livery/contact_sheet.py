#!/usr/bin/env python3
"""
FULL-FLEET LIVERY CONTACT SHEET — every aircraft type with the painted livery, in
one image, so the designer can see where the whole fleet stands at a glance.

WHY A PYTHON COMPOSITOR AND NOT THE SIM: the app renders one type per launch, so a
35-type sheet would be 35 clean-build/launch/screenshot cycles. This mirrors the
SwiftUI render (AircraftLivery.swift `AircraftLiveryImage`) faithfully instead:

  PAINTED TAIL   fill the fin with the palette's SECONDARY colour, draw the emblem
                 WHITE and oversized on top, then clip BOTH to the fin silhouette
                 (Resources/FinMasks/<TYPE>_fin.png, alpha = fin shape). An emblem
                 bigger than the fin clips at the edge — that's the design, not a bug.
  TITLE          the airline name in the palette's PRIMARY colour on the window line,
                 composited with MULTIPLY so the illustration's own windows punch
                 through the letters (the United look).

It reads the REAL values out of the Swift source — the per-type
tailCX/tailCY/tailScale + titleCX/titleCY/titleW/titleScale table in
AircraftLivery.swift, the palettes and TailArt.nudge() from Livery.swift — so the
sheet can't drift from the app. Change the app, re-run this, it follows.

KNOWN FIDELITY GAP (the only one): SwiftUI's `.minimumScaleFactor(0.4)` shrinks a
title that overruns its `titleW` box; here we do the same by measuring and scaling
down, but font rasterisation/hinting differs slightly between CoreText and Pillow,
so title glyph widths are close, not pixel-identical. Tail geometry IS exact.

USAGE
  python3 aa-livery/contact_sheet.py                       # all 35, defaults
  python3 aa-livery/contact_sheet.py --emblem 4 --palette 2 --name "PACIFIC AIR"
  python3 aa-livery/contact_sheet.py --parts 2 --out /tmp/fleet
  python3 aa-livery/contact_sheet.py --types DH8B AT46     # just a few
"""
import argparse, os, re, sys
from PIL import Image, ImageDraw, ImageFont

REPO   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP    = os.path.join(REPO, "AirlineArchitect/AirlineArchitect")
ART    = os.path.join(APP, "Resources/Illustrations")
MASKS  = os.path.join(APP, "Resources/FinMasks")
TAILART= os.path.join(APP, "Resources/TailArt")
FONTS  = os.path.join(APP, "Resources/Fonts")
SWIFT_LIVERY = os.path.join(APP, "AircraftLivery.swift")
SWIFT_MODEL  = os.path.join(APP, "Livery.swift")

# Font catalog mirrors LiveryFont.all (psName -> file, sizeAdjust).
FONT_FILES = [
    ("ArchivoBlack-Regular.ttf",  0.92),
    ("BebasNeue-Regular.ttf",     1.32),
    ("Poppins-SemiBold.ttf",      1.00),
    ("Righteous-Regular.ttf",     1.02),
    ("DMSerifDisplay-Regular.ttf",1.06),
]


# ---------------------------------------------------------------- parse Swift

def parse_placements():
    """Per-type LiveryPlacement out of AircraftLivery.swift (the real values)."""
    src = open(SWIFT_LIVERY).read()
    pat = re.compile(
        r'case\s+"(\w+)":\s*return\s*\.init\('
        r'titleCX:\s*([\d.]+),\s*titleCY:\s*([\d.]+),\s*titleW:\s*([\d.]+),\s*titleScale:\s*([\d.]+),\s*'
        r'tailCX:\s*([\d.]+),\s*tailCY:\s*([\d.]+),\s*tailScale:\s*([\d.]+)\)')
    out = {}
    for m in pat.finditer(src):
        t = m.group(1)
        out[t] = dict(titleCX=float(m.group(2)), titleCY=float(m.group(3)),
                      titleW=float(m.group(4)),  titleScale=float(m.group(5)),
                      tailCX=float(m.group(6)),  tailCY=float(m.group(7)),
                      tailScale=float(m.group(8)))
    if not out:
        sys.exit("could not parse placements from AircraftLivery.swift")
    return out


def parse_palettes():
    """LiveryPalette.all — (name, primaryRGB, secondaryRGB)."""
    src = open(SWIFT_MODEL).read()
    pat = re.compile(r'\.init\(id:\s*\d+,\s*name:\s*"([^"]+)",\s*primary:\s*Color\(hex:\s*0x([0-9A-Fa-f]{6})\),'
                     r'\s*secondary:\s*Color\(hex:\s*0x([0-9A-Fa-f]{6})\)\)')
    hx = lambda h: tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
    pals = [(m.group(1), hx(m.group(2)), hx(m.group(3))) for m in pat.finditer(src)]
    if not pals:
        sys.exit("could not parse palettes from Livery.swift")
    return pals


def parse_nudges():
    """TailArt.nudge() — 1-based emblem -> (dx, dy) fraction of the emblem box."""
    src = open(SWIFT_MODEL).read()
    body = src.split("static func nudge")[1].split("}")[0] if "static func nudge" in src else ""
    out = {}
    for m in re.finditer(r'case\s+(\d+):\s*return\s*\(([-\d.]+),\s*([-\d.]+)\)', body):
        out[int(m.group(1))] = (float(m.group(2)), float(m.group(3)))
    return out


# ---------------------------------------------------------------- the render

def paint(type_id, name, place, pal, emblem_idx, nudges, font_idx, height):
    """One aircraft, painted. Mirrors AircraftLiveryImage. Returns RGBA."""
    illo = Image.open(os.path.join(ART, f"{type_id}.png")).convert("RGBA")
    W = max(1, round(height * illo.width / illo.height))
    H = height
    base = illo.resize((W, H), Image.LANCZOS)
    p = place
    _, primary, secondary = pal

    # ---- PAINTED TAIL: secondary fill + white emblem, clipped to the fin shape.
    mask_path = os.path.join(MASKS, f"{type_id}_fin.png")
    if os.path.exists(mask_path):
        fin = Image.open(mask_path).convert("RGBA").resize((W, H), Image.LANCZOS)
        fin_alpha = fin.split()[3]          # alpha IS the fin silhouette (RGBA, not L!)

        tail = Image.new("RGBA", (W, H), secondary + (255,))

        if emblem_idx > 0:
            em = Image.open(os.path.join(TAILART, f"tailart{emblem_idx}.png")).convert("RGBA")
            size = max(1, round(H * p["tailScale"]))
            em = em.resize((size, size), Image.LANCZOS)
            # template rendering: keep alpha, force RGB white
            white = Image.new("RGBA", em.size, (255, 255, 255, 0))
            white.putalpha(em.split()[3])
            dx, dy = nudges.get(emblem_idx, (0.0, 0.0))
            cx = W * p["tailCX"] + size * dx
            cy = H * p["tailCY"] + size * dy
            tail.alpha_composite(white, (round(cx - size / 2), round(cy - size / 2)))

        tail.putalpha(fin_alpha)            # clip everything to the fin
        base.alpha_composite(tail)

    # ---- TITLE: primary colour on the window line, MULTIPLY blend.
    fname, adj = FONT_FILES[font_idx]
    size = max(6, round(H * p["titleScale"] * adj))
    font = ImageFont.truetype(os.path.join(FONTS, fname), size)
    text = name.upper()
    box_w = W * p["titleW"]
    # kerning: SwiftUI .kerning(H * titleScale * 0.02) — per-gap letter spacing
    kern = H * p["titleScale"] * 0.02

    def measure(f):
        w = sum(f.getlength(ch) for ch in text) + kern * max(0, len(text) - 1)
        return w

    # SwiftUI .minimumScaleFactor(0.4): shrink to fit the box, down to 40%.
    if measure(font) > box_w:
        lo = max(6, round(size * 0.4))
        for s in range(size, lo - 1, -1):
            f2 = ImageFont.truetype(os.path.join(FONTS, fname), s)
            if measure(f2) <= box_w:
                font, size = f2, s
                break
        else:
            font = ImageFont.truetype(os.path.join(FONTS, fname), lo)

    tw = measure(font)
    asc, desc = font.getmetrics()
    x = W * p["titleCX"] - tw / 2
    y = H * p["titleCY"] - (asc + desc) / 2

    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = x
    for ch in text:                          # draw per-glyph to apply kerning
        d.text((cx, y), ch, font=font, fill=primary + (255,))
        cx += font.getlength(ch) + kern

    # MULTIPLY only where the text is (so windows/shading show through letters).
    out = base.copy()
    lm = layer.split()[3]
    mult = Image.new("RGBA", (W, H))
    from PIL import ImageChops
    mult = ImageChops.multiply(base.convert("RGB"), layer.convert("RGB"))
    out.paste(mult, (0, 0), lm)
    return out


# ---------------------------------------------------------------- the sheet

def build(types, name, pal, emblem, font_idx, sheet_w, row_h, out_path, title):
    place_tbl = parse_placements()
    nudges = parse_nudges()
    pad, label_w, gap = 18, 92, 10

    try:
        lab_font = ImageFont.truetype(os.path.join(FONTS, "Karla-Bold.ttf"), 17)
        hdr_font = ImageFont.truetype(os.path.join(FONTS, "Karla-ExtraBold.ttf"), 24)
        sub_font = ImageFont.truetype(os.path.join(FONTS, "Karla-Regular.ttf"), 15)
    except OSError:
        lab_font = hdr_font = sub_font = ImageFont.load_default()

    avail = sheet_w - pad * 2 - label_w - gap
    rows = []
    for t in types:
        p = place_tbl.get(t)
        if not p:
            print(f"  ! no placement for {t}, skipping"); continue
        img = paint(t, name, p, pal, emblem, nudges, font_idx, row_h)
        if img.width > avail:                       # keep the widest in frame
            s = avail / img.width
            img = img.resize((avail, max(1, round(img.height * s))), Image.LANCZOS)
        rows.append((t, img))

    head = 74
    H = head + pad + sum(max(row_h, im.height) + gap for _, im in rows) + pad
    sheet = Image.new("RGB", (sheet_w, H), (250, 250, 251))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 20), title, font=hdr_font, fill=(28, 32, 40))
    d.text((pad, 50), f'"{name}"  ·  {pal[0]} palette  ·  emblem {emblem}  ·  '
                      f'{FONT_FILES[font_idx][0].split("-")[0]}  ·  {len(rows)} types',
           font=sub_font, fill=(110, 116, 128))

    y = head + pad
    for i, (t, im) in enumerate(rows):
        rh = max(row_h, im.height)
        if i % 2 == 0:
            d.rectangle([pad - 6, y - 6, sheet_w - pad + 6, y + rh + 4], fill=(243, 244, 247))
        d.text((pad, y + rh / 2 - 9), t, font=lab_font, fill=(60, 66, 78))
        sheet.paste(im, (pad + label_w + gap, y + round((rh - im.height) / 2)), im)
        y += rh + gap

    sheet.save(out_path)
    print(f"  → {out_path}  ({sheet.width}×{sheet.height}, {len(rows)} types)")
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", default="AIR TINA")
    ap.add_argument("--palette", type=int, default=0)     # 0 = Atlantic
    ap.add_argument("--emblem", type=int, default=1)      # 1 = wing
    ap.add_argument("--font", type=int, default=0)        # 0 = Archivo
    ap.add_argument("--width", type=int, default=1180)
    ap.add_argument("--rowheight", type=int, default=118)
    ap.add_argument("--parts", type=int, default=2)
    ap.add_argument("--out", default="/tmp/fleet_livery")
    ap.add_argument("--types", nargs="*", default=None)
    a = ap.parse_args()

    types = a.types or sorted(os.path.splitext(f)[0]
                              for f in os.listdir(ART) if f.endswith(".png"))
    pal = parse_palettes()[a.palette]
    print(f"Full-fleet contact sheet: {len(types)} types, {pal[0]} palette, emblem {a.emblem}")

    if a.parts <= 1:
        build(types, a.name, pal, a.emblem, a.font, a.width, a.rowheight,
              f"{a.out}.png", "FLEET LIVERY — ALL TYPES")
        return
    n = (len(types) + a.parts - 1) // a.parts
    for i in range(a.parts):
        chunk = types[i * n:(i + 1) * n]
        if not chunk: continue
        build(chunk, a.name, pal, a.emblem, a.font, a.width, a.rowheight,
              f"{a.out}_{chr(65+i)}.png",
              f"FLEET LIVERY — PART {chr(65+i)} ({i*n+1}–{i*n+len(chunk)} of {len(types)})")


if __name__ == "__main__":
    main()
