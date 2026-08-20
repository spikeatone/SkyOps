# Game Center setup — designer's one-time checklist

The app code (GameCenter.swift) is complete and ships safely with or without
this configuration: until the IDs below exist in App Store Connect, every
submission fails silently server-side and nothing player-facing breaks. The
sign-in sheet appears after the cold-launch splash; the floating Game Center
widget shows on the load menu only.

## 1. Enable Game Center (App Store Connect)

App Store Connect → Apps → Airline Architect → **Services → Game Center** →
enable for iOS. (The `com.apple.developer.game-center` entitlement is already
in the entitlements file; automatic signing picks up the capability on the App
ID at the next archive — same as the iCloud KVS capability did.)

## 2. Create the two leaderboards

Both are **efficiency** boards (the design rule from CLAUDE.md: never rank raw
accumulation — the sim runs at 25×, so raw net worth just rewards grind).

| Leaderboard ID | Type | Sort | Format | Name suggestion |
|---|---|---|---|---|
| `aa.fastest_100m` | Classic (all-time) | **Ascending** (lower = better) | Integer ("days") | Fastest to $100M |
| `aa.networth_day365` | Classic (all-time) | Descending | Money-ish integer ($) | First-year net worth |

- `aa.fastest_100m` submits the **sim-day** the $100M net-worth milestone fires.
- `aa.networth_day365` submits **net worth in dollars** on sim-day 365
  (fires with the "One year in the sky" milestone).
- Each save submits each board at most once (milestones are once-per-save).

## 3. Create the achievements

One per milestone, IDs exactly as below (points are suggestions — ASC caps the
total at 1,000; this list of 29 uses 690, leaving room for future milestones).
Hidden = "No" for all except the two iconic ones (nicer as surprises).

| Achievement ID | Suggested title | Pts |
|---|---|---|
| `aa.first_aircraft` | First Jet | 10 |
| `aa.first_flight` | Wheels Up | 10 |
| `aa.first_route` | City Pair | 10 |
| `aa.flights_100` | Finding the Rhythm | 15 |
| `aa.flights_1k` | A Thousand Departures | 40 |
| `aa.fleet_5` | A Real Fleet | 15 |
| `aa.fleet_10` | Double Digits | 25 |
| `aa.fleet_25` | Major Carrier | 40 |
| `aa.fleet_50` | Powerhouse | 60 |
| `aa.routes_5` | A Real Network | 15 |
| `aa.routes_10` | Filling the Map | 25 |
| `aa.routes_25` | Serious Network | 40 |
| `aa.first_intl` | Border Crosser | 20 |
| `aa.regions_4` | Four Corners | 30 |
| `aa.regions_7` | World Wide | 60 |
| `aa.first_widebody` | Big Metal | 20 |
| `aa.first_hub` | Fortress | 25 |
| `aa.first_club` | The Lounge | 20 |
| `aa.nw_30m` | Grown Back | 10 |
| `aa.nw_50m` | Taking Off | 15 |
| `aa.nw_100m` | Nine Figures | 25 |
| `aa.nw_250m` | Quarter Billion | 35 |
| `aa.nw_500m` | Listable | 45 |
| `aa.nw_1b` | The Big League | 60 |
| `aa.iconic_sbh` | St. Barths (hidden) | 25 |
| `aa.iconic_ppt` | Paradise Found (hidden) | 25 |
| `aa.went_public` | Opening Bell | 40 |
| `aa.first_subsidiary` | Empire Builder | 60 |
| `aa.year_one` | One Year In | 20 |

## 4. Nothing else

No code changes needed after the ASC config — the IDs are already in
`GameCenter.swift` (`achievementIDs` map + the two leaderboard constants). A
loaded save back-fills its already-earned achievements automatically
(`syncAchievements`, idempotent). Test by signing a sandbox/TestFlight account
into Game Center (Settings → Game Center) and playing to the first milestone.
