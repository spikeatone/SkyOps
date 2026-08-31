#!/usr/bin/env python3
# German localization gap finder — the ONLY scan that catches category-2 gaps
# (a String reaching Text via a param/var/concatenation never enters the catalog,
# so a de.lproj `de==en` diff can't see it). This extracts every key the app
# actually needs from ALL *.stringsdata files and diffs against the catalog's
# translated keys. Run from the repo root AFTER a Debug build.
#
# Usage:
#   DD=/path/to/DerivedData python3 aa-1.1.x/de-findgaps.py
# or pass the DerivedData root as argv[1]. The Objects-normal/arm64 dir under it
# holds the per-file <File>.stringsdata that the build's xcstringstool emits.
import json, os, re, glob, sys

DD = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get("DD", "")).rstrip("/")
if not DD:
    sys.exit("Set DD=<DerivedData root> (the -derivedDataPath you built with), "
             "or pass it as argv[1]. Needs a completed Debug build.")
# find the app target's Objects-normal/arm64 (arch may differ on Intel → try both)
cands = glob.glob(DD + "/Build/Intermediates.noindex/AirlineArchitect.build/"
                       "Debug-iphonesimulator/AirlineArchitect.build/Objects-normal/*")
APPOBJ = next((c for c in cands if os.path.isdir(c) and
               glob.glob(os.path.join(c, "*.stringsdata"))), None)
if not APPOBJ:
    sys.exit("No *.stringsdata found under %s — build Debug first." % DD)

key_re = re.compile(rb'"key"\s*:\s*"((?:[^"\\]|\\.)*)"')

needed = {}   # key -> set(files)
for sd in glob.glob(os.path.join(APPOBJ, "*.stringsdata")):
    fname = os.path.basename(sd)[:-len(".stringsdata")]
    raw = open(sd, "rb").read()
    for m in key_re.finditer(raw):
        try:
            k = m.group(1).decode("utf-8")
            k = k.replace('\\"', '"').replace('\\\\', '\\').replace('\\/', '/')
            needed.setdefault(k, set()).add(fname)
        except Exception:
            pass

catp = None
for root, _, fs in os.walk("AirlineArchitect"):
    if "Localizable.xcstrings" in fs:
        catp = os.path.join(root, "Localizable.xcstrings"); break
s = json.load(open(catp))["strings"]
translated = set(k for k, e in s.items()
                 if e.get("localizations", {}).get("de", {}).get("stringUnit", {}).get("value", "").strip())

OK = {'Airline','Airline Architect','Airline Architect Pro','Architect','Crew','Crews',
      'Phase','Reputation','Reserve','Ticker','Turbo','Marketing','AOG','Route:'}
DEBUG_FILES = {'ArchitectBackdropTestView'}  # #if DEBUG, not shipped
def skip(k, files):
    if all(ch in "·—:%@lld/9+ .-–" for ch in k):
        return True
    if len(k.strip()) <= 2:
        return True
    if k in OK:
        return True
    if files and files <= DEBUG_FILES:   # only referenced from DEBUG-only files
        return True
    return False

gap = sorted((k for k in needed if k not in translated and not skip(k, needed.get(k, set()))),
             key=lambda x: x.lower())
print("scanned %d stringsdata files; %d total keys; %d lack German:\n" %
      (len(glob.glob(os.path.join(APPOBJ, "*.stringsdata"))), len(needed), len(gap)))
for k in gap:
    print("  [%s] %r" % (",".join(sorted(needed[k])), k))
