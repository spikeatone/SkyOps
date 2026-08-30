# TASKS

Manually maintained. Update this when you start/finish something so the next
session (you tomorrow, or a different agent) doesn't have to guess what's
actually in flight vs merely planned in ROADMAP.md.

Format: `- [ ] Task — owner/session note — status`

This file went badly stale between updates — it described "repo just
scaffolded" for an extended stretch while the browser prototype grew from
a 6-type/7-airport smoke test into a 30-type/48-airport sim with a real
economy (sell, buy, lease, a used-aircraft market, a genuine player route
network, and a twice-rebuilt crew system), real player/competitor airline
identity, pan/zoom map, and Figma-sourced icons. See `CLAUDE.md` for the
actual technical detail on all of it; this file is just the task-tracking
layer. Don't let it drift this far again — update it in the same session
as the work, not "later."

## 1.1.x (maintenance / polish line)

### Shipped since (see HANDOFF.md for the current release state)

**This header has gone stale TWICE** — releases are tracked in `HANDOFF.md`, not here.
As of **21 Aug 2026**: **1.2 (41) · 1.2.1 (43) · 1.3 (44) are all LIVE**; **1.4 (build 48,
the GAMEPLAY PACK) is SUBMITTED FOR REVIEW** (`WAITING_FOR_REVIEW`). Next new build = **49+**.
What to do next lives in `NEXT_SESSION_PROMPT.md`. Keep this file for in-flight TASK tracking
only, and update it in the same session as the work.

## In flight

### German localization — SCOPED (28 Aug); a MARKET-ENTRY bet, not a demand response
TelemetryDeck shows German = 16% of preferred language (#2 after English 76%, 10× Spanish). Full
scoping in `aa-1.1.x/LOCALIZATION_SCOPING.md`. **Framing (designer): this is an ACQUISITION /
conversion lever for the DACH premium market, largely independent of current user count — the low
German count is plausibly a consequence of being English-only, not a reason to skip.** So it's not
"park until users grow"; it's "market entry, gated on timing, done properly."
- [x] INFRA — DONE (28 Aug, merged to `main`). `Resources/Localizable.xcstrings` (view-layer catalog,
      auto-registered by the synchronized group), `de` in knownRegions, `Sim/Localization.swift` (the
      framework-free `L()` shim for the ~124 Sim strings — compiles in the harness), `SimLocale.current`
      set at launch, 1 reference conversion. English byte-identical; app build + harness 13/13 green.
      Reusable for es/fr (fill more columns). AA now LEADS the family on German (FC has fr/it/es only).
- [ ] Commission a NATIVE German translation pass when committing (never MT — a first-language market
      notices; bad German converts worse than clean English). This is the real spend + timeline.
- [ ] SHIP GATE (timing, not merit): do NOT release the German build STANDALONE during the 4.3(a)
      cascade (FC's localization-only 1.3 was rejected) — bundle the `de` turn-on with a content
      update, or ship after the account cools.
- AA's unique wrinkle: the framework-free `Sim/` layer builds ~124 user-facing strings (Ops log,
  decision copy) that can't use SwiftUI localization without breaking the harness → small
  framework-free shim.
- Optional: pull the absolute German user count from TD for PRIORITIZATION vs other work (does not
  veto the bet — a low count is expected pre-localization).

### Tech Ops modernization (24 Aug) — branch `tech-ops-modernization` (off `main`)
Postmark Tech Ops cross-app audit: Airline was BEHIND its own siblings on the RC/TelemetryDeck
patterns it inspired. Plumbing + observability only, NO gameplay change. Full detail in CLAUDE.md
("Decided — Tech Ops modernization"). NOT yet in a shipped build — rides the next build after the
1.4.x train (51+).
- [x] Item 1 — RevenueCat key externalized (Secrets.xcconfig gitignored + .example template +
      pbxproj baseConfigurationReference + Info.plist $(VAR) + Store.resolveKey Test Store path
      + four isConfigured guards). Verified: Info.plist substitution, no appl_ literal left.
- [x] Item 2 — Telemetry.isDriven guard (AA's launch hooks + persisted debugProKey future-proof)
      + appID externalized + TelemetryTests.swift XCTest linkage proof. 9/9 pass.
- [x] Item 3 — MetricKit CrashReporter.swift (ported from Flight Ops) → Telemetry.errorOccurred,
      type-only, App-init after Telemetry.configure(), !isDriven. MXMetricManagerSubscriber in
      the Release binary.
- [ ] Item 4 (OPTIONAL, judgment call) — move `Sim/AircraftIcon.swift` + `Sim/SVGPath.swift`
      (which import SwiftUI) to a Views/Rendering group so Sim/ is literally SwiftUI-free.
      Cosmetic (harnesses already exclude them); parked pending designer OK — moving files in a
      synchronized-group project can ripple the harness exclude patterns.
- [ ] DESIGNER: paste the RevenueCat **Test Store** key (dashboard ▸ Apps ▸ Test Store ▸ Show
      key) into the gitignored `Secrets.xcconfig` to enable simulator purchase testing. Until
      then the slot is the placeholder and `-useTestStore` falls back to the App Store key.
- [ ] Merge `tech-ops-modernization` → `main` when ready (own PR or fast-forward — designer's call).

### 1.4 (build 48) — SUBMITTED FOR REVIEW (21 Aug, `WAITING_FOR_REVIEW`)
The GAMEPLAY PACK, from a designer-requested critical gameplay review (thesis: excellent sim,
thin game). Branch `gameplay-lever-pack`, merged to `main`. Full notes in CLAUDE.md
("Decided — Gameplay pack").
- [x] FARE LEVER — per-route Discount…Flagship pills, asymmetric elasticity (17/17 headless,
      event-proof two-route ratio harness `aa-1.1.x/FareVerify.swift`)
- [x] SESSION BRIEFING — welcome-back ops card on save load
- [x] FIRST QUEST — guaranteed curated airport offer for a new airline + rewritten tutorial
      (19/19 with the briefing, `aa-1.1.x/QuestBriefVerify.swift`)
- [x] GAME CENTER — 29 achievements ← milestone ladder, 2 efficiency leaderboards; ASC config
      + shared badge created via API (`aa-1.1.x/gc_setup.py`, `gc_upload_images.py`)
- [x] RIVAL FLAVOR + free-tier depth teaser in the Ops feed
- [x] SUBSIDIARY FLEET GROWTH — buy-for/transfer (paying-player request; 15/15
      `aa-1.1.x/SubFleetVerify.swift`)
- [x] Soak 6/6 seeds ALL GREEN · Debug + Release builds · live Simulator drive of every surface
- [x] Builds 45→48 cut + uploaded via the CLI chain (45–47 superseded by the GC entry-point
      saga); `gameCenterAppVersion` enabled via API; App Review notes REWRITTEN; submitted.
- [ ] **AFTER 1.4 IS LIVE:** designer checks Apple's GC rocket on the live build → if the
      stale record healed, re-enable the standard `GKAccessPoint` in a 1.4.1 (load menu +
      naming screen). No custom presentation hacks — see `GameCenter.swift`.

### Post-1.4 follow-ups (none blocking)
- [ ] Map: subsidiary aircraft render in competitor purple (no third colour state) — build one
      if the ambiguity bites.
- [ ] Game Center per-achievement art (all 29 share one badge; replaceable any time).
- [ ] RevenueCat: remove Monthly/Yearly from the offering once the one-time unlock dominates
      (NEVER delete the sub products).
- [ ] TelemetryDeck for Aerospace + Mars Colony Architect (no telemetry at all yet) — every
      SHIPPING sibling already has `errorOccurred`.


### 1.2.1 (build 43) — SHIPPED (LIVE 19 Aug)
- [x] **Airport offers always targeted the player's biggest hub** (paying customer:
      "all 35 of my incentives were routes into ATL"). The destination was
      DETERMINISTIC — `hubs.first(where: served…)` on a traffic-sorted list. Repro'd at
      100%. Now weighted random (sqrt pax, ×3 served / ×0.35 unserved): top dest
      100%→12%, distinct 1→30+, **60% still land on a served hub** (hold that number on
      any retune). `aa-1.1.x/OfferSpreadVerify.swift`, validated against the pre-fix
      code (fails 3/5 there). Debug+Release clean, 6/6 soak.
- [x] **TelemetryDeck error reporting folded in** (designer: "added TD error reporting to
      all builds/repos"). `Telemetry.errorOccurred(id:category:detail:)` (Errors preset,
      stable slug — never localizedDescription/PII). Cherry-picked from `livery-prototype`
      onto `main`; build bumped 42→43 so it ships with 1.2.1 rather than a later build.
- [x] **Archive → validate → upload build 43** (18 Aug, after 1.2 went live). Release build
      clean, offer-spread 5/5 on build-43 main, `altool --validate-app` + `--upload-app`
      both clean (Delivery UUID `689635df-0f22-4025-bc0f-6b1066f5ac38`).
- [x] **ASC-side (designer): version record created → build 43 attached → SUBMITTED FOR
      REVIEW** (18 Aug). No IAP re-review (the two unlock products cleared with 1.2), so it
      should move faster than 1.2's ~6-day queue. Watch state via `asc.py appStoreVersions`.

### 1.3 — PERSONALIZED LIVERY — SHIPPED (LIVE 19 Aug, build 44)
Full detail in `LIVERY_SPEC.md` + the `aa-livery/` scripts — NOW ON `main` (merged 18 Aug;
the `livery-prototype` branch still exists for history). Merge was conflict-free; Release
build clean + offer-spread 5/5; validated + uploaded (Delivery UUID `234e9bf3-…`).
**NOT yet submitted — see the two open boxes below.**
- [x] Fin masks correct on all 35 types — T-tail stabilizer bleed (CRJ/ERJ) removed via
      subtract-only `trim_stab.py`; RJ tails painted down the fairing to the fuselage;
      the 4 turboprops re-traced from the ARTWORK (`trace_fin.py`) rather than
      approximated with polygons, incl. dorsal fin + raked trailing edge.
- [x] Fleet repaint: itemized quote, real cost bands, shop QUEUE (2 at a time, so
      program length scales with fleet size), lost-revenue opportunity cost, fleet-card
      stage display. 47/47 headless + driven live.
- [x] Existing-player path: free first livery choice (`liveryChosen`), "Add Livery"
      prompt, one-time update card. 4/4 headless + driven live, both themes.
- [ ] **WALK THE FIRST-RUN FLOW ON A REAL DEVICE** (naming → livery → launch) — the last
      unverified path. Sim text entry backgrounds the app, so it has never been done
      end-to-end.
- [ ] **UPLOAD THE TWO NEW LIVERY SCREENSHOTS TO ASC** (App Store Connect → the 1.3
      version → Screenshots), for BOTH the 6.9" iPhone and 13" iPad size classes. Files
      are on the designer's Desktop in `Airline Architect Livery Screenshots/` (dark, App
      Store dimensions; airline reads "Air Tina" consistently across create + in-game).
      The two new marketing frames are "08 · Livery Create" (the design screen) and
      "09 · Livery In Game" (the painted 787-9 on Fleet detail).
- [x] Merge `livery-prototype` → `main`, bump to 1.3/build 44, verify, upload to ASC. DONE 18 Aug.
- [ ] **ASC-side (designer): create the 1.3 version record → What's New → attach build 44 →
      add the screenshots (box above) → SUBMIT** — only AFTER the real-device first-run test
      passes. (1.2.1 does NOT need to be live first; different builds.)

### (historical) Accumulated for build 34
- [x] GAME CLOCK on the speed bar (designer request): a slim "Day N · Mon D, YYYY ·
      HH:MM" line above the ¼×–25× pills (Network tab). Game Day is 1-INDEXED (Day 1
      at start); Game Date carries a year (start 2026) and is derived from the sim's
      30-day-month calendar so it stays locked to the weather/season; Game Time is a
      24-hr clock. Rendered via a leaf view reading throttled displayTick (off the
      per-tick churn path).
- [x] RANDOMIZE start date + season per new game (designer request):
      Simulation.calendarStartDay (0–359, persisted) offsets the calendar so each new
      game opens on a random date AND season (monthOfYear reads the offset, so weather
      shifts with it — a Dec start shows winter storms). Randomized from the app's
      new-game flow (ContentView, not nameAirline, so harnesses stay deterministic).
      23/23 headless (aa-1.1.x/GameClockVerify.swift, incl. persistence + the
      random-offset date==season invariant); Season/SaveCompat/RoundTrip unaffected;
      live. Parked: mirror the readout to other tabs; align the load-menu "Day N".

### Build 33 — CUT + SUBMITTED (1.1 public debut; swapped in for 32, in App Store review as of 21 Jul 2026; also the current TestFlight external cut). Contents below.
- [x] Weather/curfew map glyphs 50% larger (designer note). MapView glyph size
      9→13.5 × elementScale. On main; ships in the next archive.
- [x] Day/night terminator more obvious (designer note). MapView.drawNightShade
      maxDark 0.42→0.55 dark / 0.12→0.18 light, night colour slightly deeper.
      Verified live (clear west-night/east-day gradient across CONUS).
- [x] More vertical gap between a ground-stopped airport's ring and its weather
      glyph (designer — too tight after the 50% glyph bump). Glyph y-offset
      r+8→r+17 × es. Verified live (DEN/MCI zoomed — glyph clears the ring).
- [x] Weather/curfew glyph BELOW the ring (designer — "name above, icon below").
      MapView glyph y flips from y-(r+17) to y+(r+13) × es. Verified live
      (DEN/MCI zoomed — name label above the dot, snowflake below).
- [x] Only regionally-plausible weather (designer — "MCI would never have a
      hurricane"). Replaced computeWeatherZone's lat-10-31 US/Mexico band (swept
      in inland Kansas City / Mexico City / Guadalajara / Oaxaca / Monterrey /
      San Antonio / Austin / Guam, missed coastal Charleston / Norfolk) with a
      curated Airport.hurricaneProneCodes set of 27 real coastal airports;
      Caribbean/Central America still auto-hurricane. 43/43 headless, incl. a
      global no-stray-inland-hurricane invariant. MCI → northWinter.
- [x] SAVES SURVIVE APP UPDATES (tester "lost my game on a new TF build"). Root
      cause: synthesized Codable throws keyNotFound on a missing key for a
      NON-optional field even with a default, so every older save that predated a
      later build's new field failed to decode → swallowed to nil → "empty" slot →
      overwritten. Fix: tolerant init(from:) (decodeSafe → default) on every save
      struct; makes add-a-field-→-lose-saves impossible past+future. Plus a
      last-known-good .bak (load falls back to it) and an occupied placeholder for
      undecodable files so they can't be silently overwritten. 12/12 SaveCompat +
      13/13 real round-trip headless + live launch (existing save decoded fine).
      See CLAUDE.md persistence section. DEFERRED (need 2 devices): full-body
      cloud validation + async-correct fresh-install iCloud restore.
- [x] Add Glasgow (GLA) airport, Scotland — 8,720ft runway (blocks A380 class),
      europe region, on the GB mainland. 12/12 headless. Count 384→385.

## 1.1.x — LOD realism / delight polish batch (designer request)
Roadmap the designer greenlit: #1 registration prefixes, #5 more milestones, #2
seasonal weather, #3 seasonal leisure yield, #4 day/night + curfews, #6 flavor,
#7 weather glyph — ALL DONE. Full LOD realism/delight batch shipped.
- [x] #4 DAY/NIGHT TERMINATOR + REAL NIGHT CURFEWS — DONE. Terminator: a night
      band sweeping the map by sim-time (MapView.drawNightShade). Curfews: 27 real
      web-researched + verified airports (LHR/FRA/SYD/YTZ/SNA/…); departures gated
      during the local night window (no deadlock — 7/7 headless). Moon glyph + card
      info. Curfew data + flavor from a research WORKFLOW (parallel agents + fact-check).
- [x] #6 DESTINATION/AIRCRAFT FLAVOR — DONE. AircraftType.flavor (747 "Queen of the
      Skies" …) in Fleet detail; Airport.destinationFlavor (50 one-liners) in the
      airport card.
- [x] #7 WEATHER GLYPH — DONE. Ground-stopped airports show a hurricane/snowflake/
      rain/cloud glyph (typed by the seasonal reason); moon for an active curfew.
      See CLAUDE.md "DAY/NIGHT TERMINATOR + NIGHT CURFEWS + WEATHER GLYPHS + FLAVOR".
- [x] #2 SEASONAL WEATHER — DONE. Ground-stop rates vary by month × climate zone
      (hurricane/winter/monsoon), curves average ~1.0 so annual totals stay
      calibrated; seasonal ops-log reason ("Hurricane hold at MIA"). 28/28 headless.
- [x] #3 SEASONAL LEISURE YIELD — DONE. Leisure fares swing seasonally (peak
      northern winter, dip summer; averages ~1.0). A leisure route earns 1.61× more
      in winter than summer; non-leisure control stays flat. 28/28. See CLAUDE.md
      "SEASONALITY".
- [x] #1 NATIONAL REGISTRATION PREFIXES — DONE. Background/subsidiary tails carry
      their carrier's real national prefix (Lufthansa D…, Qantas VH…, JAL JA…)
      instead of blanket US "N…". `Airline.regPrefixByCode` (141 carriers) +
      `registrationPrefix(code:region:)`, applied in makeAircraft + acquisition.
      Player fleet stays N. Verified 43/43 headless. See CLAUDE.md "NATIONAL
      REGISTRATION PREFIXES".
- [x] #5 MORE MILESTONES — DONE. Added first_route, routes 5/10/25, first_intl,
      regions_4/7, flights_100, first_widebody, iconic SBH/PPT, first_subsidiary,
      went_public — spread across the game arc. Verified 43/43 headless. See
      CLAUDE.md "MILESTONE LADDER EXPANDED".

- [x] START-REGION PARITY — MEASURED (aa-1.1.x/RegionParityProbe.swift). Finding:
      no early traps/cakewalks — every region's starter routes are profitable with a
      gauge-matched 50-seat jet; 6/7 regions up-gauge to narrowbodies at ~90% load.
      Central America/Caribbean is the lone low-ceiling outlier (genuinely smaller
      markets — data-accurate, not a bug). Healthier than feared; no balance fix needed.
- [x] CARIBBEAN CARRIER REGION — BUILT (the one polish the parity pass surfaced).
      Split the Caribbean islands into their own `Airline.Region.caribbean` with 6
      real carriers (Caribbean Airlines/Bahamasair/Cayman/interCaribbean/Winair/
      Sunrise) instead of drawing Central America's Copa/Avianca. The "Central America
      & The Caribbean" start still spans both. Verified 18/18 headless
      (aa-1.1.x/CaribbeanVerify.swift) + clean app build. See CLAUDE.md "CARIBBEAN
      CARRIER REGION".

- [x] LEISURE FARE TUNING — DONE. A measurement pass (real Sim headless,
      scratchpad `LeisureMeasure.swift`) found leisure routes were a mild free
      lunch: the +15% fare has ZERO load/elasticity cost (pure upside), and the
      ×1.75 opening premium added only ~$63k (recouped in 2-5 flights) — the
      "bigger buy-in" never bit. Designer chose "make the buy-in bite" (keep the
      fare reward, make it a real capital commitment). Replaced the ×1.75
      multiplier with a flat $500k establishment surcharge (`leisureOpeningSurcharge`):
      opening a leisure route is now ~$580k (≈7× a mainland route), recouped in
      ~17-49 flights (vs 3-7 mainland), fare premium unchanged. Cash invariant
      verified unaffected. See CLAUDE.md "LEISURE OPENING RETUNED (1.1.x)".

- [x] HUB PAYBACK CHART — BUILT. Each hub's NETWORK ▸ Hubs drawer now shows a
      "HUB P&L" payback line (the Routes `RouteProfitChart` analog): cumulative
      spoke-route net vs the hub's facility cost (establish + club + labor +
      rent), dashed $0 break-even, red-below / mint-above, recoup marker +
      "Recouped in ~N mo" caption. New `Simulation.HubLedger` (per-hub running
      costs + capped monthly snapshots) feeds it — records already-tracked spend
      only, so the cash invariant is UNTOUCHED; persisted nil-safe, legacy/
      acquired hubs backfilled on restore. `HubProfitChart` is theme-aware +
      value-input (Canvas-freeze-safe). Verified 36/36 headless
      (`aa-1.1.x/HubChartMain.swift`) incl. an explicit climbing-to-recoup
      series, + live in the Simulator both themes. See CLAUDE.md "HUB PAYBACK
      CHART". NOTE: an unattended/crew-starved run shows the line descending
      (honest depiction of a starved hub); a well-crewed flying fleet climbs.

## Playtest feedback batch (designer, post-build-18 playtest)

Done this session:
- [x] BUG: sim kept progressing after QUIT-to-menu (milestone toasts over the
      saved-game screen) and background time drained as catch-up ticks on
      resume. Fixed: `Simulation.isPaused` (QUIT/menu/background pause, zeroes
      the accumulator) + a 250ms per-wake delta clamp in `run()` so real time
      away from the app NEVER becomes sim time.
- [x] Fleet status boxes (Total/Flying/Idle/Grounded) are tappable FILTERS on
      the fleet list (selection ring in the box's colour; tap again or tap
      Total to clear; empty-filter hint). Verified live.
- [x] Aircraft-detail leg-progress bar rides a little airplane icon at the
      fill tip (Current Status bar only; airframe-life bar unchanged).
      Verified live.
- [x] Route Opportunities: sampled from each tier's top-8 pool instead of a
      deterministic top-2, so new games stop showing the identical markets.

Queued (bigger, not started):
- [x] REGION SELECTION — BUILT. Naming screen gained "WHICH REGION DO YOU
      WANT TO START IN?" (7 chips, designer wording/order, NA default).
      Airline.PlayerRegion maps 7 choices onto the 10 internal regions (NA =
      us+canada+mexico; Asia folds middleEast; Oceania = South Pacific).
      Simulation.homeRegion (persisted; legacy saves -> NA) drives: default
      map framing (Simulation.frame(for:) — NA keeps the proven CONUS frame,
      others = padded bounding box of region airports), spare bases
      (homeBaseAirports = home airports INSIDE the frame, generalizing the
      old ANC/HNL visibility rule), route opportunities, and airport
      recruitment offers (all conusAirports uses replaced). Verified 57/57
      headless (pools/frames/spares/opps/persistence per region) + live
      (Europe start frames Europe). Focus not fence: flying anywhere still
      allowed.
- [x] LEISURE DESTINATIONS — BUILT. 26 new airports (343 total): Hawaii
      neighbors LIH/OGG/ITO/KOA, US-territory SJU/STT, 18 Caribbean primaries
      (NAS PLS GCM EIS AXA SXM SBH ANU SKB DOM UVF SVD GND BGI AUA CUR BON
      POS), MLE Maldives, SEZ Seychelles — plus existing MRU/NAN/PPT marked
      leisure (29 leisure codes in Airport.leisureCodes; CUN/CZM/SJD/PVR
      deliberately not yet). Real lat/lon + runways/passengers; fees are
      tier ESTIMATES. Both designer mechanics: leisure fare premium ×1.15
      (rollRevenue) and leisure route-opening premium ×1.75
      (routeOpeningCost — flows to the confirm panel + slot buybacks
      automatically). Regions: Caribbean -> centralAmerica carriers
      (SJU/STT stay US, like GUM); MLE -> asia; SEZ -> africa. SBH (2,119ft)
      + EIS (4,642ft) keep their REAL runways -> jet-unservable, matching
      reality (turboprop future hook). Verified 75/75 headless (uniqueness,
      regions, exact ×1.75, revenue + invariant, runway blocks, Central
      America start spans the Caribbean) + live map check.
- [x] HUBS & CLUBS — BUILT (all phases, one pass; spec:
      `HUBS_AND_CLUBS_SPEC.md`). Sim core (Hub struct, eligibility at 5
      routes, establish/club costs from real airport pax, monthly labor +
      rent billing, UNDERSTAFFED suspension, $0 decommission, rival
      buyout offer -> permanent rival hub), all economic hooks (12%/spoke
      demand at the hub, fee discounts, MX/crew-rest bases, fortress
      -50% / rival +50% competitor entry, club +6% yield + rep floor +
      share floor + FFR liability, slot-premium waiver), persistence
      (optional fields, legacy-safe), and 5 UI surfaces (airport-card
      actions, map badges, Ops box, Finance rows, Alerts offer card).
      Verified: 70/70 hub suite + 3,100/3,100 economy regression + 9
      visual fixtures + autopilot balance A/B (see CLAUDE.md).

## In progress

- [ ] The full system — fleet, airports, economy, route network, leasing,
      the used-aircraft market, crew, airline identity — has NOT been
      playtested as one continuous session. Every individual piece has
      been spot-checked or numerically verified, but that verification
      has a long, real, DEMONSTRATED catch rate at this point, not a
      theoretical one: the `operatingCost` ReferenceError, three separate
      instances of the same panel-flicker bug, a lease-proration bug that
      made leasing nearly dominant, a phantom-crew-family bug, background
      traffic generating real player decisions, crew duty time never
      actually accumulating across flights, decision cards going stale
      when resolved outside their own buttons, and aircraft color/flight-
      path rendering bugs that only became visible through actual play —
      all shipped once, all only caught after the fact (through a bug
      report or a direct question), none caught by the verification that
      shipped them. This is still the single most valuable next step
      before adding more scope — see `CLAUDE.md`'s Open section for the
      full reasoning.

## Phase 0 — DONE (native project foundation)

- [x] Create real Xcode project shell on a Mac — SwiftUI + SwiftData
      template, `AirlineArchitect/AirlineArchitect.xcodeproj`. Builds clean on the iPhone 17
      Pro simulator (`** BUILD SUCCEEDED **`), launches to the template's
      placeholder to-do UI. Verified via `xcodebuild` + simulator launch.
- [x] Decide SwiftData vs Core Data — SwiftData (kept the template's
      choice; matches the CLAUDE.md "leaning SwiftData" call).
- [x] Confirm min iOS version — set to iOS 18.0 across all three targets
      (was 26.5 from the template default). Nothing in the port needs
      26-only APIs, so 18 maximizes reach at no technical cost.
- [x] Figma → SwiftUI pipeline — PROVEN and used across the app (was
      stale-unchecked). `get_design_context` returned STRUCTURED React/Tailwind
      + tokens (NOT the raster the icon-node caveat feared) for full-screen
      mockups; adapted by hand to SwiftUI on the naming screen, NetworkView,
      Fleet, Crews, Ops, tab bar, and the panel-restyle batch. See CLAUDE.md
      "Figma-to-code workflow that worked".

## Phase 1 — DONE (port the validated tick engine)

- [x] One aircraft flies one route in SwiftUI on the SAME state machine /
      tick durations as the JS prototype, ported verbatim. Verified in the
      simulator: SKY001 flies SFO→JFK and back (origin/dest swap each
      cycle), phase colours track the real flight phase (green climb / blue
      cruise / amber descent / amber ground), tick timing matches exactly
      (142 ticks in 7s at 5× = the prototype's 50ms/tick). Files under
      `AirlineArchitect/AirlineArchitect/Sim/` + `MapView.swift`; async tick loop
      (`Simulation.run()`) decoupled from render, BASE_TICK_MS=250.
- Two real bugs caught by watching it run, not by the build:
  1. Aircraft frozen at the launch frame while the HUD advanced. Root
     cause: `MapView`'s only stored property was the `sim` reference
     (never changes), so SwiftUI diffed it as identical every tick and
     skipped re-invoking its body — the Canvas never redrew. Fixed by
     passing `tick` in as a changing VALUE input. See CLAUDE.md's new
     native-port section — this WILL recur on every new Canvas/panel view
     in Phase 2+, it's the SwiftUI analog of the prototype's per-tick
     panel-flicker bug family.
  2. `node --check`-style "it compiles" proved nothing here either — the
     freeze was a runtime/observation bug a clean build said nothing
     about. Same lesson as the prototype's `operatingCost` ReferenceError:
     build success ≠ correct behaviour; drive it in the simulator.

## Phase 2 — mostly DONE (multi-aircraft + fleet types)

- [x] Scale to full fleet. Verified: 250 aircraft render and tick at the
      full ~20 ticks/sec (5×) in the simulator, no drops. Fleet-size
      control (10/60/120/250) in the HUD.
- [x] Port AIRCRAFT_TYPES — 30 real variants / 15 crew families, verbatim,
      with real-world-proportional weighted spawn (`pickWeighted`) and
      BodyType tiers (`AircraftType.swift`). 48-airport network ported too
      (`Airport.swift`), with `randomPair()` routing.
- [x] The 4 real icon tiers — real Figma vector paths render via a small
      SVG-path parser (`SVGPath.swift` + `AircraftIcon.swift`), scaled per
      tier and oriented by heading, replacing the placeholder triangles.
      Verified in-sim: recognizable aircraft silhouettes, tiers distinct
      by size. See CLAUDE.md native-port section.
- [x] Economy layer (deferred out of Phase 2, done with Phase 5) — BUILT
      (was stale-unchecked): distance-based fare × demand-model load factor,
      real per-flight operating cost at turnaround, and the randomized
      economic-event system (Oil Spike / Fuel Drop / Boom / Recession + the
      16-event external system). See CLAUDE.md "Decided — Economy".

## In progress (Phase 3 — crew / AOG / weather)

- [x] Weather ground-stops + holding pattern + rejoin easing. Ported
      tickWeather() (per-airport onset from real groundStopsPerMonth,
      90–330 tick duration) + the departure/arrival hold gating in
      Aircraft.advance() + the holding-pattern orbit and REJOIN smoothstep
      in Aircraft.position(). Held aircraft render red; ground-stopped
      airports get a red ring. Verified in-sim with a temporary forced ATL
      ground stop: approaching aircraft held red and orbited the fix,
      desynced per-tail. (Rejoin easing is a verbatim port but wasn't
      visually caught — it only fires when a stop lifts.)
- [x] AOG onset + clustering + the player-decision card system. Onset is
      the calibrated continuous probability (2/100 aircraft/month ÷
      ticks/month), family clustering (3× same-family risk, 3-sim-day
      linear decay, no cross-contamination). Maint aircraft hold at the
      PARKED gate (in-flight aircraft land first), render red, and push
      ONE decision card: Expedite ($15,000, ready now) or Standard
      ($3,000, ~3hr timer). Sim never pauses for cards. Verified TWO ways:
      a headless test harness compiled from the actual app sources (16/16
      checks: hold, single-card push, both resolution paths + charges,
      timer auto-clear + return to service, orphaned-card cleanup on
      fleet shrink, onset-rate statistics) + visual card check in-sim.
      NOTE: applies to the whole stress-test fleet for now — ownership
      (Phase 5) must re-scope this to purchased aircraft only, exactly
      the retrofit the prototype documents getting wrong once.
- [x] Crew pools per family + duty/rest (FAA Part 117) + boarding-gate
      gating + CREW cards. Duty accrues ACROSS flights, resets only after
      a completed 600-tick rest (the corrected version — verified: duty
      reached 926 before rest). Aircraft hold red for a legal crew, push a
      CREW card (Call reserve $5,000 / Wait). Tooltip now shows the crew
      duty-hours row. Balance TUNED via a headless sweep: 1.8 crews/tail is
      the duty/rest break-even and CASCADES into a fleet-wide jam; locked
      2.1 for occasional, recoverable holds. Verified: 12/12 headless
      lifecycle checks + a balance probe (steady, no cascade) + in-sim
      (cards, red holds, tooltip crew row). Pre-ownership stand-in — Phase 5
      swaps to player-driven crew (same scoping debt as AOG).

## Phase 3 — COMPLETE (crew + AOG + weather all ported & verified)
- [x] Aircraft tap-tooltip (hover has no touch equivalent — tap-to-select
      with a highlight ring, tap empty map to dismiss). Field order per
      the documented designer decision (Route → Tail → Type → Status →
      Cycles); crew legal-hours and economy rows have marked slots in the
      layout for when those systems land. DESIGN decision (designer
      confirmed): functional dev-aesthetic now, single coherent Figma
      restyle of ALL surfaces in Phase 4 when the data behind them is
      real. Verified: headless hit-test checks (4/4 — exact hit,
      tolerance, miss, nearest-wins) + visual in-sim (ring + card).
- Note: with no ownership yet (Phase 5), AOG/crew/decisions will apply to
      the whole stress-test fleet for now; ownership-scoping comes later
      (see CLAUDE.md — the prototype had a real bug from that retrofit).

## In progress (Phase 5 — economy)

- [x] Per-flight economics (slice 1). Real revenue (pax × fare, rolled at
      scheduling so a hold erodes it), real operating cost (per-bodyType
      stage length × cost/tick), real fees (weight-based landing + body-type
      gate). Tooltip now shows LOAD + REVENUE/FEES/OP COST/NET-per-leg;
      HUD shows running net. Verified: 13/13 headless (fee/revenue/cost vs
      hand-math, load ≈ 0.838, fleet net-positive +$10.4M/4000 ticks,
      ledger identity) + in-sim (787 leg: $143k rev − $1.6k fees − $96k op
      = $45.7k net, matches). `costPerHour` added to all 30 types.
- [x] Economic-event system (slice 2). Oil Spike / Fuel Drop / Boom /
      Recession, scheduled once per sim-day (15% chance, 3–10 days), one at
      a time, modulating cost/fare/load. HUD banner (red=hurts,
      green=helps) with live multipliers + days left. Verified: 6/6
      headless (events fire, all 4 kinds, return to normal) INCLUDING the
      emergent property — under an oil spike the A340 goes net −$45,619
      while the A320 stays +$6,524 (fell out of the math for free) — plus
      in-sim banner check.
- [x] Ownership + route network (slices 3+5, the FULL SHIFT). A fresh
      session starts EMPTY: $20M, zero aircraft, zero routes. Buy
      aircraft (ACQUIRE panel, affordability-gated), which sit as idle
      spares; OPEN ROUTE via tap-origin → tap-dest → confirm (real cost =
      base + gate fees + slot premium; abstract slot scarcity per airport);
      the assigned owned aircraft flies the route (A↔B) and its net feeds
      playerBalance + route P&L. Owned aircraft fly ONLY opened routes;
      the FLEET buttons became a DEV stress-test toggle (non-owned
      background traffic). Crew/AOG/SELL now scoped to purchased aircraft
      (the retrofit the prototype documents). Cycle-based SELL decision +
      linear depreciation (5% floor). Verified: 23/23 headless
      (buy→spare→openRoute→fly→earn, scoping, shrink-protects-owned) +
      full in-sim loop ($20M → buy → open SLC↔RDU → balance grows as it
      flies). Airport tap tolerance set to 44pt (fingertip-sized).
- [x] Leasing + used-aircraft market (slice 4) — BUILT (was stale-unchecked).
      15% upfront + fixed monthly lease obligation (billed regardless of
      utilization); buy-only persistent used market priced off the same
      depreciation curve as sell value. See CLAUDE.md "Leasing + used-aircraft
      market — DONE".
- [x] Competitor airline identity (slice 6, competitor half). Background
      (non-owned) traffic now carries a real US-market-share-weighted
      airline (Airline.roster — 21 carriers + Independent Operator fallback)
      with SPECIFIC per-type eligibility (Southwest 737-only, Delta no
      Boeing widebodies, A340→Lufthansa, etc.). Competitor aircraft render
      in constant #D767FF (instantly "not mine"); their tooltip shows the
      airline + reduced fields (route/tail/type/status only — no rival
      books). The old dev "TEST" toggle is now a player-facing "TRAFFIC"
      control. Verified: 6/6 headless (every type resolves, eligibility
      respected, Big Four ~68%) + in-sim (purple fleet, "American Airlines
      · 777-300" tooltip). NOTE: Southwest under-represented overall (~6%
      vs 18%) because airline is picked AFTER type and Southwest is
      737-only — a faithful artifact of the prototype's type-first model.
- [x] Player airline NAMING — first Figma-built screen. First-launch modal
      (blocks the game until named; blank → "New Airline"), built to the
      designer's Figma (SkyOps-Production 1:2 light / 1:456 dark),
      theme-aware, colours/spacing ported from the Figma tokens. The
      Airline Architect winged logo renders NATIVELY from the Figma SVG (7 paths, via
      the existing SVGPath parser) — no bundled raster. playerAirlineName
      shows (green) as the header of the player's own aircraft tooltip.
      Verified in-sim (light + dark match Figma; launch → game, blank
      defaults). FONT NOTE: design uses Karla + Geist (not on iOS),
      approximated with the system font at matching weights — bundle the
      real families for pixel-exact type if wanted.
- [x] ROUTES panel (list/detail P&L view) — BUILT (was stale-unchecked).
      List (open+closed, newest first) → detail with full P&L + capped
      recent-flights log + the `RouteProfitChart`. See CLAUDE.md
      "ROUTES P&L panel — DONE" / "Profitability CHART — DONE".

## Blocked

- [ ] Nothing currently blocked.

## Done — original scaffold

- [x] Fleet composition + aircraft type costs researched and sourced
      (real 2025-26 public data, not invented numbers)
- [x] Crew type-locking + per-family pools designed and validated
- [x] Repo scaffolded: README, CLAUDE.md, ROADMAP.md, this file
- [x] swiftui-pro / swift-concurrency-pro / swiftdata-pro skills reviewed
      (MIT-licensed, real content, not stubs) and installed for chat-session use

## Done — fleet expansion

- [x] Browser JS prototype validated: tick engine, multi-aircraft scaling,
      crew rest, weather, AOG (calibrated + clustered), hover tooltips,
      speed controls. See `prototype-reference/`.
- [x] Fleet expanded from 6 types / 4 crew families to 31 types / 13 crew
      families — every real named variant (A319/A320/A321 ceo+neo,
      737 NG+MAX, E-Jets, CRJ, ERJ, A220, 4-engine widebodies, ARJ21) as
      its own entry, crew pools following real type-rating groupings
      (coarser than the type list — E-Jets notably split into TWO crew
      families despite one marketing name). Fleet spawn weights are
      real-world-proportional (sourced global in-service fleet counts).
      Sukhoi Superjet 100 was later removed (reasoning not documented,
      see `CLAUDE.md` Open section).
- [x] 4 real Figma-sourced vector icon tiers (regionalJet, narrowbody,
      widebody2Engine, widebody4Engine), replacing the generic fallback
      triangle. Sized +15% from original ship values per designer
      feedback; relative hierarchy verified by script after the change.

## Done — map + geography

- [x] Real lat/lon-based airport positions (equirectangular projection),
      replacing hand-placed x/y coordinates.
- [x] Airport network expanded from 7 placeholder airports to 48 real
      U.S. airports (top-50 by fee, minus 2 cross-batch duplicates),
      each with real landing/gate fees and ground-stop rates.
- [x] Real U.S. nation outline + state borders (Natural Earth data via
      `us-atlas`), including Alaska and Hawaii (added after an initial
      gap where those two states had no landmass shape).
- [x] Canada added as a muted background-context layer (`world-atlas`
      npm package — new dependency) so Alaska doesn't read as a
      disconnected blob in empty ocean space.
- [x] Pan (drag) + zoom (scroll wheel, cursor-anchored) camera system —
      the desktop-appropriate equivalent of pinch-zoom, built as real
      reusable infrastructure (not a continental-only patch) since the
      designer's stated direction is an eventual global map.
- [x] Airport dot / label sizing and aircraft icon sizing both tuned
      through real designer feedback iteration: v1 (airports fully
      zoom-invariant, aircraft fully zoom-proportional) -> v2 (both share
      one damped curve -- flat until default zoom, then capped at +15%
      growth at max zoom).
- [x] Label decluttering for close-together airport clusters (leader
      lines + fan-out), generic over whatever's in the airport list --
      automatically picked up new clusters as the network grew to 48.

## Done — economy

- [x] Real per-flight revenue formula (seats x load factor x average
      fare per seat, real 2025-26 sourced baselines), replacing an
      arbitrary random-range placeholder.
- [x] Real per-flight operating cost, charged on every flight (not just
      held ones) -- required fixing a real design bug where cost spikes
      had paradoxically been making the airline MORE profitable net-net.
- [x] Randomized economic events (Oil Price Spike, Fuel Price Drop,
      Economic Boom, Recession) with real-anchored magnitude, modulating
      cost/fare/load together.
- [x] Real weight-based landing fees and body-type-tiered gate fees,
      replacing flat per-airport placeholders.
- [x] Financials UI rebuilt as a stacked ledger (Revenue / -Operating
      Costs / -Fees / =Net Revenue) instead of a single formula string;
      same breakdown surfaced in the aircraft hover tooltip.
- [x] A real ship-blocking bug (`ReferenceError: operatingCost is not
      defined`, firing on most flights) was caught and fixed after a
      refactor left one reference unmigrated -- this changed the
      project's verification practice going forward (see `CLAUDE.md`
      Economy section): `node --check` alone doesn't catch undefined-
      variable references, only actual parse errors. An ESLint
      `no-undef` pass now runs alongside it before anything ships.

## RESOLVED — these "beyond current scope" items are ALL BUILT now (list was stale)

This section listed 4 items as "not yet started." A code check (2026-07-22 session)
found every one is shipped — this is the TASKS.md drift the file's own header warns
about. Corrected to `[x]` with code pointers so it stops misleading; do NOT re-open
these as pending work.

- [x] Player-funded route marketing — BUILT as the per-route ad-campaign /
      fare-war / loyalty-push levers on each Ops "Competition" row
      (`startFareWar` / `launchAdCampaign` / `startLoyaltyPush`, Simulation.swift;
      `totalMarketingSpend` joined the Finance cash invariant). 22/22 headless.
      See CLAUDE.md "PLAYER COMPETITION ACTIONS — BUILT".
- [x] Airport-incentive-offer mechanic — BUILT as the `.airportOffer` recruitment
      offer: waived opening cost + signing bonus, a 14-day fulfillment deadline,
      and bonus clawback on forfeit (`incentiveWaived` / `incentiveBonus` /
      `fulfillByTick`, Route.swift + Simulation.swift). See CLAUDE.md
      "#18 AIRPORT RECRUITMENT OFFER — DONE".
- [x] Route profitability chart — BUILT as `RouteProfitChart`
      (ContentView.swift:800, used at :758 with a changing-value `flights:` input;
      the documented model for HubProfitChart). Verified live. Only pending: an
      OPTIONAL Figma restyle (it's hand-drawn in the dev aesthetic). See CLAUDE.md
      "Profitability CHART — DONE".
- [x] Bankruptcy / negative-balance consequences — BUILT: a 14-sim-day insolvency
      grace countdown → `forcedLiquidation()` (sells owned-outright most-valuable-
      first, then hands back leases) → `isBankrupt` GAME OVER via `GameOverView`
      (`insolventSinceTick` / `bankruptcyGraceTicks` / `tickSolvency`,
      Simulation.swift). See CLAUDE.md "Bankruptcy / failure state — BUILT".

## Done — fleet lifecycle & ownership economy

- [x] Bombardier CRJ700 removed from the fleet (aging out of most real
      fleets, nearing retirement, per designer direction) — 30 types now.
      Designer has stated an ongoing intent to keep the fleet current
      with real deliveries/retirements; expect more changes like this.
- [x] Real `purchasePrice` added to every type — median of designer-
      sourced published list price and estimated market value, or a
      documented discount-ratio extrapolation where only one figure
      existed (regional-jet vs. narrowbody discount ratios differ
      meaningfully, ~0.66 vs ~0.46 — handled per-category, not blended).
- [x] Real `expectedLifespanCycles` added to every type — real FAA/
      manufacturer Design Service Goal data for well-established
      families, extrapolated from a confirmed real figure for regional
      jets lacking published data.
- [x] Cycle-based lifespan mechanic: 1 cycle = 1 completed flight,
      tracked per aircraft, 80% threshold triggers a real sell decision
      through the same AOG/CREW decision-card system.
- [x] Real sell mechanic: linear depreciation from purchase price,
      floored at 5%, verified against a designer-specified example
      before shipping.
- [x] Real buy mechanic: a minimal stand-in `playerBalance` (accumulates
      net flight revenue + sell proceeds — explicitly NOT the full Phase
      5 economy), a Buy Aircraft panel listing all types with live
      affordability, purchased aircraft starting genuinely fresh (0
      cycles, PARKED).
- [x] A real bug caught before it could destroy a player's purchase: the
      stress-test fleet slider's old truncation logic would have
      silently deleted purchased aircraft. Fixed by protecting purchased
      aircraft from slider shrinkage; verified numerically including the
      extreme case.
- [x] A real bug fixed after being reported: the decision panel (AOG/
      CREW/SELL) flickered and unreliably registered clicks, caused by a
      per-tick full DOM rebuild. Fixed by removing the redundant per-tick
      render call — the two structural triggers (decision added/
      resolved) were already correct and sufficient on their own.

## Done — real starting capital

- [x] Starting capital: $20M, calibrated to cover the cheapest aircraft
      plus a typical route-opening cost with buffer. A fresh session now
      starts with real capital, no planes, no routes, and zero background
      traffic — an actual new-game experience, not a stress-test default.

## Done — leasing

- [x] Real leasing mechanic alongside buying: 15% of purchase price
      upfront (designer-specified), real sourced monthly rate (0.8% of
      aircraft value — industry lease-rate-factor data, cross-validated
      against real quoted dollar figures). ACQUIRE AIRCRAFT panel (renamed
      from BUY AIRCRAFT) shows Buy and Lease as two independent options
      per type.
- [x] A real bug caught mid-build: the first version prorated lease cost
      per-flight (same as operating cost), which made leasing nearly
      strictly dominant — an idle leased aircraft cost nothing, so the
      real downside risk of a fixed obligation was missing. Fixed with a
      genuine recurring-billing mechanism (`tickLeaseBilling()`) charging
      every leased aircraft monthly regardless of flying/idle/held status.
      Verified numerically: an idle leased aircraft now genuinely loses
      money over time with zero revenue.
- [x] Lease cost is a real separate line item in report views (financials
      ledger, route detail panel) but folds into the tooltip's displayed
      "Operating cost" as a smoothed estimate, per designer direction —
      too much detail for the in-flight view.

## Done — real player route network

- [x] The foundational shift: purchased aircraft no longer fly random
      destinations. They fly only between airports the player has
      explicitly opened a route between, swapping direction each cycle.
      An unassigned purchased aircraft is a real idle spare, not wandering
      traffic. Background stress-test traffic is unaffected — still fully
      random by design.
- [x] Abstract airport slot scarcity (no real competitor-airline modeling
      — deliberately deferred, matching `ROADMAP.md`'s existing scope
      decision), scaled to real landing-fee data already in the game.
- [x] Real route-opening cost, built from real data already in the game
      (base fee + both endpoints' gate fees), landing in a real
      $68K-$275K range.
- [x] Route-opening UI rebuilt from dropdowns (which hit the same
      flicker bug as the decision panel) to real click-to-select-on-map:
      click OPEN ROUTE, click origin, click destination, confirm panel
      with live cost/slot data. Basic mobile tap support included.
- [x] Buying/leasing an aircraft while mid-route-selection auto-assigns
      it to the pending route — the whole "realize you need a plane,
      buy one, route opens" flow now completes in one pass. A second
      ACQUIRE AIRCRAFT button lives inside the route-confirm panel itself.
- [x] Deterministic route-economics preview in the route-confirm panel —
      real distance (haversine), revenue/fees/operating cost/net for a
      round trip, using a real spare's actual type if one exists.
- [x] Real per-flight simulated load tracking: the aircraft tooltip shows
      actual pax/seats/load% for the current flight — previously
      computed internally and immediately discarded, now captured and
      displayed.
- [x] Real route-level profitability, weighed against actual
      establishment cost — a route isn't "profitable" until cumulative
      net revenue recoups what it cost to open, not just whenever one
      flight nets positive. Reduced by real lease bills too, not just
      flight economics.
- [x] Full per-flight route history (revenue, fees, costs, load, net,
      cumulative net per flight) — real data, verified sufficient to
      support a future profitability-over-time chart (not built yet).
- [x] Routes are archived, not deleted, when closed — selling a
      route-assigned aircraft used to destroy the route's history
      entirely; now moves to a real archive with a close date stamped on.
- [x] A dedicated ROUTES panel: list view of every route (open and
      closed), tap for full detail (dates, flights flown, financials,
      assigned-aircraft history, recent-flights log).

## Done — crew system rebuilt (twice)

- [x] Crew provisioning changed from automatic ratio-based sizing to
      player-driven hiring. Buying/leasing an aircraft bundles exactly 1
      crew (deliberately not enough for continuous operation); growing
      the pool further requires the new ADD CREW panel with a real
      designed hire cost, scaled by aircraft complexity.
- [x] A real reported bug fixed: crew pools showed a phantom minimum
      ("1/0/0 · 2 res") for every family regardless of ownership. Fixed
      at the root — `resizeCrewPools()` no longer auto-sizes by ratio at
      all, it's a pure cleanup pass now.
- [x] A second real reported bug fixed: AOG, crew-shortage, and
      sell-eligibility decisions were firing for background traffic the
      player doesn't own. Fixed across five functions — background
      traffic now has zero economic/decision stakes, confirmed via
      individually checking every other fleet-wide loop in the codebase
      to make sure this wasn't a sixth instance hiding somewhere.
- [x] Reserve crew count corrected: 1 per family (not 2) — a family's
      first aircraft should grant 2 crew total (1 bundled + 1 reserve),
      not 3.
- [x] Background traffic given a distinct color scheme, reduced hover
      tooltip (Route/Tail/Type/Status only — no performance data). NOTE:
      the color scheme changed twice after this — first blue/orange
      (flying/ground) vs. the player's green/amber, later simplified to
      one constant color (`#B25BFF`) regardless of state. See the
      rendering-fixes batch below for the current, correct version —
      this entry is kept for history, don't treat "blue/orange" as
      current.
- [x] A real, substantive bug fixed after direct questioning, not a bug
      report: crew duty time never actually accumulated across flights.
      `dutyTicks` was reset to 0 on every new assignment, meaning a lone
      crew member could fly indefinitely without ever hitting real rest
      (a single flight cycle is well under the duty ceiling). Fixed to
      match real FAA Part 117 mechanics — duty time now carries across
      consecutive assignments, only clearing after an actual completed
      rest period. Also caught and corrected in the same pass:
      `REST_TICKS` was wrong (480/8hr), not just simplified — real Part
      117 minimum rest is 10 consecutive hours. Verified via simulation:
      a lone crew member now flies exactly 2 consecutive cycles before
      mandatory rest blocks a third.

## Done — decision panel fixes

- [x] A real reported bug: decision cards went stale when resolved
      through a path OTHER than that card's own buttons (hiring crew via
      ADD CREW while a CREW hold was showing). Root cause affected AOG's
      timed auto-repair too, caught by checking rather than assuming the
      fix was narrowly scoped. Fixed with a real cleanup function called
      from both actual resolution points.
- [x] CREW decision now has a real third option, "Hire new crew" —
      reuses the same `hireCrew()` function as the standalone panel, not
      a duplicate implementation.

## Done — used aircraft market

- [x] Real used-aircraft market: buy-only, persistent inventory (1-2
      listings per type, generated once, slowly replenished over time).
      Pricing reuses the exact same linear depreciation formula as the
      sell mechanic, per designer direction for consistency. Real market
      research behind it: a genuine $1.96B+ industry segment, real
      depreciation curve cross-checked against an actual Boeing 737-800
      example. Verified end-to-end with the real extracted functions —
      listing generated, purchased, balance deducted exactly, the
      resulting aircraft correctly inheriting the used cycle count
      instead of starting fresh.

## Done — rendering fixes

- [x] A real reported bug: flight-path arcs looked disproportionately
      curved on short routes. Root cause was a fixed 90px arc height
      regardless of actual distance between airports. Fixed to scale
      with real distance (12% of straight-line distance, floored at
      15px, capped at 120px) — verified numerically.
- [x] A real reported bug: aircraft color stayed in the wrong flight-
      phase color too long, both at takeoff and landing. Root cause:
      color was picked from an altitude THRESHOLD that never actually
      lined up with the real state machine (TAKEOFF's altitude curve
      never even crosses the old threshold; APPROACH stayed above it for
      ~71% of its duration). Fixed to key color directly off the real
      state instead — three real colors for the player's own aircraft
      (takeoff/climb, cruise, descent/landing), applied the same
      state-based fix to background traffic too for the same accuracy
      reason.
- [x] Background traffic's color simplified to one constant color,
      replacing an earlier two-tier scheme from the same session — makes
      it instantly recognizable as "not mine" regardless of flight
      phase. NOTE: this value was tweaked again later in the same
      session (`#B25BFF` -> `#D767FF`, "wasn't popping enough") — see the
      color-tweaks batch below, don't treat `#B25BFF` as current.

## Done — airline identity & competitor traffic

- [x] Player airline naming: a styled modal blocks the game on load,
      asking the player to name their airline. Shown as the first line
      in the player's own aircraft tooltip.
- [x] Real-world-weighted competitor airlines assigned to background
      traffic — actual 2025-26 US domestic market share (BTS/OAG/
      Statista, cross-checked across five sources). Original version
      restricted eligibility by aircraft BODY TYPE (narrowbody/widebody/
      etc) — see the REBUILD below, this is superseded, not current.
- [x] Alaska Airlines roster entry updated mid-session for a real,
      independently-verified 2026 news development (absorbed Hawaiian's
      787 fleet, launched real widebody international routes from
      Seattle) — confirmed via search before changing anything, not
      taken on request alone, though it matched.

## Done — fleet-accuracy rebuild, certification gating, A330/A350

- [x] Airline eligibility REBUILT from body-type-category restriction to
      real SPECIFIC-aircraft-type restriction — prompted by a real
      concern ("a player will notice if Airline X doesn't fly type Y").
      Every airline's eligible-types list is now individually researched,
      not a category. Real findings, several of which corrected
      assumptions rather than confirmed them: Delta's widebody fleet was
      100% Airbus (none modeled in this game at the time — see A330/A350
      below); Delta flies no 737 MAX at all; United flies A321neo but no
      A321ceo; JetBlue retired its last E190 in Sept 2025; Emirates flies
      no 787 at all; Lufthansa flies no Boeing 777 passenger service at
      all — but IS confirmed the world's largest A340 operator in 2026
      (14 -300s + 5 -600s, kept flying due to 777X delivery delays), the
      opposite of the "probably retired" assumption made before checking.
      Types with no real match anywhere in the roster (A319neo, E190,
      E195, ERJ135/140, ARJ21) fall to a generic "Independent Operator"
      fallback rather than a forced fake match. Verified via script that
      every type in the fleet resolves to at least one eligible airline
      (no crash risk), and via real 10,000-20,000-sample distribution
      checks that the weighted outcomes match the real sourced
      percentages.
- [x] A new, real design principle: aircraft must be actually FAA/ICAO
      certified AND in real service to stay in this fleet — an order or
      certification-pending status isn't enough. Established by removing
      Boeing 737 MAX 7 and MAX 10 entirely (verified via search: neither
      was certified as of this game's real current timeframe, first
      deliveries not until 2027 even after certification). Same bar then
      applied to Delta's real Jan 2026 787-10 order — confirmed real, but
      deliberately NOT added to Delta's fleet yet since an order isn't a
      delivery.
- [x] Airbus A330-900 and A350-900 added — specifically to give Delta a
      real widebody fleet in this game (their actual widebody fleet is
      100% Airbus). Real sourced specs (MLW, seats matching Delta's own
      cabin config, market-value-based purchase price, not Airbus sticker
      list price). Also added to Air France (both), Lufthansa/British
      Airways/Japan Airlines (A350 only), Air Canada (A330 only) — each
      individually confirmed, not assumed uniform. A real correction
      surfaced while researching this, unrelated to the reason for the
      search: Air France's A380 fleet was fully retired by 2022 and had
      never been re-verified since the original roster build — fixed in
      the same pass.

## Done — color tweaks

- [x] Background traffic color: `#B25BFF` -> `#D767FF` ("wasn't popping
      enough"). Player aircraft cruise color: `#6CD3FF` -> `#83C9FF`
      (better contrast).
