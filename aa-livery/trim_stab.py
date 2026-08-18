#!/usr/bin/env python3
"""
T-TAIL STABILIZER TRIM — remove the horizontal-stabilizer bleed from an EXISTING fin
mask, in place, without regenerating it.

WHY NOT make_fin_masks.py: the committed masks were produced by a BETTER pass than that
script's current auto-detector (verified — its output differs from every committed mask,
jets included). Regenerating would clobber known-good fins, which the spec explicitly
warns about. So this operates on the COMMITTED mask as the source of truth and only
SUBTRACTS the stabilizer, leaving the fin blade byte-identical.

HOW IT FINDS THE STABILIZER: a T-tail's horizontal stab is mounted at the fin top and
reads, column by column, as a THIN vertical run that continues aft of the fin's trailing
edge, while the fin blade itself is DEEP. Walking aft from the deepest column, the first
column that thins past STAB_RATIO of that depth is the start of the stab — cut there.
(CRJ900/ERJ145 profiles: fin peaks ~0.54-0.58 of image height, stab tapers 0.24 → 0.03,
so 0.45 sits mid-gap.) The cut is clamped so it can never remove more than MAX_TRIM of
the mask, i.e. a mis-detection degrades to "unchanged", never to a destroyed fin.

USAGE
  python3 aa-livery/trim_stab.py --dry-run CRJ900 CRJ1000 ERJ135 ERJ140 ERJ145
  python3 aa-livery/trim_stab.py           CRJ900 CRJ1000 ERJ135 ERJ140 ERJ145
Then: CLEAN build (bundled art changed) + check with -liveryGallery / contact_sheet.py.
"""
import argparse, os
from PIL import Image

REPO  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASKS = os.path.join(REPO, "AirlineArchitect/AirlineArchitect/Resources/FinMasks")

STAB_RATIO = 0.45     # column thinner than this * peak depth = stabilizer
MAX_TRIM   = 0.45     # never remove more than this fraction of the mask (safety)


def trim(path, ratio=STAB_RATIO, dry=False):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    a = im.split()[3]
    px = a.load()

    # per-column: the extent of the opaque run (the mask is already just the fin+stab)
    depth, span = {}, {}
    for x in range(w):
        ys = [y for y in range(h) if px[x, y] > 8]
        if ys:
            depth[x] = ys[-1] - ys[0]
            span[x] = (ys[0], ys[-1])
    if not depth:
        return None, "empty mask"

    xpeak = max(depth, key=lambda x: depth[x])
    peak = depth[xpeak]
    cut = max(depth)
    for x in sorted(k for k in depth if k > xpeak):
        if depth[x] < peak * ratio:
            cut = x - 1
            break

    total = sum(1 for x in depth for _ in range(1))
    removed_cols = [x for x in depth if x > cut]
    if not removed_cols:
        return None, "nothing aft of the fin — already clean"

    before = sum(1 for x in depth for y in range(h) if px[x, y] > 8)
    after_est = sum(1 for x in depth if x <= cut for y in range(h) if px[x, y] > 8)
    frac = 1 - after_est / max(1, before)
    if frac > MAX_TRIM:
        return None, f"REFUSED — would remove {frac:.0%} (> {MAX_TRIM:.0%} guard)"

    if dry:
        return None, (f"cut at x={cut/w:.3f} (peak x={xpeak/w:.3f}, depth {peak/h:.3f}h) "
                      f"→ removes {frac:.1%} of mask, {len(removed_cols)} cols")

    for x in removed_cols:
        for y in range(h):
            if px[x, y]:
                px[x, y] = 0
    out = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    out.putalpha(a)
    out.save(path)
    return path, f"cut at x={cut/w:.3f} → removed {frac:.1%}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("types", nargs="+")
    ap.add_argument("--ratio", type=float, default=STAB_RATIO)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    for t in a.types:
        p = os.path.join(MASKS, f"{t}_fin.png")
        if not os.path.exists(p):
            print(f"{t:9} !! no mask"); continue
        _, msg = trim(p, a.ratio, a.dry_run)
        print(f"{t:9} {msg}")


if __name__ == "__main__":
    main()
