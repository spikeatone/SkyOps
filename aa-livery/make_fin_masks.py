#!/usr/bin/env python3
"""
Generate the per-aircraft FIN MASKS (Resources/FinMasks/<TYPE>_fin.png, RGBA, alpha =
fin shape) used by the painted-tail livery.

TWO SOURCES per type:
  1. HAND POLYGON (FIN_POLYGONS below) — for the EXCEPTION aircraft whose fin geometry
     the auto-detector gets wrong (turboprops with high wings / T-tails / stubby fins).
     A list of (x,y) fractional points (0..1 of the image) tracing the fin outline:
     tip → down the trailing edge → across the base → up the leading edge. Filled solid.
  2. AUTO-DETECT — everything else (the jets, which the detector handles well): the
     rear-most tall opaque run above the mid-fuselage crown, top contiguous blade.

WHY: on high-wing turboprops (Dash-8/ATR/Do-328/B1900) the fuselage is low, so cutting
the fin at the mid-body crown chops the fin and leaves a flat/ jagged edge. Those get a
hand polygon. The jets don't need it.

TO ADD/FIX an exception: open the illustration, read off the fin-outline corners as
fractions (there's a corner-probe snippet in this session's git history), add a
FIN_POLYGONS[<TYPE>] entry, run this script, CLEAN build, check in -liveryGallery.

⚠️ THIS SCRIPT'S AUTO PATH NO LONGER REPRODUCES THE COMMITTED MASKS — VERIFIED
   (2026-08-15). Regenerating was diffed against every committed mask: ALL 35 differ,
   the jets included (e.g. A320 ~8.8k px). The committed masks came from a BETTER pass
   than `auto_mask` below. So running this over an existing type DOWNGRADES it — which
   is exactly the "an improved auto pass broke the jets once" regression LIVERY_SPEC.md
   warns about. Treat auto_mask as legacy.
   • To FIX an existing mask, prefer `aa-livery/trim_stab.py`, which EDITS the committed
     mask (subtract-only) instead of regenerating it — that's how the CRJ/ERJ T-tail
     stabilizer bleed was fixed without touching the fin blades.
   • Only use THIS script for a type that has NO good mask yet, or with a FIN_POLYGONS
     entry (the hand-traced path, which ignores auto_mask entirely).
   • Always pass explicit type names so it can't touch anything else, and diff the
     result against the previous mask before committing.

USAGE:  python3 aa-livery/make_fin_masks.py [TYPE ...]   # all, or just the named types
"""
import glob, os, sys
from PIL import Image, ImageDraw

REPO=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR=os.path.join(REPO,"AirlineArchitect/AirlineArchitect/Resources/Illustrations")
OUT=os.path.join(REPO,"AirlineArchitect/AirlineArchitect/Resources/FinMasks")

# Hand-traced fin outlines (fractional x,y), traced 2026-08-15 off aa-livery/fin_probe.py
# (which draws the tail zoomed with a fractional grid). Order: fin TIP → aft along the
# tip → DOWN the trailing edge → across the base → UP the leading edge.
#
# These are the 4 TURBOPROPS, whose auto masks were wrong in SHAPE (a rectangular block
# with a flat bottom cutting across the fin, lower fin left unpainted, and on the T-tails
# the horizontal stabilizer painted too). A high-wing prop's fuselage sits low, so the
# auto detector's "cut at the mid-body crown" rule slices the fin in half.
#
# TWO RULES that make these read right:
#  1. STOP BELOW THE STABILIZER on the T-tails (AT46/B1900/D328/DH8B all have one) — the
#     polygon's top edge runs UNDER the stab so the cross-arm stays unpainted, the same
#     result trim_stab.py gets on the CRJ/ERJ jets.
#  2. RUN THE BASE INTO THE FUSELAGE. poly_mask intersects with the airframe silhouette,
#     so the base can be drawn a little low/long — it gets clipped to the body and the
#     paint meets the fuselage cleanly instead of stopping in mid-air.
FIN_POLYGONS = {
    # Dash-8: swept blade. Top edge sits at 0.125 — just UNDER the stabilizer root — and
    # the leading edge is a 2-segment sweep so it hugs the dorsal fillet.
    "DH8B":  [(0.845,0.125),(0.892,0.125),(0.905,0.600),(0.760,0.600),(0.800,0.330)],
    # ATR-42: big curved dorsal. The stab is mounted LOW here (y~0.15-0.19), so the top
    # edge drops to 0.205 to clear it — the painted fin is the dorsal below the stab.
    "AT46":  [(0.792,0.205),(0.872,0.205),(0.874,0.570),(0.706,0.570),(0.741,0.330)],
    # Beech 1900: strongly swept narrow blade; stab + endplate sit above 0.21, so the
    # polygon starts below them. The leading edge is steeply raked, so the base corner
    # tracks it (0.762 at the root, not 0.716) instead of spilling onto the fuselage.
    "B1900": [(0.812,0.215),(0.858,0.215),(0.936,0.560),(0.762,0.560),(0.786,0.360)],
    # Do-328: curved dorsal fillet. Base pulled up to 0.575 (the crown line) so the paint
    # meets the fuselage instead of running along it; leading edge is a 2-segment sweep.
    "D328":  [(0.852,0.120),(0.884,0.120),(0.890,0.575),(0.726,0.575),(0.782,0.340)],
}

def auto_mask(path):
    im=Image.open(path).convert("RGBA"); w,h=im.size; px=im.load()
    def op(x,y): return px[x,y][3]>40
    midcrown=min(next((y for y in range(h) if op(x,y)),h) for x in range(int(w*0.30),int(w*0.55)))
    cols={}
    for x in range(int(w*0.55),w):
        col=[y for y in range(0,h) if op(x,y)]
        if col: cols[x]=col
    finxs=[x for x in sorted(cols) if min(cols[x])<midcrown-h*0.05]
    runs=[];cur=[finxs[0]]
    for x in finxs[1:]:
        if x-cur[-1]<=4: cur.append(x)
        else: runs.append(cur);cur=[x]
    runs.append(cur)
    fin=max(runs,key=lambda r:max(midcrown-min(cols[x]) for x in r))
    mask=Image.new("L",(w,h),0); m=mask.load()
    for x in fin:
        col=set(cols[x]); top=min(cols[x]); y=top
        while (y+1) in col: y+=1
        for yy in range(top,y+1): m[x,yy]=255
    rgba=Image.new("RGBA",(w,h),(255,255,255,0)); rgba.putalpha(mask); return rgba

def poly_mask(path, poly):
    im=Image.open(path).convert("RGBA"); w,h=im.size
    mask=Image.new("L",(w,h),0)
    d=ImageDraw.Draw(mask)
    d.polygon([(px*w,py*h) for px,py in poly], fill=255)
    # intersect with the aircraft silhouette so the paint never spills off the airframe
    alpha=im.split()[3].point(lambda a: 255 if a>40 else 0)
    from PIL import ImageChops
    mask=ImageChops.multiply(mask, alpha)
    rgba=Image.new("RGBA",(w,h),(255,255,255,0)); rgba.putalpha(mask); return rgba

def main():
    want=set(sys.argv[1:])
    for p in sorted(glob.glob(f"{DIR}/*.png")):
        tid=os.path.basename(p).replace(".png","")
        if want and tid not in want: continue
        if tid in FIN_POLYGONS:
            mk=poly_mask(p, FIN_POLYGONS[tid]); src="poly"
        else:
            mk=auto_mask(p); src="auto"
        mk.save(f"{OUT}/{tid}_fin.png")
        print(f"{tid:9} {src}")

if __name__=="__main__": main()
