# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

_Written 2 September 2026, at the end of the session that: triaged a detailed App Store
review (`aa-1.1.x/PLAYER-FEEDBACK-1.6-TRIAGE.md`) and drafted the reply; shipped three
"cheap tier" player-feedback fixes to `main` (crew tuning, 100× speed + auto-slow-on-alert,
route-swap discoverability); SHELVED the preventive-maintenance budget after two balance
sweeps proved it economically trivial; then designed + built the real answer — a full
MX maintenance program (Line/A/C/D checks) — on the `mx-program` branch, verified but NOT
merged._

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, all pushed.
>
> **RELEASE STATE (verify, don't trust this snapshot):**
> `cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`
> - **1.6.0 (build 55) is LIVE** (`READY_FOR_SALE`) — German localization + 43 city hero
>   images + per-achievement Game Center icons. Cleared 4.3(a) (the artwork made it a real
>   content update, not localization-only). Next new build = **56+**.
> - ⚠️ **App Review 4.3(a) is account-wide** — every submission leads its App Review notes with
>   the §1 studio-context block. Reuse `aa-1.1.x/app-review-notes-1.5.0.txt` (or `-1.4.3`), bump
>   the version line. Playbook: `PostmarkOps/APP_REVIEW_NOTES.md`.
>
> **WHAT THIS SESSION LEFT — three things, in priority order:**
>
> 1. **`main` carries THREE unshipped player-feedback fixes** (merged, verified, waiting for the
>    next content build — never ship them standalone during the 4.3(a) cascade):
>    - **Crew tuning** — labor actions now rare (~0.5/sim-yr, was ~1.25) + training sidelines ¼
>      of a family (was ½). Balance-swept.
>    - **100× speed + auto-slow-on-alert** — a 7th speed pill; the sim auto-drops to 1× when a
>      decision card appears (a `didSet` on `decisionQueue`). `aa-1.1.x/AutoSlowVerify.swift` 4/4.
>    - **Route-swap discoverability** — an in-context Fleet-detail hint explaining ASSIGN TO NEW
>      ROUTE / PARK (the reviewer's #1 was already built, just unfindable).
>    These are the answer to a real App Store review; the drafted reply is in this session's log
>    (and the triage doc). ⚠️ The 100× pill layout + hint rendering are static UI, NOT yet
>    eyeballed on device (the sim host jammed) — glance at them when you next drive the app.
>
> 2. **⭐ MX MAINTENANCE PROGRAM — BUILT + VERIFIED on branch `mx-program`, NOT merged.** The
>    real replacement for the shelved PM budget. Full spec: `aa-1.1.x/MX_PROGRAM_SPEC.md`.
>    Player-driven SCHEDULED maintenance (Line/A/C/D checks; B is obsolete) distinct from AOG
>    emergencies, in a new **OPS ▸ MX** section. Each owned aircraft accrues toward A/C/D on the
>    tighter of a cycle OR calendar limit (D pegged to `expectedLifespanCycles/3` → ~2–3 per
>    airframe, matches reality, zero blast radius on the sell economy). Due → a `.mxCheck`
>    decision card (Service / Keep flying) + the OPS ▸ MX list; cost = % of purchase price
>    (reproduces the real 737≈$1M / 747≈$6M D-cost spread); downtime blocks at the gate
>    (airborne finishes first, mirrors the repaint shop). **Deferral has real teeth**: overdue →
>    AOG risk ×6 + overdue breakdowns cost ×4; past a HARD legal window (1.5× interval) the
>    aircraft is force-grounded into a MANDATORY check; and an OVERDUE check costs a **2.5×
>    surcharge** vs on-time — which is what makes servicing early economically right (the
>    "sell before the D check" dynamic emerges naturally). Verified: full build clean ·
>    RoundTripVerify 13/13 · MX sweep 6/6 (`aa-1.1.x/MXProbe.swift` — SERVICED beats DEFERRED,
>    invariant holds, D economics real) · soak 6/6 (~6.3M ticks, MX integrated, in `SoakMain.swift`)
>    · de gap scan clean. **To ship it:** `git checkout mx-program`, drive OPS ▸ MX + the
>    decision card live in the Simulator (the one thing not yet eyeballed), then merge to `main`
>    and cut a content build (bundling it with the three fixes from #1 = a natural 1.7 release).
>    ⚠️ Balance took 4 rounds — the honest finding (in the commit + spec) is that AOG is so rare
>    and shop-downtime so cheap at ~2 legs/day that only the overdue COST surcharge made the
>    service-vs-defer choice matter; keep that if you retune.
>
> 3. **Monetization signals** (give ~2 weeks from each release): RevenueCat trial→paid
>    conversion + TelemetryDeck `Paywall.shown ÷ Game.started` (production view = Test Mode OFF)
>    + the `hang.under3s` count trend (the 1.4.2/1.4.3 async fixes should have dropped it).
>
> **SHELVED (don't re-attempt blind):** the preventive-maintenance BUDGET (`maint-budget-t22`
> branch) — a passive PM cost/AOG-frequency lever. Two balance sweeps proved it economically
> trivial (AOG too rare at the real 2/100/month anchor). The MX program (#2) is the real answer.
> Only revisit the budget idea if the AOG base rate is ever raised.
>
> **THE STANDING CONCERN:** the UI/"does it feel right" half no harness reaches. It found the
> ASSIGN-TO-NEW-ROUTE no-op + the SLC-artwork bug in past sessions; it keeps paying. Drive the
> app.
>
> **HOW THIS CODEBASE VERIFIES (don't skip):** every sim change gets a headless harness in
> `aa-1.1.x/` (compile the real `Sim/*.swift` with `swiftc`, excluding AircraftIcon/SVGPath and
> adding `RepaintVerifyStubs.swift`; entry file MUST be `main.swift`) + the soak
> (`SoakMain.swift`, ~6–8 min) + `RoundTripVerify.swift` (save-path) + a Debug `xcodebuild` + a
> live Simulator drive of any new UI. **German:** the app ships `de` on `main` — any NEW
> user-facing string needs a translation; the ONLY reliable gap check is
> `DD=<derivedDataRoot> python3 aa-1.1.x/de-findgaps.py` after a Debug build (scans ALL
> stringsdata; a `de.lproj` `de==en` diff and a hand-picked file list both MISS category-2
> gaps — a String reaching `Text` via a var/param/concatenation bypasses the catalog).
>
> **Simulator warnings:** tap coordinates are in POINTS (402×874 iPhone 17 Pro / 440×956 Pro Max),
> not screenshot pixels; the input channel degrades mid-session — re-screenshot before concluding
> a control is broken, a fresh `simctl launch` (or killing CoreSimulator + rebooting one device)
> clears a wedge, and terminate sibling Architect apps that steal focus; LANDSCAPE captures come
> out rotated (`sips -r 90`/`-r 270`). The `-devScenario` harness
> (`publicGate|listed|activist|ouster|fleet|bigfleet|legacyPlayer|subfleet|mx`) seeds otherwise-
> unreachable states (`mx` = a routed fleet staged at distinct MX due-states — A due, A overdue,
> C due, D due — with idle spares + a widebody D-check to exercise the C/D coverage flow).

---

## Useful commands

```bash
# review status
cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"

# headless harness pattern (entry file MUST be main.swift; ~30s compile under -O)
cd AirlineArchitect/AirlineArchitect
cp ../../aa-1.1.x/MXProbe.swift /tmp/main.swift      # or RoundTripVerify / SoakMain / AutoSlowVerify
swiftc -O -DDEBUG $(ls Sim/*.swift | grep -vE 'AircraftIcon.swift|SVGPath.swift') \
  Persistence.swift ../../aa-1.1.x/RepaintVerifyStubs.swift /tmp/main.swift -o /tmp/run && /tmp/run

# German gap scan (the ONLY reliable category-2 check — after a Debug build)
DD=<your -derivedDataPath root> python3 aa-1.1.x/de-findgaps.py

# release chain is scriptable end-to-end (see CLAUDE.md "upload is SCRIPTABLE"):
#   xcodebuild archive → -exportArchive → altool --validate-app → altool --upload-app
```
