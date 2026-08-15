# NOTE (2026-08-15): the livery is now a PAINTED TAIL — the whole fin is filled with
# the palette secondary colour and the emblem is drawn WHITE and CLIPPED to the fin
# shape (United/Delta/Lufthansa style). This file's job is now: (1) emit large,
# fin-bbox-centred tailCX/CY/Scale so the emblem fills the tail (clipping at the edge
# is intentional), and (2) the fin MASKS live in Resources/FinMasks/<TYPE>_fin.png
# (RGBA, alpha = fin shape) — regenerate them if illustrations change (see the
# mask-gen snippet in git history of this session). Per-emblem re-centre nudges (for
# emblems whose art is unbalanced, e.g. 3/4/7) live in TailArt.nudge() in Livery.swift.

#!/usr/bin/env python3
"""
Auto-place livery tail emblems on each aircraft's fin.

WHAT IT DOES
  For every illustration in Resources/Illustrations/<TYPE>.png it:
    1. Detects the FIN silhouette (opaque pixels above the fuselage crown, rear ~45%).
    2. Detects whether it's a T-TAIL (wide horizontal bar near the fin top).
    3. Finds the LARGEST SQUARE that fits fully INSIDE the fin outline (so the
       emblem can NEVER exceed the fin edge), centred on the fin body. T-tails bias
       the search LOWER (below the horizontal stab). Big tall fins also get a
       height-based minimum size so the emblem doesn't read too small.
    4. Writes tailCX / tailCY / tailScale back into AircraftLivery.swift (keeps the
       hand-tuned TITLE values untouched).

TUNABLES (top of file) — nudge these to refine:
  MARGIN     emblem = this fraction of the largest inscribed square (bigger = larger, but
             keep < ~1.0 to preserve the never-overflow guarantee). Currently 0.95.
  ARTBUMP    emblems have transparent padding in their square (~74% artwork); this scales
             the square up so the visible art fills the fin. Currently 1.35.
  T_LOWER    vertical start (fraction down the fin) for the inscribed-square search on
             T-TAILS — higher = lower on the fin, away from the horizontal stab. 0.40.
  SWEPT_LOWER same, for swept/conventional fins. 0.22.
  HEIGHT_FRAC minimum emblem size as a fraction of fin HEIGHT (helps big tall fins like
             A380/777 not read too small). 0.42 swept / 0.40 T-tail.
  TOP_KEEP   fraction of the emblem kept ABOVE the crown (stops it sinking into the
             fuselage on short fins like AT46). 0.30.

KNOWN EDGE CASES STILL TO REFINE (2026-08-14, handoff):
  • AT46 (ATR 42) — stubby T-tail; the globe/round emblems can still kiss the
    horizontal stab. Wants a smaller emblem or a lower centre on this one type.
  • ERJ145 — could sit ~one notch lower.
  • The T-tail detector is a width-ratio heuristic; verify new/edge airframes classify
    right (print `isT` per type — see the `--report` flag).
  Consider: a per-type override table for the 2-3 stubborn ones, layered on top of the
  auto values, rather than fighting the global constants.

USAGE
  python3 aa-livery/fin_place.py            # rewrite AircraftLivery.swift tail values
  python3 aa-livery/fin_place.py --report   # just print detected values + T-tail flags
Then: clean build (art/values changed) and check with the -liveryGallery harness
(shows ALL 10 emblems on one aircraft; -galleryType <ID> to switch aircraft).
"""
import glob, os, re, sys
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR  = os.path.join(REPO, "AirlineArchitect/AirlineArchitect/Resources/Illustrations")
SWIFT= os.path.join(REPO, "AirlineArchitect/AirlineArchitect/AircraftLivery.swift")

MARGIN=0.95; ARTBUMP=1.35
T_LOWER=0.40; SWEPT_LOWER=0.22
HEIGHT_FRAC_SWEPT=0.42; HEIGHT_FRAC_T=0.40
TOP_KEEP=0.30

def analyze(path):
    im=Image.open(path).convert("RGBA"); w,h=im.size; px=im.load()
    def op(x,y): return px[x,y][3]>40
    crown=min(next((y for y in range(h) if op(x,y)),h) for x in range(int(w*0.30),int(w*0.62)))
    fin=set()
    for x in range(int(w*0.55),w):
        for y in range(0,crown):
            if op(x,y): fin.add((x,y))
    if not fin: return None
    xs=[p[0] for p in fin]; ys=[p[1] for p in fin]
    minx,maxx,miny,maxy=min(xs),max(xs),min(ys),max(ys)
    grid=[[False]*(maxx-minx+1) for _ in range(maxy-miny+1)]
    for (x,y) in fin: grid[y-miny][x-minx]=True
    GH=len(grid); GW=len(grid[0])
    def inside(x,y):
        gy=y-miny; gx=x-minx
        return 0<=gy<GH and 0<=gx<GW and grid[gy][gx]
    def widthAt(frac):
        yy=int(miny+(maxy-miny)*frac); row=[x for x in range(minx,maxx+1) if inside(x,yy)]
        return (max(row)-min(row)) if row else 0
    isT = widthAt(0.12) > widthAt(0.55)*1.15 and widthAt(0.12) > (maxx-minx)*0.6
    lo = T_LOWER if isT else SWEPT_LOWER
    best=None
    for cy in range(miny+int((maxy-miny)*lo), maxy):
        for cx in range(minx,maxx):
            if not inside(cx,cy): continue
            r=1
            while True:
                ok=True; step=max(1,r//3)
                for dx in range(-r,r+1,step):
                    if not(inside(cx+dx,cy-r) and inside(cx+dx,cy+r)): ok=False;break
                if ok:
                    for dy in range(-r,r+1,step):
                        if not(inside(cx-r,cy+dy) and inside(cx+r,cy+dy)): ok=False;break
                if not ok: break
                r+=2
            r-=2
            if r>0 and (best is None or r>best[0]): best=(r,cx,cy)
    r,cx,cy=best
    finH=maxy-miny
    inscribed=2*r*MARGIN*ARTBUMP
    heightBased=finH*(HEIGHT_FRAC_T if isT else HEIGHT_FRAC_SWEPT)*ARTBUMP
    side=max(inscribed,heightBased)
    cy=min(cy, crown - side*TOP_KEEP)
    return dict(cx=round(cx/w,3), cy=round(cy/h,3), scale=round(side/h,3), isT=isT)

def main():
    report = "--report" in sys.argv
    tail={}
    for p in sorted(glob.glob(f"{DIR}/*.png")):
        tid=os.path.basename(p).replace(".png","")
        a=analyze(p)
        if a: tail[tid]=a
        if report: print(f"{tid:9} cx={a['cx']} cy={a['cy']} scale={a['scale']} {'[T-TAIL]' if a['isT'] else ''}")
    if report: return
    src=open(SWIFT).read()
    def repl(m):
        tid=m.group(1); tcx,tcy,tw,ts=m.group(2),m.group(3),m.group(4),m.group(5)
        if tid in tail:
            a=tail[tid]
            return (f'case "{tid}": return .init(titleCX: {tcx}, titleCY: {tcy}, titleW: {tw}, '
                    f'titleScale: {ts}, tailCX: {a["cx"]}, tailCY: {a["cy"]}, tailScale: {a["scale"]})')
        return m.group(0)
    pat=re.compile(r'case "([^"]+)": return \.init\(titleCX: ([\d.]+), titleCY: ([\d.]+), titleW: ([\d.]+), titleScale: ([\d.]+), tailCX: [\d.]+, tailCY: [\d.]+, tailScale: [\d.]+\)')
    open(SWIFT,"w").write(pat.sub(repl,src))
    print(f"rewrote {len(tail)} tail placements in AircraftLivery.swift")

if __name__=="__main__": main()
