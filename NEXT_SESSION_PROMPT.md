# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

_Written 21 August 2026, at the end of the session that: ran a critical gameplay review and
built the six-feature GAMEPLAY PACK (fare lever, session briefing, first quest, Game Center,
rival flavor + free-tier teaser, subsidiary fleet growth); created the full Game Center config
in App Store Connect via the API; cut builds 45→48; and SUBMITTED 1.4 (build 48) for review
with rewritten App Review notes._

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, all pushed.
>
> **RELEASE STATE:**
>
> 1. **1.2 (41) · 1.2.1 (43) · 1.3 (44) are all LIVE** (`READY_FOR_SALE`).
>
> 2. **1.4 (build 48) is SUBMITTED FOR REVIEW** (`WAITING_FOR_REVIEW`, 21 Aug) — the
>    GAMEPLAY PACK. Auto-releases on approval. Check state with:
>    `cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`
>    Builds 45–47 are superseded (the Game Center entry-point saga — see below). App Review
>    notes were REWRITTEN for 1.4 (they were stale: subscription-era pricing, old 3/2 caps, "no
>    analytics"); they now describe the one-time unlock, 6/5 caps, Game Center reporting-only,
>    and TelemetryDeck. Next new build = **49+**.
>
> **THE ONE FOLLOW-UP THAT MATTERS — after 1.4 is LIVE:**
>
> Game Center ships in 1.4 as **reporting-only, no in-app GC UI** (family decision mirroring
> FC Architect build 35). Cause: an app that shipped before its GC integration existed (AA
> 1.0–1.3) carries a stale server-side record that makes GameKit's own dashboard open EMPTY;
> every client-side workaround (Apple's rocket, a trophy button → `.achievements` grid, page
> sheet) lost on the designer's device. The record should HEAL once 1.4 is publicly released —
> the `gameCenterAppVersion` record enabled at submit is the heal mechanism. **Once 1.4 is
> live: have the designer check Apple's Game Center rocket on the live App Store build. If it
> opens the populated dashboard, re-enable the standard `GKAccessPoint` in a 1.4.1** —
> `GameCenter.setAccessPointActive` in `GameCenter.swift` is a hard-off stub with the whole
> story documented at the site; the clean re-enable is the standard three-liner (location
> `.topLeading`, `isActive = active && isAuthenticated`) called on the load menu + naming
> screen (a fresh install never sees the load menu — that bit us in build 46). FCA's 1.2 is
> the second data point for the same theory. Do NOT re-add any custom presentation hacks.
>
> **OTHER OPEN ITEMS (none blocking):**
> - Map color for subsidiary aircraft: they render in the competitor purple (`MapView` keys on
>   `airlineName != nil`), so a sub is indistinguishable from a rival on the map. The spec's
>   third colour state was never built. Small follow-up if it bites.
> - Per-achievement Game Center art: all 29 share one gold-ring badge
>   (`aa-1.1.x/gc_achievement_badge.png`). Images are replaceable any time via
>   `aa-1.1.x/gc_upload_images.py` (idempotent) — a polish pass, not a blocker.
> - Once 1.2's one-time unlock is dominant: remove Monthly/Yearly from the RevenueCat
>   offering (NEVER delete the sub products).
> - Cross-app: FCA's 1.2 submission will hit the same "select the Game Center checkbox"
>   error AA hit — its version needs a `gameCenterAppVersion` (POST via the API works; see
>   this session's note in HANDOFF.md). Also FCA's tree had an uncommitted `Telemetry.swift`
>   change + untracked `whatsnew-1.1.txt` on 21 Aug — not AA's, but flag it.
>
> **HOW THIS CODEBASE VERIFIES (don't skip):** every sim change gets a headless harness in
> `aa-1.1.x/` (compile the real `Sim/*.swift` with `swiftc`, excluding AircraftIcon/SVGPath
> and adding `RepaintVerifyStubs.swift`) + the soak (`SoakMain.swift`) + a Debug AND Release
> `xcodebuild` + a live Simulator drive of any new UI. The fare lever's
> `aa-1.1.x/FareVerify.swift` is the reference for an event-proof behavioral A/B (two routes in
> one sim, measured as a ratio). Release chain is scriptable end-to-end (see CLAUDE.md's
> "upload is SCRIPTABLE" note).
>
> **Simulator warnings:** tap coordinates are in POINTS (402×874 on iPhone 17 Pro), not
> screenshot pixels; the input channel degrades — re-screenshot before concluding a control
> is broken; terminate sibling Architect apps that steal focus. The `-devScenario` harness
> (`publicGate|listed|activist|ouster|fleet|bigfleet|legacyPlayer|subfleet`) seeds otherwise
> unreachable states.

---

## Useful commands

```bash
# review status
cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"

# headless harness pattern (entry file MUST be main.swift; ~30s compile under -O)
mkdir -p /tmp/h && cp aa-1.1.x/FareVerify.swift /tmp/h/main.swift && cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/h/
swiftc -O -DDEBUG -o /tmp/h/run \
  $(ls AirlineArchitect/AirlineArchitect/Sim/*.swift | grep -vE 'AircraftIcon|SVGPath') \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/h/RepaintVerifyStubs.swift /tmp/h/main.swift && /tmp/h/run

# the soak (cash invariant + crew/route integrity) — run after ANY sim change (~6 min)
#   same recipe with aa-1.1.x/SoakMain.swift

# Game Center config (idempotent — re-run to add milestones / swap badge art)
python3 aa-1.1.x/gc_setup.py && python3 aa-1.1.x/gc_upload_images.py
```
