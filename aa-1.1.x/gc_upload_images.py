#!/usr/bin/env python3
"""Upload the shared achievement badge to every Airline Architect achievement.

ASC asset-upload flow per image: reserve (POST gameCenterAchievementImages
with fileName/fileSize + the localization relationship) -> PUT the bytes to
the returned uploadOperations -> PATCH uploaded=true -> ASC processes it.
Idempotent: a localization that already has an image is skipped.
"""
import sys, json, urllib.request
sys.path.insert(0, "/Users/michaelstevens/Architect Universe/PostmarkOps/ASCTools")
from asc import ASC

BADGE = ("/Users/michaelstevens/Architect Universe/Airline Architect/"
         "SkyOps/aa-1.1.x/gc_achievement_badge.png")
APP_ID = "6790569697"

data = open(BADGE, "rb").read()
print(f"badge: {len(data)} bytes")
asc = ASC()

def call(method, path, body=None, ok=(200, 201)):
    status, payload = asc.request(method, path, body)
    if status not in ok:
        print(f"  !! {method} {path} -> HTTP {status}")
        print(json.dumps(payload, indent=2)[:800])
        return None
    return payload

_, d = asc.request("GET", f"/v1/apps/{APP_ID}/gameCenterDetail")
detail_id = d["data"]["id"]
achs = call("GET", f"/v1/gameCenterDetails/{detail_id}/gameCenterAchievements?limit=200")["data"]
print(f"{len(achs)} achievements")

done = skipped = failed = 0
for a in achs:
    vid = a["attributes"]["vendorIdentifier"]
    locs = call("GET", f"/v1/gameCenterAchievements/{a['id']}/localizations")
    if not locs or not locs["data"]:
        print(f"{vid}: NO LOCALIZATION — skipped"); failed += 1; continue
    loc_id = locs["data"][0]["id"]
    # Already has an image? (idempotency)
    img = call("GET", f"/v1/gameCenterAchievementLocalizations/{loc_id}/gameCenterAchievementImage",
               ok=(200, 404))
    if img and img.get("data"):
        skipped += 1; continue
    # 1. Reserve
    res = call("POST", "/v1/gameCenterAchievementImages", {
        "data": {"type": "gameCenterAchievementImages",
                 "attributes": {"fileName": "aa_badge.png", "fileSize": len(data)},
                 "relationships": {"gameCenterAchievementLocalization":
                     {"data": {"type": "gameCenterAchievementLocalizations", "id": loc_id}}}}})
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
        done += 1; print(f"{vid}: uploaded")
    else:
        failed += 1

print(f"\n{done} uploaded, {skipped} already had images, {failed} failed")
