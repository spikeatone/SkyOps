# CLAUDE.md — Persistent Context for SkyOps

Read this before doing anything else. It exists so a new session (different
day, different context window, possibly a different agent) doesn't have to
re-derive decisions that were already made and validated. If you're about to
suggest something that contradicts a "Decided" item below, stop and check
whether there's a reason logged here before overriding it.

This file was substantially rewritten in this session — the fleet grew from
6 types to 32, the map went from an abstract scope grid to a real geographic
projection with actual U.S. airports, fees moved from placeholder numbers to
real sourced data, and aircraft icons moved from a generic triangle to real
Figma-sourced vector art. If you're picking this up cold, don't assume the
smaller original scope — read this whole file, not just skim it.

## What SkyOps actually is

NOT a combat RTS. It's an airline operations/logistics tycoon sim — closer to
Airline Tycoon / Transport Fever than Command & Conquer. Player automates the
boring parts (aircraft fly assigned routes automatically, PAX loads simulated,
revenue collected on arrival) and makes strategic decisions: open/close routes,
hire crew, decide maintenance response, manage fleet composition. In the
shipped game, the player will "buy" the aircraft types they want to fly — the
browser prototype's fleet weights are for sim-testing purposes, calibrated to
match real-world deployment ratios rather than the eventual player-driven
economy (see Fleet section below).

Core tension: **the sim never pauses for disruptions.** AOG and crew-shortage
events surface as decisions the player must resolve, but every other aircraft
keeps flying while they think. This is deliberate and load-bearing — do not
add a global pause button back in. (A dev/QA-only pause is fine; a player-facing
one contradicts the design thesis.)

## Decided — Core Simulation

- **Tick engine**: 1 tick = 1 sim-minute, decoupled from real-time. Speed
  multiplier just changes how often ticks fire; the tick logic itself never
  changes with speed. Speeds: ¼× / ½× / 1× / 5× / 10× / 25×. No pause.
  ¼× is rate-limited: 3 uses per FIXED sim-calendar-day boundary (resets when
  the day-of-sim-clock number changes, not on a rolling 24h window). Exhausting
  it snaps speed to 1×, not back to whatever was active before.
- **State machine per aircraft**: PARKED → BOARDING → TAXI_OUT → TAKEOFF →
  CRUISE → APPROACH → LANDING → TAXI_IN → TURNAROUND → loop. Durations were
  tuned so that PEAK velocity (not just average) matches across phases —
  short states covering large path-distance fractions will visually/mechanically
  "run fast" if you don't check this. See prototype-reference for exact tick
  counts per phase; port them, don't re-guess them.
- **Position interpolation**: waypoint/bezier-arc between airports, NOT real
  pathfinding. Aircraft don't need A*/navmesh — they follow known routes.
  Airport *positions themselves* are now real (see Map section) — this is
  about the curve shape between two real points, not the points' locations.
- **Revenue model**: each flight's revenue is rolled at SCHEDULING time (when
  a route is assigned), not at landing. This is what lets an AOG/crew hold
  erode the actual number a flight will collect — the player watches one live
  number cross from profitable to net-loss, rather than two abstract stats.
  Do not go back to rolling revenue only at landing.
- **AOG frequency**: calibrated to a real anchor (2 incidents/month for a
  ~100-aircraft "large" airline), scaled as a continuous per-aircraft
  per-tick probability — NOT five hardcoded bracket values (that creates a
  cliff at bracket boundaries). Formula: rate/aircraft/month ÷ ticks/month.
- **AOG clustering**: one incident temporarily (3 sim-days, linear decay)
  triples AOG risk for the SAME aircraft family only (real-world analog:
  type-wide issues like an AD or bad parts batch — see the actual 737 MAX
  grounding). Families never cross-contaminate each other's risk.
- **CoreML**: NOT currently justified. This genre runs on deterministic/
  lightly-randomized rule systems, which is what's built. The one place it
  could earn its place is a competitor-airline AI that learns rather than
  follows scripted rules — deliberately deferred, not forgotten. Don't
  introduce it speculatively.
- **GameKit**: deferred, secondary. Leaderboards/achievements layer, not
  core loop. Add later without architectural risk.
- **Task tracking**: `TASKS.md` in this repo, not GitHub Issues. Default
  chosen for zero-setup simplicity given the designer isn't a dev by
  background. Revisit if that becomes limiting.

## Decided — Fleet (rewritten this session, was 6 types / 4 families, now 32 / 14)

- **Fleet size**: 32 distinct playable aircraft types. This is a major
  expansion from the original locked 6 — the "locked" framing on the old
  6-type list no longer applies; that constraint was explicitly reopened by
  the designer this session.
- **Granularity principle**: each real named variant (A319, A320, A321,
  A319neo, A320neo, A321neo, etc.) is its own separate `AIRCRAFT_TYPES`
  entry with its own seats/cost/revenue/MLW — NOT one averaged entry per
  "family." Designer's explicit call: "separate entry per named variant,
  real specs each."
- **Crew-pooling principle — the one that does NOT follow the same 1:1
  granularity**: crew pools follow REAL type-rating groupings, which are
  coarser than the aircraft-type list and don't always match marketing
  "family" names. Concretely:
  - A320 family (ceo + neo, all 6 variants) = ONE crew family
    (`A320_FAMILY`) — real EASA type rating covers ceo and neo together.
  - 737 family (NG + MAX, all 7 variants) = ONE crew family
    (`B737_FAMILY`) — FAA/EASA treat all 737 generations as one type
    rating with differences training between them.
  - A220-100/-300 = ONE crew family (`A220_FAMILY`) — 99% commonality,
    same type rating, despite one being tagged `narrowbody` and the other
    `regionalJet` for icon/fee purposes (see below — these are
    independent axes, not in conflict).
  - **E-Jets split into TWO crew families despite one marketing name**:
    E170/E175 share a type rating (`E170_FAMILY`); E190/E195 require a
    SEPARATE one — different wing, different airframe systems, despite
    Embraer marketing all four as "the E-Jet family." This is the one
    real-world nuance most likely to get silently re-flattened by a
    future session that doesn't read this note — don't merge them.
  - CRJ700/900/1000 = ONE crew family (`CRJ_FAMILY`) — Bombardier
    differences-training model, one base type rating.
  - ERJ135/140/145 = ONE crew family (`ERJ_FAMILY`) — shared type
    certificate.
  - Every 4-engine widebody (747, A380, A340) and every other widebody
    (777, 787) is its OWN separate family — no real-world commonality
    between manufacturers or airframe generations at that size.
  - ARJ21 and SSJ100 are each their own standalone family — no other
    type shares their rating.
  - **Net result: 14 crew families total** (`A320_FAMILY`, `B737_FAMILY`,
    `A220_FAMILY`, `B777`, `B787`, `B747`, `A380`, `A340`, `E170_FAMILY`,
    `E190_FAMILY`, `CRJ_FAMILY`, `ERJ_FAMILY`, `ARJ21_FAMILY`,
    `SSJ100_FAMILY`), covering 32 aircraft types. `CREW_FAMILIES` is
    auto-derived from `AIRCRAFT_TYPES.map(t => t.family)` — adding a new
    aircraft type with an existing family string automatically joins that
    pool, no separate list to maintain. `FAMILY_LABELS` (crew status
    display) is NOT auto-derived — it's a separate hardcoded lookup that
    must be updated by hand every time a new family is added, or the UI
    silently shows `undefined`. This bit twice this session; check it
    every time.
  - `crewsPerTail: 6` was applied to every narrowbody AND every regional
    jet by default. This is a real, UNVERIFIED assumption for the
    regional-jet tier specifically — there's no sourced reason RJs should
    have the same crew ratio as mainline narrowbodies, it just hasn't
    been researched. Revisit if regional-jet crew shortages feel wrong in
    playtesting.
- **Fleet spawn weights are real-world-proportional, not designer
  placeholders** — explicit designer direction: "for sim testing it's fine
  to have a ratio that matches real-world deployment" (the shipped game
  will have players buy their fleet directly, so this doesn't need to be
  the final economy, just realistic for now). Confidence varies by tier:
  - **Well-sourced** (real Wikipedia-cited global in-service fleet
    counts, 2025-26): A320 family 11,374 · 737 family 7,876 · A220 family
    522 · 777 ~1,600 · 787 ~1,000 · 747 (passenger) 427 · A380 ~170 ·
    A340 71. All weights scaled from one anchor: A340 (rarest) = weight 1.
  - **Real but lower confidence**: the SPLIT within the A320/737/A220
    family totals across named variants (e.g., how much of the A320
    family's total weight goes to A319 vs A320 vs A321neo specifically).
    The family-level total is sourced; the intra-family proportions are
    estimated from order-share data and general market knowledge, not
    independently sourced per-variant counts.
  - **Weakest tier**: all 6 regional-jet family totals (E170/E175,
    E190/E195, CRJ, ERJ, ARJ21, SSJ100) are synthesized estimates, not
    directly cited totals like the mainline families above. Plausible,
    not verified — revisit with real sourcing if precision matters here.
  - `TYPE_WEIGHT_TOTAL` is auto-computed via `.reduce()`, not a hardcoded
    number — always correct by construction, don't hand-maintain it.
- **32-type fleet has NOT been visually playtested end-to-end.** Individual
  pieces were spot-checked (the 777/787 icon smoke test, the 4-engine
  widebody icon, syntax/math verification on every weight and scale
  calculation) but nobody has watched a full play session with all 32
  types spawning together. Do this before treating the expansion as done,
  not just implemented.

## Decided — Fees (real data, replacing original flat placeholders)

- **Landing fee**: real signatory rate ($/1,000 lbs of aircraft max landing
  weight) at the destination airport × that aircraft type's `mlwLbs`. This
  is why aircraft of different sizes now correctly pay different amounts at
  the same airport — the original flat per-airport fee couldn't express
  that. `mlwLbs` is set per `AIRCRAFT_TYPES` entry, sourced from public
  type-cert-adjacent data (SimpleFlying/AirInsight/Wikipedia-tier, not
  primary type-certificate documents).
- **Gate fee**: real per-turn rate, tiered by `bodyType`
  (`narrowbody`/`widebody`/`widebody2Engine`/`widebody4Engine`/
  `regionalJet`), sourced per real airport. Fee-tier logic uses
  `WIDEBODY_BODY_TYPES.has(bodyType)` (a Set), NOT a direct string
  comparison to `'widebody'` — the old direct-comparison version broke
  silently the moment 777/787 got reassigned to `'widebody2Engine'` for
  icon testing. If a new widebody-adjacent bodyType string is ever added,
  it must be added to `WIDEBODY_BODY_TYPES` or gate fees will silently
  undercharge that type at the narrowbody rate.
- **Airport network**: the definitive top-25 U.S. airports by landing/gate
  fee, designer-sourced (not the original 7 placeholder airports). Also
  carries real per-airport `groundStopsPerMonth`, replacing one flat rate
  that was previously applied uniformly to every airport.

## Decided — Map (real geography, replacing the original abstract scope grid)

- **Airport positions are real**, not hand-placed. Each airport carries
  real lat/lon; a lightweight equirectangular projection with a longitude
  cosine correction at the map's center latitude (`projectPoint()`,
  shared by airports AND the basemap below so nothing can drift out of
  alignment) converts these to canvas coordinates once at startup, fixed
  to continental-US bounds. NOT a true Albers/conic projection — a
  defensible approximation at this latitude range and scale, not
  survey-grade.
- **Real basemap**: an actual continental-U.S. outline and state borders
  render under the airports (Natural Earth data via the `us-atlas` npm
  package, topology-aware simplified — not hand-drawn). This REVERSES an
  earlier in-session call to keep the map as "projected positions only" —
  revisited once it was clear the primary player-facing UI needed real
  geographic legibility, not just correct relative positions. Rendered
  fresh every frame; cheap at current point count (~1,800 total), but a
  candidate to pre-render to an offscreen canvas if more visual layers
  stack on top later.
- **Label decluttering**: airports genuinely close together at this map
  scale (JFK/EWR/LGA in NYC, MIA/FLL in South Florida) get their text
  labels fanned out with leader lines (`computeAirportLabelPositions()`),
  while their dots stay at true projected positions. This is a stopgap for
  the browser prototype's fixed zoom level — see Open items below
  (pinch-zoom).
- **Airport hover tooltip**: shows live ground-stop status (with time
  remaining if active), on-ground/inbound aircraft counts, and fee
  reference data. Shares the same tooltip DOM element as the aircraft
  tooltip (id is still `aircraftTooltip` — cosmetic naming leftover, not
  worth a rename-everywhere). Aircraft hover takes priority over airport
  hover when they overlap (a PARKED/BOARDING/TURNAROUND aircraft renders
  at the airport's exact position) — this was an explicit default, not
  extensively tested against alternatives.

## Decided — Aircraft Icons (real Figma vector data, replacing the generic triangle)

- **4 icon tiers, all sourced as real SVG path data from Figma** (pasted
  directly as `<path d="...">` strings, not raster images — the Figma MCP
  tool's `get_design_context` only returns flattened raster exports for
  these nodes regardless of query parameters, a confirmed tool-side
  limitation, not a property of the source file): `narrowbody`,
  `regionalJet`, `widebody2Engine`, `widebody4Engine`.
- **Rendering**: each icon is a precomputed `Path2D`, filled with a
  dynamically-set `fillStyle` at render time (red=held, green=flying,
  amber=ground) — this is why real vector paths were necessary instead of
  the raster export; a raster image can't be recolored per-state the same
  way. Icons are recentered and scaled via a per-icon `targetLength`
  (NOT a shared constant) so the real size hierarchy holds:
  regionalJet (7.5px) < narrowbody (9.5px) < widebody2Engine (13px) <
  widebody4Engine (15px). A shared constant was tried first and caused a
  real bug (narrowbody rendering larger than the widebody fallback) —
  caught and fixed before shipping, not after.
- **bodyType now drives THREE independent things** that all happen to
  read the same field: gate-fee tier, on-scope render scale (fallback
  triangle path), and icon selection (`AIRCRAFT_ICON_PATHS` lookup, real
  Figma icon path). Changing what a bodyType string means has
  consequences in all three places — check all three before renaming or
  adding a bodyType value.
- All 4 icon tiers are confirmed visually correct in-browser as of this
  session (narrowbody, then widebody2Engine via the 777/787 smoke test,
  then widebody4Engine via 747/A380/A340). This is real verification, not
  just algebraic transform-math checking — but it was checked type-by-type
  as each was added, not re-verified after the full 32-type expansion.

## Open / not yet decided

- Xcode project shell doesn't exist yet — needs creating in Xcode itself on
  a Mac (can't be done from a Linux sandbox). See ROADMAP Phase 0.
- SwiftData vs Core Data for persistence — leaning SwiftData (iOS 17+) for
  developer-ergonomics reasons, not finalized.
- Figma → SwiftUI pipeline: designer has real mockups in Figma; pull via
  Figma MCP `get_design_context` against actual file/node URLs, don't
  guess at layouts from descriptions. Note the raster-export limitation
  documented above under Icons — full-screen mockups may hit the same
  wall the icon nodes did; verify early rather than assuming it'll work.
- Route competition / competitor airlines: designed to be deferred until
  the core loop is solid in Swift.
- Hub connectivity, reputation, passenger demand curves: named in the
  original design brief, not yet modeled in the prototype or planned in
  detail — bigger systems, deliberately last.
- **Pinch-zoom on the map**: the mobile game is intended to support it.
  Would help with NYC/South Florida label crowding beyond what the
  leader-line declutter fix does (zoom in, labels separate on their own),
  and is no longer blocked on a map-style decision (the real basemap is
  built). Not built in the browser prototype — viewport transform +
  touch/wheel gesture handling is real scope, arguably Phase 4 UI work
  rather than core-loop validation.
- **Regional-jet `crewsPerTail`**: defaulted to 6 (same as narrowbody),
  unverified. Real research not done for this tier specifically.
- **Intra-family fleet-weight splits** for A320/737/A220 families, and ALL
  6 regional-jet family totals: real but lower-confidence data, flagged
  in the Fleet section above. Revisit with dedicated sourcing if the
  designer wants higher precision here.
- **Full 32-type fleet has not been playtested end-to-end** — see Fleet
  section above. This is the single most important thing to do before
  building further on top of the expansion.
- `README.md` is referenced in `TASKS.md`'s "Repo scaffolded" line but was
  never confirmed to actually exist in the repo — flagged once early in
  this project's history, never independently verified since. Check it.

## Working agreement for future sessions

1. Read this file. Read `TASKS.md` for what's actually in flight.
2. If you make a decision that should bind future sessions, ADD it to the
   appropriate "Decided" section above, in the same terse style, with the
   real-world reasoning if there is one. Don't just fix code — update this
   file in the same commit/session.
3. If you find a "Decided" item that's wrong, don't silently override it —
   flag it explicitly, explain why, and update this file to reflect the
   correction with a short note on what changed and why (see the map
   basemap reversal above for the pattern: state that an earlier call
   changed, not just what's true now).
4. The prototype-reference numbers (tick durations, AOG rates, crew ratios,
   revenue ranges) came from real back-and-forth tuning or real-world
   sourcing, not arbitrary placeholders — EXCEPT where explicitly flagged
   above as an estimate (regional-jet weights, intra-family splits,
   regional-jet crewsPerTail). Port faithfully; don't casually re-round
   "for cleanliness," and don't upgrade a flagged estimate to treated-as-fact
   without actually sourcing it.
5. This file has drifted badly out of sync with the actual code multiple
   times in a single session before (five distinct gaps accumulated before
   this rewrite: fee model, map position source, label clustering, real
   basemap, and the fleet expansion). If you make a code change that
   contradicts something written here, update this file in the SAME
   response, not "later" — later is how the drift happened the first time.
