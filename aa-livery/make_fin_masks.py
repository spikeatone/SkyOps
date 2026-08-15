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

# Hand-traced fin outlines (fractional x,y). Fill in per exception type.
# TODO(designer session): trace AT46 / B1900 / D328 / DH8B (+ any T-tail that looks off).
FIN_POLYGONS = {
    # "DH8B": [(0.836,0.06),(0.850,0.06),(0.887,0.54),(0.595,0.54)],  # example shape — RE-TRACE
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
