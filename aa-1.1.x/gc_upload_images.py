#!/usr/bin/env python3
"""Upload each Airline Architect achievement's OWN custom icon to Game Center.

Supersedes the old shared-badge version: instead of pushing one `aa_badge.png`
to all 29 achievements, this maps every achievement to its own PNG by vendor id.

File convention: vendor id `aa.first_hub` -> `Finished/aa_first_hub.png`
(the id with its dots turned into underscores).

HARD ERROR on missing files: every achievement in Game Center must have a
matching PNG in ICONS_DIR, or the script prints the full list of missing files
and exits WITHOUT uploading anything (fail fast — never half-apply a set).

Because every achievement currently carries the old shared badge, an existing
image is REPLACED (deleted, then re-uploaded), not skipped — a skip-if-present
policy would upload nothing on the first real run.

ASC asset-upload flow per image: reserve (POST gameCenterAchievementImages with
fileName/fileSize + the localization relationship) -> PUT the bytes to the
returned uploadOperations -> PATCH uploaded=true -> ASC processes it.
"""
import sys, os, json, urllib.request
sys.path.insert(0, "/Users/michaelstevens/Architect Universe/PostmarkOps/ASCTools")
from asc import ASC

APP_ID = "6790569697"
ICONS_DIR = ("/Users/michaelstevens/Architect Universe/Airline Architect/"
             "Achievements/Finished")

def icon_path(vendor_id):
    """aa.first_hub -> <ICONS_DIR>/aa_first_hub.png"""
    return os.path.join(ICONS_DIR, vendor_id.replace(".", "_") + ".png")

asc = ASC()

def call(method, path, body=None, ok=(200, 201)):
    status, payload = asc.request(method, path, body)
    if status not in ok:
        print(f"  !! {method} {path} -> HTTP {status}")
        print(json.dumps(payload, indent=2)[:800])
        return None
    return payload

# ----------------------------------------------------------------- fetch list
_, d = asc.request("GET", f"/v1/apps/{APP_ID}/gameCenterDetail")
detail_id = d["data"]["id"]
achs = call("GET",
            f"/v1/gameCenterDetails/{detail_id}/gameCenterAchievements?limit=200")["data"]
print(f"{len(achs)} achievements in Game Center")

# ------------------------------------------------------ PREFLIGHT: every file
# must exist before we touch a single upload. Fail fast, list ALL that are missing.
missing = []
for a in achs:
    vid = a["attributes"]["vendorIdentifier"]
    p = icon_path(vid)
    if not os.path.isfile(p):
        missing.append((vid, p))

if missing:
    print(f"\nERROR: {len(missing)} achievement(s) have no matching PNG in:")
    print(f"  {ICONS_DIR}\n")
    for vid, p in missing:
        print(f"  MISSING  {vid}  ->  {os.path.basename(p)}")
    sys.exit("\nAborted — no images uploaded. Add the files above, then re-run.")

print(f"preflight OK: all {len(achs)} icons present in {ICONS_DIR}")

# ----------------------------------------------------------------- upload loop
done = failed = 0
for a in achs:
    vid = a["attributes"]["vendorIdentifier"]
    path = icon_path(vid)
    fname = os.path.basename(path)
    data = open(path, "rb").read()

    locs = call("GET", f"/v1/gameCenterAchievements/{a['id']}/localizations")
    if not locs or not locs["data"]:
        print(f"{vid}: NO LOCALIZATION — skipped"); failed += 1; continue
    loc_id = locs["data"][0]["id"]

    # Replace any existing image (e.g. the old shared badge) so the new icon wins.
    existing = call("GET",
        f"/v1/gameCenterAchievementLocalizations/{loc_id}/gameCenterAchievementImage",
        ok=(200, 404))
    if existing and existing.get("data"):
        old_id = existing["data"]["id"]
        call("DELETE", f"/v1/gameCenterAchievementImages/{old_id}", ok=(200, 204))

    # 1. Reserve
    res = call("POST", "/v1/gameCenterAchievementImages", {
        "data": {"type": "gameCenterAchievementImages",
                 "attributes": {"fileName": fname, "fileSize": len(data)},
                 "relationships": {"gameCenterAchievementLocalization":
                     {"data": {"type": "gameCenterAchievementLocalizations",
                               "id": loc_id}}}}})
    if not res:
        failed += 1; continue
    img_id = res["data"]["id"]
    ops = res["data"]["attributes"]["uploadOperations"]

    # 2. PUT the bytes (may be chunked into several operations)
    try:
        for op in ops:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
            for h in op.get("requestHeaders") or []:
                req.add_header(h["name"], h["value"])
            with urllib.request.urlopen(req, timeout=120) as r:
                r.read()
    except Exception as e:
        print(f"{vid}: upload failed — {e}"); failed += 1; continue

    # 3. Commit
    ok = call("PATCH", f"/v1/gameCenterAchievementImages/{img_id}", {
        "data": {"type": "gameCenterAchievementImages", "id": img_id,
                 "attributes": {"uploaded": True}}})
    if ok:
        done += 1; print(f"{vid}: uploaded {fname} ({len(data)} bytes)")
    else:
        failed += 1

print(f"\n{done} uploaded, {failed} failed")
sys.exit(0 if failed == 0 else 1)
