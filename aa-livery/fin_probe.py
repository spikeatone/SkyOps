#!/usr/bin/env python3
"""
FIN TRACING PROBE — zoom into an aircraft's tail with a fractional coordinate grid so
fin-outline corners can be read off directly for FIN_POLYGONS in make_fin_masks.py.

Renders, per type, a magnified crop of the tail region:
  • left  : the illustration alone + grid (trace the fin corners off this)
  • right : the CURRENT mask tinted red over the illustration (see what's wrong)

Grid labels are FRACTIONS OF THE FULL IMAGE (what FIN_POLYGONS expects), not crop pixels.

USAGE
  python3 aa-livery/fin_probe.py CRJ900 ERJ145
  python3 aa-livery/fin_probe.py --x0 0.72 --zoom 7 CRJ900     # tighter/bigger
"""
import argparse, os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES  = os.path.join(REPO, "AirlineArchitect/AirlineArchitect/Resources")
ART  = os.path.join(RES, "Illustrations")
MASK = os.path.join(RES, "FinMasks")
FONT = os.path.join(RES, "Fonts/Karla-Bold.ttf")


def panel(im, x0, x1, zoom, title, step, font, small):
    """Crop [x0,x1] of the image, scale by zoom, overlay a fractional grid."""
    W, H = im.size
    cx0, cx1 = int(W * x0), int(W * x1)
    crop = im.crop((cx0, 0, cx1, H))
    cw, ch = crop.size
    scaled = crop.resize((cw * zoom, ch * zoom), Image.NEAREST)

    pad_l, pad_t = 46, 26
    out = Image.new("RGB", (scaled.width + pad_l + 10, scaled.height + pad_t + 26), (255, 255, 255))
    # checkerboard so transparent areas are obvious
    d = ImageDraw.Draw(out)
    for yy in range(pad_t, pad_t + scaled.height, 12):
        for xx in range(pad_l, pad_l + scaled.width, 12):
            if ((xx - pad_l) // 12 + (yy - pad_t) // 12) % 2:
                d.rectangle([xx, yy, xx + 11, yy + 11], fill=(238, 238, 240))
    out.paste(scaled, (pad_l, pad_t), scaled if scaled.mode == "RGBA" else None)

    d.text((pad_l, 6), title, font=font, fill=(20, 24, 32))

    # vertical grid lines at fractional x
    fx = x0
    while fx <= x1 + 1e-9:
        px = pad_l + int((fx - x0) * W * zoom)
        if px <= pad_l + scaled.width:
            d.line([(px, pad_t), (px, pad_t + scaled.height)], fill=(255, 0, 0, 90), width=1)
            d.text((px - 14, pad_t + scaled.height + 6), f"{fx:.02f}", font=small, fill=(200, 0, 0))
        fx = round(fx + step, 4)

    # horizontal grid lines at fractional y
    fy = 0.0
    while fy <= 1.0 + 1e-9:
        py = pad_t + int(fy * H * zoom)
        if py <= pad_t + scaled.height:
            d.line([(pad_l, py), (pad_l + scaled.width, py)], fill=(0, 90, 255, 90), width=1)
            d.text((4, py - 6), f"{fy:.02f}", font=small, fill=(0, 60, 200))
        fy = round(fy + 0.10, 4)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("types", nargs="+")
    ap.add_argument("--x0", type=float, default=0.62)
    ap.add_argument("--x1", type=float, default=1.0)
    ap.add_argument("--zoom", type=int, default=6)
    ap.add_argument("--step", type=float, default=0.02)
    ap.add_argument("--out", default="/tmp/fin_probe")
    a = ap.parse_args()

    try:
        font = ImageFont.truetype(FONT, 15); small = ImageFont.truetype(FONT, 10)
    except OSError:
        font = small = ImageFont.load_default()

    for t in a.types:
        im = Image.open(os.path.join(ART, f"{t}.png")).convert("RGBA")
        left = panel(im, a.x0, a.x1, a.zoom, f"{t} — illustration (trace fin corners)", a.step, font, small)

        # current mask tinted red over the art
        over = im.copy()
        mp = os.path.join(MASK, f"{t}_fin.png")
        if os.path.exists(mp):
            m = Image.open(mp).convert("RGBA").resize(im.size, Image.NEAREST).split()[3]
            red = Image.new("RGBA", im.size, (255, 0, 0, 130))
            over.alpha_composite(Image.composite(red, Image.new("RGBA", im.size, (0, 0, 0, 0)), m))
        right = panel(over, a.x0, a.x1, a.zoom, f"{t} — CURRENT mask (red)", a.step, font, small)

        sheet = Image.new("RGB", (max(left.width, right.width), left.height + right.height + 8), (255, 255, 255))
        sheet.paste(left, (0, 0)); sheet.paste(right, (0, left.height + 8))
        p = f"{a.out}_{t}.png"
        sheet.save(p)
        print(f"  → {p}")


if __name__ == "__main__":
    main()
