#!/usr/bin/env python3
"""Create Airline Architect's Game Center config via the ASC API.

Idempotent: existing items (matched by vendorIdentifier) are skipped, so
re-running after a partial failure only creates what's missing. Images are NOT
uploaded here (designer-side, or a follow-up script) — an achievement needs its
image before release, but creation works without it.

Source of truth for IDs/copy: GAMEKIT_SETUP.md + GameCenter.swift.
"""
import sys, json
sys.path.insert(0, "/Users/michaelstevens/Architect Universe/PostmarkOps/ASCTools")
from asc import ASC

APP_ID = "6790569697"
asc = ASC()

def call(method, path, body=None, ok=(200, 201)):
    status, payload = asc.request(method, path, body)
    if status not in ok:
        print(f"  !! {method} {path} -> HTTP {status}")
        print(json.dumps(payload, indent=2)[:1200])
        return None
    return payload

# ---------------------------------------------------------------- detail
payload = call("GET", f"/v1/apps/{APP_ID}/gameCenterDetail")
detail = payload and payload.get("data")
if detail is None:
    print("Creating gameCenterDetail…")
    payload = call("POST", "/v1/gameCenterDetails", {
        "data": {"type": "gameCenterDetails",
                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    if not payload:
        sys.exit("FATAL: could not create gameCenterDetail")
    detail = payload["data"]
DETAIL_ID = detail["id"]
print(f"gameCenterDetail: {DETAIL_ID}")

def existing(kind):
    """vendorIdentifier -> item id for already-created leaderboards/achievements."""
    out = {}
    path = f"/v1/gameCenterDetails/{DETAIL_ID}/{kind}?limit=200"
    payload = call("GET", path)
    for item in (payload or {}).get("data") or []:
        out[item["attributes"]["vendorIdentifier"]] = item["id"]
    return out

# ---------------------------------------------------------------- leaderboards
LEADERBOARDS = [
    {   # ranks sim-DAYS to $100M — LOWER IS BETTER, so ASC sort. Un-fixable
        # after go-live; this being scripted is how the footgun stays unfired.
        "referenceName": "Fastest to $100M",
        "vendorIdentifier": "aa.fastest_100m",
        "defaultFormatter": "INTEGER",
        "submissionType": "BEST_SCORE",
        "scoreSortType": "ASC",
        "scoreRangeStart": "1", "scoreRangeEnd": "36500",
        "loc": {"name": "Fastest to $100M",
                "formatterSuffix": " days", "formatterSuffixSingular": " day"},
    },
    {
        "referenceName": "First-Year Net Worth",
        "vendorIdentifier": "aa.networth_day365",
        "defaultFormatter": "MONEY_DOLLAR",
        "submissionType": "BEST_SCORE",
        "scoreSortType": "DESC",
        "scoreRangeStart": "0", "scoreRangeEnd": "999999999999",
        "loc": {"name": "First-Year Net Worth"},
    },
]

have = existing("gameCenterLeaderboards")
for lb in LEADERBOARDS:
    vid = lb["vendorIdentifier"]
    if vid in have:
        print(f"leaderboard {vid}: already exists — skipped")
        continue
    attrs = {k: v for k, v in lb.items() if k != "loc"}
    payload = call("POST", "/v1/gameCenterLeaderboards", {
        "data": {"type": "gameCenterLeaderboards", "attributes": attrs,
                 "relationships": {"gameCenterDetail":
                     {"data": {"type": "gameCenterDetails", "id": DETAIL_ID}}}}})
    if not payload:
        continue
    lb_id = payload["data"]["id"]
    loc = dict(lb["loc"], locale="en-US")
    call("POST", "/v1/gameCenterLeaderboardLocalizations", {
        "data": {"type": "gameCenterLeaderboardLocalizations", "attributes": loc,
                 "relationships": {"gameCenterLeaderboard":
                     {"data": {"type": "gameCenterLeaderboards", "id": lb_id}}}}})
    print(f"leaderboard {vid}: created ({lb['scoreSortType']})")

# ---------------------------------------------------------------- achievements
# (id, title, points, hidden, before-earned, after-earned)
ACHIEVEMENTS = [
    ("aa.first_aircraft", "First Jet", 10, False,
     "Buy your first aircraft.", "You bought your first aircraft — the fleet begins."),
    ("aa.first_flight", "Wheels Up", 10, False,
     "Complete your first flight.", "Your first flight is in the books."),
    ("aa.first_route", "City Pair", 10, False,
     "Open your first route.", "Your first city pair is live."),
    ("aa.flights_100", "Finding the Rhythm", 15, False,
     "Fly 100 flights.", "100 flights flown — the operation has a pulse."),
    ("aa.flights_1k", "A Thousand Departures", 40, False,
     "Fly 1,000 flights.", "1,000 flights flown. The network hums."),
    ("aa.fleet_5", "A Real Fleet", 15, False,
     "Own 5 aircraft.", "Five aircraft strong."),
    ("aa.fleet_10", "Double Digits", 25, False,
     "Own 10 aircraft.", "Ten aircraft in the fleet."),
    ("aa.fleet_25", "Major Carrier", 40, False,
     "Own 25 aircraft.", "Twenty-five aircraft — a major carrier now."),
    ("aa.fleet_50", "Powerhouse", 60, False,
     "Own 50 aircraft.", "Fifty aircraft. A powerhouse of the skies."),
    ("aa.routes_5", "A Real Network", 15, False,
     "Operate 5 routes at once.", "Five routes flying — a real network."),
    ("aa.routes_10", "Filling the Map", 25, False,
     "Operate 10 routes at once.", "Ten routes — the map is filling in."),
    ("aa.routes_25", "Serious Network", 40, False,
     "Operate 25 routes at once.", "Twenty-five routes. A serious network."),
    ("aa.first_intl", "Border Crosser", 20, False,
     "Open your first international route.", "You're flying across borders now."),
    ("aa.regions_4", "Four Corners", 30, False,
     "Serve four world regions.", "Four regions served — your reach is spreading."),
    ("aa.regions_7", "World Wide", 60, False,
     "Serve seven world regions.", "Seven regions. A truly worldwide airline."),
    ("aa.first_widebody", "Big Metal", 20, False,
     "Add your first widebody.", "The big metal has arrived."),
    ("aa.first_hub", "Fortress", 25, False,
     "Establish your first hub.", "Your first fortress hub is open."),
    ("aa.first_club", "The Lounge", 20, False,
     "Open your first club.", "Loyalty has a lounge now."),
    ("aa.nw_30m", "Grown Back", 10, False,
     "Reach $30M net worth.", "Past your starting stake and climbing."),
    ("aa.nw_50m", "Taking Off", 15, False,
     "Reach $50M net worth.", "$50M net worth — really taking off."),
    ("aa.nw_100m", "Nine Figures", 25, False,
     "Reach $100M net worth.", "Nine figures on the books."),
    ("aa.nw_250m", "Quarter Billion", 35, False,
     "Reach $250M net worth.", "A quarter billion in net worth."),
    ("aa.nw_500m", "Listable", 45, False,
     "Reach $500M net worth.", "$500M — big enough to ring the bell."),
    ("aa.nw_1b", "The Big League", 60, False,
     "Reach $1B net worth.", "A billion-dollar airline. The big league."),
    ("aa.iconic_sbh", "St. Barths", 25, True,
     "A hidden badge awaits on a very short runway.",
     "You landed on St. Barths' 2,000-ft strip — a badge of honor."),
    ("aa.iconic_ppt", "Paradise Found", 25, True,
     "A hidden badge awaits in paradise.", "Tahiti joins the network."),
    ("aa.went_public", "Opening Bell", 40, False,
     "Take the airline public.", "You rang the opening bell."),
    ("aa.first_subsidiary", "Empire Builder", 60, False,
     "Acquire another airline.", "Your empire grows by merger."),
    ("aa.year_one", "One Year In", 20, False,
     "Operate for a full year.", "365 days of operations — happy anniversary."),
]
total = sum(p for _, _, p, _, _, _ in ACHIEVEMENTS)
assert total <= 1000, total
print(f"points total: {total}/1000")

have = existing("gameCenterAchievements")
created = skipped = failed = 0
for vid, title, points, hidden, before, after in ACHIEVEMENTS:
    if vid in have:
        skipped += 1
        continue
    payload = call("POST", "/v1/gameCenterAchievements", {
        "data": {"type": "gameCenterAchievements",
                 "attributes": {"referenceName": title, "vendorIdentifier": vid,
                                "points": points, "repeatable": False,
                                "showBeforeEarned": not hidden},
                 "relationships": {"gameCenterDetail":
                     {"data": {"type": "gameCenterDetails", "id": DETAIL_ID}}}}})
    if not payload:
        failed += 1
        continue
    ach_id = payload["data"]["id"]
    loc = call("POST", "/v1/gameCenterAchievementLocalizations", {
        "data": {"type": "gameCenterAchievementLocalizations",
                 "attributes": {"locale": "en-US", "name": title,
                                "beforeEarnedDescription": before,
                                "afterEarnedDescription": after},
                 "relationships": {"gameCenterAchievement":
                     {"data": {"type": "gameCenterAchievements", "id": ach_id}}}}})
    created += 1
    print(f"achievement {vid}: created ({points} pts{', hidden' if hidden else ''})"
          + ("" if loc else "  [localization FAILED]"))

print(f"\nachievements: {created} created, {skipped} already existed, {failed} failed")
