#!/usr/bin/env python3
"""
EXTEND A FIN MASK DOWN TO THE FUSELAGE — so the paint runs all the way down the tail,
following the CURVE where the fin fairing blends into the body, instead of stopping at a
straight cut partway down (designer request for the RJs).

WHY THIS AND NOT A HAND POLYGON: the fairing is a curve, and the airframe silhouette
already encodes it exactly. So for each column of the existing mask we simply keep walking
DOWN the illustration's opaque pixels until we reach the fuselage underside, then stop at
the local "crown" — the top of the body. That traces the real curve per-column at pixel
resolution, which no 4-6 point polygon can match, and it stays correct if the art changes.

HOW THE STOP IS FOUND — the FUSELAGE CROWN LINE:
  Below the fin the airframe is CONTINUOUS (fairing and body are one silhouette), so
  there is no gap to detect. Instead we measure the body's TOP EDGE (crown) from the
  columns just AHEAD of the tail, fit a straight line to it (the rear fuselage tapers up
  toward the tailcone, so a line tracks it far better than a constant), and extrapolate
  that line aft under the fin. Each column then paints down to the crown.
  The result follows the real fairing curve, because the mask's own per-column top edge
  is the fin outline and the crown is the body — the paint fills exactly between them.
  `crown_lift` nudges the stop line up/down a touch; `max_drop` clamps it.

Only ADDS pixels (never removes), so a fin blade that is already correct stays correct.

USAGE
  python3 aa-livery/extend_fin_base.py --dry-run CRJ900 CRJ1000 ERJ135 ERJ140 ERJ145
  python3 aa-livery/extend_fin_base.py           CRJ900 ...
Then: CLEAN build + check with contact_sheet.py / -liveryGallery.
"""
import argparse, os
from PIL import Image

REPO  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES   = os.path.join(REPO, "AirlineArchitect/AirlineArchitect/Resources")
ART   = os.path.join(RES, "Illustrations")
MASKS = os.path.join(RES, "FinMasks")


def extend(tid, crown_lift=0.0, max_drop=0.30, dry=False):
    ip = os.path.join(ART, f"{tid}.png")
    mp = os.path.join(MASKS, f"{tid}_fin.png")
    illo = Image.open(ip).convert("RGBA")
    mask = Image.open(mp).convert("RGBA")
    w, h = illo.size
    if mask.size != (w, h):
        mask = mask.resize((w, h), Image.NEAREST)
    ip_px = illo.load()
    a = mask.split()[3]
    mpx = a.load()

    opaque = lambda x, y: ip_px[x, y][3] > 40
    cap = int(h * max_drop)

    cols = [x for x in range(w) if any(mpx[x, y] > 8 for y in range(h))]
    if not cols:
        return "no mask"
    x_fin = min(cols)

    # Fit the fuselage crown from the body AHEAD of the fin, then extrapolate aft.
    sx, sy, n = [], [], 0
    for x in range(int(w * 0.35), x_fin):
        top = next((y for y in range(h) if opaque(x, y)), None)
        if top is not None:
            sx.append(x); sy.append(top); n += 1
    if n < 8:
        return "not enough crown samples"
    mx = sum(sx) / n; my = sum(sy) / n
    den = sum((v - mx) ** 2 for v in sx)
    slope = sum((sx[i] - mx) * (sy[i] - my) for i in range(n)) / den if den else 0.0
    crown = lambda x: my + slope * (x - mx) - h * crown_lift

    added = 0
    for x in cols:
        ys = [y for y in range(h) if mpx[x, y] > 8]
        bot = max(ys)
        stop = int(round(crown(x)))
        stop = min(stop, bot + cap)
        y = bot
        while y + 1 <= stop and y + 1 < h and opaque(x, y + 1):
            y += 1
        for yy in range(bot + 1, y + 1):
            if not mpx[x, yy]:
                mpx[x, yy] = 255
                added += 1

    total = sum(1 for x in range(w) for y in range(h) if mpx[x, y] > 8)
    msg = f"+{added} px ({added/max(1,total-added):.0%} bigger), crown slope {slope:+.4f}"
    if not dry:
        out = Image.new("RGBA", (w, h), (255, 255, 255, 0))
        out.putalpha(a)
        out.save(mp)
    return msg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("types", nargs="+")
    ap.add_argument("--crown-lift", type=float, default=0.0)
    ap.add_argument("--max-drop", type=float, default=0.30)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    for t in a.types:
        if not os.path.exists(os.path.join(MASKS, f"{t}_fin.png")):
            print(f"{t:9} !! no mask"); continue
        print(f"{t:9} {extend(t, a.crown_lift, a.max_drop, a.dry_run)}")


if __name__ == "__main__":
    main()
