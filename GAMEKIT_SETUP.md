# Game Center setup — designer's one-time checklist

> ## ✅ THE CONFIG WAS CREATED VIA THE ASC API (19 Aug 2026)
> `aa-1.1.x/gc_setup.py` (idempotent — safe to re-run; skips whatever exists)
> created it all with the ASCTools key and it's verified by read-back: both
> leaderboards (aa.fastest_100m **ASC/low-to-high** ✓ — the un-fixable field —
> INTEGER + "days" suffix; aa.networth_day365 DESC, MONEY_DOLLAR) and all 29
> achievements (840/1000 points; iconic_sbh + iconic_ppt hidden) with their
> en-US titles + before/after-earned descriptions.
>
> **ONE TASK LEFT (designer, in the ASC web UI): upload each achievement's
> image** — required before release; 1024×1024 PNG/JPG, and ONE shared badge
> (the app logo mark on the navy circle) uploaded to all 29 is fine for launch
> (per-achievement art can be a later polish pass). Then eyeball the Game
> Center page once and test (see the bottom of this file). Everything goes
> live with **1.4**.
>
> The tables below are now REFERENCE (what exists), not a to-do list.

**Where:** App Store Connect → Airline Architect → Distribution → App Store →
**Growth & Marketing → Game Center** (the page with the Leaderboards /
Achievements / Challenges / Activities sections). There is no separate
"enable Game Center" switch to find — this page IS the configuration, and the
app side is already done (the `com.apple.developer.game-center` entitlement is
in the binary; automatic signing picks up the capability at the next archive,
same as iCloud KVS did).

The app ships safely in either order: until the config went live, every
submission fails silently server-side and nothing player-facing breaks.

⚠️ **Two things ASC won't let you undo:**
- A leaderboard or achievement that has gone LIVE with any version can never be
  removed (the page says so). Create them with the exact IDs below — a typo'd
  ID is permanent clutter.
- A leaderboard's **sort direction** is part of its creation. `aa.fastest_100m`
  MUST be "low to high" (it ranks sim-DAYS — lower is better). If it goes live
  high-to-low, the board is ruined and we'd have to burn the ID.

---

## 1. Leaderboards (2) — "Add Leaderboard"

Both **Classic** (not Recurring). Both are **efficiency** boards — the design
rule from CLAUDE.md: never rank raw accumulation; the sim runs at 25×, so raw
net worth just rewards grind.

### `aa.fastest_100m`
| Field | Value |
|---|---|
| Reference Name | Fastest to $100M |
| Leaderboard ID | `aa.fastest_100m` |
| Score Format | Integer |
| **Sort Order** | **Low to High** ⚠️ (lower = better) |
| Score Range (recommended) | 1 – 36,500 (filters junk submissions) |
| Localization (English) | Name: "Fastest to $100M" · suffix: "days" |

Submits the **sim-day** the $100M net-worth milestone fires. Once per save.

### `aa.networth_day365`
| Field | Value |
|---|---|
| Reference Name | First-Year Net Worth |
| Leaderboard ID | `aa.networth_day365` |
| Score Format | Integer (a dollar amount) |
| Sort Order | High to Low |
| Score Range (recommended) | 0 – 999,999,999,999 |
| Localization (English) | Name: "First-Year Net Worth" · prefix/suffix: "$" |

Submits **net worth in dollars** on sim-day 365 (fires with the "One year in
the sky" milestone). Once per save.

---

## 2. Achievements (29) — "Add Achievement"

Per achievement, ASC wants: Reference Name, **Achievement ID** (exact strings
below), **Points**, Hidden yes/no, and an English localization with a **Title**,
a **Pre-earned Description**, an **Earned Description**, and an **image
(required — the achievement can't ship without one; 1024×1024 PNG/JPG)**.

**Image shortcut:** one shared 1024×1024 badge (the app logo mark on the navy
circle works) uploaded to all 29 is fine for launch — per-achievement art can
be a polish pass later. Don't let 29 unique images block the release.

Use the Description for both the pre-earned and earned fields (tweak tense if
you feel like it — the API-created ones already have distinct before/after
copy, see `aa-1.1.x/gc_setup.py`). Points total 840 of ASC's 1,000 cap — some
room for future milestones. Hidden = No for all except the two iconic ones.

| Achievement ID | Title | Description | Pts | Hidden |
|---|---|---|---|---|
| `aa.first_aircraft` | First Jet | Buy your first aircraft. | 10 | No |
| `aa.first_flight` | Wheels Up | Complete your first flight. | 10 | No |
| `aa.first_route` | City Pair | Open your first route. | 10 | No |
| `aa.flights_100` | Finding the Rhythm | Fly 100 flights. | 15 | No |
| `aa.flights_1k` | A Thousand Departures | Fly 1,000 flights. | 40 | No |
| `aa.fleet_5` | A Real Fleet | Own 5 aircraft. | 15 | No |
| `aa.fleet_10` | Double Digits | Own 10 aircraft. | 25 | No |
| `aa.fleet_25` | Major Carrier | Own 25 aircraft. | 40 | No |
| `aa.fleet_50` | Powerhouse | Own 50 aircraft. | 60 | No |
| `aa.routes_5` | A Real Network | Operate 5 routes at once. | 15 | No |
| `aa.routes_10` | Filling the Map | Operate 10 routes at once. | 25 | No |
| `aa.routes_25` | Serious Network | Operate 25 routes at once. | 40 | No |
| `aa.first_intl` | Border Crosser | Open your first international route. | 20 | No |
| `aa.regions_4` | Four Corners | Serve four world regions. | 30 | No |
| `aa.regions_7` | World Wide | Serve seven world regions. | 60 | No |
| `aa.first_widebody` | Big Metal | Add your first widebody. | 20 | No |
| `aa.first_hub` | Fortress | Establish your first hub. | 25 | No |
| `aa.first_club` | The Lounge | Open your first club. | 20 | No |
| `aa.nw_30m` | Grown Back | Reach $30M net worth. | 10 | No |
| `aa.nw_50m` | Taking Off | Reach $50M net worth. | 15 | No |
| `aa.nw_100m` | Nine Figures | Reach $100M net worth. | 25 | No |
| `aa.nw_250m` | Quarter Billion | Reach $250M net worth. | 35 | No |
| `aa.nw_500m` | Listable | Reach $500M net worth. | 45 | No |
| `aa.nw_1b` | The Big League | Reach $1B net worth. | 60 | No |
| `aa.iconic_sbh` | St. Barths | Land on the 2,000-ft strip only one aircraft can reach. | 25 | **Yes** |
| `aa.iconic_ppt` | Paradise Found | Bring Tahiti into the network. | 25 | **Yes** |
| `aa.went_public` | Opening Bell | Take the airline public. | 40 | No |
| `aa.first_subsidiary` | Empire Builder | Acquire another airline. | 60 | No |
| `aa.year_one` | One Year In | Operate for a full year. | 20 | No |

---

## 3. Everything else on that page — skip

- **Challenges** ("Add Challenge") — friend-vs-friend contests built on
  leaderboards/achievements. The app doesn't surface them; can be layered on
  later.
- **Activities** ("Add Activity") — the newer surface for jumping players into
  a specific mode/level. A single-mode sim has nothing to deep-link; skip.
- **Legacy Challenges (Deprecated)** — leave the "Turn On" link alone;
  Apple has deprecated it.
- **Groups** ("Move to Group") — shares leaderboard/achievement data ACROSS
  your apps. Do **not** move Airline Architect into a group: the boards are
  AA-specific (sim-days to $100M means nothing in Golf Course Architect), and
  a group move is hard to reason about after items go live.

---

## 4. Nothing else app-side

The IDs above are already in `GameCenter.swift` (`achievementIDs` map + the two
leaderboard constants) — no code changes after the ASC config. A loaded save
back-fills its already-earned achievements automatically (idempotent).

**Test before submitting 1.4:** on a device (or the sim signed into a sandbox
Apple ID via Settings → Game Center), start a new airline and buy one plane —
the "First Jet" achievement should appear in the Game Center overlay within a
minute. The load-menu screen also shows the floating Game Center widget once
signed in.

**Tedium escape hatch:** all of the above can be created through the App Store
Connect API (`gameCenterLeaderboards` / `gameCenterAchievements` endpoints —
the same key `ASCTools/asc.py` already uses). If clicking through 29 forms is
too painful, ask Claude to script the creation; you'd only review the result
and upload the images.
