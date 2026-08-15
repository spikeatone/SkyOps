#!/usr/bin/env python3
"""
TRACE A FIN MASK FROM THE ARTWORK — the fin's real outline, not a polygon approximation.

WHY: a hand-traced polygon has straight edges, but a real fin has a CURVED leading edge
and a ROUNDED tip. Approximating those with 4-6 corners leaves slivers of unpainted fin
along the curve (visible as a white edge above/ahead of the paint) and reads as the wrong
fin shape. The illustration already contains the exact outline, so trace it.

THE SHAPE, per column x:
  top    = the illustration's own top opaque pixel  → the true curved leading edge + tip
  bottom = the fuselage CROWN line, fitted from the columns AHEAD of the tail and
           extrapolated aft (same method as extend_fin_base.py — below the fin the
           airframe is continuous, so there's no gap to detect)
Everything between is fin, so the mask is the artwork's own silhouette. Curves come out
exact and stay exact if the art changes.

TWO CUTS make it a FIN and not a whole tail:
  • X RANGE  [x0, x1] — x0 is the DORSAL FIN's front (the fillet blending into the spine),
    x1 the fin's trailing edge (excluding a T-tail stabilizer that continues aft, and on
    the B1900 its separate endplate).
    ⚠️ x0 MATTERS MORE THAN IT LOOKS: past the dorsal there is no fin left to trace, just
    fuselage, and this function will happily paint the spine — that's how a teal band once
    ran forward to mid-cabin. Find it by SLOPE, not by eye and not by height: the rear body
    tapers up at a slow steady rate and the dorsal is several times steeper, so the jump is
    the boundary. `--report` prints the per-column top edge; the measured values for the
    four turboprops are recorded in make_fin_masks.py. (An auto-detector was tried and
    removed: a height-above-crown test follows the spine on a long shallow fillet, and a
    slope test needs per-type thresholds anyway because these dorsals climb in stages.)
  • STAB FLOOR (`stab_top`) — on a T-tail the stabilizer sits ON the fin top, so within
    the fin's own x-range the top opaque pixel IS the stab, not the fin. Passing
    `stab_top` clamps the traced top DOWN to that line, so the cross-arm stays unpainted
    while the fin below it is still traced from the real outline.

THE BOTTOM EDGE — where the dorsal meets the fuselage — is the fiddly one, and a FLAT
`--base` is wrong: the fuselage crown SLOPES down going aft, so a horizontal cut dips onto
the body at the front and floats above it at the back. Use `--base y0 --base-aft y1` to
give the junction a SLOPE (y0 at x0, y1 at x1, linear between). The auto crown-fit is no
help here — it's fitted from the forward fuselage and comes out nearly flat, missing the
tailcone's rise entirely. Read the two ends off `fin_probe.py` and tune them by eye; this
is the one part of the shape the artwork can't hand you, because fin and body are a single
continuous silhouette with no edge between them.

USAGE
  python3 aa-livery/trace_fin.py --report DH8B                    # print the outline
  python3 aa-livery/trace_fin.py DH8B --x0 0.742 --x1 0.905 --stab-top 0.125
"""
import argparse, os
from PIL import Image

REPO  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES   = os.path.join(REPO, "AirlineArchitect/AirlineArchitect/Resources")
ART   = os.path.join(RES, "Illustrations")
MASKS = os.path.join(RES, "FinMasks")


def crown_fit(px, w, h, x_end, x_start=0.35):
    """Least-squares fit of the fuselage crown from the body ahead of the tail."""
    op = lambda x, y: px[x, y][3] > 40
    sx, sy = [], []
    for x in range(int(w * x_start), x_end):
        top = next((y for y in range(h) if op(x, y)), None)
        if top is not None:
            sx.append(x); sy.append(top)
    n = len(sx)
    if n < 8:
        return None
    mx = sum(sx) / n; my = sum(sy) / n
    den = sum((v - mx) ** 2 for v in sx)
    slope = sum((sx[i] - mx) * (sy[i] - my) for i in range(n)) / den if den else 0.0
    return lambda x: my + slope * (x - mx)


def trace(tid, x0, x1, stab_top=None, base=None, base_aft=None, x1_base=None, dry=False):
    ip = os.path.join(ART, f"{tid}.png")
    illo = Image.open(ip).convert("RGBA")
    w, h = illo.size
    px = illo.load()
    op = lambda x, y: px[x, y][3] > 40

    cx0, cx1 = int(w * x0), int(w * x1)
    crown = crown_fit(px, w, h, cx0)
    if crown is None and base is None:
        return "could not fit crown — pass --base"

    # highest traced point of the fin (its tip), for the rake interpolation
    tops_all = []
    for x in range(cx0, int(w * (x1_base if x1_base is not None else x1)) + 1):
        col = [y for y in range(h) if op(x, y)]
        if col:
            t = min(col)
            if stab_top is not None and t < h * stab_top:
                t = h * stab_top
            tops_all.append(t)
    tip_y = (min(tops_all) / h) if tops_all else 0.0

    mask = Image.new("L", (w, h), 0)
    m = mask.load()
    stab_y = None if stab_top is None else h * stab_top
    painted = 0
    xmax = max(cx1, int(w * x1_base)) if x1_base is not None else cx1
    for x in range(cx0, xmax + 1):
        col = [y for y in range(h) if op(x, y)]
        if not col:
            continue
        top = min(col)
        if stab_y is not None and top < stab_y:
            top = int(round(stab_y))         # clamp under a T-tail stabilizer
        if base is not None:
            if base_aft is not None and cx1 > cx0:
                f = (x - cx0) / (cx1 - cx0)          # 0 at the dorsal front, 1 at the TE
                bot = int(round(h * (base + (base_aft - base) * f)))
            else:
                bot = int(round(h * base))
        else:
            bot = int(round(crown(x)))
        if x1_base is not None and x > cx1:
            # RAKED TRAILING EDGE. A fin's TE slopes aft going down, so a single vertical
            # x1 lops off the lower-aft corner (a white wedge along the TE). Aft of the tip
            # cut the fin is simply the TOP CONTIGUOUS RUN below the stab clamp, and that
            # run's own bottom IS the raked edge — measured, not interpolated. Stop at
            # x1_base so we never wander onto the tailcone.
            if x > int(w * x1_base):
                continue
            s_ = set(col)
            y = top
            while y + 1 in s_:
                y += 1
            for yy in range(top, min(y, bot) + 1):
                if op(x, yy):
                    m[x, yy] = 255
                    painted += 1
            continue

        # only paint contiguous airframe between top and bot
        y = top
        while y <= bot and y < h:
            if op(x, y):
                m[x, y] = 255
                painted += 1
            y += 1

    if dry:
        return f"x[{x0:.3f},{x1:.3f}] → {painted} px (dry-run)"
    out = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    out.putalpha(mask)
    out.save(os.path.join(MASKS, f"{tid}_fin.png"))
    return f"x[{x0:.3f},{x1:.3f}] → {painted} px"


def report(tid, lo=0.60, hi=1.0):
    illo = Image.open(os.path.join(ART, f"{tid}.png")).convert("RGBA")
    w, h = illo.size
    px = illo.load()
    op = lambda x, y: px[x, y][3] > 40
    print(f"{tid}  {w}x{h}   per-column top of opaque (the fin outline):")
    x = int(w * lo)
    while x <= int(w * hi) - 1:
        col = [y for y in range(h) if op(x, y)]
        if col:
            print(f"   x={x/w:.3f}  top={min(col)/h:.3f}")
        x += max(1, int(w * 0.005))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("types", nargs="+")
    ap.add_argument("--x0", type=float); ap.add_argument("--x1", type=float)
    ap.add_argument("--stab-top", type=float, default=None)
    ap.add_argument("--base", type=float, default=None)
    ap.add_argument("--base-aft", type=float, default=None)
    ap.add_argument("--x1-base", type=float, default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    for t in a.types:
        if a.report:
            report(t)
        else:
            print(f"{t:9} {trace(t, a.x0, a.x1, a.stab_top, a.base, a.base_aft, a.x1_base, a.dry_run)}")


if __name__ == "__main__":
    main()
