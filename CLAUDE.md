# CLAUDE.md — Persistent Context for Airline Architect

Read this before doing anything else. It exists so a new session (different
day, different context window, possibly a different agent) doesn't have to
re-derive decisions that were already made and validated. If you're about to
suggest something that contradicts a "Decided" item below, stop and check
whether there's a reason logged here before overriding it.

This file has been substantially rewritten and updated multiple times
across sessions — the fleet peaked at 32 types then settled to 30 (two
real-world-driven removals, Sukhoi Superjet 100 and Bombardier CRJ700, per
designer direction to keep the fleet current with real deliveries and
retirements — expect this number to keep moving), the map went from an
abstract scope grid to a real geographic projection with pan/zoom and
actual U.S. airports (plus Alaska, Hawaii, and Canada for context), fees
and revenue moved from placeholder numbers to real sourced data with a
working economic-event system, aircraft icons moved from a generic
triangle to real Figma-sourced vector art, and a real, playable ownership
economy now exists — cycle-based lifespan, selling, buying, leasing, AND
a real used-aircraft market, a genuine player route network (aircraft fly
real routes the player opens, not random destinations), real starting
capital, a crew system rebuilt twice in one session (first from
ratio-auto-sizing to player-driven hiring, then to fix duty/rest time not
actually accumulating across flights), and — most recently — a real
player airline identity plus real-world-weighted competitor airlines on
background traffic, alongside a round of rendering fixes (flight-path
arcs that scale with real distance instead of a fixed pixel offset, and
aircraft color tied to actual flight phase instead of an altitude
threshold that never lined up with it). Most recently: the competitor
airline roster was rebuilt from body-type-category eligibility to real
SPECIFIC-aircraft-type eligibility (researched per-airline, with several
real corrections found along the way — Delta's all-Airbus widebody
fleet, Lufthansa turning out to still be the world's largest A340
operator, Air France's A380 retirement), a new "must be actually
certified and in service, not just ordered" principle got established
(737 MAX 7/10 removed from the fleet entirely; Delta's real Jan 2026
787-10 order deliberately NOT added yet for the same reason), and the
Airbus A330-900/A350-900 were added specifically to give Delta a real
widebody fleet in this game for the first time. If you're picking this
up cold, don't assume the smaller original scope — read this whole file,
not just skim it. If you're the one updating this file next, note that
comments and counts elsewhere in this codebase have gone stale between
updates more than once already (see the `TYPE_WEIGHT_TOTAL` stale-comment
note in the Fleet section for a concrete example) — spot-check numbers
against the actual code rather than trusting a prior description at face
value, including the numbers in THIS file. Also note: the SAME flicker/
dropped-click bug (a panel re-rendering on every tick instead of only on
real state changes) has now been independently discovered and fixed
THREE separate times in this codebase (decision panel, route-picker
dropdowns, buy/lease panel) — if a fourth panel shows this symptom, don't
apply a fourth one-off fix, see the note in the Fleet Lifecycle section.

## What Airline Architect actually is

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

## Decided — Fleet (rewritten this session, was 6 types / 4 families, now 30 / 15)

- **TURBOPROP TIER — ADDED (designer supplied Figma side-view art). 35 types
  now (was 31).** A brand-new `BodyType.turboprop` (the first non-jet
  body-type) with FOUR types: **Beechcraft 1900D** (`B1900`, 19 seats,
  $2.5M — out of production, cheap used), **ATR 42-600** (`AT46`, 48 seats,
  $18M — in production, the EIS-class workhorse), **Dornier 328-110** (`D328`,
  33 seats, $4M), and **De Havilland Dash 8-200** (`DH8B` — its real ICAO
  type code — 39 seats, $4.5M, the designer's Twin-Otter stand-in). Each is its
  OWN crew family (`B1900_FAMILY` / `ATR42_FAMILY` / `D328_FAMILY` /
  `DASH8_FAMILY` — real distinct type ratings; FAMILY_LABELS + CREW_FAMILY_INFO
  hand-updated). The tier default `BodyType.turboprop.minRunwayFt = 3400` serves
  short regional/island fields jets can't (EIS 4,642 ft). **The Dash 8 is the
  SHORTEST-FIELD aircraft** via a new per-type override
  (`AircraftType.minRunwayFtOverride`, read by the runway gate as
  `type.minRunwayFt`): `DH8B` = 2,000 ft, so it's the ONLY type that can serve
  **St. Barths (SBH 2,119 ft)** — the shortest field in the game. (Real Dash 8-200
  needs ~3,000 ft; 2,000 is a deliberate gameplay stretch since it's the
  Twin-Otter/DHC-6 stand-in the designer couldn't source. A true DHC-6 would go
  lower still.) The other three turboprops keep the 3,400 default, so SBH is a
  genuine Dash-8-exclusive unlock.
  All the derived BodyType switches got a turboprop case (iconLength 8.5,
  block-minutes 55, fare $150, cruise 4.6 nm/min ≈ 275 kt); `usesWidebodyGateFee`
  is false so they pay the narrowbody gate tier. **Map icon is a PLACEHOLDER** —
  reuses the regionalJet top-down silhouette (no turboprop glyph exists); the
  side-view Marketplace/Fleet art is real (Resources/Illustrations/{B1900,AT46,
  D328,DH8B}.png). **FIGMA-EXPORT GOTCHA (bit us once):** `download_assets`'s
  `export` PNG bakes in the frame's GRAY BACKGROUND (opaque) — the aircraft art
  shipped with a gray box the first time. The fix: use the `rawImages` entry
  instead (the transparent source fill, `raw_image_1`, already 1024px-wide and
  alpha-0). For any future Figma illustration pull, grab the RAW image, not the
  node export. Not in any
  competitor roster's `types` list → background traffic resolves them via the
  Independent Operator fallback (realistic — regional turboprops = small
  operators). Verified 29/29 headless (types resolve, families labeled, runway
  gating serves EIS but blocks SBH, buyable + in-range route) + live Marketplace
  (Beech 1900D + Dornier 328 render with correct specs, buy/lease/used rows,
  auto-generated used listings).


- **Fleet size**: 31 distinct playable aircraft types (native-app era).
  Running history: 32 (initial big expansion) -> 31 (Sukhoi Superjet 100
  removed) -> 30 (Bombardier CRJ700 removed — aging out of most real fleets,
  nearing retirement, per designer direction) -> 28 (737 MAX 7 and MAX 10
  removed — see the new "not yet certified" principle below) -> 30 (Airbus
  A330-900 and A350-900 added — see the new Airline Identity section for why)
  -> 31 (Boeing 787-10 Dreamliner added, id `B78J`, B787 family — a widely
  flown Dreamliner stretch; United/British Airways operators). ALSO changed,
  not a count change: the `B747` entry was re-modelled from Boeing 747-8 →
  **Boeing 747-400** (the -8 passenger variant was essentially freighter-only;
  the -400 is the passenger 747 airlines actually flew) — seats 416, MLW
  652,700 lb, range 7,260 NM updated; its cost/price/lifespan now carry real -400-profile values (lifespan 20k =
  Boeing DSG; cheaper price, higher op cost for an aging jumbo). Family
  count grew from 13 to 15 with the two new widebody families (`A330`,
  `A350`). `CRJ_FAMILY` stays real (CRJ900/1000 remain). See the "stale
  comment" note near the end of this section for a real gotcha this kind
  of repeated change has already surfaced once. This is still a major
  expansion from the original locked 6 — the "locked"
  framing on the old 6-type list no longer applies; that constraint was
  explicitly reopened by the designer this session. **Designer has stated
  an explicit ongoing intent to keep the fleet current with real-world
  aircraft deliveries and retirements** — expect this number to keep
  moving in both directions over time, not just grow. The architecture
  already supports this cleanly for add/remove in almost every respect
  (see the dedicated note on this later in this section) — only
  `FAMILY_LABELS` requires hand-maintenance on change.
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
    (777, 787, A330, A350) is its OWN separate family — no real-world
    commonality between manufacturers or airframe generations at that
    size. (Real-world footnote, not modeled: Airbus itself says the
    A350 and A330 actually DO share a common type rating in reality —
    see the A350-900 sourcing note in Airline Identity — but this game
    keeps them as separate crew families anyway, consistent with how
    every other widebody pair here is modeled as non-interchangeable.)
  - ARJ21 was its own standalone family — but the COMAC ARJ21 has since been
    REMOVED entirely (native app; designer direction — no illustration, few
    carriers, none in the US roster), so `ARJ21_FAMILY` is gone too.
    (Sukhoi Superjet 100 / `SSJ100_FAMILY` was in this standalone category too,
    before its earlier removal — see stale-comment note below.)
  - **Net result: 14 crew families total** (`A320_FAMILY`, `B737_FAMILY`,
    `A220_FAMILY`, `B777`, `B787`, `A330`, `A350`, `B747`, `A380`, `A340`,
    `E170_FAMILY`, `E190_FAMILY`, `CRJ_FAMILY`, `ERJ_FAMILY` — `ARJ21_FAMILY`
    removed with the ARJ21). The `B787` family now covers THREE variants
    (787-8 `B788`, 787-9 `B789`, 787-10 `B78J`) on one type rating.
    Covering 31 aircraft types — verified via script, not hand-counted,
    after this count went stale at least once before (see the
    `TYPE_WEIGHT_TOTAL` note). `CREW_FAMILIES` is auto-derived from
    `AIRCRAFT_TYPES.map(t => t.family)` — adding or removing an aircraft
    type automatically updates this list, no separate maintenance needed.
    `FAMILY_LABELS` (crew status display) is NOT auto-derived — it's a
    hand-maintained object literal, and DOES need updating whenever a
    family is added or removed. This bit an update mid-session: adding
    the A330 and A350 families for Delta's real widebody fleet required
    a manual `FAMILY_LABELS` edit (`A330: 'A330', A350: 'A350'`) — miss
    this step next time a family changes and the crew status strip will
    show `undefined` for that family instead of a real label.
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
  - **Weakest tier**: all remaining regional-jet family totals (E170/E175,
    E190/E195, CRJ, ERJ, ARJ21) are synthesized estimates, not directly
    cited totals like the mainline families above. Plausible, not
    verified — revisit with real sourcing if precision matters here.
  - `TYPE_WEIGHT_TOTAL` is auto-computed via `.reduce()`, not a hardcoded
    number — always correct by construction, don't hand-maintain it.
    **A stale COMMENT on this line is a real trap even though the CODE is
    self-correcting**: after SSJ100 was removed, the code was already
    correct (31 types, weight auto-recalculated to 363), but the
    descriptive comment next to it still said "32 types / ~365" for an
    unknown number of sessions until caught by chance while doing
    unrelated work. The lesson: auto-computed VALUES don't drift, but
    comments describing them are just prose and drift like any other doc
    — don't trust a comment's numbers without spot-checking them
    occasionally, the same way this file itself needs periodic syncing.
- **Aircraft icon base sizes are +15% larger than originally shipped**
  (regionalJet 8.6→9.9, narrowbody 10.9→12.5, widebody2Engine 14.9→17.1,
  widebody4Engine 17.3→19.9 — see Icons section below), per direct
  designer feedback that the original sizing felt too small. Relative
  hierarchy between tiers preserved, verified by script after the change.
- **Every type now carries real `purchasePrice` and `expectedLifespanCycles`
  fields**, added to support the cycle-based lifespan/sell/buy economy —
  see the new "Decided — Fleet Lifecycle & Ownership Economy" section
  below for the full mechanic and sourcing detail. Confidence on these two
  fields specifically: `purchasePrice` is real (median of designer-sourced
  published list price and estimated current market value, or a
  discount-ratio extrapolation where only one figure existed — see that
  section for the exact methodology and its known weak points).
  `expectedLifespanCycles` is real FAA/manufacturer Design Service Goal
  data for the well-established families (A320ceo/737/777/787/A340/CRJ),
  extrapolated from CRJ's confirmed figure for regional-jet types lacking
  a published DSG — same two-tier confidence pattern as everything else
  real-data-sourced in this file.
- **30-type fleet has NOT been visually playtested end-to-end.** Individual
  pieces were spot-checked (the 777/787 icon smoke test, the 4-engine
  widebody icon, syntax/math verification on every weight/scale/price/
  lifespan calculation) but nobody has watched a full play session with
  the current fleet spawning together, including the newer sell/buy loop.
  Do this before treating the expansion as done, not just implemented —
  this note has been true and repeated at every fleet-size change so far;
  don't let its repetition make it feel less urgent than it is.

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
- **Airport network**: 48 U.S. airports (grew from an initial top-25 to
  top-50 minus overlaps — see Map section below for the exact accounting),
  designer-sourced (not the original 7 placeholder airports). Each carries
  real `groundStopsPerMonth`, replacing one flat rate that was previously
  applied uniformly to every airport.
- **Fee detail level is context-dependent, and this is deliberate, not an
  inconsistency to "fix" later.** The aircraft hover tooltip (in-gameplay,
  quick-glance context) collapses landing fee + gate fee into one "Fees"
  line — scanning speed matters more than granularity while actively
  playing. The eventual native app's dedicated FINANCIALS section
  (dashboard context, not yet built — the Figma mockups show a finance
  tab, but nothing in this browser prototype implements it) should split
  landing fee and gate fee back into separate line items — a player
  intentionally reviewing financials can afford, and likely wants, more
  detail than someone glancing mid-flight. Both views can pull from the
  same `computeLegEconomics()` breakdown (`landingFee`/`gateFee` returned
  separately even though the tooltip currently sums them for display) —
  this is a presentation-layer choice per screen, not a data-layer one.
- **Known data conflicts, not silently resolved one way:** BWI and FLL each
  appear in two different source batches with different ground-stop
  numbers (BWI 2.4 vs 3.8/month; FLL 3.8 vs 3.4/month). Kept the
  original/first-sourced values since they were already live; flag if the
  newer numbers are actually the correction. SMF's real fee structure is
  base+per-seat ($61 + $6/seat), which doesn't fit this schema at all —
  approximated by averaging comparable mid-size regional airports already
  in the network (PIT/CMH/MCI/IND/CVG/RDU/STL/SAT/CLE) rather than
  guessing at representative seat counts, which had produced an outlier
  on the first attempt (see git history / chat log for that version).

## Decided — Economy (revenue, operating cost, and economic events)

- **Revenue formula**: `seats × load factor × average fare per seat`,
  replacing the original arbitrary `revMin`/`revMax` random-range bands
  entirely (those fields no longer exist on `AIRCRAFT_TYPES`). Real
  2025-26 sourced baselines: average domestic one-way fare ~$214 (BTS/DOT
  Q1 2026 data), average international one-way fare ~$608 (FCM/Corporate
  Traveler), industry load factor 83.8% (IATA 2026 — a genuine record
  high due to supply-chain-constrained aircraft deliveries, not a rounded
  guess). Regional jet fare ($165) is an ESTIMATE — no direct source,
  meaningfully lower confidence than the other two tiers. Both fare and
  load factor carry a small per-flight random spread so identical
  aircraft/conditions don't produce identical revenue every time.
- **PASSENGER-DEMAND MODEL — prototype, native app, behind a DEV toggle
  (`Simulation.useDemandModel`, default ON; "Demand (DEV)" switch under the
  Network eye-overlay dev row).** The flat 83.8% load factor made route
  SELECTION meaningless — every city pair earned the same per seat. The demand
  model makes load factor an OUTCOME of a route's real passenger demand vs. the
  aircraft's capacity, so matching aircraft SIZE to route is now the core
  decision. `Demand` (Economics.swift) is a gravity model: `dailyOneWay =
  k × geomean(throughputA, throughputB) × distanceFactor(nm)`, where throughput
  = `AirportInfo.annualPassengers` (geomean, NOT the raw product, so the big×small
  spread stays sane and demand tracks the SMALLER endpoint). `k = 3.0e-5`
  calibrated so two ~5M-pax airports at medium haul fill a narrowbody at ~75%.
  `loadFactor(seats:dailyOneWay:) = min(0.92, (dailyOneWay / 2) / seats)` — the
  `/2` is the sim's ~2 daily frequencies each way (a ~369-tick leg). `rollRevenue`
  uses it (event/random modifiers still stack on top); the route-confirm panel
  shows "Est. demand N/day" + "Projected load X% · <a/c>" so the choice is
  informed. `Airport.greatCircleNM(to:)` (haversine, antimeridian-normalized for
  PPT's stored +210° lon) is the shared distance helper. Verified headlessly: the
  gradient is right (trunk/long-haul overflow → reward big jets; mid = narrowbody
  sweet spot; thin routes only pay on regional jets; Cheyenne-tier ≈ dead), and
  the settled load factor matches the predicted value exactly (ERJ135 BZN-FAR →
  59% predicted, 59% settled). NOT YET: real distance-based fare, and COMPETITION
  splitting a route's demand (the natural next layer — background traffic is still
  cosmetic). **Balance finding this surfaced (independent of demand, verified via
  the OFF/ON A/B — demand is NOT the cause): a $20M starting player can only
  afford the ERJ135/145, which LOSE money even at full load because regional
  fares ($165) don't cover their per-leg cost. Early-game economy (starting
  capital / cheaper viable aircraft / regional fares) needs a tuning pass — a real
  "more balanced" lever, separate from demand.**
- **Real per-flight operating cost, charged on EVERY flight at
  turnaround — not just held ones.** This was NOT the original design:
  the first version only charged `costPerHour`-derived cost during
  AOG/crew holds, which meant an economic event that raised costs
  paradoxically made the airline MORE profitable net-net (fare gains hit
  every flight, cost gains only hit the rare held ones). Fixed by
  deducting real operating cost from every flight's revenue at
  `TURNAROUND`, computed via a shared `computeLegEconomics(ac)` function
  (also used by the aircraft hover tooltip, so the "projected" leg
  economics shown mid-flight always match what actually gets recorded).
- **Operating cost uses per-bodyType realistic stage length, NOT the
  fixed ~4.8hr state-machine visual cycle every aircraft flies through.**
  This was also a real bug caught before shipping: an initial version
  applied one universal block-time constant to every aircraft type,
  which — because the sourced `costPerHour` figures were quoted assuming
  each type's typical REAL mission length (narrowbody ~1.5-2.5hr,
  widebody ~8-10hr) — over-charged narrowbodies and under-charged
  widebodies badly enough that the A321neo was unprofitable even with no
  economic event active. Fixed with
  `OPERATING_COST_BLOCK_MINUTES_BY_BODYTYPE` (regionalJet 75min,
  narrowbody 120min, widebody2Engine 480min, widebody4Engine 540min) —
  industry-commonly-cited average stage lengths, not freshly sourced this
  session, real but lower-confidence than the direct-cited fare/load data
  above. This is intentionally decoupled from the visual flight-cycle
  timing (which is locked, see Core Simulation section) — the cost
  calculation uses its own realistic assumption, the aircraft still
  visually flies the same fixed cycle either way.
- **DISTANCE-BASED FARES + DISTANCE-BASED OPERATING COST (native app) —
  replacing the flat per-bodyType fare AND the fixed per-bodyType block
  minutes above. A matched pair; done together on purpose.** Fare now depends
  on the ROUTE, not the aircraft: `FareModel.farePerSeat(nm) = 25 + 2.95 ×
  nm^0.65` (~$145 at 300nm, $464 at 2,200nm, $982 at 7,300nm — sublinear,
  long-haul end rich enough for premium-cabin blended yield). This fixes the
  old quirk where a widebody on a short domestic leg charged the $608
  "international" fare. Because a distance fare alone makes long routes a
  same-cost/more-revenue EXPLOIT, operating cost is now distance-based too:
  `BodyType.blockMinutes(forNM:) = max(oldFixed×0.5, 35 + nm / cruiseNMPerMin)`
  (cruise 6.8/7.5/8.3 nm-per-min by tier) × `holdCostPerTick`. The two were
  calibrated TOGETHER against a full aircraft×distance profitability matrix
  (headless): every type has a real distance sweet spot, widebodies lose on
  short hops (A380 −$63k at 300nm) but profit big on long-haul (A380 +$73k,
  B789 +$53k — their purpose), regionals pay on short-medium, mismatches lose.
  Verified the demand gradient still holds and the $30M 2-aircraft startup
  grows (+$491k/mo). `avgFarePerSeat` and `operatingCostBlockMinutes` on
  BodyType are now SUPERSEDED (kept as calibration references). `greatCircleNM`
  (Airport) is the shared distance source. NOTE the interaction with the demand
  model: profitability = fare(distance) × load(demand vs seats) − opcost(distance)
  — so a long route needs BOTH range AND demand to pay; that's the strategic core.
- **AGING & ESCALATING MAINTENANCE (native app).** An old airframe now costs
  progressively more and breaks more as it nears retirement — so buy-new vs
  buy-used vs lease is a real trade-off (a cheap high-cycle used jet is no longer
  a free win). `Aircraft.ageFraction = cyclesAccrued / expectedLifespanCycles`.
  Two QUADRATIC escalators (climb accelerates near/past design life):
  `aogAgeMultiplier = 1 + 3.0·age²` scales AOG onset probability AND repair costs
  (new 1×, 80% life 2.9×, design life 4×, past it 5×+); `maintenanceAgeMultiplier
  = 1 + 0.4·age²` scales per-leg operating cost (design life +40%). Surfaced in
  the Fleet detail Maintenance card ("Upkeep (age)" row). Leased/newly-bought
  aircraft start at 0 cycles (fresh); used-market aircraft carry their real
  cycles — so leasing = a fresh low-maintenance jet with an ongoing bill, buying
  used = cheap upfront but higher AOG + upkeep. Verified headlessly.
- **FUEL EFFICIENCY as a real per-aircraft axis (native app).** Fuel used to be
  invisible except as an event that hit every aircraft equally. Now the economic
  event's `costMultiplier` is explicitly a FUEL-PRICE multiplier that scales ONLY
  the fuel share (~35%, `fuelShareBase`) of operating cost, and by each type's
  `AircraftType.fuelIntensity` (modern neo/MAX/787/A350/A330neo/A220 = 0.72,
  4-engine widebodies = 1.6, everything else 1.0). `effectiveCostMultiplier` is
  now a PER-AIRCRAFT function `effectiveCostMultiplier(for:)`: normal conditions →
  1.0 for everyone (so real `costPerHour` stays the truth when fuel is normal),
  but an Oil Spike (raised 1.30→1.50, i.e. fuel +50%) hits a thirsty 4-engine jet
  +28% vs a modern neo/787 only +12.6% — a 15-pt differential that makes a modern
  fleet a real hedge against fuel volatility (and the fuel hedge still caps a
  spike to 1.0 = full protection). Fuel Drop raised 0.85→0.70. Finance market
  banner relabeled "Costs"→"Fuel". `avgFarePerSeat`/`operatingCostBlockMinutes`
  stay superseded refs; costPerHour already carries each type's NORMAL-condition
  fuel efficiency — this is the extra differential fuel-PRICE sensitivity on top.
- **Economic events**: randomly triggered (checked once per sim-day, 15%
  daily chance when conditions are normal, designed pacing not sourced),
  lasting 3-10 sim-days, one active at a time. Four types (Oil Price
  Spike, Fuel Price Drop, Economic Boom, Recession), each with a
  cost/fare/load multiplier. Magnitude is anchored to a real data point
  (jet fuel prices moved ~32% year-over-year in a real 2026 supply shock,
  per IATA Jet Fuel Price Monitor data) but the specific multiplier
  values and the price-elasticity relationship (higher fares -> lower
  load factor) are designed for gameplay pacing, not derived from an
  economic model. A real emergent property worth knowing: 4-engine
  widebodies (747/A380) go NET NEGATIVE during an oil spike while
  everything else just compresses — this wasn't hand-tuned, it fell out
  of the real cost/revenue math, and it happens to match the actual
  historical dynamic that pushed those aircraft toward retirement.
  - **PER-EVENT COOLDOWN (native app) — the same economic event can't recur
    within 30 sim-days.** A playtester saw two "Fuel Price Drop"s a few days
    apart (unrealistic). `tickEconomicEvents` now sets `eventCooldownUntil[id] =
    tick + 30d` at ONSET (not end — onset-based is airtight regardless of the
    event's duration) and picks only from ids whose cooldown has expired (falls
    back to all if every type is cooling, which can't happen with 5 types).
    Verified 0 same-within-30d violations across 3× 3-sim-year runs. Cooldowns are
    transient (not persisted — events reset to Normal on load anyway).
- **Financials UI is a stacked ledger** (Revenue / −Operating Costs /
  −Fees / =Net Revenue), replacing a single-line formula string — net
  revenue colors green/red by sign. Same breakdown surfaced in the
  aircraft hover tooltip, both pulling from `computeLegEconomics()`.
  Tooltip field ORDER is Route → Tail → Type → Status → Crew legal hours →
  Revenue → Fees → Operating cost → Net for this leg (Route moved to the
  top per designer direction; this is presentation-order only, doesn't
  affect `computeLegEconomics()` itself).
- **A real ship-blocking bug happened here, worth understanding the root
  cause, not just knowing it got fixed.** When `computeLegEconomics()` was
  extracted (pulling shared fee/cost math out of the inline TURNAROUND
  block so the tooltip could reuse it — see above), one log-message
  reference to the old local `operatingCost` variable was missed and left
  bare instead of being updated to `econ.operatingCost`. This threw
  `ReferenceError: operatingCost is not defined` on every flight that hit
  either the 4%-random-log-sample branch or any net-loss branch — meaning
  it fired constantly in practice, not on some rare path. **`node --check`
  never caught this because it only parses syntax; a reference to a
  variable that's syntactically valid but doesn't exist at runtime is
  invisible to a parse-only check.** Fixed, and the verification practice
  changed as a direct result: an ESLint pass with the `no-undef` rule
  (config: `/tmp/eslint.config.mjs` pattern used in-session, not
  persisted anywhere in this repo — recreate if needed) now runs
  alongside `node --check` before anything ships. This was validated
  against both a synthetic test case and the actual broken file before
  being trusted (confirmed it caught the real bug, not just that it ran
  without erroring) — don't skip that validation step if resurrecting
  this practice in a future session, a linter that silently passes
  everything is worse than no linter.
- **Player-facing purchase economy — PARTIALLY built now, was "not built
  yet" as of the last update to this file.** Buying and selling aircraft
  is real (see the new "Decided — Fleet Lifecycle & Ownership Economy"
  section immediately below for the full mechanic). Route-opening costs
  and starting capital are still NOT built — see that section's Open
  items. The real tension flagged here previously is still real and still
  worth repeating: real aircraft list prices run into the hundreds of
  millions, this sim's per-flight revenue is in the tens of thousands —
  the purchase prices now in the game are NOT a naive real-price import,
  they went through real designer-supplied market-value data and a
  documented discount methodology (see below), but the deeper
  game-balance question (does a player's revenue realistically support
  buying anything without selling first, given there's still no starting
  capital) has not been tested end-to-end.

## Decided — Fleet Lifecycle & Ownership Economy (cycles, sell, buy, lease, crew)

- **1 cycle = 1 completed flight (takeoff + landing)**, tracked per
  aircraft as `cyclesAccrued`, incremented once per `TURNAROUND`. Every
  type carries a real `expectedLifespanCycles` (see Fleet section above
  for sourcing). Spawned (stress-test) aircraft start with a RANDOMIZED
  cycle count (0-90% of expected lifespan) rather than 0 — same reasoning
  as the existing crew-backfill pattern seeding partial duty hours on
  spawn: a real fleet is mixed-age, not all brand-new, and starting
  everyone at 0 would mean nobody approaches retirement without an
  unreasonably long real-time play session. Aircraft bought through the
  real purchase flow (see below) DO start at exactly 0 cycles — a genuine
  new purchase hasn't flown for this airline yet, unlike a stress-test
  spawn representing an existing mixed-age fleet.
- **At 80% of expected lifespan, a `SELL` decision is pushed** — same
  `decisionQueue`/`DECISION_TYPES` system as AOG/CREW, not a separate
  mechanic. Options are "Sell aircraft" (real transaction, see below) or
  "Keep flying" (sets `ac.sellOfferDismissed = true` so the aircraft
  doesn't re-prompt every single subsequent flight — the offer is a
  one-time nudge per aircraft, not a recurring interruption).
- **Sell value is real LINEAR depreciation from `purchasePrice`, floored
  at 5%** — explicit designer spec, verified against a concrete example
  before shipping ($50M new, 20% cycles remaining -> sells for exactly
  $10M) rather than just trusting the formula matched the words. The 5%
  floor is a deliberate designer choice (confirmed directly, not just
  assumed): an aircraft never sells for literally $0 even well past
  100% of expected lifespan, matching a real scrap/parts-value floor
  rather than a cliff to zero. This is a simple linear model, NOT a real
  depreciation curve (real aircraft depreciate steeply early and flatten
  out) — a known, acceptable simplification, not an oversight.
- **`playerBalance` is a real, minimal stand-in economy — NOT the full
  Phase 5 purchase economy from `ROADMAP.md`.** It accumulates net
  revenue from every completed flight (`econ.net`, the same number the
  financials ledger and tooltip already show) plus sell proceeds. This is
  explicitly a "master account" in the sense the designer described it:
  proceeds from a sale go into the same balance used to buy new aircraft.
  What's still missing: no starting capital (a fresh session begins at
  $0 — buying anything requires accumulating revenue or selling first),
  and no route-opening cost yet (still just the fleet slider's random
  route assignment, no real "open a route" action for the player).
- **Buying**: `buyAircraft(typeId)` checks `playerBalance >= purchasePrice`,
  deducts it, and creates a genuinely fresh aircraft via
  `makePurchasedAircraft()` — a separate function from the stress-test
  `makeAircraft()`, not a parameterized branch of it, since the two need
  meaningfully different defaults (0 cycles vs. randomized;
  always-`PARKED` vs. randomized starting state). A purchased aircraft
  gets its route/crew through the SAME `PARKED` gate logic every other
  aircraft uses — no special-casing needed there. UI is a scrollable
  "Buy Aircraft" panel listing all types sorted by price, each row
  showing a Buy button that disables itself when unaffordable and stays
  LIVE (re-rendered every tick while the panel is open, via
  `updateStatusStrip()`) since balance changes with every completed
  flight, not just on click.
- **A real bug caught and fixed BEFORE it could destroy a player's
  purchase, not after.** The stress-test fleet slider's old
  `setFleetSize()` used `fleet.length = n` to shrink the fleet — a raw
  array truncation with no concept of "some of these aircraft are real
  purchases, not stress-test filler." The moment buying became real,
  dragging the slider down would have silently deleted purchased
  aircraft the player had actually paid for, with no warning. Fixed by
  tagging every aircraft with `purchased: true/false` and rewriting
  `setFleetSize()` to only ever trim NON-purchased aircraft when
  shrinking — verified numerically for both normal shrinkage and the
  extreme case where the slider goes below the actual purchased count
  (fleet size floors at the owned count rather than deleting anything).
  This is the kind of bug that's invisible until two previously-separate
  systems (a stress-test convenience control, and a new real economy)
  start interacting — worth remembering when adding future mechanics
  that touch the `fleet` array.
- **A second real bug, unrelated to the economy itself but caught in the
  same work area: the decision panel (AOG/CREW/SELL — anything using
  `decisionQueue`) used to flicker and unreliably register clicks.**
  Root cause: `advanceTick()` called `renderDecisions()` unconditionally
  whenever any decision was pending, and `advanceTick()` can fire up to
  50 times per animation frame at high game speed. Every call did a full
  `innerHTML` replacement of the whole panel — destroying and recreating
  every button that often. That produced exactly the two reported
  symptoms: hover flicker (`:hover` CSS state resets because it's
  literally a new DOM node each time) and dropped clicks (a re-render
  landing between mousedown and the click event completing means the
  clicked button no longer exists by the time the click would fire).
  Fixed by removing the per-tick call entirely — `pushDecision()` and
  `resolveDecision()` already call `renderDecisions()` exactly when the
  queue's contents actually change (a card added or resolved), which is
  the correct and sufficient trigger. **This exact same bug pattern
  recurred TWICE more later in this session** — once in the route panel's
  original dropdown-based UI (fixed by replacing dropdowns with
  click-to-select entirely), and once in the buy/lease panel (fixed the
  same way, removing its per-tick refresh). Three independent instances
  of the identical root cause, each only caught after being built, not
  anticipated. If a FOURTH panel ever shows this symptom, stop applying
  one-off fixes — build a single shared "re-render only on real state
  change" helper every panel uses, instead of trusting each new panel to
  independently avoid a mistake that's already happened three times.
- **Leasing — a real alternative to buying, not a strictly-better option.**
  Explicit designer spec: 15% of purchase price upfront (`LEASE_UPFRONT_RATE`),
  vs. paying the full purchase price outright. Monthly lease rate is real,
  sourced data — 0.8% of aircraft value per month (`LEASE_MONTHLY_RATE`),
  the middle of a real industry range (0.6%-1.2% "lease rate factor",
  Acumen Aero market analysis), cross-validated against real quoted
  dollar figures for narrowbody leases ($380K-$500K/month on $55-70M
  aircraft). The ACQUIRE AIRCRAFT panel (renamed from BUY AIRCRAFT — same
  button, both the main one and the copy inside the route-confirm panel)
  shows Buy and Lease as two independent options per type, each with its
  own affordability check.
- **A real, substantive bug caught mid-build on leasing, not shipped
  quietly: the first version made leasing almost strictly dominant, not
  a genuine tradeoff.** Root cause: lease cost was prorated PER-FLIGHT,
  the same way operating cost works (block-minutes × per-tick rate) —
  meaning an idle leased aircraft (a spare never assigned to a route, or
  one sitting held) cost nothing. Real leases are a FIXED MONTHLY
  OBLIGATION regardless of utilization — you owe the lessor whether the
  plane flies or sits idle. Under the wrong model, the crossover point
  where cumulative lease payments would exceed the upfront savings from
  buying was ~38,000 flights (roughly 23 years of daily flying) —
  functionally never reached in any real playthrough. Fixed with a real
  recurring-billing mechanism, `tickLeaseBilling()`: checked every tick,
  bills `ac.type.monthlyLeaseCost` against `playerBalance` whenever
  `tick >= ac.nextLeaseBillTick`, for EVERY leased aircraft regardless of
  flying/parked/held/idle-spare status, then advances the next-bill tick
  by `TICKS_PER_MONTH`. Verified numerically: an idle leased aircraft
  that never flies a single leg now genuinely loses money over time (a
  representative narrowbody: ~$4.5M lost over 6 months of pure idle
  lease payments). `playerBalance` is allowed to go negative here — no
  bankruptcy mechanic exists (see Open below) or is planned yet; a
  negative balance is itself the consequence, rendering in red and
  blocking further Buy/Lease/Open Route actions.
- **`computeLegEconomics()` still returns a `leaseCostEstimate` field,
  but it is DISPLAY-ONLY and does not affect `net`.** This is deliberate,
  not a leftover from the broken per-flight model: the designer wants the
  in-flight tooltip to show a smoothed, readable lease-cost-per-leg
  estimate folded into the displayed "Operating cost" line (too much
  detail to break out in that view), while report views (the financials
  ledger's real "– Lease Costs" row, the Routes detail panel's "Total
  lease cost" line) show the REAL number from `tickLeaseBilling()`'s
  running totals (`totalLeaseCost`, `route.totalLeaseCost`) — not derived
  from the per-flight estimate, which would now be wrong since billing
  isn't tied to individual flights anymore.
- **Crew provisioning was rebuilt from automatic ratio-based sizing to
  fully player-driven hiring — a real architecture reversal, not a bug
  fix, prompted by a real reported bug.** The original design auto-sized
  each family's crew pool to `ownedAircraftCount × crewsPerTail` (6-11
  crews per aircraft) via `resizeCrewPools()` — meaning a SINGLE aircraft
  purchase silently granted 6-11 crew immediately, which trivialized the
  entire crew-rest tension the AOG/CREW hold mechanic exists to create.
  Worse, a `Math.max(1, ...)` floor guaranteed a phantom minimum pool
  for EVERY family regardless of ownership — the reported bug (crew
  status strip showing "1/0/0 · 2 res" for families with zero owned
  aircraft). Both are fixed by the same redesign: buying or leasing an
  aircraft now bundles exactly 1 crew member (`grantBundledCrew()`,
  called from both `buyAircraft()`/`leaseAircraft()`) — deliberately NOT
  enough for continuous operation once duty/rest limits kick in, which
  is the actual intended pressure toward hiring more. A family's FIRST
  aircraft also seeds its reserve pool (1 reserve — see the "2 res"
  correction below), which stays flat regardless of how many more
  aircraft get added to that family. `resizeCrewPools()` is now purely a
  CLEANUP pass — it clears a family's pool/reserves to 0 only when owned
  aircraft count hits zero (last one sold), and otherwise does NOT grow
  or shrink the pool by any ratio. Real `crewsPerTail` ratios (6
  short-haul, 11 long-haul) are no longer consumed by any code — they're
  now purely a REFERENCE figure the player has to learn and reason about
  themselves ("how many crews does this route actually need"), per
  explicit designer direction that this stays on the player to figure
  out, not something the game calculates or recommends for them.
- **New ADD CREW panel**: lists only families the player currently owns
  aircraft in (never the full 13), each with a real hire cost
  (`computeCrewHireCost()`) and current pool size shown. Hire cost is a
  DESIGNED estimate, not deeply sourced like purchase prices/lease rates
  — real crew hiring/training costs vary too much by role and seniority
  to research precisely at this level; 0.2% of a representative
  aircraft's purchase price (`CREW_HIRE_COST_RATE`) scales cost with
  aircraft complexity ($28K for a regional jet crew up to $578K for a
  widebody crew) without claiming to be researched. Revisit with real
  sourcing if precision matters here later.
- **Reserve crew count corrected: 1, not 2** — a family's first aircraft
  purchase should grant 2 crew TOTAL (1 bundled + 1 reserve), not 3. Both
  places that seeded the old value of 2 were fixed for consistency: the
  real functional one (`grantBundledCrew()`) and a vestigial startup
  default (`reserveCrewsByFamily` initialization) that was functionally
  harmless but left inconsistent — the same class of stale-value trap
  this file has flagged before elsewhere in this codebase.
- **A second real, reported bug: AOG, crew shortage, and sell-eligibility
  decisions were firing for background stress-test traffic the player
  doesn't own** — offering to sell aircraft, or asking the player to call
  in reserve crew, for planes that were never theirs. Root cause: these
  three mechanics (plus `resizeCrewPools()` and `backfillStaggeredCrews()`)
  predate the `purchased` ownership concept entirely and were never
  retrofitted with an ownership check when background traffic and real
  ownership diverged. Fixed across FIVE places, all with the same
  principle — background traffic has zero economic/decision stakes, pure
  visual flavor: `tickAOGOnset()` skips non-purchased aircraft entirely
  (they can never be flagged `maint`, not just never prompted about it);
  the PARKED boarding gate's crew check is gated on `ac.purchased` (
  background traffic proceeds unconditionally, no hold, no decision); the
  SELL trigger requires `ac.purchased`; `resizeCrewPools()` only counts
  purchased aircraft; `backfillStaggeredCrews()` is scoped the same way
  so background traffic can't pull a crew slot from a pool sized for the
  player's real fleet. Every OTHER fleet-wide loop in the codebase (main
  tick advancement, canvas rendering, status-strip counts, airport hover
  status) was individually checked and confirmed to be correctly
  UNSCOPED — those legitimately need background traffic included for it
  to look and feel like real airspace. Only the five decision/stake-bearing
  mechanics needed the fix.
- **Background traffic is visually distinct from the player's own fleet**:
  `#55BBFF` inflight / `#FF6D0C` on the ground, vs. the player's
  green/amber. Held (red) stays shared between both — background traffic
  can still show a real weather ground-stop (that applies universally),
  and red-for-problem was kept as a universal constant rather than adding
  a fourth color scheme.
- **Background traffic's hover tooltip is deliberately reduced**: Route,
  Tail, Type, Status only — no economics, no crew, no load, no route P&L.
  This is a real early return in `renderAircraftTooltip()`, not fields
  hidden in the template — none of the economic computation (crew
  lookup, `computeLegEconomics()`, route P&L) runs at all for background
  traffic, since none of it would be displayed anyway.
- **Crew duty/rest was rebuilt to real FAA 14 CFR Part 117 mechanics —
  the original implementation didn't actually accumulate duty time
  across flights.** Reported and diagnosed directly: `dutyTicks` was
  reset to 0 on every new assignment (`crew.dutyTicks = 0` at the
  boarding gate), including for a crew member who'd just been released
  as `AVAILABLE` without hitting the rest threshold. Since one full
  flight cycle (369 ticks) is well under `MAX_DUTY_TICKS` (600), this
  meant duty time NEVER meaningfully accumulated — a lone crew member
  could fly indefinitely without ever triggering real rest, as long as
  no SINGLE flight was individually delayed past 600 ticks. Fixed by
  removing the reset from the assignment point entirely; `dutyTicks` now
  only resets when a crew member completes an ACTUAL rest period
  (`RESTING` → `AVAILABLE` transition in `tickCrewPool()`), matching how
  a real Flight Duty Period works — the whole duty day (potentially
  several flight segments back-to-back), not a per-flight allowance that
  refills on every new leg. Also caught and fixed in the same pass: 
  `REST_TICKS` was **wrong**, not just simplified — 480 (8hr) conflated
  the real Part 117 minimum-sleep-opportunity component (8 of the 10
  hours) with the full required rest period, which is 10 CONSECUTIVE
  hours (14 CFR 117.25(e)). Corrected to 600. `MAX_DUTY_TICKS` (600,
  10hr) was independently verified as already reasonable — real Table B
  Flight Duty Period limits run roughly 9-13hr depending on report time
  and segment count, so 10hr sits appropriately in that real range.
  Verified with an actual simulation, not just logic review: a lone
  crew member now flies exactly 2 consecutive cycles (~12.3 cumulative
  hours) before mandatory rest blocks a third, which is the real
  mechanism creating pressure toward hiring a second crew member.
- **Real used-aircraft market, buy-only (no lease), persistent inventory
  (designer decisions, not re-randomized on panel open).** 1-2 listings
  generated per type at game start, randomized 15%-75% of expected
  lifespan, slowly replenished over time (~10%/day per under-2 type) so
  the market doesn't permanently deplete over a long session. Pricing
  reuses the EXACT SAME linear depreciation formula as `computeSellValue()`
  — same 5% floor, deliberate consistency with the sell mechanic, not a
  new formula. Real market research behind this: used aircraft trading is
  a genuine $1.96B+ industry segment (Technavio, 7.7% CAGR 2025-2030),
  partly driven by real OEM production delays. Real depreciation curve
  (Acumen Aero): aircraft retain ~70%/50%/35% of value at 5/10/15 years —
  cross-checked against a real Boeing 737-800 example ($106.1M new,
  ~$20-22M at 8 years old). The linear model runs slightly OPTIMISTIC at
  high cycle counts versus that real curve (real depreciation steepens
  with age/usage, this model doesn't) — a known simplification matching
  the designer's existing choice for the sell mechanic, not a new,
  undisclosed one. A purchased used aircraft genuinely starts with its
  real cycle count (not 0), verified end-to-end with the actual extracted
  functions: a real listing generated, purchased, balance deducted
  exactly, and the resulting aircraft correctly inherited the used
  aircraft's cycle count rather than starting fresh.
- **A real, reported bug: decision cards went stale when their underlying
  condition resolved through a path OTHER than that card's own buttons.**
  Concretely: hiring a new crew member via the ADD CREW panel while a
  CREW hold was showing correctly unblocked the aircraft, but the stale
  "no available crew" card kept showing anyway. Root cause: `decisionQueue`
  entries were ONLY ever removed by `resolveDecision()` (a card's own
  buttons) — there was no cleanup path for a condition resolving
  independently. This turned out to affect a SECOND case too, caught by
  checking rather than assuming the fix was narrowly scoped: AOG's timed
  "standard repair" auto-completion had the identical gap. Fixed with a
  real `clearDecisionForAircraft(ac, type)` function, called from both
  actual resolution points (crew becoming available, AOG auto-clearing).
  Verified the removal logic directly, not just reasoned about it.
- **CREW decision now has a real third option: "Hire new crew"**,
  alongside "Call in reserve crew" and "Wait." Reuses `hireCrew()`
  directly — same real cost, same pool-growth logic as the standalone
  ADD CREW panel, not a duplicated implementation — and immediately
  assigns the newly hired crew to the specific held aircraft, resolving
  the hold right away rather than waiting for the next tick's normal
  boarding-gate pickup. Disables itself with "Insufficient funds to
  hire" using the same real cost function the ADD CREW panel uses.
- **Not yet playtested**: the sell/buy/lease/used-market loop, the full
  route-opening and route-history system, the rebuilt crew-hiring
  economy, the corrected duty/rest mechanic, and the airline-identity
  system below — none of this has been run together in one continuous
  real session. Individually spot-checked and numerically verified at
  every step (that verification caught real bugs — the lease proration
  bug, the crew-reset bug, the phantom-family bug, the ownership-scoping
  gap, the stale-decision-card bug — meaning "spot-checked" has a real,
  demonstrated catch rate here, not just a theoretical safety net), but
  the combined, played experience is still the one thing that hasn't
  actually happened.

## Decided — Airline Identity & Competitor Traffic

- **Player airline naming**: a styled modal blocks the game on load,
  asking the player to name their airline (Enter or button submits;
  defaults to "New Airline" if left blank rather than blocking
  submission). Stored in `playerAirlineName`, shown as the first line
  in the player's own aircraft tooltip.
- **Background traffic now carries a real competitor airline name**,
  weighted by actual 2025-26 US domestic market share (BTS/OAG/Statista,
  cross-checked across five sources this session). `AIRLINE_ROSTER`:
  American ~21%, Delta ~19%, Southwest ~18%, United ~17% (the real "Big
  Four," together ~75-76% of US domestic capacity, consistent across
  every source checked), Alaska a clear real 5th at ~6%. Remaining ~19%
  split across JetBlue/ULCCs (Spirit, Frontier, Allegiant)/regional-brand
  liveries (SkyWest, Republic, Envoy, Endeavor, Horizon, PSA) — designed
  proportions within that remainder, not individually sourced the way
  the Big Four figures are.
- **Airline eligibility was REBUILT mid-session from body-type CATEGORY
  restriction to SPECIFIC aircraft-type restriction — a real
  architecture upgrade, not a refinement.** The original version only
  restricted by category (narrowbody/regionalJet/widebody2Engine/
  widebody4Engine), which isn't accurate enough: "Southwest doesn't fly
  widebodies" is a category fact, but "Southwest doesn't fly the
  737-900, only 700/800/MAX8" or "Delta has ZERO Boeing widebodies at
  all" are SPECIFIC-type facts a category system can't represent — and
  the designer explicitly flagged the risk of a player noticing
  ("Airline X doesn't fly the A340!"). Every airline's `types` array is
  now a real, individually-researched list of specific `AIRCRAFT_TYPES`
  IDs, not a category. Real findings from that research, several of
  which corrected assumptions rather than confirming them:
  - **Delta's widebody fleet was ENTIRELY excluded at first** — real
    fleet was 100% Airbus (A330/A350), and neither was modeled in this
    game at the time, despite Delta being a real widebody operator.
    Resolved this session — see the A330/A350 addition below.
  - Delta flies NO Boeing 737 MAX at all (confirmed, a real and
    deliberate carrier choice); United flies A321neo but no A321ceo;
    JetBlue retired its LAST Embraer E190 in September 2025 (real,
    recent) and is now all-Airbus; Emirates flies NO 787 at all (777/
    A380 only); Lufthansa flies NO Boeing 777 passenger service at all
    (747-8/A380/787/A340/A350 instead).
  - **A genuine surprise caught by checking rather than assuming**:
    Lufthansa is confirmed the world's LARGEST Airbus A340 operator in
    2026 (14 A340-300s + 5 A340-600s), kept flying specifically because
    of Boeing 777X delivery delays — not a retired type as first
    assumed before searching. The A340 in this game now resolves 100%
    of the time to Lufthansa specifically, verified via a 10,000-sample
    check, matching this real, current fact.
  - Seven specific types (`A319NEO`, `E190`, `E195`, `ERJ135`, `ERJ140`,
    `ARJ21`, and formerly `MAX10` before it was removed entirely — see
    below) have NO real match anywhere in the 21-airline roster — either
    vanishingly rare variants, retired from major-carrier US regional
    feed, or (ARJ21) a China-market-only type no Western carrier flies.
    These fall to a generic `Independent Operator` fallback entry rather
    than forcing a fake mainline match — smaller/charter/startup
    operators are the genuine real-world pattern for exactly this kind
    of orphaned type. This fallback is also what prevents
    `pickAirlineForType()` from crashing on an empty eligible-airlines
    array; every type in `AIRCRAFT_TYPES` is verified via script (not
    just assumed) to resolve to at least one eligible entry.
  - Alaska Airlines includes real `B788` eligibility from an earlier
    update this session — absorbed Hawaiian Airlines' 787-9 fleet and
    launched genuine widebody international routes from Seattle (London,
    Rome, Reykjavik, Seoul, Tokyo), confirmed via search before that
    change, not taken on request alone. Still excluded from
    `widebody4Engine` — no 747/A380/A340-class aircraft.
- **A new, real design principle established this session: aircraft
  types must be actually FAA/ICAO certified AND in real service to stay
  in this game — an order or a certification-pending status isn't
  enough.** Prompted by removing Boeing 737 MAX 7 and MAX 10 entirely
  from `AIRCRAFT_TYPES` — verified via search before removing (not
  assumed): as of this game's real current timeframe, MAX 7 certification
  is expected within weeks but hadn't cleared FAA sign-off yet, and MAX
  10 isn't expected until year-end 2026, with first DELIVERIES for both
  not until 2027 even after certification clears. Fleet dropped to 28
  types/349 weight, then back to 30/367 with the A330/A350 addition
  below. This same certified-and-flying bar was then applied to Delta's
  real Boeing 787-10 order (Jan 2026, 30 firm + 30 options) — a genuine
  order, confirmed via search, but explicitly NOT added to Delta's fleet
  yet since an order isn't a delivery. Revisit both MAX7/10 and Delta's
  787 once they've actually entered real service, not before. **UPDATE: the
  Boeing 787-10 TYPE has since been added (id `B78J`) — consistent with the
  certified-and-in-service bar, since the -10 is widely flown (United, Singapore,
  BA, etc.). What stays excluded is DELTA specifically flying it — Delta's
  order is still undelivered, so `B78J` is NOT in Delta's roster `types` (it's
  on United + British Airways).**
- **Airbus A330-900 and A350-900 added specifically because Delta's
  entire real widebody fleet is Airbus** — this is what actually
  resolved the "Delta excluded from every widebody" gap noted above.
  Real sourced specs: A330-900 MLW 191,000kg (confirmed, Airbus/
  AeroCorner), 300 seats; A350-900 MLW 207,000kg (confirmed, multiple
  technical sources), seats set to 306 to match DELTA'S OWN real cabin
  configuration specifically (not a generic representative number),
  purchase price ~$300M sourced from Axon Aviation's real market-value
  estimate, not Airbus sticker list price — the same "real transacted
  value" methodology already used for every other type in this game.
  Delta gets both new types. Also added, individually confirmed (not
  assumed uniform across "the international carriers"): Air France
  (both A330 and A350 — real, current operator of both), Lufthansa and
  British Airways and Japan Airlines (A350 only — each independently
  confirmed, deliberately not adding A330 to any of them since that
  wasn't confirmed), Air Canada (A330 only, confirmed, no A350).
  - **A second real correction surfaced while researching this
    addition, unrelated to the reason for the search**: Air France's
    A380 fleet was fully retired by 2022 — their current 2026 long-haul
    fleet is 787/777/A350 only. The roster had them still eligible for
    A380 from the ORIGINAL build, which had simply never been
    independently re-verified. Fixed in the same pass rather than left
    for later, exactly the kind of drift this roster is expected to
    accumulate over time (see the scope-limit note below).
- Verified via real 10,000-20,000-sample distribution checks at multiple
  points this session, not just trusting the configured weights on
  paper: narrowbody assignment lands within a percentage point or two of
  the real sourced market share; widebody-only international carriers
  come out appropriately rare (~1.5-4% each depending on how many
  carriers are eligible for that specific type); Delta appropriately
  dominates A330/A350 assignment as the real anchor customer, with the
  occasional international carrier showing up alongside it.
- **Real scope limit worth being explicit about**: this whole roster is
  hardcoded to US market share because the game itself is hardcoded to
  48 real US airports — there's no region-selection feature. If a future
  version lets players start in a different region, this roster and its
  weights would need to become region-aware rather than assuming US
  market share universally, which is what "weight based on the
  geography the player is playing within" actually implied as a design
  intent, not fully realized yet.
- **This roster has now been independently corrected twice for facts
  that were wrong in the original build** (Air France's A380 status,
  and implicitly Delta's widebody exclusion once A330/A350 existed to
  resolve it). Real airline fleets and route networks change constantly
  and this roster has no mechanism to detect that on its own — it only
  gets fixed when someone notices and asks, or when unrelated research
  happens to surface the correction. Treat every entry as due for
  re-verification eventually, not as settled once written.

## Decided — Route Network & Player Operations

- **The foundational shift this session: aircraft you own no longer fly
  randomly.** Before this work, EVERY aircraft (purchased or background)
  picked a destination via `randomRoutePair()` on every PARKED cycle —
  there was no concept of "the player's network" at all. Purchased
  aircraft now fly ONLY between airports the player has explicitly opened
  a route between (`ac.assignedRouteId`), swapping direction each cycle
  (A→B, then B→A) rather than picking randomly. A purchased aircraft with
  no assigned route is a real "spare" — it sits genuinely idle (skips the
  entire state machine via an early return in `advanceAircraft`, consumes
  no crew) until assigned via `openRoute()`. Background traffic keeps the
  old fully-random behavior unchanged — it's unrelated to the player's
  network by design.
- **Abstract slot scarcity, explicitly NOT real competitor-airline
  modeling** — a deliberate scope decision. Each airport has
  `slotsTotal`/`slotsAvailable`, `slotsTotal` scaled inversely to real
  landing-fee data already in the game (busier/more-expensive airports
  have less room for new entrants — ORD floors at 3 slots, smaller
  airports get up to ~13). Slots free up slowly over time
  (`tickSlotAvailability()`, ~5%/day per under-capacity airport, designed
  pacing not sourced) representing unnamed background churn, or can be
  bought outright when none are free (a real premium added to the
  route-opening cost). Real competitor airlines were explicitly
  considered and rejected for this pass — see `ROADMAP.md`'s "Deferred
  indefinitely" list, which this deliberately did not reopen.
- **Real route-opening cost**, built from data already in the game rather
  than invented: a base fee plus both endpoints' gate fees
  (`computeRouteOpeningCost()`), landing in a real $68K-$275K range
  depending on airport size and slot scarcity — small relative to
  aircraft prices, real relative to per-flight revenue.
- **Route-opening UI is click-to-select on the map, not dropdowns** — a
  real rebuild, not the original design. The first version used two
  `<select>` dropdowns and hit the exact same per-tick-flicker bug
  documented above (third instance). Rebuilt as a real 4-step flow: click
  OPEN ROUTE → click origin airport on the map → click destination
  airport → confirm panel with live cost/slot info and Open Route/Abandon
  buttons. Selected airports get a visible highlight ring, correctly
  zoom-scaled the same way as everything else on the map. Basic tap
  support exists for mobile, honestly scoped to just this flow (not full
  touch-pan/pinch-zoom, which remains unbuilt). Airport hit-testing was
  refactored into one shared function (`findAirportAtScreenPos`) used by
  both hover AND route-picking, rather than two copies that could drift.
- **Buying/leasing an aircraft while mid-route-selection auto-assigns it
  to the pending route** — explicit designer call, chosen over a
  separate two-step buy-then-manually-assign flow. If the acquisition
  succeeds but the route still can't open (e.g., the route fee alone
  exceeds what's left of the balance), the aircraft stays as a real spare
  and the route panel stays open showing why, rather than silently
  failing. A second ACQUIRE AIRCRAFT button lives inside the route
  confirm panel itself (next to Open Route/Abandon) for exactly this
  case — both buttons share one `toggleBuyPanel()` implementation, not
  two copies.
- **Real route-level profitability, weighed against the actual
  establishment cost** — a route isn't "profitable" the moment one
  flight nets positive; it's profitable once cumulative net revenue
  actually recoups `route.openingCost`. Tracked via `route.cumulativeNet`,
  accumulated at every completed flight AND decremented by real lease
  bills (`tickLeaseBilling()` reduces a route's cumulativeNet too, if its
  aircraft is leased) — so a route's true P&L reflects both flight
  economics and ongoing lease obligations, not just ticket revenue.
- **Full per-flight route history**, not just the running total — this is
  what makes a real "chart profitability over time" view possible.
  `route.history` captures one entry per completed flight: tick,
  aircraft tail, revenue, fees, operating cost, a DISPLAY-ONLY lease
  estimate, net, pax/seats/load factor, and cumulative net at that point.
  Verified the data model is sufficient to reconstruct the full curve and
  identify the exact flight that crossed into profitability, not just
  that it eventually did. `route.assignmentHistory` tracks which
  aircraft has flown the route and when — a real array even though today
  a route only ever has ONE aircraft for its whole life (it just closes
  if that aircraft is sold); this is intentionally future-proofed for
  when aircraft reassignment on an existing route gets built.
- **Routes are archived, not deleted, when closed.** Selling a
  route-assigned aircraft used to `splice()` the route out of
  `playerRoutes` entirely — which would have destroyed exactly the
  history data the designer wants to eventually chart, right at the
  moment it'd be most interesting to review (a route that didn't make
  it). Routes now move to `closedPlayerRoutes` with a `closedTick`
  stamped on, full history intact. The closure log message now reports
  real final P&L ("recouped its $X opening cost with $Y to spare" or
  "never recouped... closed $Z short") instead of a bare "aircraft sold."
- **A dedicated ROUTES panel**: list view of every route (open AND
  closed, newest first), tap one for full detail — start date, close
  date if applicable, flights flown, opening cost, cumulative net and
  profitability status, total revenue/fees/operating cost/lease cost,
  average load, full assigned-aircraft history, and a recent-flights log
  (capped at the most recent 15 for display — a long-running route could
  have hundreds of entries, but the summary numbers above are always
  computed from the COMPLETE history regardless of that display cap, not
  truncated). Not yet built: the actual chart visualization the designer
  described wanting eventually — this panel has the real data ready for
  it, but the chart itself doesn't exist yet.
- **Not yet built**: player-funded route marketing (view loads by
  route/origin, spend to boost them) — flagged early as a genuinely
  separate feature from the airport-incentive-offer mechanic, needs its
  own load-visibility UI that doesn't exist yet. The airport-incentive
  mechanic itself (bottom-15 airports offering waived fees + marketing
  support, with a real clawback penalty for abandoning the route early)
  is also not built — this was explicitly sequenced as Phase C/D, held
  until the Phase A/B foundation (this section) could be felt in actual
  play first.

- **AIRCRAFT REASSIGNMENT — BUILT (tester-reported: "ASSIGN TO NEW ROUTE doesn't
  work").** The button was a bare tab switch (`{ detailID = nil; tab = 0 }`) with
  THREE defects: (1) no follow-through — it never started the route flow, so the
  Network tab looked identical to a normal tab tap; (2) wrong aircraft — even if
  the player then tapped Open Route themselves, `openConfirmedRoute` assigned
  `idleSpares.first`, NOT the aircraft they'd tapped (with several spares you got
  a different tail); (3) impossible for a routed aircraft — `openRoute` guards
  `assignedRouteId == nil`, so an aircraft already flying could never be
  assigned, which is the case a tester is most likely to try.
  The fix, per designer direction ("build true reassignment"):
  `Simulation.reassign(_:from:to:)` moves ANY owned aircraft (idle spare or
  currently flying) onto a brand-new route. `openRoute` keeps its
  spare-only guard and both now share `openRouteCore(…detaching:)`, so the
  cost/range/runway/duplicate checks and hub-eligibility logging can't drift
  between the two paths. **The route the aircraft LEAVES is archived** (moved to
  `closedPlayerRoutes` with `closedTick`, full P&L history intact, both slots
  freed, pending slot-offer cards cleared) — the same teardown selling uses, via
  a shared `detachFromRoute`. Chosen over leaving it PENDING because a pending
  route with no way to close it would hold its slots forever. **Detach happens
  BEFORE `createRoute`**, so reassigning onto a route that reuses an old endpoint
  gets that slot back instead of being blocked by its own aircraft (verified).
  A failed reassign (out of range, already-open, unaffordable) is INERT — it
  returns before detaching, so the existing route survives.
  UI: `Simulation.pendingAssignment` (transient, not persisted) carries the tapped
  aircraft across the tab switch; NetworkView adopts it exactly like
  `pendingSuggestion` (`adoptAssignmentIfAny` → `routeMode = .pickOrigin`), the
  pick hint names the tail ("Assigning N1ZR: tap the first airport…"), the confirm
  panel's projected-load/range/runway checks read THAT aircraft rather than a
  spare, and it shows a red "Leaves ORD–DFW · that route closes" row so the
  consequence is visible BEFORE committing. The intent is cleared on success and
  on every exit from the flow.
  **DEFERRED WHEN AIRBORNE (designer: "I'd rather the jet complete the leg it's
  flying first. Real world.")** — an initial version repositioned a mid-flight
  aircraft to the new origin as PARKED, i.e. it teleported. Now `reassign` checks
  `isEnRoute(ac)` (assigned AND not parked): if airborne it creates + PAYS FOR the
  new route immediately but sets `ac.pendingRouteId` and leaves the aircraft on its
  current route; `completePendingReassignment` runs at `.legCompleted` (after
  `settleLeg`, so the leg's revenue is still booked to the OLD route) and only then
  detaches/archives and assigns. An IDLE spare still moves instantly — no pointless
  delay. Two non-obvious consequences handled: `assignSpareToPendingRoutes` skips
  routes reserved by a pending move (otherwise a newly-bought spare STEALS the
  route the airborne aircraft is heading to — this is tested), and
  `pendingRouteId` is PERSISTED (optional field on AircraftSave, back-compatible)
  so a save/load mid-move doesn't strand the aircraft. Surfaced in the UI: the
  confirm panel reads "closes after this leg", the flash says "moves over after it
  lands at X", and the Fleet detail shows an amber "Moves to PDX–SEA after landing
  at BOS" line. If the reserved route disappears before arrival (e.g. a slot
  buyback), the pending move is dropped rather than crashing.
  Verified 41/41 headless (archival, slot accounting incl. the shared-endpoint
  case, inert failures, no aircraft pointing at a closed route, no teleport, the
  route-stealing guard, completion on arrival, immediate move for idle spares, and
  a save/load round-trip of a pending move) plus live in the Simulator.

## Decided — Map (real geography, replacing the original abstract scope grid)

- **Airport positions are real**, not hand-placed. Each airport carries
  real lat/lon; a lightweight equirectangular projection with a longitude
  cosine correction at the map's center latitude (`projectPoint()`,
  shared by airports AND the basemap below so nothing can drift out of
  alignment) converts these to "world pixel" coordinates once at startup.
  NOT a true Albers/conic projection — a defensible approximation at this
  latitude range and scale, not survey-grade, and NOT a true global
  projection either (see camera section below — still a fixed rectangular
  lon/lat box, not a sphere).
- **Airport network grew in three passes, worth knowing the accounting**:
  started at 7 placeholder airports → 25 (definitive top-25 by fee,
  designer-sourced) → 46 (top 26-50 batch, minus BWI/FLL which were
  duplicates across both source lists with conflicting ground-stop
  numbers, see Economy section) → 48 (added ANC + Honolulu HNL once the
  projection bounds were expanded to include Alaska/Hawaii). Current
  count is 48, not 25 or 50 — don't assume either round number.
- **`WORLD_BOUNDS` now covers Alaska-to-Hawaii-to-East-Coast**
  (`latMin: 18, latMax: 71, lonMin: -170, lonMax: -66.5`), expanded from
  continental-only. This was a deliberate reversal, not scope creep: the
  designer's stated direction is an eventual GLOBAL map (players will
  open routes worldwide), so when ANC/HNL needed the map to go
  non-continental, the choice was between a throwaway continental+AK/HI
  patch or building the real mechanism (camera pan/zoom, see below) that
  a global map will actually need. Chose the latter — "let's do C."
  Aleutian Islands are clipped at `lonMin: -170` rather than crossing the
  antimeridian, which this projection can't handle cleanly; no airports
  sit that far west so it doesn't matter yet.
- **Camera system: pan (drag) + zoom (scroll wheel, cursor-anchored),
  the desktop-appropriate equivalent of pinch-zoom** (which isn't a
  native desktop gesture — the eventual mobile app gets real pinch-zoom +
  touch-drag, this is NOT the final interaction design, just the
  right one for a browser POC). Implementation: `camera = { zoom,
  worldCenterX, worldCenterY }` is a transform applied ONCE per frame via
  `ctx.translate/scale/translate`, wrapping all world content (geography,
  airports, aircraft). Mouse hit-testing inverts the same transform once
  (`screenToWorld()`) rather than every position needing dual awareness.
  Default view is NOT the full Alaska-to-Hawaii world — `resetCameraToConus()`
  computes a zoom/center that frames continental US specifically (real
  lat/lon math, not hardcoded pixel numbers, captured once into
  `DEFAULT_CAMERA_ZOOM` for reuse elsewhere — see the sizing curve below),
  matching what the map looked like before this expansion. A "Reset View"
  button returns to this default after panning away. Real bug caught
  before shipping: the reset button initially shared `class="speed"` with
  the game-speed controls, which would have swept it into that click
  handler and set game speed to `NaN` on click, silently freezing the
  tick loop — caught by checking the class assignment before shipping,
  not by a bug report.
- **Airport AND aircraft screen size follow a shared damped zoom curve —
  this went through two real iterations based on direct designer
  feedback, not one clean build.** V1 (first shipped): airport dots were
  made fully zoom-INVARIANT (constant screen size regardless of zoom,
  like a map pin), while aircraft icons were left with NO zoom
  compensation at all (scaling fully proportional to `camera.zoom`, same
  as terrain). Designer feedback on V1: airports should grow SLIGHTLY at
  high zoom (not stay perfectly flat), and aircraft were "too large when
  zoomed in" — the fully-proportional behavior was the actual problem,
  not a minor tuning issue. V2 (current): both now share one function,
  `getMapElementVisualScale()` — constant size from zoomed-out through
  the default (CONUS-framing) zoom level, then growing modestly, capped
  at exactly +15% at max zoom (`CAMERA_MAX_ZOOM`). Airports implement
  this by dividing their base pixel sizes by `zoom/visualScale`; aircraft
  implement it by inserting an explicit counter-scale `ctx.scale()` call
  into `drawAircraft()` that didn't exist before (they previously relied
  entirely on the ambient camera transform for sizing, which is exactly
  why they scaled fully proportional). Verified numerically before
  shipping both times — screen-pixel output confirmed via script at
  multiple zoom levels, not just eyeballed after a code change.
- **Real basemap, including Alaska and Hawaii** (added after an earlier
  gap where AK/HI airports existed with no landmass under them — same
  `us-atlas` extraction pipeline, re-run with AK/HI INCLUDED instead of
  filtered out). Nation outline and state borders both cover all 50
  states now, not just the continental 48.
- **Canada renders as a separate, deliberately muted background-context
  layer** (`CANADA_RINGS`, sourced from the `world-atlas` npm package —
  a NEW dependency, not previously in this project — filtered to Canada's
  ISO numeric id 124, tiny Arctic-archipelago islands dropped). Purely
  visual context so Alaska doesn't read as a disconnected blob floating
  in empty ocean space; NOT interactive, no airports here, drawn UNDER
  the US outline in a neutral gray specifically so it stays visually
  secondary. Real geography, but deliberately the least prominent layer
  on the map by design, not by oversight.
- **Label decluttering**: airports genuinely close together at this map
  scale get their text labels fanned out with leader lines
  (`computeAirportLabelPositions()`), while their dots stay at true
  projected positions. Runs generically over whatever's in `AIRPORTS`, so
  it automatically picked up new clusters when the network grew to 48
  (Chicago's MDW/ORD, the Bay Area's SFO/SJC/OAK three-way, DFW/DAL,
  LAX/SNA, BWI/IAD, AUS/SAT, IAH/HOU, MCO/TPA, on top of the original
  JFK/EWR/LGA and MIA/FLL) — no code changes needed when the airport
  count grew, this held up as designed. Cluster detection itself is
  computed ONCE at startup and does NOT re-evaluate as the player zooms —
  a cluster fanned out at the default zoom stays fanned out even if
  zooming in would naturally have given it enough room to un-fan. Known,
  not fixed — flagged in Open below.
- **Airport hover tooltip**: shows live ground-stop status (with time
  remaining if active), on-ground/inbound aircraft counts, and fee
  reference data. Shares the same tooltip DOM element as the aircraft
  tooltip (id is still `aircraftTooltip` — cosmetic naming leftover, not
  worth a rename-everywhere). Aircraft hover takes priority over airport
  hover when they overlap (a PARKED/BOARDING/TURNAROUND aircraft renders
  at the airport's exact position) — this was an explicit default, not
  extensively tested against alternatives.
- **A real reported bug: flight-path arcs looked disproportionately
  curved on short routes.** Root cause in `getPathPoints()`: the bezier
  midpoint's vertical offset was a FIXED 90px regardless of the actual
  distance between the two airports — a short hop (e.g. DEN-MCI) got the
  exact same bulge as a coast-to-coast route, which reads as an
  unrealistic exaggerated arc on anything nearby. Fixed to scale with
  real distance: 12% of the straight-line distance between the two
  points, floored at 15px (so very short hops still read as a
  deliberate curve, not robotically straight) and capped at 120px (so a
  genuinely long route doesn't arc absurdly high relative to the visible
  map). These specific proportions are a designed visual choice, not
  sourced from anything. Verified numerically: a short route now gets a
  ~15px arc instead of the old flat 90px, scaling smoothly up to the
  120px cap for long routes.

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
  (NOT a shared constant) so the real size hierarchy holds. Current values
  (as of the +15% designer-requested bump, up from an earlier baseline
  that itself already wasn't the original ship values — this comment had
  gone stale before, check the actual code if precision matters):
  regionalJet 9.9px < narrowbody 12.5px < widebody2Engine 17.1px <
  widebody4Engine 19.9px. A shared constant was tried first (early in the
  icon work) and caused a real bug (narrowbody rendering larger than the
  widebody fallback) — caught and fixed before shipping, not after.
- **Icon screen size now follows a damped zoom curve, not the ambient
  camera transform directly.** Originally aircraft had NO zoom
  compensation and scaled fully proportional to `camera.zoom` (this is
  what made them feel oversized when zoomed in — a real designer-caught
  issue, not a hypothetical). Fixed by sharing `getMapElementVisualScale()`
  with airports (see Map section) — both now render at a constant size up
  to the default (CONUS-framing) zoom level, then grow modestly, capped at
  +15% at max zoom, rather than airports staying perfectly flat and
  aircraft scaling linearly. This required an explicit counter-scale
  `ctx.scale()` call inserted into `drawAircraft()`, not just a constant
  tweak — the two element types now share one formula but arrive at their
  final size through different render-path mechanics (airports divide
  their base radius, aircraft insert a compensating transform).
- **bodyType now drives THREE independent things** that all happen to
  read the same field: gate-fee tier, on-scope render scale (fallback
  triangle path), and icon selection (`AIRCRAFT_ICON_PATHS` lookup, real
  Figma icon path). Changing what a bodyType string means has
  consequences in all three places — check all three before renaming or
  adding a bodyType value.
- All 4 icon tiers are confirmed visually correct in-browser (narrowbody,
  then widebody2Engine via the 777/787 smoke test, then widebody4Engine
  via 747/A380/A340) — real verification, not just algebraic
  transform-math checking. This was checked type-by-type as each was
  added, and again after the zoom-curve and +15%-size changes via
  numeric script verification (constant-then-damped-growth confirmed
  exact at multiple zoom levels), but a full in-browser re-check across
  the entire 31-type fleet at varied zoom levels hasn't happened.
- **A real reported bug: aircraft color stayed in the wrong flight-phase
  color too long, both at takeoff and at landing.** Root cause: color was
  picked from an altitude THRESHOLD (`pos.alt > 0.5`), which never
  actually lined up with the real state-machine transitions. Checked the
  actual altitude curves before fixing: TAKEOFF's altitude never even
  crosses 0.2 across its whole duration (so it never triggered the
  "flying" color at all during takeoff), while APPROACH stayed above the
  0.5 threshold for roughly the first 71% of its duration before
  dropping. Fixed by tying color DIRECTLY to the real state, not
  altitude: the player's own aircraft now use three real per-phase
  colors — `#37FFB0` (takeoff/initial climb, the original green,
  unchanged), `#83C9FF` (cruise — updated from an initial `#6CD3FF` for
  better contrast, a follow-up tweak in the same session), `#FFB300`
  (descent/landing, i.e. APPROACH+LANDING states). Ground states keep
  the original amber, unchanged. Applied the same state-based fix (not
  altitude-threshold) to background traffic too, for the same accuracy
  reason, even though only the player's colors were explicitly requested
  to change.
- **Background traffic's color scheme was simplified to one constant
  color**, replacing an earlier two-tier blue/orange (flying/ground)
  scheme from the same session. Makes background traffic instantly
  recognizable as "not mine" regardless of what it's doing, without
  needing the phase-distinction that actually matters for the player's
  own fleet. The constant color itself was tweaked once already —
  `#B25BFF` initially, then `#D767FF` in a follow-up pass because the
  first value "wasn't popping enough" — current value is `#D767FF`, if a
  future edit references the old one it's stale. HELD (red) stays a
  shared universal constant for both ownership tiers — background
  traffic can still show a real weather ground-stop, and red-for-problem
  doesn't need a fourth color.

## Decided — Native iOS Port (Phase 0–1, the actual Xcode app)

The port from the browser prototype into the real SwiftUI app has started.
The prototype (`prototype-reference/…Stress Test.html`) remains the source
of truth for all sim behavior — the Swift code ports FROM it, verbatim
where numbers are involved.

- **App RENAMED SkyOps → Airline Architect (designer direction).** Full deep
  rename done and build-verified: the `.xcodeproj`, all three targets
  (`AirlineArchitect` / `AirlineArchitectTests` / `AirlineArchitectUITests`),
  the source/test/container folders, the scheme (autocreated from the target,
  so `xcodebuild -scheme AirlineArchitect`), the entitlements file, the app
  struct (`AirlineArchitectApp`), the logo type (`SkyOpsLogo` → `AppLogo`),
  and the **bundle id** (`Postmark-Digital.SkyOps` → `Postmark-Digital.AirlineArchitect`)
  all carry the new name. `CFBundleDisplayName` = "Airline Architect" (in the
  merged `Info.plist`). The default blank-name airline is now "New Airline"
  (was "SkyOps Air"). Identifiers use the NO-SPACE `AirlineArchitect`; the
  human display name uses the space. **Deliberately still named SkyOps** (not
  a miss): the git REPO directory (`GitHub/SkyOps`), the Figma file
  (`SkyOps-Production`, an external name), and the prototype artifact
  (`prototype-reference/SkyOps — Multi-Aircraft Stress Test.html`). The
  launch/naming screen reuses the SAME winged-plane badge mark; only the
  wordmark changed to the two-line "Airline Architect" (Karla Light 25), and
  the whole naming screen now uses the bundled Karla family.

- **Project shape**: `AirlineArchitect/AirlineArchitect.xcodeproj`, SwiftUI + SwiftData
  template. objectVersion 77 → uses **file-system-synchronized groups**
  (`PBXFileSystemSynchronizedRootGroup`): any `.swift` file dropped inside
  `AirlineArchitect/AirlineArchitect/` is auto-compiled into the app target — NO `.pbxproj`
  editing needed to add files. This is a real workflow win; don't hand-edit
  the project file to register new sources, just create them in the folder.
- **Min deployment target: iOS 18.0** (was 26.5 from the template default).
  Nothing in the port needs iOS-26-only APIs; 18 maximizes reach at no
  technical cost. Set across all three targets.
- **SwiftData kept** (template default) but NOT used yet — Phase 1 has
  nothing to persist. `Item.swift` template model deleted. SwiftData
  returns for real in Phase 5 (fleet/routes/economy persistence).
- **Tick engine architecture (Phase 1)**: `Simulation` is a `@MainActor
  @Observable` class owning airports + aircraft + `tick`. The tick loop is
  `Simulation.run()` — a Swift-Concurrency async task started from the
  view's `.task`, using a `ContinuousClock` accumulator: `BASE_TICK_MS =
  250` at 1× (ported from the prototype), divided by `speed`, capped at 50
  catch-up ticks/wake. This is the ROADMAP's "async tick source decoupled
  from render frame rate." Verified in-sim the timing matches the prototype
  exactly (142 ticks in 7s at 5×).
- **State machine + interpolation ported VERBATIM** into `Sim/FlightState`,
  `Sim/FlightPath`, `Sim/Aircraft`. The chained per-state `t` ranges
  (takeoff 0→0.12, cruise 0.12→0.82, approach 0.82→0.92, landing
  0.92→1.0) and the eased takeoff/landing curves are the exact prototype
  values — that continuity is what prevents the takeoff-jolt/landing-
  teleport bugs. Phase 1 deliberately OMITS the WEATHER holding-pattern and
  REJOIN branches (Phase 3). Aircraft color is tied to real flight PHASE,
  not an altitude threshold — same validated fix as the prototype.
- **A real SwiftUI redraw bug caught by watching it run, NOT by the build
  — and it WILL recur in Phase 2+.** The map froze at the launch frame
  (aircraft stuck parked-at-SFO, amber) while the HUD's tick/phase advanced
  live. Root cause: a child view (`MapView`) whose only stored property is
  a reference type (`Simulation`) that never changes gets diffed as
  IDENTICAL by SwiftUI every tick, so its `body` is never re-invoked and
  its `Canvas` never redraws. Plain (non-`@Observable`) model classes
  (`Aircraft`/`Airport`) don't help — they carry no observable dependency.
  Neither did a `TimelineView(.animation)` wrapper, nor a discarded `let _
  = sim.tick` read inside the frozen body. **The fix that works: pass the
  changing value (`tick: sim.tick`) into the child view as a real VALUE
  input, so SwiftUI sees the input change and re-renders.** Aircraft
  position is a step-function of the tick, so a tick-driven redraw is exact,
  not a hack. This is the SwiftUI analog of the prototype's three-times-
  recurring per-tick panel-flicker bug: any new tick-driven Canvas or panel
  view (fleet, routes, decision cards in later phases) must take a changing
  value input, or it will silently freeze. If a second view freezes this
  way, build the shared pattern rather than fixing it one-off a fourth time.
- **Verification practice for the native app**: a clean `xcodebuild`
  build proves NOTHING about runtime behavior — the freeze above compiled
  perfectly. Same lesson as the prototype's `operatingCost` ReferenceError
  (`node --check` passed it). Drive the app in the simulator
  (`xcrun simctl` install/launch/screenshot) and actually WATCH the
  behavior before calling a phase done. This caught the freeze bug.
- **Phase 2 (multi-aircraft + fleet + icons) — DONE.** Ported the full
  fleet data as Swift structs (`AircraftType.all` = 30 variants, weighted
  `pickWeighted`; `Airport.all` = 48 airports with real fee/ground-stop
  fields). Stress-test fleet spawns weighted/staggered via `setFleetSize`
  (10–250). Verified 250 aircraft tick at the full rate with no drops —
  Canvas + tick-driven redraw scales fine. The 4 real Figma icon tiers
  render via a hand-written `SVGPath.parse()` (M/L/H/V/C/Z, absolute +
  relative, handles scientific-notation numbers like `4.8e-06`; no arcs/
  shorthands — the icons don't use them) → SwiftUI `Path`, cached once in
  `AircraftIcon.byBodyType`, scaled per-tier by `targetLength/viewBoxWidth`
  and recentred, nose authored toward +x so `rotate(heading)` aims it. Same
  transform order as the prototype's `drawAircraft`.
- **Default map framing = continental US** (`Simulation.layout` excludes
  ANC/HNL from the fit bounds, like the prototype's `resetCameraToConus`).
  There is NO camera/pan-zoom yet — that's Phase 4; until then ANC/HNL
  render off the framed area and AK/HI-bound flights fly off-screen. This
  is expected, not a bug.
- **Deferred out of Phase 2 into the economy work**: the ROADMAP folded
  revenue/operating-cost/economic-event systems into Phase 2, but they
  pair more naturally with the Phase 5 economy + the hover-tooltip UI —
  not yet ported. Phase 2 covered scale + types + icons only.
- **Basemap (continent outline + state lines) — PULLED FORWARD from
  Phase 4** at the designer's request while looking at the map. Real
  geometry (`US_NATION_RINGS`/`US_STATE_RINGS`/`CANADA_RINGS`) extracted
  from the prototype into a bundled `Basemap.json` (~58KB: 26 nation
  rings, 51 state features, 22 Canada rings), decoded + pre-projected to
  unit space once in `Basemap.swift`, drawn beneath airports in
  `MapView.drawBasemap` with the prototype's colours/layer order (Canada
  muted gray → US nation faint-green fill+stroke → state borders fainter).
  Projects through `Simulation.transform` (the shared unit→screen map
  transform, now exposed) so it can't drift from the airports. The rest of
  Phase 4 (pan/zoom camera, label decluttering, the Figma UI pass) is
  still deferred — only the static basemap was pulled forward.
- **Resource bundling works with synchronized groups**: dropping
  `Basemap.json` in the app folder (under `Resources/`) auto-bundles it —
  confirmed it lands in the built `.app` and `Bundle.main.url(forResource:)`
  finds it. No pbxproj resource-phase editing needed, same as source files.
- **LATIN AMERICA expansion — DONE (native app). 48 → 93 airports; map now
  covers Alaska → the Americas down to Argentina.** Added 15 Mexico + 10
  Central America + 20 South America airports (`Airport.all`), real lat/lon.
  Fee/ground-stop figures are **TIER-BASED ESTIMATES** calibrated to the US
  ranges + each airport's real size/role — NOT per-airport sourced signatory
  rates (unavailable for most); same "weakest tier" confidence as the RJ
  weights. Flagged in the code.
  - **Projection extended WITHOUT disturbing the existing North American map**
    — the key trick: `GeoProjection` keeps `lonMin = -170` and `latMax = 71`
    UNCHANGED and PINS the longitude cosine correction to a new constant
    `cosRefLat = 44.5` (the ORIGINAL bounds' centre) instead of recomputing it
    from the new centre. Since `unit()` only uses `lonMin`, `latMax`, and
    `lonCorrection`, every previously-placed point (US/Canada geometry, all US
    airports, the CONUS frame) projects to the EXACT same unit position; only
    `latMin` (−56, Tierra del Fuego) and `lonMax` (−33, Recife) grew, extending
    the canvas south/east. Default CONUS framing is unchanged (verified) —
    `conusFrame` uses fixed CONUS bounds, and `defaultZoom`/`worldScale` cancel
    so CONUS fills the frame identically; the previously-empty southern margin
    now shows Mexico peeking in, inviting pan-down.
  - **Basemap geometry**: pulled Natural Earth 110m country outlines (same
    fidelity as the existing Canada layer) for the 20 countries via `curl` +
    a Python extract (outer rings only, tiny-island drop, 2-dp round) → a new
    `"latam"` key in `Basemap.json` (22 rings, ~1.4k pts, +22KB). `Basemap.swift`
    decodes it (optional, back-compatible) and projects it through the SAME
    `GeoProjection`; `MapView.drawBasemap` renders it muted like Canada (faint
    fill + 0.20 stroke). Verified in the Simulator: all 45 airports sit on their
    countries (BOG/Colombia, LIM/Peru coast, GRU-CGH/São Paulo, EZE-AEP/Buenos
    Aires, SCL/Chile, REC-SSA/Brazil east coast), US map pixel-identical.
  - **Region-aware competitor airlines — DONE, then EXPANDED to 5 regions.**
    `Airline.Region` = {us, canada, mexico, centralAmerica, southAmerica}, each
    with its OWN roster (`roster` US / `canadaRoster` / `mexicoRoster` /
    `centralAmericaRoster` / `southAmericaRoster`) and its own airport-code Set
    (`canadaCodes`/`mexicoCodes`/…; US is the default). `Airline.region(code)`
    classifies an airport; `pick(forType:origin:dest:)` draws that region's
    roster for a same-region leg, or BOTH rosters for a cross-region leg (every
    type resolves → Independent Operator fallback). `makeAircraft` calls it with
    `Airline.region(origin.code)`/`dest.code`. This replaced the old binary
    `latamRoster`/`latamAirportCodes`/`pick(…originLatam:destLatam:)` — the LatAm
    pool was too coarse (MEX↔CUN could show LATAM). Carriers (real, per-type
    researched, real IATA codes incl. digit ones): Canada — Air Canada, WestJet,
    Jazz, Porter, Air Transat, Flair; Mexico — Aeroméxico, Volaris, Viva Aerobus;
    Central America — Copa, Avianca, Volaris; South America — LATAM, GOL, Azul,
    Avianca, Aerolíneas Argentinas, SKY, JetSMART. New codes in `realCodes`:
    AD/VB/JA (LatAm) + TS/PD/QK (Canada). Verified 17/18 headless (the one
    "fail" was a bad test expectation — Air Canada correctly doesn't fly the
    737-800, only the MAX 8): region isolation both ways, transborder shows both,
    every type resolves in every region pair, tails carry real codes.
  - **Remaining scope note (deliberate)**: still no region-SELECTION (player
    always starts US). The equirectangular projection stretches the far south
    modestly (pinned cosine) — accepted per the "not a true global projection"
    limitation.
- **Cozumel (CZM) added — 114 airports (48 US + 46 LatAm + 20 Canada).** For the
  scuba divers. Real lat/lon (20.52, −86.93), Mexico-tier fees; added to
  `mexicoCodes` so it draws Mexican carriers.
- **NETWORK control bars restyled for light (Figma 2:1592) — DONE.** The control
  bar / speed bar were dark navBarDark boxes that read as "black" on the white
  light map. Now theme-aware via `barBG`/`barBorder`/`barText`/`barShadow` in
  NetworkView: dark = navBarDark @0.92 (unchanged); **light = opaque white + a
  #C9C9C9 border + soft shadow + #497AA5 "Core Blue" text** (Figma uses white@80%
  but opaque here since our map is white, not the Figma's dark screenshot). The
  active speed pill stays bright-blue+white in both. The DEV Competitive-Traffic
  + Pro-toggle controls (previously loose) are now wrapped in a matching
  `devControls` container so they don't get lost on white; the traffic count
  colour is theme-aware too. Verified both themes.
- **Map is now THEME-AWARE (was dark in both themes) — DONE (designer request).**
  `MapView` reads `@Environment(\.colorScheme)`: **light mode = white canvas**,
  dark mode unchanged. Only the background, grid, labels, and selection ring
  flip: `mapBackground` (white/dark), `gridColor` (black-tint/white-tint),
  `labelColor` (slate #334155 / white), `selectionRing` (black/white). Coloured
  strokes get a `strokeBoost` (×1.7 in light, ×1.0 in dark) because a light
  colour at low opacity vanishes on white; region FILL opacities are also
  bumped in light. Airport dots stay green (climb-green) in both. Verified both
  themes (dark pixel-unchanged). Follow-up (done): the player's own CRUISE-phase
  colour is now theme-aware — `#83C9FF` on dark, **`#4E67A0` on light** (the
  section-header blue) since the light blue washed out on white; `cruiseColor` is
  a computed var in MapView. Also: NetworkView's header/eye/bell + the
  Competitive-Traffic/Pro(DEV) labels were switched from the bright `#0EA5E9` to
  the shared `titleColor` (dark `#BDE0FF` / light `#4E67A0`, Figma 2:1594) so the
  Network tab matches every other tab's section-header colour (the bottom tab-bar
  active tint stays bright blue — that's its own Figma spec).
- **Per-region geography COLOURS — DONE (designer request).** The basemap used
  to be all one green; now each region has its own hue at a shared brightness
  (the old US-outline treatment: faint fill + `0.35×strokeBoost` outline, one
  colour each): **US blue `#4A9EFF` · Mexico green `#35C75A` · Canada red
  `#FF5C5C` · Central America orange `#FF9A3C` · South America yellow `#EDB93C`**.
  Required SPLITTING the old single `latam` basemap layer into `mexico` /
  `centralAmerica` / `southAmerica` keys in `Basemap.json` (re-extracted from the
  same Natural Earth 110m geojson, per-region; `Basemap.swift` decodes the new
  optional keys). Canada gained a fill (was stroke-only muted grey). US state
  borders are a faint US-blue now (were grey). `MapView.drawBasemap` has a
  `region(rings, color)` helper. Colours defined as `usColor`/`mexicoColor`/etc.
  in MapView. Verified both themes framed to the whole Americas.
- **Canada airports — DONE. 93 → 113 airports (48 US + 45 LatAm + 20 Canada).**
  Top-20 Canadian airports added to `Airport.all`, real lat/lon; fee/ground-stop
  figures are tier-based ESTIMATES like the LatAm set (ground-stops lean high for
  winter/Atlantic-weather airports). **Correction applied:** the requested "YKA
  — Kelowna" is wrong (YKA is Kamloops); added Kelowna as **YLW** (correct code).
  No WORLD_BOUNDS change needed (all within existing lat/lon extent). SCOPE NOTE:
  no Canadian CARRIERS yet — Canadian domestic legs draw the US roster (Air
  Canada is in it for widebodies only), so YYZ↔YVR shows US carriers; the
  region-aware `pick` only splits US vs LatAm. Adding WestJet/Porter/Flair + a
  Canada region is an easy follow-up if wanted.
- **Pan/zoom camera + airport labels — ALSO PULLED FORWARD from Phase 4**
  (same session, designer focused on the map). The projection is now
  camera-based: everything lives in unit space and `Simulation` maps
  unit→screen via `{cameraZoom, cameraCenter}` each frame (`project`/`unit(fromScreen:)`).
  Ported from the prototype's camera: default view frames CONUS
  (`resetCameraToConus` math, 0.92 pad), zoom clamps to [0.4×, 4×], and a
  damped `elementScale` keeps airports/aircraft legible (constant size to
  default zoom, +15% at max) instead of ballooning. Gestures: `DragGesture`
  → `pan`, `MagnifyGesture` (anchored at pinch start) → `zoom`, plus a
  RESET VIEW button. Airport code labels now render (constant size), and
  zooming separates the dense NE / Bay-Area clusters.
- **Redraw on camera change uses the same value-input pattern as `tick`**:
  `MapView` takes `cameraZoom`/`cameraCenter` as inputs (ContentView reads
  them from the `@Observable` sim), so a pan/zoom re-renders immediately,
  not on the next tick. Same fix family as the Phase 1 freeze bug.
- **Default-framing robustness**: a transient launch/rotation viewport size
  briefly mis-framed the map once. Fixed with `userAdjustedCamera` — the
  view auto-re-frames CONUS on every size change UNTIL the user first
  pans/zooms, so a bad transient size can't lock the wrong framing.
  RESET VIEW clears the flag (re-enables auto-framing).
- **Verification caveat**: pan/zoom RENDERING was verified (exact camera
  values confirmed via an on-screen debug readout; a forced zoomed-in view
  confirmed basemap scaling + label separation + non-ballooning icons). The
  live GESTURE input was NOT driven end-to-end — the user declined
  Simulator control for computer-use — so the drag/pinch handlers
  themselves are only verified by inspection, not by a real gesture.
  UPDATE: designer confirmed interactively — "pan feels great, as does
  pinch." Max zoom raised 4→14→28→**60** (`cameraMaxZoom`) across designer
  passes — the latest bump (28→60) so tightly-clustered airports (SFO/OAK/SJC)
  can be pinched far enough apart to tap the right one against the 44pt hit
  target. The icon-growth curve is anchored to a FIXED span (defaultZoom×2.5) so
  icons/airports don't balloon as max zoom rises; labels get their own
  `labelScale` reaching +15% at max zoom. Basemap coastline reads faceted at
  extreme zoom (topology-simplified source) — accepted for now.
- **TAP AN OPS EVENT TO LOCATE ITS AIRPORT — DONE (native app).** `OpsEvent`
  gained an optional `airportCode` (set on capacity-expansion + single-airport
  ground-stop logs via `logOps(..., airportCode:)`). Those Ops event cards show a
  "Show on map" affordance + chevron and are tappable → `Simulation.focusCamera(on:)`
  centers the map on that airport (zoom `max(defaultZoom*8, 10)`, capped at max)
  and ContentView switches to the Network tab (`onShowAirport` closure). Solves
  "most airport codes are foreign to the player" (WLG, YVR…) — they can see WHERE
  it is. Route-opened (two airports) is deliberately not mappable.
- **Label declutter — DONE, better than the prototype.** Ports
  computeAirportLabelPositions() (greedy 13px-threshold clustering, ring
  fan from cluster centroid starting straight up, leader lines) but
  recomputes clusters against CURRENT screen distance EVERY FRAME — the
  exact upgrade the old "doesn't re-evaluate on zoom" Open item asked
  for, affordable now because 48 airports is ~1,100 distance checks.
  Fanned clusters un-fan automatically once zoom gives labels room.
  Ground-stopped airports' labels render red. The old Open item is
  resolved for the native app (the browser prototype still has the
  static version).
- **Wrap-around map — DONE (native app; designer request).** The map now
  tiles horizontally so panning east/west circles the globe seamlessly
  instead of hitting a hard edge (Tahiti/far-east rolls into the
  Americas/far-west and back). Mechanism: `Simulation.wrapWidthUnits =
  360° × lonCorrection` is the wrap PERIOD; `wrapDrawOffsetsPx()` returns
  the pixel x-offsets of every world tile that intersects the viewport,
  and `MapView` redraws the whole world (basemap/routes/airports/aircraft)
  once per offset into a translated `GraphicsContext` copy (same trick
  `drawAircraft` already used per-icon; the grid stays screen-space, drawn
  once). `pan()` normalizes `cameraCenter.x` mod the period via
  `wrapCameraX()` (a shift of exactly one period is invisible on a periodic
  scene, so it never jumps); the incremental-delta drag gesture is
  unaffected. Hit-testing (`airport(atScreenPoint:)`/`aircraft(...)`) uses a
  `wrappedDX()` minimal-horizontal-distance so a tap on ANY tile registers.
  **Key subtlety, don't "fix" it:** the rendered content spans ~390° of
  longitude (Alaska −170° → Tahiti stored at +210°), but the wrap period is
  360°, NOT the 390° content width — because Anchorage and Tahiti are at the
  SAME real longitude (~150°W) and must coincide at the seam. This leaves a
  ~30° overlap of near-empty mid-Pacific where far-north (Alaska) and
  far-south (Tahiti/NZ) content co-draw at the same x but different
  latitudes — correct, not a bug. Verified: seam renders Asia→Americas
  across the Pacific like a globe; default CONUS view pixel-unchanged (tiles
  off-screen at that zoom). NOT fixed by this: a single flight leg whose
  endpoints straddle the seam still draws the long way around (rare;
  acceptable). The browser prototype does NOT have wrap.
- **Phase 3 slice 2 — AOG + decision cards, DONE.** Faithful port:
  calibrated onset (2/100/month as continuous per-tick probability),
  family clustering (3×, 3-sim-day linear decay, families never
  cross-contaminate), maint blocks at the PARKED gate only (in-flight
  aircraft finish flying first), Expedite $15,000-now vs Standard
  $3,000-~3hr(180-tick timer). `Aircraft.advance` returns an
  `AdvanceEvent` (aogHoldStarted / aogRepairCompleted) so the aircraft
  stays free of queue/UI knowledge; `Simulation` owns `decisionQueue`,
  push (dupe-guarded), resolve, and `clearDecision` (the prototype's
  stale-card fix, called on timer completion + fleet shrink).
  `maintenanceSpend` accumulates real charges until the Phase 5 economy
  absorbs them. Decision cards are bottom-anchored SwiftUI views over the
  map — stable `Decision.id` + ForEach diffing is the SwiftUI idiom for
  the prototype's thrice-recurring per-tick-re-render bug; don't key
  cards off tick. OWNERSHIP SCOPING DEBT (deliberate): AOG currently
  applies to the whole stress-test fleet because `purchased` doesn't
  exist until Phase 5 — when it lands, gate `tickAOGOnset` on ownership,
  the SAME retrofit the prototype documents having missed once.
- **A second verification lane now exists and caught nothing only because
  it ran BEFORE shipping**: the Sim/ sources compile standalone with
  `swiftc` (no SwiftUI imports in the sim layer — deliberate), so a
  headless test harness can drive the REAL app code. The AOG slice
  shipped with 16/16 passing lifecycle checks (hold/push/resolve paths/
  timer/cleanup/onset statistics) run this way. Pattern lives in the
  session scratchpad, trivial to recreate: compile Sim/*.swift + a
  @main @MainActor TestMain.swift. Use it for every future sim-layer
  port (crew duty/rest is next and is exactly the kind of logic it
  catches).

- **Aircraft tap-tooltip — DONE, and a real gesture bug shipped twice
  before a fix stuck.** Tap-to-select (highlight ring + bottom card), tap
  empty to dismiss, field order per the documented designer decision
  (Route → Tail → Type → Status → Cycles) with marked slots for the crew
  and economy rows. THE BUG: tap + pan were TWO separate recognizers
  (`.onTapGesture` / `SpatialTapGesture` alongside `.gesture(DragGesture)`).
  They fought — the tap fired then the drag machinery cleared it, exactly
  the user's "flashes up then it's gone." First remote fix (swap
  SpatialTap→onTapGesture) also failed. THE FIX THAT WORKS: ONE
  `DragGesture(minimumDistance: 0)` that decides tap-vs-pan itself —
  movement > 8pt = pan, ended-without-moving = tap → hit-test at
  `v.location`. Simultaneous with the magnify gesture; nothing else
  competes. **Lesson for every future map interaction: don't stack a tap
  recognizer next to the pan recognizer — extend the ONE drag gesture.**
- **Gesture bugs are invisible to the headless harness — they need a real
  driven gesture.** The hit-test logic passed 4/4 headless checks and was
  fine; the bug was 100% in SwiftUI gesture COMPOSITION, which only
  surfaces through an actual tap. Verified the fix by driving the
  Simulator via computer-use (an on-screen tap-debug readout —
  `tap (x,y) → HIT/miss · sel yes/no` — pinpointed it as a hit that was
  immediately cleared, not a miss). When a UI-interaction bug resists
  reasoning, add a temporary on-screen state readout and drive it, rather
  than shipping another blind fix. (The user initially declined Simulator
  control, then granted it once the on-screen readout wasn't enough — ask
  for it when a gesture genuinely can't be verified any other way.)

- **Phase 3 slice 3 — crew, DONE. Phase 3 now COMPLETE (weather + AOG +
  crew).** Per-family pools (`Crew`, `crewPoolsByFamily`), real Part 117
  duty/rest (`maxDutyTicks`/`restTicks` = 600/600), duty accrues ACROSS
  flights and resets ONLY after a completed rest (the corrected version —
  verified duty reaching 926 before rest). Boarding gate holds an aircraft
  red for a legal crew and pushes a CREW card (Call reserve $5,000 / Wait);
  staggered spawns get backfilled crew with partial duty. The pool lives on
  `Simulation`; `Aircraft.advance` takes `assignCrew`/`releaseCrew` CLOSURES
  so the aircraft stays pool-free and headless-testable. Same event-return
  pattern as AOG (`crewHoldStarted`/`crewHoldResolved` → push/clear card).
  Tooltip's crew-legal-hours slot is now filled.
- **A real balance bug found and fixed BY the headless harness, not in
  play: crew provisioning has a hard CLIFF at the duty/rest break-even.**
  A crew flies ~55% of the time (2 cycles on, one 600-tick rest), so you
  need ~1.8 crews/aircraft just to keep aircraft flying. At/below 1.8 there
  is ZERO margin: any timing cluster starts a shortage that CASCADES into a
  permanent fleet-wide jam (I first shipped 1.8 → the whole screen filled
  with CREW cards). At 2.6+ it never holds at all (trivial, the thing
  CLAUDE.md warned about). A headless sweep (1.9–2.4 all steady, max 1–2
  simultaneous holds) pinned the usable band; locked `crewsPerAircraft =
  2.1`. LESSON: this behavior is bimodal (cascade vs dead) with a sharp
  edge — any future change to duty/rest timing, cycle length, or the ratio
  must be re-swept with the balance probe, not eyeballed. The real
  crew-management tension (starting under-crewed, hiring up) is the Phase 5
  player-driven model; this auto-provisioned ratio is the pre-ownership
  stand-in (same ownership-scoping debt as AOG — re-scope to `purchased`
  when it lands). **UPDATE: this auto-ratio stand-in is now GONE — replaced
  by the player-driven model below.**
- **Player-driven crew hiring — DONE (native app), replacing the auto-ratio
  `crewsPerAircraft = 2.1` stand-in entirely.** Ported the prototype spec
  (re-supplied by the designer). Buying/leasing/used-buying an aircraft now
  `grantBundledCrew(family)` — exactly 1 crew, plus 1 reserve seeded on the
  family's FIRST aircraft (1 bundled + 1 reserve = 2 total, the corrected
  count — was 2 reserves). `resizeCrewPools()` is CLEANUP-ONLY now: it clears
  a family's pool/reserves to 0 when its owned count hits zero (last sold),
  and NEVER grows/shrinks by any ratio — so the old cascade-prone 2.1 sweep is
  irrelevant (the balance probe no longer applies to crew sizing; the player
  sizes the pool). `hireCrew(family:)` costs a real `crewHireCost` (0.2% of a
  representative aircraft's price — ERJ $28k … 777 $578k, verified) charged to
  `playerBalance`. The CREW decision card gained a 3rd option "Hire · $X"
  (`resolveCrewHire`, disabled "Can't afford hire" when broke) alongside
  Reserve/Wait. `ownedFamilies`/`crewCount(family:)`/`ownedCount(family:)`
  feed the ADD CREW panel (which lands with the NETWORK view). Duty/rest is
  UNCHANGED (already correct: dutyTicks resets only on a completed rest). The
  intended tension is now REAL: a fresh 1-aircraft-1-crew operator hits a CREW
  hold within ~2 flight cycles and must hire — verified headlessly. Also
  removed `backfillStaggeredCrews` (dead — purchased aircraft always spawn
  PARKED and get crew at the boarding gate; background traffic uses no crew).
- **Fixed a real pre-existing gap while here: decision costs were FREE.**
  `maintenanceSpend` accumulated AOG-expedite ($15k) / AOG-standard ($3k) /
  crew-reserve ($5k) charges but NEVER subtracted from `playerBalance` and was
  never displayed — a dead accumulator, so every decision was silently free.
  Now a shared `chargeDecisionCost()` deducts from `playerBalance` (and still
  tracks the stat) at all three points, plus `hireCrew`. Verified headlessly.
- Crew model verified: 22/22 headless (bundled 1+reserve, per-family seeding,
  hire cost/deduction, sell-clears-only-at-zero + crew release, decision-cost
  balance deductions, resolveCrewHire assign+resolve, and the CREW-hold
  tension arising on a busy single-crew route).
- **NETWORK view — DONE (native app), the FIRST full app screen from Figma.**
  The app is now a 5-tab shell (`ContentView` = `TabView`: Network / Fleet /
  Crews / Ops / Finance — the latter four are "Coming soon" placeholders,
  designed later). `NetworkView.swift` is the Network tab, built to the Figma
  (2:1592 light / 2:1994 dark): a **Cash-on-hand + NETWORK header** (cash value
  green `#10B981`, live), an **eye** toggle (`View Overlay Menus` — hides the
  Control Bar + Speed Bar for a clean map; icon flips eye↔eye.slash) and a
  **bell** (`Events Icon`, badge on pending decisions — the events feed itself
  is NOT built yet, a real TODO), the **Network Control Bar** (Acquire A/C /
  Open Route / Routes / Hire Crew / Fuel Hedge — mutually-exclusive panels via
  a `NetPanel` enum, except Open Route which drives `routeMode`), the map, and
  the **Sim Speed Control Bar** (¼× ½× 1× 5× 10× 25×). Design tokens in the
  `Sky` enum (`brightBlue #0EA5E9`, `coreGreen #10B981`, `navBarDark #1F232D`,
  `darkBG #2B303D`, `onDarkStroke #4C5D88`, etc.); theme-aware via colorScheme.
  Karla/SF-Pro approximated with the system font (bundle OFL Karla for exact
  type). Tab icons are SF Symbol approximations of the Figma glyphs. The DEV
  TRAFFIC stress-test control (not in the Figma) is tucked under the eye
  overlays, labelled DEV.
- **The map is now a BOUNDED ROUNDED CARD, not full-screen — this reworked the
  tap coordinate space AGAIN.** The Figma insets the map (rounded card below
  the header, above the tab bar). So MapView's Canvas `.ignoresSafeArea()` was
  REMOVED (it now fills the card), and taps are read in a NAMED coordinate
  space (`.named("mapCanvas")` on the card) instead of the earlier full-screen
  `.global` fix — because the Canvas now fills the card, the card's local
  space IS the Canvas draw space. Verified live: route-picker DEN selection
  landed correctly in the new bounded card. (Lesson: the correct tap space is
  whatever matches the Canvas's actual frame — `.global` when it's full-screen
  ignoresSafeArea, a named/local card space when it's bounded.)
- **¼×/½× speeds + the ¼× rate limit — ported.** `Simulation.speedOptions` is
  now [0.25, 0.5, 1, 5, 10, 25]; `speed` is `private(set)` and set via
  `requestSpeed(_:)`. ¼× is capped at 3 uses per FIXED sim-day
  (`quarterSpeedUsesRemaining`, resets when `tick/1440` changes, NOT a rolling
  window); the 4th request snaps to 1× (not the previous speed). Verified 8/8
  headless. NetworkView reads/greys the ¼× control by the remaining count.
- **Two NEW control-bar panels (functional; FuelHedge now Figma-restyled — see
  the "Figma panel-restyle batch — DONE" note; AddCrew still dev-chromed):**
  `AddCrewPanel` (Hire Crew — lists owned families with crew count + real hire
  cost, verified showing "ERJ · 1 crew · 1 aircraft · Hire $28k" live after a
  purchase) and `FuelHedgePanel` (Fuel Hedge — empty-fleet / active-countdown /
  30-60-90-day-buy states, verified showing the empty-fleet message with no
  fleet). Both use a shared `NetPanelBox` dev chrome.
- Verified live in the Simulator: header + live cash update ($20M→$6M on a
  buy), all five control-bar buttons + panel switching, the eye toggle
  hiding/showing the bars, the bounded-card map tap (route picker), the speed
  bar, and the 5-tab nav. Existing panels (BuyPanel/RoutesPanel/tooltip/
  decision cards) carried over unchanged into the new view — their Figma
  restyle (Acquire, Routes, Open Route flow, tooltip, Fuel Hedge) was the
  designer's next batch of frames, now DONE (see the "Figma panel-restyle
  batch — DONE" note near the end of this Phase-5 section).
- **The headless harness now has a third proven catch** (after nothing,
  then the AOG lifecycle): it caught the crew cascade as a design/balance
  bug a unit test wouldn't frame. Two harness kinds now live in the session
  scratchpad: lifecycle assertions (`CrewMain` — 12/12) and a balance probe
  (`BalanceMain` — steady-state / max-simultaneous sweep). Both compile the
  real `Sim/*.swift`. Reach for the balance probe whenever a change alters
  rates, capacities, or timing.

- **EARLY-GAME BALANCE PASS (native app) — two tunables.** Playtest analysis
  found the reported "starter aircraft loses money even full" was NOT the base
  economics (a well-crewed ERJ135 nets ~+$1.8k/leg on a trunk route, +$2.5k on
  mid routes — profitable) — it was CREW-HOLD BURN. An under-crewed 1-aircraft
  operator sits in crew-rest holds, and that burn was charged at the FULL
  in-flight operating rate (op cost $9.7k vs $2.5k base → ~$5k/held-leg loss,
  ruinous). Fix 1: `holdBurnRate = 0.4` — a PARKED aircraft (AOG/crew hold)
  isn't burning full block-hour cost, so hold burn is 40% of the flight rate.
  Now under-crewing is a recoverable setback (~−$0.1M/mo drift, a clear "hire
  crew" signal + you still lose the held flights) instead of a death spiral, and
  a well-run regional is profitable. The AOG expedite-vs-standard tradeoff is
  PRESERVED and now correct: a regional's standard-repair burn (~$2.4k+$3k) <
  expedite $15k → wait; a widebody's (~$24k+$3k) > $15k → expedite. Fix 2 was
  `startingCapital` $20M → $30M, but **REVERTED to $20M by designer direction** —
  the starting stake is **$20M** again ($30M briefly aimed to reach a two-aircraft
  operation faster; the designer prefers the leaner $20M start). The slow-early-
  growth issue below still stands at $20M — revisit with a revenue lever if wanted.
  KNOWN DEEPER ISSUE (flagged, not fixed — a designer decision): growth is still
  slow in absolute terms because REAL aircraft prices ($14M–$300M) against
  realistic per-leg profit + the LOCKED ~6-hr flight cycle (aircraft fly only
  ~2 legs/day vs real ~6) mean long aircraft-payback times. Options if faster
  growth is wanted: higher starting capital, a gameplay revenue multiplier, or
  variable (distance-based) leg duration — none done, all change the game's
  core scale/feel.
- **Phase 5 core loop — the FULL SHIFT to a player-driven game, DONE.**
  Designer chose (over a hybrid) to match the prototype: a fresh session
  starts EMPTY — `startingCapital` **$20M** (was briefly $30M in an early-game
  balance pass, then reverted to $20M by designer direction — see above), zero
  aircraft, zero routes. The
  player BUYS aircraft (ACQUIRE panel, affordability-gated, sorted by
  price) which sit as idle SPARES (`isIdleSpare` — a purchased aircraft
  with no `assignedRouteId` returns early from `advance`, fully idle), and
  OPENS routes (tap-origin → tap-dest → confirm). `openRoute` charges a
  real cost (base + both gate fees + a per-endpoint slot-buyout premium
  when none free), consumes airport slots (`slotsTotal`/`slotsAvailable`,
  scaled inversely to landing fee, replenished slowly), and assigns a
  spare. Owned aircraft fly ONLY their route (A↔B); `settleLeg` feeds
  `playerBalance` + `Route.cumulativeNet` only for `purchased` aircraft.
- **Ownership scoping retrofit — done deliberately, the exact thing the
  prototype documents getting wrong once.** `purchased` gates: AOG onset,
  the crew boarding-gate, crew provisioning/backfill, SELL, and economics
  settlement. Non-owned = pure background flavor. The old FLEET slider is
  now a DEV stress-test control spawning NON-owned traffic; `setFleetSize`
  only ever trims non-purchased aircraft, so it can never delete an
  aircraft the player paid for (`ownedCount`/`stressTestCount`).
- **Architecture that kept it headless-testable**: `Aircraft.advance`
  takes `assignCrew`/`releaseCrew` CLOSURES and returns `AdvanceEvent`s
  (`legScheduled`/`legCompleted` now too) — the aircraft never reaches
  into the pool, balance, or routes. So the whole buy→spare→openRoute→fly→
  earn loop + scoping is verified by a standalone `swiftc` harness (23/23,
  incl. "shrinking the dev fleet never removes an owned aircraft"). Then
  the full loop was driven live in the Simulator ($20M → buy ERJ135 →
  open SLC↔RDU → balance grows as it flies).
- **Airport tap tolerance is 44pt** (`Simulation.airport(atScreenPoint:)`)
  — a fingertip, and nearest-wins keeps dense clusters unambiguous. 26pt
  (the first value) was too tight for real touch AND for driving via
  computer-use on the small simulator; don't shrink it.
- **Competitor airline identity — DONE.** Background (non-owned) traffic
  now carries a real competitor airline (`Airline.roster`, ported verbatim
  incl. the researched per-type eligibility — Southwest 737-only, Delta no
  Boeing widebodies, A340→100% Lufthansa, orphan types→Independent
  Operator). Assigned in `makeAircraft` via `Airline.pick(forType:)`.
  Competitor aircraft render in the constant `#D767FF` (owned = phase
  colours; held = red, shared) and get a REDUCED tooltip (airline +
  route/tail/type/status only — no crew/economics, a rival's books aren't
  visible). The old dev FLEET/"TEST" slider is now the player-facing
  "TRAFFIC" control.
- **Background traffic rebuilt to an AIRLINE-FIRST, region-constrained model
  (native app) — replacing the old type-first / random-global-route model.**
  The trigger was a real playtest report: an EgyptAir flight going South
  America → Oklahoma City. Root cause (two compounding bugs): (1) `makeAircraft`
  picked a random GLOBAL airport pair (`Airport.randomPair()`), and (2) a
  background aircraft RE-RANDOMISED to another random global pair every leg
  (`advanceTick`'s `.legScheduled`) while KEEPING its spawn carrier — so a
  carrier assigned on an African leg would later wander anywhere still wearing
  its livery. The new model: pick a REGION (weighted by that region's airport
  count ≈ its traffic share) → a CARRIER in it (`Airline.weighted(roster(for:))`)
  → a TYPE it actually flies (`pickBackgroundType`, weighted by global type
  commonness) → a ROUTE in its sphere (`backgroundLeg(for:)`). Each aircraft
  stores `homeRegion` and stays that ONE coherent airline for life; its re-route
  draws from the SAME `backgroundLeg(for: homeRegion)`. `backgroundLeg` is
  mostly a DOMESTIC leg within the region; ~25% of the time, and ONLY from a
  GATEWAY airport, an INTERNATIONAL leg to a plausible-neighbour region's
  gateway. Gateways = the busiest ~35% of each region's airports by
  `AirportInfo.annualPassengers` (min 2) — so a small airport (OKC, Bozeman)
  is domestic-only and never gets a foreign carrier flying in. Plausible
  corridors are `Airline.corridors` (real intercontinental flows; excludes ones
  nobody flies nonstop like Oceania↔Africa or South America↔Asia). Verified
  headlessly over 3,000 spawns + 3,000 ticks: 0 legs where the carrier's home
  isn't an endpoint, 0 international legs off-corridor or at a non-gateway, every
  EgyptAir leg touches Africa, and 0 foreign carriers at any small US airport.
  SIDE EFFECT (an improvement): the old "type-first" model's Southwest-under-
  representation artifact is GONE — carriers are now picked directly by roster
  weight, so Southwest ≈ its roster share. `Airline.pick(forType:origin:dest:)`
  still exists (region-combining) but is no longer used by background spawns.
  Helpers are `@ObservationIgnored lazy` (the `@Observable` macro rejects plain
  `lazy` stored props — needed that attribute to cache the region grouping).
  - **RANGE-GATED (native app) — a narrowbody is never handed a leg it can't
    fly.** A playtester saw an American A320 on FLL→BCN (transatlantic, far past an
    A320's range). `backgroundLeg(for:type:)` now takes the aircraft TYPE (picked
    before the leg in `makeAircraft`) and filters both the international-corridor
    dest AND the domestic dest to airports within `type.rangeNM` of the origin; a
    remote origin with nothing in range falls back to its NEAREST airport (rare,
    cosmetic). So only widebodies get the long corridors; short international
    (US↔Mexico/Canada) stays open to narrowbodies — realistic. Both call sites
    (spawn + the per-leg re-route in `advanceTick`'s `.legScheduled`) pass the
    type. Verified: 0 over-range legs across 400 background aircraft over 8k ticks.
- **Player airline naming — DONE, and the FIRST Figma-built screen.**
  First-launch modal (`AirlineNamingView`, overlaid in ContentView while
  `sim.playerAirlineName == nil`; blank submits as "New Airline"). Built to
  the designer's real Figma (file `wRMkEaLt6bJdZoHsOz9JWH`, node 1:2 light
  / 1:456 dark), theme-aware via `@Environment(\.colorScheme)`, all
  colours/sizes/spacing ported from the Figma tokens. The player's airline
  name renders (green) as the header of their OWN aircraft's tooltip
  (competitors already showed theirs).
- **Player fleet TAIL CODE — DONE (native app), a second field on the naming
  screen (designer request).** The player picks a 2-letter code stamped into
  every owned aircraft's tail (e.g. code `ZQ` → tails `N1ZQ`, `N2ZQ`…),
  replacing the old hardcoded `SK` suffix (note: `SK` was itself a real code
  — SAS — so the old default would have failed today's validation). Stored in
  `Simulation.playerTailCode` (default `"ZQ"` when blank), set by
  `nameAirline(_:tailCode:)`. **Validation: the code can't collide with a real
  airline's IATA designator** — `Airline.realCodes` (in Airline.swift) is a
  `[code: name]` map of the roster's own carriers plus ~50 major world
  airlines; the naming field live-validates (2 letters, uppercased, letters
  only), shows the exact owner on a hit ("UA belongs to United Airlines —
  choose another." in the readable `#FF9292`/`#D70000` red), red-borders the
  field, and disables Launch. `nameAirline` also ignores an invalid code
  server-side (keeps the default), so the sim can't be handed a colliding
  code. As a bonus, **competitor (background) traffic now carries its real
  IATA code in the tail too** — `Airline` gained a `code` field (AA/DL/WN/UA…),
  `Airline.pick(forType:)` now returns the `Airline` struct (was a bare name
  String — update this one caller signature if porting), and `makeAircraft`
  builds the tail from `airline.code` (Delta → `N123DL`); the generic
  "Independent Operator" fallback (empty code) gets `Airline.randomTailCode()`,
  a random non-real 2-letter code, so background tails are varied rather than
  all-`SK`. Verified: 12/12 headless (valid accept + uppercase, real-code
  reject, blank default, player tail carries the code, background shows real
  carrier codes) + Simulator screenshots of the new field and the UA error
  state.
- **Figma-to-code workflow that worked (for the next Figma screen):**
  `get_design_context` (official Figma MCP, loaded via ToolSearch) returned
  STRUCTURED React+Tailwind + a screenshot + a token list — NOT the
  raster the old CLAUDE.md note feared for full-screen mockups. So the
  caveat did NOT bite here; design-to-code gave real structure. Adapt the
  React/Tailwind to SwiftUI by hand (colours as hex, Tailwind sizes →
  points 1:1). The Airline Architect LOGO came back as an SVG asset (7 solid-fill
  paths) — rendered NATIVELY via the existing `SVGPath.parse` into a
  `Canvas` (`AppLogo.swift`), no bundled raster and it scales crisply.
  Downloaded from the `figma.com/api/mcp/asset/...` URLs (valid ~7 days).
- **Karla font — BUNDLED (font-substitution debt resolved).** The 5 static
  Karla weights (Light/Regular/Medium/SemiBold/Bold, OFL, from googlefonts/
  karla) live in `Resources/Fonts/` (+ OFL.txt) and are registered in
  `Info.plist` `UIAppFonts`. Confirmed in the built `.app`: the TTFs land FLAT
  in the bundle root (the synchronized group flattens `Resources/Fonts/*` out),
  so the bare-filename UIAppFonts entries resolve. `Font.karla(_:_:)`
  (Typography.swift) maps a SwiftUI weight → the matching face
  (Karla-Light/Regular/Medium/SemiBold/Bold); Font.custom falls back to system
  if a face is missing, so it degrades gracefully. Applied across the NETWORK
  chrome (header, control bar, speed bar, tab labels); apply `.karla(...)` on
  every future Figma screen. NOTE: the project uses `GENERATE_INFOPLIST_FILE=YES`
  AND `INFOPLIST_FILE=AirlineArchitect/Info.plist` — Xcode MERGES them, so custom keys in
  that Info.plist (UIAppFonts, UIBackgroundModes) DO take effect. (Geist was
  dropped by the designer; only Karla is needed.)
- **NETWORK control-bar spacing fixed + tab bar rebuilt to the Figma.** The
  control bar was cramped ("Acquire A/C"/"Open Route" crowding); fixed with
  Karla 12 + `lineLimit(1)` + `minimumScaleFactor(0.72)` so long labels shrink
  to fit their equal columns instead of crowding the dividers. The bottom nav
  was rebuilt as a CUSTOM bar (`SkyTabBar`) — the Figma tab bar (2:2001 dark /
  2:1602 light) isn't a stock UITabBar: active tint is theme-dependent (Light
  Yellow `#FFC73B` on dark, Bright Blue `#0EA5E9` on light), inactive is Light
  Blue on dark / slate on light, with custom line icons and Karla labels. The
  5 icons were extracted from the Figma as stroked SVGs (viewBox 24, stroke
  1.5, round caps — commands all C/L/M/H/V/Z, no arcs) into `SkyTabIcons.swift`
  and rendered via `SVGPath` into a tintable Canvas (same native-SVG approach
  as AppLogo/AircraftIcon — no raster). ContentView dropped `TabView` for a
  `switch`-on-`tab` + `.safeAreaInset(edge:.bottom){ SkyTabBar }`, driving
  selection itself. Tradeoff (acceptable for now): switching tabs recreates the
  content view, so NetworkView's transient UI state (open panel, route-in-
  progress) resets — the sim state persists in `sim`. Verified live (via a temp
  naming-skip, since a Simulator input glitch this session blocked driving the
  UI directly — screenshots still worked): the custom tab bar icons render
  correctly, Karla renders in the header/control bar, and the control-bar
  spacing is clean.
- **EARLY LEASE TERMINATION (native app) — a leased jet can't be SOLD, it's
  handed back with a penalty.** The Fleet-detail action button reads **TERMINATE
  LEASE** (not SELL AIRCRAFT) for `ac.isLeased`, and the confirm dialog charges a
  real early-termination fee = **3 months' lease** (`leaseTerminationPenalty` =
  `3 × monthlyLeaseCost`; ERJ135 = $336k) — the real-world "few months' rent to
  break early" analog (there's no fixed lease TERM in this model, so months-of-rent
  is the honest proxy). `terminateLease()` hands the jet back (proceeds $0 — you
  never owned it) and books the fee to `totalLeaseCost` so the Finance invariant
  holds. `resolveSell` (the SELL card) and the end-of-service card also route a
  leased aircraft to terminate instead of crediting a bogus sell value. Verified
  live (button + dialog) + 6/6 headless. KNOWN cosmetic gap (not fixed): the
  Fleet-detail "Market Value" card still shows a sell-value figure for a leased
  jet — RESOLVED: the Fleet-detail "Maintenance & Value" card now shows the real
  lease figures for a leased jet (Monthly Lease + Early Termination fee) instead of
  a resale value/depreciation; owned aircraft still show Market Value + Depreciation.
- **Leasing + used-aircraft market — DONE (native app).** Ported faithfully
  from the prototype. LEASING: 15% upfront (`leaseUpfrontRate`) + a fixed
  MONTHLY obligation (`AircraftType.monthlyLeaseCost` = 0.8% of purchase price),
  ACCRUED continuously (`monthlyLeaseCost / ticksPerMonth`) but COMMITTED once per
  sim-HOUR (`tickLeaseBilling`, `leaseBillIntervalTicks = 60`), REGARDLESS of
  utilization — an idle leased spare that never flies still bleeds money (the
  whole reason leasing is a real tradeoff, not strictly dominant; the prototype's
  original per-leg proration bug made idle leases free — did NOT reappear here).
  **The hourly commit is a DISPLAY-cadence fix** (was per-tick, which made the
  Finance "Lease payments" total flicker "multiple times/second" at speed — a
  playtester flagged it); the monthly total is unchanged (1 sim-month bills
  ≈ `monthlyLeaseCost`, verified). Sub-dollar remainders carry in `ac.leaseAccrued`. Leased aircraft are
  still `purchased: true`. Route P&L absorbs lease bills (`Route.totalLeaseCost`
  + `cumulativeNet -= bill`). USED MARKET: buy-only, persistent per-type
  inventory (`usedInventory`, 1–2 listings/type at start via
  `initializeUsedInventory()`, replenished ~10%/day per under-stocked type),
  each listing at 15–75% of life, priced with the EXACT SAME linear
  depreciation as `sellValue()`; a bought used aircraft inherits its real
  cycle count (not 0). UI: `BuyPanel` now has NEW/USED tabs — NEW shows Buy +
  Lease per type, USED lists pre-owned airframes cheapest-first with cycle/%
  -of-life. The tooltip folds a DISPLAY-ONLY smoothed lease estimate
  (`LegEconomics.leaseCostEstimate` → `displayOperatingCost`/`displayNet`,
  does NOT affect settlement) into OP COST and shows an amber `LEASED · $X/mo`
  line. Crew still uses the auto-ratio `provisionCrew()` model (leasing/used
  buying call it like `buyAircraft` does) — the prototype's separate
  player-driven crew-hiring rebuild (grantBundledCrew + ADD CREW panel) is a
  distinct future item, deliberately NOT bundled into this work. Verified: a
  20/20 headless harness (`scratchpad/LeaseUsedMain.swift` → rename to
  `main.swift` to run; covers upfront math, idle-spare monthly billing, used
  price = sell formula, cycle inheritance, listing removal) PLUS live in the
  Simulator (exact $2.1M lease deduction on an ERJ135, NEW/USED tabs, USED
  listings with real cycle data, a leased aircraft flown SLC↔DEN with the
  `LEASED · $112,000/mo` tooltip and lease-folded OP COST confirmed).
- **Off-screen spare base — FIXED.** `makePurchasedAircraft` used to pick
  `airports.randomElement()` as a bought/leased spare's base, which could be
  an OFF-SCREEN AK/HI airport (ANC lat 61 / HNL lat 21) in the CONUS-framed
  default view — making a fresh spare invisible/untappable until routed. Now
  it picks from `conusAirports` (airports within the CONUS frame bounds
  lat 24.5–49.5 / lon −125…−66.5), so a new spare is always visible. The base
  is cosmetic anyway (openRoute reassigns origin), so this purely improves
  visibility; background traffic is unaffected (it can still fly AK/HI).
  Verified: 400 purchases across buy/lease/used all base in CONUS (46 distinct
  airports, never ANC/HNL).
- **ROUTES P&L panel — DONE (native app).** A ROUTES button (HUD action row)
  toggles a bottom panel. LIST view: every route open+closed, newest first,
  each row "`ORIG ↔ DEST` OPEN/CLOSED · profitable|$X short · N flts", tap for
  DETAIL. DETAIL view (Back button): start date, close date (if archived),
  flights, opening cost, cumulative net, profitability status (green
  "profitable (+$X)" / red "$X short"), then total revenue/fees/operating
  cost/lease cost/avg load, assigned-aircraft history, and a recent-flights
  log CAPPED at the last 15 for display (header reads "last 15 of N") while
  every aggregate is computed from the FULL history. The `Route` model gained
  `history: [FlightRecord]` (per-flight tick/tail/rev/fees/opcost/leaseEst/net/
  pax/seats/load/cumulativeNet — the data a future chart needs),
  `assignmentHistory`, `closedTick`, and history-derived aggregates.
  `settleLeg` appends a FlightRecord; `resolveSell` now ARCHIVES the route to
  `closedPlayerRoutes` (closedTick set, history intact) instead of deleting it
  — so a route that never recouped stays reviewable. All @Observable, so an
  open route's numbers tick up LIVE. Verified: 18/18 headless (`scratchpad`
  RoutesMain: history accumulation, field sanity, cumulativeNet consistency,
  archival-preserves-history) + live in the Simulator (watched a SLC↔DEN route
  recoup from $50,951 short → $7,112 short over ~30 flights, correct P&L math
  rev−fees−opcost=cumulativeNet, the "last 15 of N" cap, and the flight log).
- **Profitability CHART — DONE (native app).** `RouteProfitChart` (top of the
  ROUTES detail view) plots per-flight net measured AGAINST opening cost, so a
  dashed break-even (zero) line shows exactly when — and whether — a route
  recouped. Series is `[−openingCost]` (flight 0, the full hole) + one point
  per flight (`cumulativeNet − openingCost`); the line is RED below break-even
  and MINT above, split PRECISELY at each zero crossing, with a mint dot at the
  recoup point and a caption naming the exact flight ("Recouped at flight 40 ·
  Day 13 · 11:02"). Hand-drawn in a `Canvas` (matches the map + dev aesthetic;
  the Figma restyle repaints it later). Verified live: watched a route's line
  climb red from −$84k, cross the $0 line at flight 40 with the mint dot, then
  continue green to +$19k — chart, caption, and summary all agreeing.
- **The Canvas-freeze bug RECURRED — its SECOND native occurrence (first was
  the Phase 1 MapView).** `RouteProfitChart`'s only input was `route` (a stable
  reference), so SwiftUI diffed it identical and NEVER redrew the Canvas — the
  chart froze at its first render (red line, "$33k short") while the sibling
  summary Texts, being inline in the parent's body, updated live. A clean
  build hid it (compiles fine); only watching it run at 25× exposed the frozen
  chart vs. a "profitable" summary. Fix is the documented one: pass a CHANGING
  VALUE input — `RouteProfitChart(route: r, flights: r.history.count)`. CLAUDE.md
  warned "if a second view freezes this way, build the shared pattern": noted —
  every future tick-driven Canvas/child view in this app MUST take a changing
  value input (tick, or a count that moves with its data), or it silently
  freezes. This is now a firm rule, not a per-view surprise.
- **A real SwiftUI note from the ROUTES detail scroll:** at high sim speed the
  recent-flights `ForEach(history.suffix(15).reversed())` churns its element
  identity every completed flight (a new flight shifts the 15-window), which
  fights manual scroll position — expected, not a bug; scrolling is fine at
  low speed. (The chart above does NOT have this issue — it redraws in one
  Canvas pass rather than a ForEach of moving rows.)
- **Fuel hedging (sim mechanic) — DONE (native app); panel UI lands with the
  NETWORK view.** Ported faithfully from the prototype spec (which had been
  dropped from CLAUDE.md and was re-supplied by the designer). A fuel hedge is
  a real CALL OPTION, and the ASYMMETRY is the whole point:
  `Simulation.effectiveMultiplier(raw:hedged:)` (a pure, testable helper) caps
  the player's cost multiplier at `fuelHedgeCeiling` (1.0) ONLY when a spike
  would push above it — a genuine price DROP (fuel glut 0.85×) passes through
  UNCHANGED, since a call option doesn't erase the benefit of prices falling.
  A native port that applied a flat discount instead of this conditional cap
  would be the wrong mechanic. `effectiveCostMultiplier` (instance) feeds every
  player-facing cost calc — `legEconomics` op cost AND the AOG/crew
  hold-erosion in `advanceTick` were both re-routed through it; the GLOBAL
  economic banner deliberately still reads the RAW `currentEvent.costMultiplier`
  (the market's true state, not the hedged view). Premium
  (`fuelHedgePremium(days:)`) is priced against the player's ACTUAL owned fleet
  (Σ holdCostPerTick × durationTicks × 0.35 utilization × 10% rate), scales
  LINEARLY with duration (30/60/90-day tiers), and is $0 for an empty fleet.
  `buyFuelHedge(days:)` guards fleet>0 / not-already-active / affordable, and
  the hedge expires naturally (`fuelHedgeExpiryTick`, computed
  `fuelHedgeActive`/`fuelHedgeDaysRemaining`). The prototype's warning about an
  UNGATED turnaround-settlement corrupting the balance does NOT apply here —
  native `settleLeg` is already `guard ac.purchased`. Verified: 18/18 headless
  (asymmetry both directions, linear premium, formula match, buy/deduct/expire/
  block-re-buy/insufficient-funds). Premium magnitude is fleet-dependent (4×
  ERJ135 ≈ $200k/30d; the spec's "$1.1M/4-aircraft" anchor was a larger
  representative fleet — the FORMULA matches exactly, only the fleet differs).
- **A real SwiftUI note from the ROUTES detail scroll:** at high sim speed the
  recent-flights `ForEach(history.suffix(15).reversed())` churns its element
  identity every completed flight (a new flight shifts the 15-window), which
  fights manual scroll position — expected, not a bug; scrolling is fine at
  low speed. If a chart view is built later, snapshot the history for display
  rather than binding a live-growing slice if scroll stability matters.
- **Figma panel-restyle batch — DONE** (the "designer's NEXT batch of frames"
  flagged above at the FuelHedge/AddCrew note). All to real Figma nodes, Sky
  tokens + `.karla(...)`, verified together live via a temp seed (buy an
  ERJ135, open SLC↔RDU, select it) + screenshot, then reverted:
  - **Aircraft tooltip** (3:1662): `Label:`-style rows (white Karla-Bold 14 +
    light-blue Karla-Regular 14 value), airport-code Route row
    (Karla-ExtraBold 12 + arrow), lease folded into the Tail value (no
    separate badge), `Cycles` before `Crew legal hours` ("N.N hrs remaining"),
    and a new `Route P&L` line. Airline row keeps the ownership colour signal
    (own = On-Dark green, competitor = purple) layered on the Figma layout.
    NO close button (tap the map to dismiss) — matches the Figma. Route P&L
    uses `Route.isProfitable`/`netVsOpeningCost` ("$X short of $Y opening
    cost" until recouped), NOT a raw `cumulativeNet>=0` test — a real bug
    caught in the screenshot ("recouped +$0" on a brand-new route).
  - **Open Route steps 1-2** (alert box 5:8040 / 19:6705): `routeHint` is now a
    solid `#1F232D` bar with the exact "Step One: Tap one of the airports you
    want in the city pair" / "Step Two: Now tap the other airport pair" lines
    (Karla-Bold 14, light blue). No cancel button — the highlighted "Open
    Route" control-bar button toggles the flow off.
  - **Open Route step 3** (New Route Confirm 19:6758): `RouteConfirmPanel`
    rebuilt — ORIG → DEST header (Karla-ExtraBold 20), Distance (great-circle
    nm, computed in-panel) / Slots (green "Avail both ends" vs red "Buyout
    needed") / Range check (vs the spare that'd be assigned = `idleSpares.first`;
    "a/c not assigned" red when none) / Opening cost (green/red by
    affordability), then outlined "Open route" / "Abandon" buttons. Dropped the
    separate `onBuy`/ACQUIRE button that the older prototype had — the Figma
    step-3 has only two buttons, and "Open route" with no spare still opens the
    Acquire panel via `openConfirmedRoute`'s existing no-spare branch (buy
    mid-flow auto-assigns, preserved).
    - **ENFORCED PHYSICAL CONSTRAINTS (native app) — the range check is now REAL,
      plus a runway check.** `openRoute` rejects a route the assigned aircraft
      can't physically fly, via `Simulation.routeBlock(for:from:to:)` →
      `.range(nm)` if the great-circle distance exceeds `rangeNM`, or
      `.runway(code)` if either endpoint's `AirportInfo.longestRunwayFt` is below
      the type's `BodyType.minRunwayFt` (RJ 5000 / NB 6800 / WB2 8000 / WB4 9500
      ft). New `OpenRouteResult` cases `.outOfRange` / `.runwayTooShort(code)`
      (NetworkView flashes a reason); the confirm panel's old display-only "Range
      check" row became an "Aircraft check" (range + runway) that also DISABLES
      Open Route when blocked. This is a real fleet-vs-network puzzle: a regional
      jet can't fly transcon (ERJ135 JFK-LAX blocked, 2146 > 1750nm), and a
      short-runway field is RJ-only (Queenstown 6,204ft takes an ERJ135 but blocks
      a narrowbody/widebody — matching reality). Airports with no runway data
      don't block (data-gap tolerant). Background traffic is NOT gated (cosmetic).
  - **Fuel Hedge** (Fuel Hedge Card 19:6920): `FuelHedgePanel` rebuilt as a
    titled card (Karla-ExtraBold 20) + the real explainer paragraph (with live
    owned-aircraft count) + 30/60/90-day premium rows (light-blue label, white
    "$X premium", green BUY), plus empty-fleet and active-hedge states. Dropped
    `NetPanelBox`/`onClose` — the toggle-off is the highlighted control-bar
    button, matching the Figma (no X). `AddCrewPanel` still uses the dev
    `NetPanelBox` chrome (no Figma frame for Hire Crew in this batch).
- **FLEET tab — DONE (all three screens).** The Fleet tab (was a placeholder)
  is now `FleetView` + `FleetDetailView`, built to the Figma
  (Airline-Architect-Production: fleet home 1:725/1:1057, detail 2:561/2:1273,
  marketplace 5:6501/5:6941). Theme-aware via the Sky tokens + light Figma
  colours; reads `sim.tick` so statuses/counts refresh live (the owned fleet is
  small, so a per-tick body re-eval is cheap — no Canvas freeze concern here).
  - **My Fleet**: My Fleet / Marketplace segmented control, a 4-box status bar
    (Total / Flying / Idle / Grounded — live counts), and a scrollable list of
    fleet cards (tail, type, live status chip, current route or "No route",
    OWNED/LEASED chip, airframe-life bar). Fleet status: `grounded` = AOG,
    `idle` = spare (no route), `flying` = in service — a STABLE mapping
    (doesn't flicker per flight phase), chosen over the literal
    airborne/on-ground reading so the chip/counts don't churn every landing.
  - **Detail** (tap a card): back header, tail/type/ownership + the bundled
    side-view illustration, a Current Status card (live phase + ETA computed
    from the state-machine tick budget + leg-progress bar), a Maintenance &
    Value card (airframe-life bar + market value = real `sellValue` +
    depreciation-vs-new), and a Last Leg Economics card from the route's last
    `FlightRecord`. Actions: ASSIGN TO NEW ROUTE (jumps to the Network tab —
    route reassignment on an existing route still isn't a real feature, so this
    is a nav shortcut, not in-place reassignment) and SELL AIRCRAFT (confirm →
    `sim.sellAircraft`, factored out of `resolveSell` so the SELL card and the
    detail share ONE sell path).
  - **Marketplace**: cheapest-first aircraft profile cards (name, illustration,
    Seats/Practical Range/Avg Lifespan, then Buy new / Lease new / Buy used
    rows), reusing the sim's real `buyAircraft`/`leaseAircraft`/`buyUsedAircraft`
    with live affordability gating. **Deliberate overlap, designer's call:** the
    Network tab's ACQUIRE panel STAYS (it auto-assigns a bought aircraft to the
    pending route mid-flow — a convenience the Marketplace doesn't replicate).
    So there are now TWO acquire entry points; not a bug to "dedupe."
  - Verified live in the Simulator (light + dark) with a seeded fleet: all three
    screens, live phase/ETA/cycles, real economics (Net Income math checks),
    illustrations with the fixed transparent backgrounds, and the buy/lease/used
    rows. `FleetView` takes a `@Binding var tab` (from ContentView) so the
    detail's Assign action can switch tabs.
- **Alerts modal + bell badge — DONE, and it REPLACED the always-on map
  decision cards.** `AlertsView.swift`: a badged bell (`AlertBell` — a red
  count bubble, "9+" cap) and the Alerts modal (Figma 5:4488 light / 5:4552
  dark). "Alerts" = the sim's `decisionQueue` (the events that need player
  attention: AOG / crew / end-of-service sell). Each is an accent-bordered
  "Needs Attention" sub-card — AOG red (live $/min erosion), crew red
  (Reserve/Hire/Wait), sell amber (Sell/Keep) — wired to the SAME resolvers
  the old cards used, so acting here is identical. Empty state ("all caught
  up") when the queue clears.
  - **App-wide wiring**: `ContentView` owns the modal overlay (dimmed bg,
    tap-to-close, `@State showAlerts`) and passes an `onBell` closure to
    `NetworkView` / `FleetView` / `FleetDetailView`; their bells are now
    `AlertBell(count: sim.decisionQueue.count, …, action: onBell)`. So the bell
    works from any tab, and the badge count is live.
  - **Removed the always-on AOG/Crew/Sell cards from the Network map bottom
    stack** — alerts now live SOLELY in the bell/modal, so the same alert no
    longer appears in two places (it did briefly — see the light screenshot in
    that session). The `AOGCard`/`CrewCard`/`SellCard`/`DecisionCardChrome`/
    `CardButton` structs in ContentView.swift are now UNUSED (kept, not deleted
    — harmless, and they document the resolver wiring; delete if desired).
  - The Figma also shows an "Offer" alert type (blue — e.g. an airport offering
    to buy a slot back). That event type doesn't exist in the sim yet, so the
    modal renders only the three real decision kinds; the card layout is generic
    (`AlertModel`) so adding Offer later is a one-case addition.
- **CREWS tab — DONE.** `CrewsView.swift` (Figma crews home 5:2439 light /
  5:2218 dark; hire success 12:4509 / 12:4713), wired into the Crews tab. One
  card per crew family the player owns aircraft in (`sim.ownedFamilies`):
  family name + type-rating coverage, a 2×2 grid of Available (green #10B981) /
  On duty (blue #497AA5) / Resting (slate — #555E70 dark / #F1F1F1 light) /
  Reserve (purple #6E43A6), computed live from `crewPoolsByFamily` +
  `reserveCrewsByFamily`, a "New crew · $X · HIRE" action, and a "RUNNING THIN"
  chip (orange #FFAB44) when `available == 0 && ownedCount > 0`.
  - **`CREW_FAMILY_INFO` added to Crew.swift** — a hand-maintained (name,
    coverage) map for all 14 families (like FAMILY_LABELS; keep the coverage in
    sync if the fleet changes). Coverage strings verified against the real
    AircraftType variants per family.
  - **Hire "confirmation" is an inline SUCCESS BANNER, not a modal** — the
    Figma "hire confirmation" frame is just Crews Home with a green
    #10B981/#87ED7A banner ("New {family} crew successfully hired!") at the top.
    So HIRE fires immediately (`sim.hireCrew`, affordability-gated) and shows
    the banner for ~3s; no confirm dialog.
  - The Figma also shows an "Alert box" (red — "N sidelined; labor action - D
    days left") inside the card; that's a labor-action EVENT the sim doesn't
    have yet, so it's omitted for now (add when that event exists).
  - Verification note: the HIRE button is small; driving it via computer-use on
    the scaled Simulator kept missing the target (NOT a dropped-click bug — the
    banner rendered fine when forced on; SwiftUI preserves button identity
    across the per-tick re-render, unlike the JS prototype's innerHTML flicker).
- **OPS tab — DONE, and it introduced a real EVENT LOG.** `OpsView.swift`
  (Figma ops home 5:3458 light / 5:3707 dark), wired into the Ops tab. Two
  groups:
  - **Needs Attention** = the sim's `decisionQueue` (AOG/crew/sell), rendered
    with a NEW shared `NeedsAttentionCard` (extracted from AlertsModal — the
    Alerts modal and Ops now render IDENTICAL decision sub-cards from one
    source; refactor removed the duplicate).
  - **Events** = a real, capped (40) event log: NEW `Sim/OpsEvent.swift`
    (`OpsEvent` + `Category` = disruption/market/structural) and
    `Simulation.opsEventLog` + `logOps()`. Grouped in the UI into DISRUPTIONS /
    MARKET / STRUCTURAL with relative timestamps (`sim.tick − event.tick`,
    1 tick = 1 min → Xm/Xh/Xd ago). Fed from REAL mechanics via three hooks:
    economic-event onset (`tickEconomicEvents` → MARKET, with the real %
    change), weather ground-stop onset/lift **only at the player's route
    airports** (`tickWeather` → DISRUPTIONS, kept relevant), and route
    open/close (`openRoute` / `sellAircraft` archive → STRUCTURAL).
  - **The Figma's flavour events with no sim mechanic (ATC shortage, fare war,
    ORD capacity expansion) are NOT fabricated** — the feed shows only real
    events. Add them if/when those mechanics exist. Also folded in: the "Offer"
    alert type (blue slot-buyback) still doesn't exist, so Needs Attention shows
    only the three real decision kinds.
  - Gotcha fixed: a plain `↔` in a Text string renders as an EMOJI (blue box);
    the route-log strings use `↔\u{FE0E}` (text variation selector) to force
    text presentation. Watch for this with any bare arrow/symbol char in a
    string (elsewhere the app uses `Image(systemName: "arrow.right")` instead).
- **FINANCE tab — DONE, and the FIRST screen with NO Figma mockup (designer
  said to build critical info from the app's own design language).**
  `FinanceView.swift`, wired into the Finance tab. Four cards + a conditional
  market banner, all theme-aware (Sky tokens / light, same card+header pattern
  as Crews/Ops), reds per the app rule (`#FF9292` dark / `#D70000` light):
  - **NET WORTH hero** = cash on hand + fleet market value, with a "$X since
    launch" delta vs `startingCapital`.
  - **FLIGHT OPERATIONS** stacked ledger (revenue − fees − op-cost = operating
    profit/loss) + flights-flown and avg net/flight.
  - **OVERHEAD & CAPITAL** itemized: lease / insurance / maintenance+crew, then
    acquisition / route openings / fuel hedges (out), then sales / slot
    buybacks (in).
  - **CASH FLOW** reconciliation: starting capital → +operating → −overhead →
    −capital-out → +capital-in = **cash on hand**, and it ties EXACTLY (verified
    on-screen: $20.0M − $1,082,607 − $208,904 − $17,285,840 = $1,422,649 = header).
  - **Market banner** when an economic event is active — shows the event and its
    fare/cost/demand % deltas (amber if harmful, green if favourable).
  - **New reconciling accumulators on Simulation** (so the Cash Flow card can't
    quietly disagree with cash): `totalAcquisitionSpend` (buy+used+lease-upfront),
    `totalRouteSpend`, `totalHedgeSpend`, `totalSaleProceeds`, `totalOfferIncome`
    — added at every cash-move site. INVARIANT (keep it if you add a new cash
    flow): startingCapital + totalRevenue − totalFees − totalOperatingCost −
    totalLeaseCost − totalInsuranceSpent − maintenanceSpend − totalAcquisitionSpend
    − totalRouteSpend − totalHedgeSpend + totalSaleProceeds + totalOfferIncome ==
    playerBalance. Verified 9/9 headless across buy/lease/used/route/hedge/sell +
    40k ticks.
  - **A real modeling fix caught in the first screenshot: leased aircraft were
    inflating net worth.** `fleetMarketValue` originally summed sellValue over
    ALL `purchased` aircraft — but a LEASED aircraft isn't a sellable asset (15%
    down + ongoing monthly obligation, you don't own it). Fixed to
    `purchased && !isLeased`; added `ownedOutrightCount`/`leasedCount`, and the
    hero footnote now reads "resale value of N aircraft owned outright (M leased,
    not counted)". A $34M fleet-value for 2 aircraft that cost $17M total (one
    leased) was the tell.
  - Verified live in the Simulator (dark + light) with a seeded fleet; a random
    run rolled an Oil Price Spike, correctly showing the market banner + an
    operating LOSS + net worth down — the real emergent economy, not a happy path.
- **FINANCE per-period views + net-worth trend — DONE (native app).** Added a
  **period selector** (Total / This month / Last month) that drives the P&L,
  overhead/capital, and cash-flow cards, plus a **NET WORTH TREND** sparkline.
  - **Month-boundary snapshots** power it: `Simulation.FinanceSnapshot` freezes
    every cumulative total (+cash +netWorth +flights) at a moment;
    `financeSnapshots` gets a **launch baseline seeded in `init`** (tick 0, $20M
    — NOT lazily on first tick, so it's pristine regardless of when the player
    first buys) and one appended at each sim-month boundary in `advanceTick`
    (`tick % ticksPerMonth == 0`). A period's activity = difference between two
    snapshots, so it reconciles the SAME way the cumulative ledger does:
    cashStart + operatingProfit − overhead − capitalOut + capitalIn == cashEnd.
    Verified 5/5 headless over ~3.2 sim-months (every completed month
    reconciles, this-month reconciles to live cash, flights partition exactly).
  - Added `totalFlightsFlown` (owned-leg counter, per-period via snapshot delta).
  - The Cash Flow card relabels for periods ("Cash, period start" → "Cash,
    period end") vs Total ("Starting capital" → "Cash on hand"); the hero delta
    and label follow the selected period ("this month" / "last month" / "since
    launch").
  - **NET WORTH TREND** = a small `NetWorthSparkline` (private Canvas) plotting
    `financeSnapshots.map(netWorth) + [live]`, green above / red below the dashed
    launch baseline, split per segment. Kept as a **value-input** view (`values`
    changes every tick via the live last point) so it re-renders and never hits
    the documented Canvas-freeze bug — do NOT make it a stable-input child.
  - Verified live (dark): trend line renders (red below the $20M launch dash
    during a recession run), and the Last-month view shows that period's own
    numbers reconciling exactly ($934,633 − $1,079,046 − $187,128 = −$331,541),
    with capital spending correctly $0 (acquisitions were in earlier months).
- **IN-APP PURCHASES — scaffolded behind a stub (native app). Designer has a
  RevenueCat account; two tiers ($5.99/mo, $49.99/yr) + a free preview.**
  Decisions (designer): free tier gates SCALE not features (route + fleet cap),
  custom SwiftUI paywall (not RevenueCatUI), and build the whole gating
  experience NOW behind a local stub so it's testable before the account is
  wired.
  - **`Store.swift`** (`@MainActor @Observable`): `isPro` (STUB flag),
    `freeFleetCap = 3` / `freeRouteCap = 2`, `canAcquireAircraft(sim)` /
    `canOpenRoute(sim)` (= `isPro || count < cap`), `capMessage(.fleet/.route)`,
    a `plans` list (annual/monthly display stubs), and `purchase()`/`restore()`
    STUBS. **RevenueCat wiring is deferred and localized to THIS file**: add the
    SPM package + public SDK key, then drive `isPro` from `Purchases.shared`
    customerInfo (entitlement "pro") and route purchase/restore through it —
    nothing else in the app changes (every gate reads `Store`).
  - **`PaywallView.swift`**: custom Karla/Sky paywall (logo badge, contextual
    reason line, 3 feature rows, annual-preselected plan cards with a "save 30%"
    badge, Continue, Restore Purchases, fine print, close X). Theme-aware.
    Presented as a ContentView overlay (`showPaywall`/`paywallReason`) via an
    `upgrade(reason:)` helper.
  - **Gating is at the UI entry points** (single-player local game, no server —
    UI-level is sufficient; sim methods unchanged): Network "Open Route" button,
    the ACQUIRE panel's Buy/Lease/Used rows (`AircraftProfileCard.gated`), and
    the Fleet Marketplace rows (`FleetView.gatedAcquire`) all check the Store and
    call `onUpgrade(reason)` at the cap instead of acting. Finance has a **PLAN
    card** (free: live "N/3 aircraft · N/2 routes" usage + Upgrade; pro: a
    confirmation). A **DEV "Pro (DEV)" toggle** sits under the eye-overlay dev
    row in NetworkView to flip `isPro` without a purchase (remove once RevenueCat
    drives it).
  - **Cap reachability note**: on the $20M start a free player affords ~1
    regional jet, so CASH is the early gate and the 3-aircraft/2-route caps are
    the growth ceiling reached after playing — intended. Numbers are easily
    tunable constants.
  - Verified: 9/9 headless (isPro bypasses both gates, predicate tracks the
    count, purchase stub flips isPro, cap messages present) + Simulator
    screenshots (paywall dark + light, Finance free-plan card with live usage).
  - **What's needed to go live (designer/account side; I can't configure these):**
    RevenueCat public iOS SDK key, an entitlement id (e.g. "pro"), the two
    product ids + an Offering, the App Store Connect subscription products +
    "Paid Apps" agreement, and adding the `purchases-ios` SPM package (cleanest
    via Xcode's Add Package UI, since a package dependency isn't auto-added by
    the file-synchronized groups the way source files are).
- **External-events system — the designer specced 16 events; being built in
  PHASES.** The full list (designer, verbatim intent): Market/economic (mutually
  exclusive) — Oil Spike, Fuel Drop, Boom, Recession, **FFR Redemption Surge**
  (fare/load opposite); Ground-stops (shared mechanism) — **Weather**, **ATC
  Staffing Shortage** (regional 2–4 airports), **Security Incident** (single,
  sharp/short); Crew/fleet — **Labor Action** (sidelines a fraction of one crew
  family), **Aircraft Recall/AD** (grounds every owned aircraft of one type at
  once — a real AOG escalation); Cost — **Insurance Premium** (recurring monthly
  bill vs fleet value, occasional hard-market ×), **Maintenance Cost Inflation**
  (spikes AOG REPAIR cost only, separate from fuel); Revenue — **FX Shock**
  (widebody fare only — the honest adaptation given no real intl routes),
  **Competitor Fare War** (depresses fare on ONE existing player route, names a
  plausible competitor); Structural — **Airport Expansion** (permanent slot
  increase — the only durable event); Decision — **Slot-Value Buyback** (an
  airport offers to buy a route's slot back — the ONE item that's a real choice
  with buttons, i.e. the blue "Offer" decision card).
  - **Phase 1 — DONE** (`25e625b`): FFR Surge (economic #5), ATC Shortage,
    Security Incident (ground-stop causes reusing the weather mechanism), and
    Airport Expansion (structural). New `tickWorldEvents()` = once-per-sim-day
    check (designed daily probs 4%/3%/2.5%). Headless-verified over 120 sim-days.
  - **Phase 2 — DONE** (`f94fb56`): Slot-Value Buyback (#16), the one event
    that's a real CHOICE. Daily 6% check when the player has a route (one open
    at a time); the dest airport offers 2–4× the route's opening cost. **BUGFIX
    (designer-reported):** the base is `max(openingCost, incentiveWaived)`, NOT
    just `openingCost` — a SUBSIDIZED route (opened via an airport recruitment
    offer) has `openingCost` 0, which produced a "$0 offered" buyback; the waived
    cost is recorded in `incentiveWaived` and is the slot's real value. Routes with
    no real value are filtered out. Accept =
    credit cash + close/archive the route + its aircraft becomes an idle spare
    (SLOT sold, not plane); Decline = keep it. **Decision refactor**:
    `Decision.aircraft` is now OPTIONAL and `Decision` gained an `.offer` kind +
    `SlotOffer` payload (route-based, not aircraft-based). The blue "Offer" card
    renders via the shared `NeedsAttentionCard` → shows in the Alerts modal AND
    Ops Needs Attention. Also removed the now-dead AOGCard/CrewCard/SellCard/
    DecisionCardChrome/CardButton structs from ContentView (they blocked the
    optional-aircraft change). Headless + visually verified.
  - **Phase 3 — DONE** (`1bca200`): Labor Action (#9) + Aircraft Recall/AD (#10).
    #9 added a `.sidelined` CrewStatus; a daily 2% check sidelines ~40% of ONE
    owned crew family's pool (from ready/resting crew, NOT mid-flight) for 3–8
    days, returning them at expiry — and lit up the red "N sidelined; labor
    action — D days left" box on the Crews card (previously omitted).
    `laborActionExpiryByFamily` is the per-family state. #10 grounds EVERY owned
    aircraft of one type at once (daily 1.5%) by setting `maint = true`, so each
    AOGs at its next gate via the existing mechanism (an AOG card per tail).
    Both log DISRUPTIONS. Headless + visually verified.
  - **Phase 4 — DONE** (`e33bbd5`): the cost/revenue passive events — #11
    Insurance Premium (recurring MONTHLY bill via `tickInsuranceBilling` = fleet
    value × 0.08%/mo, occasional ×1.8 hard market; `totalInsuranceSpent` tracked
    for the Finance tab), #12 Maintenance Cost Inflation (temporary ×1.6 on AOG
    REPAIR cost only, via `maintCostMultiplier` in the resolvers), #13 FX Shock
    (widebody fare ×0.85 in `rollRevenue`, gated on owning a widebody), #14
    Competitor Fare War (one existing player route's fare ×0.75, names a
    Big-Four competitor). Headless-verified over 300 sim-days (insurance/maint/
    fare-war fire; FX correctly gated off with a regional fleet — its
    widebody-gated firing wasn't exercised end-to-end since a widebody is
    unaffordable at the $20M start, but the effect is one line analogous to the
    verified fare-war line).
  - **ALL 16 external events are now built.** Magnitudes for every built event
    are DESIGNED pacing, not sourced. All surface in the Ops feed and/or the
    economics; the only one that's a player choice is #16 (the Offer card).
  - **#17 RECURRENT CREW TRAINING — DONE (a recurring player CHOICE).** Each owned
    crew family comes due for recurrent training on a ~150-day cycle (real FAA
    analog). Pushes a blue `.training` card (graduation-cap) with: **Train now**
    (pay the base cost = the crew-hire basis, ERJ $28k; ~half the family's ready
    crew go `.sidelined` ~4 days — degrades but doesn't stop ops), or **Defer 30
    days** (no downtime now, auto-runs in 30 days at 1.6× cost). `Decision` gained
    `.training` + `trainingFamily`. State: `crewTrainingDueByFamily` /
    `crewTrainingDeferredByFamily` (BOTH persisted — the schedule survives save/
    load) + a transient downtime expiry. `tickCrewTraining()` (daily) returns
    trainees, runs due deferrals, pushes due cards; `resizeCrewPools` clears
    training state when a family is sold off. Verified 11/11 headless.
  - **#18 AIRPORT RECRUITMENT OFFER — DONE (the counterpart to the #16 slot
    buyback, which is the OPPOSITE: an airport buying YOUR slot).** A smaller,
    off-radar CONUS airport periodically courts the player to open a route TO it,
    with a **human pitch** from its officials (3 templates using real
    `AirportInfo.city` names) + real incentives: **waived opening cost** (`openRoute`
    gained a `subsidized` flag → 0 charge, route.openingCost 0) + a **signing
    bonus** ($100k + demand-scaled, capped $500k). Origin drawn from the bottom
    ~2/3 by traffic (unserved); dest prefers a hub already in the player's network.
    Blue `.airportOffer` card (megaphone) via NeedsAttentionCard. **ACCEPT ALWAYS
    WORKS now (was a spare-required dead-end — designer-reported).** Accept opens
    the route free + banks the bonus (`totalOfferIncome`, Finance invariant holds)
    regardless of fleet: with an in-range spare it's assigned + flies immediately;
    WITHOUT one the route opens PENDING (no aircraft), and `assignSpareToPendingRoutes()`
    (per tick) auto-staffs it once the player acquires/frees an in-range spare —
    so "accept → buy a plane → it flies the route" just works. `openRoute` was
    refactored into shared `createRoute` + `assign` helpers; accept reuses them.
    **PENDING ROUTES are a real concept now**: `routeStaffed(_)`/`pendingRoutes`
    (a route in `playerRoutes` with no aircraft assigned) — harmless (no flights,
    no demand rolled) until staffed. Competition entry now also requires `flights>0`
    (a subsidized route's $0 opening cost makes `isProfitable` true from tick 0).
    Route gains `incentiveBonus`/`incentiveWaived` (persisted); a new Ops **"Airport
    Incentives"** box lists each incented route with the banked bonus + waived
    opening cost + "Awaiting aircraft"/"In service" status. Offers expire after 12
    days; one at a time; ~8%/day. `pitch`/`AirportPitch` on `Decision`; not
    persisted (regenerates). Verified 9/9 headless + live. Example pitch: "Jackson,
    MS's authority is courting you: fly JAN ↔ ATL and we'll waive every opening fee,
    plus a $200,800 marketing package…".
    - **FULFILLMENT COUNTDOWN + FORFEIT (designer request) — the obligation has
      teeth.** Accepting WITHOUT a spare opens the route pending with a **14-day
      deadline** (`Route.fulfillByTick`, `offerFulfillmentDays`, persisted).
      `tickOfferFulfillment()` (daily): staffed-in-time clears the deadline (bonus
      kept); missed → the route is FORFEITED (closed, slots freed) and the marketing
      **bonus is clawed back** (`playerBalance` + `totalOfferIncome` both reversed,
      Finance invariant holds). Ops "Airport Incentives" box shows the live "Nd left
      to staff" countdown; the accept note states the deadline. Verified headlessly.

- **LOAN / FINANCING mechanic — DONE (Finance tab).** The player can borrow to
  expand faster than cash flow allows, at the cost of interest + a fixed monthly
  debt-service payment. `Sim/Loan.swift`: `LoanOffer` products (Short-term
  $5M/24mo/8%, Fleet $15M/48mo/10%, Expansion $40M/72mo/12%) with an amortized
  monthly payment `P·r/(1−(1+r)^−n)`; `Loan` tracks remaining principal. `takeLoan`
  credits cash + creates the loan; `tickLoanBilling` (monthly) charges
  interest-on-balance + a principal slice, retiring the loan over its term.
  Borrowing capped at `max($30M, fleetMarketValue)` — a base credit line + fleet
  collateral — so it can't be abused to infinity. `totalLoanProceeds` /
  `totalDebtService` accumulators; **the Finance cash invariant now includes
  `+loanProceeds −debtService`** (folded into PeriodFigures.capitalIn / .overhead,
  so the cash-flow card still ties out). New Finance **"FINANCING"** card: total
  debt, monthly service, active loans, and gated Borrow options (a product is
  disabled when it would breach the limit). Persisted (loans + the two totals +
  FinanceSnapshot/FinanceSave fields). Verified 9/9 headless (gating, cash credit,
  full amortization to $0 over the term, invariant holding through 28 sim-months) +
  live (FINANCING card renders; $40M option correctly disabled past the $30M limit).
  **A related non-bug clarified (designer question):** the Marketplace lease button
  updates live (FleetView reads `sim.tick`; the check is upfront-only, matching
  `leaseAircraft`) — a button that looked stuck was the cash DISPLAY rounding
  ("$2.1M" covers $2.05–2.14M) sitting just under the exact $2.1M upfront.
  - **EARLY PAY-OFF — ADDED (designer request).** A loan can now be retired
    early, and the action ONLY appears when the player has the cash to settle it
    in full (no partial payments, no unaffordable button). `payOffLoan(id)` /
    `canPayOffLoan(loan)` / `earlyPayoffCost(loan)` on Simulation: cost = the
    loan's full `remainingPrincipal` (no future interest — paying early saves
    every remaining interest payment; no penalty, a deliberately player-friendly
    choice). The payment counts as `totalDebtService` so the Finance cash
    invariant (`…−debtService…`) holds EXACTLY unchanged (playerBalance drops by
    the same amount debtService rises). UI: a green **PAY OFF** button on each
    active-loan row in the FINANCING card, rendered only when `canPayOffLoan` is
    true (FinanceView already reads `sim.tick`, so it appears live the moment
    cash crosses the balance). No new accumulators, no persistence change — an
    early payoff just removes the loan and bumps the existing debtService total.

- **ROUTE OPPORTUNITIES ARE TAPPABLE → one-tap open (Ops → map preview).**
  Each Route Opportunity row is now a button (chevron + "tap one to preview it
  on the map" hint). Tapping one calls `sim.suggestRoute(from:to:)` — sets
  `pendingSuggestion` (a `RouteSuggestion`, survives the tab switch because it
  lives on the sim) and frames the camera on both endpoints (`frameRoute`,
  same fit math as `applyHomeFraming`) — then ContentView switches to the
  Network tab. NetworkView's `.onAppear`/`.onChange(pendingSuggestion)` adopts
  it by driving the EXISTING `routeMode = .confirm(o,d)` flow, so opening/buying
  reuses all the normal machinery (openConfirmedRoute + the no-spare→Acquire
  branch + handleBought auto-open). MapView.drawSuggestion renders a marching
  amber DASHED arc between the pair (the in-game FlightPath curve) with
  continuously PULSING endpoints (tick-driven loop). The RouteConfirmPanel
  gained `openTitle`/`cancelTitle`/`subtitle` params: for a suggestion it reads
  "Open This Route" / "Don't Open" with a "Suggested market · ~N pax/day"
  subtitle. "Open This Route" → openConfirmedRoute + clearSuggestion; "Don't
  Open" → clearSuggestion + `onReturnToOps` (→ Ops tab). Verified live on iPad:
  tap FLL↔CLE → framed map + dashed line + pulse → Don't Open returned to Ops;
  tap CMH↔NLU with an in-range spare → Open This Route opened it (green player
  route drawn, panel dismissed, Ops event logged).
- **ROUTE OPPORTUNITIES finder — DONE (Ops tab; "underserved markets").**
  `Simulation.topRouteOpportunities(perClass:)` surfaces high-demand city pairs the
  player doesn't serve, using the demand model (the truth of profitability here,
  since no competitor route-saturation is modeled). Returns a SPREAD across fleet
  tiers (top regional / narrowbody / widebody markets) rather than a raw demand
  ranking — otherwise it's always the same mega-hub widebody pairs a starter can't
  touch; the regional tier naturally surfaces the smaller, off-radar airports.
  Each row: city pair + real city names + est. demand/day + distance + suggested
  class. Cached in OpsView `@State`, recomputed only when the route network
  changes (not per tick). Verified visually + headlessly.

- **MILESTONE ladder extended + audio-fix batch — DONE.** Net-worth awards added a
  **$30M** tier (gated on owning ≥1 aircraft, so it fires as "grown back past your
  starting stake", NOT at the $30M start) and a **fleet-of-50** award, alongside
  the existing $50M/$100M/$250M/$500M/$1B + fleet 5/10/25. Also a **"First jet
  purchased!"** milestone (🛩️, `first_aircraft`, fires at `ownedCount >= 1`).
  Haptics come free via the existing celebration `.onChange` hook.
  - **SOUND-COLLISION FIXES (designer-reported).** (a) Opening a route by BUYING an
    aircraft in one action played the jet whoosh AND the "now boarding" voice at
    once — the voice is now suppressed when it follows a purchase
    (`openConfirmedRoute(announce:false)` from `handleBought`); the route-open
    haptic still fires, and opening with an EXISTING spare still says "now
    boarding". (b) The first-purchase whoosh would collide with the new
    first-aircraft milestone chime — so `Feedback.aircraftAcquired(isFirst:)` skips
    the whoosh on the FIRST-EVER acquire (the congrats chime is that moment's
    sound). `isFirst = sim.ownedCount == 1` at each acquire call site.

- **SAVE / QUIT now persistent on EVERY top-level tab — DONE.** Extracted the pair
  into a shared `SaveQuitBar` (own "Saved ✓" flash + light haptic), flushed right
  on the cash line of Network / Fleet / Crews / Ops / Finance (was Network-only).
  `.fixedSize(horizontal:)` keeps the labels from truncating to "S…"/"Q…" when the
  cash line is tight (a real bug caught in the Simulator).

- **PERSISTENCE + MULTI-SLOT SAVES — DONE (native app).** The game persists so a
  player picks up where they left off, with up to 3 named save slots.
  - **`Persistence.swift`**: a `Codable` `GameSnapshot` captures the PERSISTENT
    state only — identity (name/tail code), economy + all the Finance
    reconciling accumulators, `playerBalance`/`tick`, owned aircraft
    (`AircraftSave`: tail/type/origin-dest/state-index+tick/cycles/route/leased/
    maint/crewId), routes + closed routes (`RouteSave` incl. full `history` so the
    ROUTES P&L/chart survive a reload), per-family crew pools (`CrewSave`:
    status-as-int/dutyTicks/restTicksLeft), reserve counts, finance snapshots,
    camera, fired milestones, `stressTestCount`. Background (competitor) traffic,
    the in-flight event state, and the used market are **NOT** persisted — they
    regenerate on load, which keeps the snapshot small (~1KB/save) and the
    restore robust. `CrewStatus.saveCode` maps sidelined→available on reload (the
    labor action itself isn't persisted).
  - **`Simulation.snapshot()` / `restore(from:)`** live IN Simulation.swift so
    they can set `private(set)` state. `restore` rebuilds crew pools → routes →
    owned aircraft (airport-by-code lookup, re-rolls each leg's revenue), then
    resets transient state (`currentEvent = .normal`, clears the decision queue,
    re-provisions + decrements slots per open route, re-seeds the insurance bill
    tick) and re-applies `stressTestCount`. Verified round-trip last session (a
    restored sim keeps ticking + earning), and live this session (loading a slot
    restored the exact $16.0M balance).
  - **Slots (max 3, a DELIBERATE cap — designer):** enough to try a few
    strategies, not so many saves become throwaway save-scum (which would gut the
    bankruptcy stakes). `GameStore` is slot-based (`savegame_<n>.json`):
    `save(_:slot:)`/`load(slot:)`/`clear(slot:)`/`slotInfos()` (lightweight
    summaries for the menu)/`firstFreeSlot`/`anySave`. Migrates a legacy
    single-file `savegame.json` into slot 0 once. `GameSnapshot.savedAtEpoch`
    (stamped at save time) drives the "saved Xm ago" labels.
  - **`SaveSlotsView`** = the load / slot-picker menu: shown at cold launch when
    ANY save exists, and again on QUIT. Each saved slot shows airline/day/cash/
    fleet/routes + relative save time and loads in place; each empty slot starts
    a fresh airline there (dashed card); per-slot Delete with a two-tap confirm.
  - **`ContentView` tracks `currentSlot`** — autosave-on-background
    (`scenePhase != .active`) and the SAVE button both target it; naming a fresh
    airline claims `firstFreeSlot`; bankruptcy clears that slot and returns to the
    menu if other airlines remain (else the naming screen). LOAD always builds a
    FRESH `Simulation()` + bumps `gameID` (so the `.task(id:)` run loop restarts
    on the restored instance, no residue from a prior game) — same restart family
    as the bankruptcy path.
  - **SAVE / QUIT buttons** (NetworkView, flushed right on the cash line, per
    designer): SAVE persists to the current slot with a "Game saved" flash; QUIT
    auto-saves then returns to the load menu. Both are `onSave`/`onQuit` closures
    from ContentView.
  - Verified live end-to-end in the Simulator: launch→menu (real path, driven by
    on-disk saves), tap a slot→loads the exact game, SAVE/QUIT render, QUIT→
    auto-save→menu with updated timestamps.

- **FIRST-PLAY TUTORIAL — DONE (native app).** `Tutorial.swift`: 5 coach cards
  (`tutorialSteps`) — goal → open your first route → Fleet → Crews → Ops/Finance
  — each tagged with the tab it describes. `TutorialCard` is a BOTTOM-DOCKED card
  (progress dots, Skip, Next/"Start playing") that deliberately does NOT dim the
  screen, so the section behind stays visible as the player reads. As they tap
  Next, ContentView advances the step AND switches to that step's tab, building
  the mental model of where things live. **TRIGGER: it runs whenever the player
  NAMES a fresh airline** (NOT when Continuing a save — that's correctly no
  walkthrough). The old "seen once, ever" UserDefaults gate (`hasSeenTutorial_v*`)
  was REMOVED — it kept the walkthrough from re-showing for returning testers who
  saw it on an earlier build (designer-reported TWICE); it's skippable, so
  re-showing on each new game is fine. `TutorialState` still exists but is no
  longer read for gating. Verified live (set the seen flag true → walkthrough
  still appears on a new airline).

## Decided — iCloud save sync (cross-device, per Apple ID)

- **BUILT — saves sync across a player's own devices via iCloud key-value
  store (`NSUbiquitousKeyValueStore`), keyed to the device's Apple ID.**
  Player idea: continue the same game on iPhone ↔ iPad. Chosen approach
  (over CloudKit / Game Center `GKSavedGame`) for simplicity: our saves
  are tiny Codable JSON (~1–7 KB × 3 slots), far under KVS's 1 MB cap, and
  there's NO in-app login — it piggybacks on whatever Apple ID is signed
  into the device's iCloud (zero account system to build).
- **Offline-first: local Documents files stay the source of truth the app
  reads/writes** (everything works with no iCloud account — verified: the
  simulator has none, and the app launches straight to the load menu with
  the local save intact, no crash). iCloud is a MIRROR layer on top:
  `GameStore.save` also writes the slot to KVS; `clear` removes it.
- **Reconcile = most-recent-EVENT-wins per slot (save OR delete).**
  `GameStore.reconcileAction(localEpoch:cloudSaveEpoch:tombstoneEpoch:)` is a
  PURE, unit-tested function (14/14 headless) returning
  `.adoptCloud/.pushLocal/.deleteLocal/.none`: the newest `savedAtEpoch` save
  wins UNLESS a delete-tombstone is strictly newer than every save (then the
  slot is removed). Ties favor the save (keep data — safe direction).
  `reconcileCloud()` runs at cold launch (ContentView `.onAppear`,
  BEFORE the `anySave` check so a save made on another device already shows
  in the menu) and on `NSUbiquitousKeyValueStore.didChangeExternallyNotification`
  (another device saved while this one is running → merge + rebuild the
  load menu via a `cloudGen` `.id` bump). Every `GameSnapshot` already
  stamped `savedAtEpoch`, so conflict resolution was almost free.
- **Entitlement**: `com.apple.developer.ubiquity-kvstore-identifier` =
  `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` in the (previously empty)
  entitlements file. **MANUAL STEP THE DESIGNER MUST DO ONCE (I can't):**
  enable the **iCloud → Key-value storage** capability in Xcode → Signing
  & Capabilities. Simulator builds sign fine without it (ad-hoc), but a
  DEVICE build / TestFlight ARCHIVE will fail code-signing on the
  entitlement until the App ID / provisioning profile includes iCloud.
- **DELETE TOMBSTONES (resurrection fixed).** Deleting a slot removes the
  cloud save AND writes a dated tombstone (`savegame_slot_N_deleted` = epoch)
  to iCloud. Reconcile treats a delete as an event competing on recency with
  saves, so a delete newer than every save removes the slot on all devices
  (no resurrection), while starting a NEW game in that slot writes a save
  newer than the tombstone that correctly wins (`mirrorToCloud` also clears
  the stale tombstone on save). Data is only removed when a delete is
  genuinely the most-recent action for the slot.
- **VERIFICATION CAVEAT: the real iPhone↔iPad handoff needs two physical
  devices on the same Apple ID** — the Simulator can't exercise real iCloud
  sync. Verified here: the pure merge logic (7/7 headless) + offline-first
  no-crash launch. The designer confirms the actual cross-device sync on
  real hardware.

## Decided — iPad Adaptation (native app; universal, one codebase)

Designer wanted a genuinely iPad-DESIGNED experience, not a stretched phone
app ("with all the extra space it'll just make the game better"). Built
code-first with screenshot iteration — designer explicitly decided **NO iPad
Figma frames were needed** after seeing it ("I don't see anything that needs
major changes"). Verified live on the iPad Pro 13" simulator (both themes,
both orientations) incl. the full open-a-route→acquire flow.

- **Already universal — no new target.** `TARGETED_DEVICE_FAMILY = "1,2"` and
  all iPad orientations were already set from the template, so the app always
  RAN on iPad; the work was purely adaptive LAYOUT, not a port. iPhone is
  completely untouched — every fork is gated on
  `@Environment(\.horizontalSizeClass) == .regular` (`PadLayout.isPad(hSize)`
  in `AdaptiveLayout.swift`, the one shared predicate). Compact width = the
  existing iPhone layout verbatim.
- **Sidebar rail replaces the bottom tab bar on iPad** (`SkySidebar.swift`,
  `SkySidebarRail`). Reuses the SAME `SkyTabIcon` glyphs, active/inactive
  tints, and Ops badge as `SkyTabBar` — so it stays visually consistent, just
  vertical. Width 232. Header = the `AppLogo` badge LARGE and centered above a
  centered two-line "Airline / Architect" wordmark (designer's explicit call).
  ContentView picks `SkySidebarRail` (regular) vs `SkyTabBar` (compact) in
  `adaptiveShell`; the tab content is shared via a `content` @ViewBuilder.
- **All list screens are FULL-WIDTH single column on iPad, NOT multi-column
  grids.** A multi-column grid was built first (2-up portrait / 3-up
  landscape) and REJECTED by the designer twice: Fleet/Marketplace went
  full-width so the aircraft art could be BIG (marketplace image capped at
  340pt tall on iPad), then Finance + Ops + Crews followed for consistency
  ("I don't like how there are big gaps between cards" — the gaps were
  LazyVGrid row-height staggering when a short card sits next to a tall one).
  Net: `PadLayout.cardColumns` was built then DELETED as dead code — every
  list is a plain `LazyVStack`/`VStack` at full content width on both idioms.
  Only `PadLayout.isPad` survives.
- **Landscape Network = map + docked side rail** (the flagship interaction the
  designer loved). In `NetworkView`, gated to iPad LANDSCAPE only via a
  `GeometryReader` (`wide = width > height`) — portrait iPad + iPhone keep the
  panels FLOATING over the map (a tall screen has no room for a 380pt rail).
  When wide, the body is an `HStack { mapCard(sideDocked: true) | sidePanelColumn }`;
  the map keeps its control/speed bars and stays fully live (all airports
  tappable) while whatever panel would have overlaid it — Acquire / Routes /
  Hire / route-confirm / aircraft tooltip / airport card — docks into a 380pt
  right rail instead. `sideDocked` swaps the map overlay's `panelMiddle` for a
  `Spacer`. Verified end-to-end: open route with no spare → rail swaps from the
  confirm panel to Acquire (route stays pending) → buy → route auto-opens with
  the jet assigned and flying, balance deducted, rail dismisses.
  - **SUPERSEDED (designer, on seeing it in play): the rail no longer reserves
    space when idle — the map now fills the full landscape width.** The reserved
    gutter read as "the map didn't expand" after rotating. The flinch it existed
    to prevent is now solved a better way: the MAP is always laid out at the FULL
    available width and the card simply shows a narrower window onto it when a
    panel docks (`mapCard(mapWidth:cardWidth:)` — map at `full`, card clipped to
    `full − 390`). So docking CLIPS the map's right edge instead of resizing it,
    which means the world-scale never recomputes and the map never rescales.
    Verified on the iPad simulator: LAX sits at the identical x/scale idle vs
    docked. The control/speed bars are attached AFTER the card frame, so they
    size to the VISIBLE width and never get clipped. `hasSidePanel(_:)` decides
    whether anything is docked. The ORIGINAL note, for history:
  - **(Historical) The rail's 380pt width was RESERVED PERMANENTLY, even
    when nothing was docked** — the `sidePanelColumn` is always in the HStack at
    `.frame(width: 380)`, empty (page background) when idle. This was a real QA
    finding (independent code review during the RC pass): docking a panel used
    to NARROW the map card, which recomputes the map's `worldScale` (=
    `min(width/worldW, height/worldH)`, width-limited since the world is ~390°
    wide) → the whole map visibly "flinched"/rescaled every time a panel opened
    or an aircraft was selected. Reserving the width keeps the map card a
    constant size so it never rescales. Tradeoff the designer accepted: the map
    is always a bit narrower in landscape (a ~380pt right margin when idle). The
    OLD approach (conditionally adding the column via a now-removed
    `hasSidePanel`) is what caused the flinch — don't reintroduce it.
  - **EXCEPTION the designer requested: the route-PICK hints (Step One / Step
    Two) float over the map as a chip, they do NOT take the rail** — you're
    tapping the map to pick airports, so the instruction belongs on it. Only
    the CONFIRM step (step 3, with buttons) docks in the rail.
    `isRouteConfirm` gates the rail; `routePickHintText` (single source, also
    consumed by the iPhone `routeFlowPanel`) drives the floating chip in the
    map overlay.
- **Fleet = list + detail side-by-side on iPad landscape** (`fleetSplitLayout`),
  50/50 split (`.frame(maxWidth:.infinity)` on both columns — designer bumped
  it from an initial fixed-400pt list "for better visual balance"). Left =
  status bar + fleet list; right = the selected aircraft's detail, defaulting
  to the FIRST owned aircraft until one is tapped (`detailAC = owned.first{
  id==detailID } ?? owned.first` — no state mutation). The tapped card gets a
  blue selection ring (`fleetCard(_:selected:)`, `fleetList(selectedID:)`).
  `FleetDetailView` gained `embedded: Bool` — hides its own header (cash line +
  back chevron + title) in the split since the list side already carries the
  header; portrait/iPhone keep the tap-to-push full-screen detail unchanged.
  Only My Fleet splits — Marketplace stays full-width. The portrait tap-to-push
  animates: the detail slides in from the trailing edge / list slides off
  (`.move` + opacity, `.easeInOut(0.3)`), keyed on `detailID` ONLY so a rotation
  (which flips `split`) stays instant instead of sliding.
- **Screenshot capture gotcha (for the next session driving the Simulator):**
  `xcrun simctl io … screenshot` captures the RAW framebuffer, so in landscape
  the PNG comes out rotated 90°/180° depending on which way the device was
  rotated (cmd+Right vs cmd+Left give opposite handedness). Rotate the file for
  viewing with `sips -r 90` or `-r 270` (whichever lands upright) — the app
  itself is fine, it's purely a capture artifact.
- **Not adapted (deliberate, designer OK'd):** the naming/paywall/tutorial
  modals still float centered (functional on iPad, not restyled); portrait
  iPad Network uses the floating-overlay panels rather than the rail.

## Decided — Release Candidate & QA pass

- **The app is being treated as a RELEASE CANDIDATE (universal iPhone + iPad;
  build 21 = RC2).** Build history this stretch: 12–14
  (pre-iPad polish), 15 (cash precision + "need $X more" hint), 16 (iPad
  adaptation), 17 (portrait Fleet slide transition), 18 (map-flinch fix, RC1),
  19 (Hubs & Clubs + region selection + leisure destinations + playtest fixes
  — archived, superseded before upload), 20 (region carousel — archived,
  also superseded before upload), 21 (RC2: everything above + island basemap
  geometry, player-build control-bar layout with DEV toggles compiled out of
  Release, region-carousel peek polish, Africa expansion + South Asia trio,
  Japan-to-10 + Central Asia — 373 airports), 22 (cold-launch splash
  route-network reveal at the 1.25× tempo, naming-screen fit pass — smaller
  badge / 44pt fields / fits unscrolled on iPhone 17 Pro, "Central America &
  The Caribbean" card label, South America +10 — 383 airports), 23 (tappable
  Route Opportunities → one-tap map preview + open, turboprop tier — Beech
  1900D / ATR 42-600 / Dornier 328-110 / Dash 8-200 (shortest-field, reaches
  St. Barths), Canary→Africa region + Azores stays Europe + early loan pay-off;
  merged via PR #1), 24 (iCloud cross-device save sync with delete tombstones +
  the iCloud Key-value-storage capability now enabled/provisioned, iPad
  responsiveness fix — throttled UI heartbeat, pending-route staffing reason in
  the Ops incentive box), 25 (Marketplace category filter (box-style, per-class
  type counts) + Price/Seats/Range sort; My Fleet category + Owned/Leased +
  Seats/Range filters). Each
  TestFlight cut = bump `CURRENT_PROJECT_VERSION` (6 configs) → archive →
  Organizer → the DESIGNER does the credentialed Distribute/upload (Claude opens
  the Organizer but can't upload).
- **A three-part RC QA pass was run and is CLEAN** (the designer owns the 4th
  part — on-device feel/fun playtest, which no automated check can cover):
  1. **Independent code review** of the iPad changes → safe to ship, no
     must-fix issues (no crashes, no iPhone regressions, no stuck state). Its one
     finding (the map-flinch) is FIXED (reserved rail width, above).
  2. **Headless economy regression** (`scratchpad/main.swift`, compile the real
     `Sim/*.swift` + `Persistence.swift` with `swiftc -O`; entry file MUST be
     named `main.swift`) → **525/525 checks, 0 failures.** Asserts the master
     Finance cash invariant (`startingCapital + revenue − fees − opCost −
     leaseCost − insurance − maintenance − acquisition − routeSpend − hedgeSpend
     + saleProceeds + offerIncome + loanProceeds − debtService == playerBalance`)
     holds through every money-moving action, 10 long randomized games (0
     bankruptcies under competent play), and a forced bankruptcy→liquidation.
     Trim tick volume (≤~6M ticks) or it exceeds a 5-min run cap. LoanOffer ids
     are `small`/`medium`/`large` (not "fleet"). This harness is the proven net
     for any future economy change — re-run it.
  3. **iPad visual sweep** with a populated game → clean across tabs/orientations
     /themes. (A "empty detail pane" scare in the Fleet split was a rotation
     transient, not a bug — the split's `detailAC` defaults to the first owned
     aircraft.)
- **APP STORE SCREENSHOT HARNESS (recreate, don't reinvent).** 40 shots (20
  iPhone + 20 iPad, 10 light + 10 dark each) are driven by
  `scratchpad/capture.sh`: it boots both simulators, installs the Debug build,
  and for each of 10 named shots relaunches the app with `SIMCTL_CHILD_SHOT=<name>`
  then `simctl io screenshot`s into the designer's Desktop folders. The app side
  is a set of **TEMPSHOT blocks that are deliberately NOT committed** — grep
  `TEMPSHOT` and strip them all before any real commit. They are: a `#if DEBUG`
  `devSetBalance` on Simulation (playerBalance is `private(set)`); a
  `seedForShot(_:)` in ContentView's `.onAppear` that names the airline, buys a
  flagship fleet, opens real long-haul routes, HIRES CREW, runs ~62k ticks, then
  clears `maint` and picks the tab; and small `SHOT`-driven defaults in FleetView
  (segment/category/detail + a `ScrollViewReader` that scrolls Marketplace to
  the 787). Hard-won details: (a) **hire 3+ crew per owned family** — a bundled
  single crew leaves aircraft sitting in rest holds, which shows as GROUNDED with
  ~24 cycles instead of FLYING with ~150; (b) **clear `ac.maint` then tick again**
  so nothing reads GROUNDED red in a marketing shot; (c) the tail code must not
  collide with a real IATA code or `nameAirline` silently falls back to the
  default (`MQ` = Envoy, rejected; `MR` is free); (d) **gate the `devToggles` row
  on `SHOT`** — Pro/Demand (DEV) are `#if DEBUG` so they're absent from Release,
  but the screenshot build IS Debug, and they appeared in the first pass; (e)
  allow ~16s per shot (the seed's tick loop is slow), and dismiss `celebrations`
  or a milestone toast lands over the UI.
- **Screenshot/verification gotchas for the Simulator (recurring this session):**
  (a) `xcrun simctl io … screenshot` captures the RAW framebuffer, so LANDSCAPE
  comes out rotated 90°/180° — `sips -r 90` or `-r 270` to view upright (the app
  is fine). (b) computer-use CLICKS on the Simulator started intermittently
  landing on the macOS menu bar (opening Window/Integrate/Help menus) — a real
  input glitch; keys (rotation, Escape) still worked. Work around by seeding the
  target `tab`/state and driving via `simctl` rather than clicks; a Simulator
  restart may clear it.
- **TIME AWAY FROM THE APP NEVER BECOMES SIM TIME (designer-reported playtest
  bug, fixed).** Two holes: (a) QUIT-to-menu left the sim ticking behind the
  SaveSlotsView (milestone toasts fired over the saved-game screen — the run
  loop is keyed on `gameID`, which QUIT doesn't change); (b) backgrounding let
  the `ContinuousClock` accumulator bank the whole suspension and drain it at
  50 catch-up ticks per 8ms wake after resume. Fix: `Simulation.isPaused`
  (transient, not persisted — set on QUIT/menu/background via ContentView,
  cleared by fresh instances on load/new; run() zeroes the accumulator while
  paused so unpausing never fast-forwards) PLUS a `min(deltaMs, 250)` per-wake
  clamp in `run()` as a structural guarantee. NOTE: this is distinct from the
  design's "no player-facing pause DURING play" — that still holds; this only
  stops the world while the player isn't looking at it.
- **Playtest quick wins (same batch):** fleet status boxes are tappable list
  FILTERS (ring in the box's colour, tap-again/Total clears); the detail
  leg-progress bar rides an airplane icon at the fill tip (leg bar only);
  `topRouteOpportunities` samples each tier's top-8 (was deterministic top-2 —
  every new game showed identical markets). Queued bigger items live in
  `TASKS.md`: region selection at start, Hawaii+Caribbean "leisure
  destination" airports with a fare premium, and `HUBS_AND_CLUBS_SPEC.md`.
- **REGION SELECTION AT START — BUILT (designer playtest request).** The naming
  screen asks "WHICH REGION DO YOU WANT TO START IN?" — 7 chips in the
  designer's wording/order (Africa, Asia, Australia/New Zealand, Central
  America, Europe, North America, South America), North America default.
  `Airline.PlayerRegion` maps the 7 player choices onto the 10 internal carrier
  regions (NA = us+canada+mexico; Asia folds in middleEast — not offered as its
  own start; oceania = the whole South Pacific). `Simulation.homeRegion`
  (persisted in GameSnapshot as rawValue; nil/legacy saves → NA) drives FOUR
  things: (1) default map framing — `Simulation.frame(for:)`, where NA keeps
  the proven CONUS frame and every other region gets the padded bounding box of
  its airports; `configure()`/`resetCamera()` now use the instance `homeFrame`,
  and `applyHomeFraming()` re-fits on region change or viewport change; (2)
  spare bases — `homeBaseAirports` = home airports INSIDE the frame, which
  generalizes the old "no ANC/HNL bases" visibility rule to every region; (3)
  `topRouteOpportunities`; (4) airport recruitment offers. ALL former
  `conusAirports` uses are replaced (that pool is gone). FOCUS NOT FENCE: the
  player can still open routes anywhere on the globe. Verified 57/57 headless
  (per-region pools, frames, in-region spares/opportunities, save/load
  round-trip, legacy default) + live (Europe start frames Europe with its
  region colours). Naming screen now scrolls (the picker adds height).
- **LEISURE DESTINATIONS — BUILT (designer playtest request).** 26 new airports
  (343 total): Hawaii neighbors (LIH/OGG/ITO/KOA), the Caribbean primaries per
  the designer's territory list (SJU STT NAS PLS GCM EIS AXA SXM SBH ANU SKB
  DOM UVF SVD GND BGI AUA CUR BON POS), MLE Maldives + SEZ Seychelles. Real
  lat/lon and real runways/passenger counts; fee/ground-stop figures are
  tier-based ESTIMATES (same confidence tier as the LatAm set, flagged in
  code). `Airport.leisureCodes` (29 — includes existing MRU/NAN and PPT by the
  same island-leisure logic; Mexican beach airports CUN/CZM/SJD/PVR
  deliberately NOT leisure yet). TWO designer-specified mechanics, deliberately
  opposed: fares on any route touching a leisure code run ×1.15
  (`leisureFareMultiplier`, in `rollRevenue`'s fareMult stack) while OPENING a
  leisure route costs ×1.75 (`leisureOpeningCostMultiplier`, in
  `routeOpeningCost` — automatically surfaces in the route-confirm panel and
  slot-buyback values). Bigger buy-in, richer payback; both numbers are
  DESIGNED pacing. Carrier regions: Caribbean islands ride
  `centralAmericaCodes` (Copa/Avianca approximation — a real Caribbean roster
  is a future refinement); SJU/STT stay US-region (territories, same principle
  as GUM); MLE→asia, SEZ→africa. REAL-RUNWAY HONESTY: SBH (2,119 ft) and EIS
  (4,642 ft) are genuinely jet-unservable — turboprop-only in reality; they
  render + host background flavor and are a future turboprop-type hook, NOT a
  data error. Verified 75/75 headless + live (Central America start now frames
  the whole Caribbean; the label declutterer fans the Lesser Antilles cluster
  automatically).
- **ISLAND BASEMAP GEOMETRY — ADDED (designer-reported: Caribbean airports sat
  on empty ocean).** The original Natural Earth 110m extraction drops small
  islands, so every island-airport group lacked land: the whole Caribbean
  (Cuba/Bahamas/Hispaniola/Jamaica/PR + the full Lesser Antilles arc down to
  Trinidad, incl. Aruba/Curaçao/Bonaire and Guadeloupe/Martinique sliced from
  FRANCE's multipolygon), Maldives, Seychelles, Mauritius, Tahiti/Society
  Islands, Guam, Canary Islands + Azores (sliced from Spain/Portugal), and —
  found while fixing — FRENCH GUIANA (part of France, so the South America
  extraction had a real coastline gap). Sources: NE 50m for big islands, NE 10m
  for small ones; rings APPENDED to the EXISTING Basemap.json region keys
  (caribbean→centralAmerica, MLE→asia, SEZ/MRU→africa, Tahiti→australia,
  GUM→nation, Canary/Azores→europe) so ZERO Swift changes were needed — each
  group inherits its region's map hue automatically. KEY SUBTLETY: Tahiti's
  rings are stored at lon+360 (matching PPT's +210° stored-longitude wrap
  convention) — extract-time shift, don't "fix" the data. Basemap.json ~80KB →
  254KB. Verified live: Central America start shows the full Caribbean arc with
  airports on land; oceania start shows Tahiti under PPT.
  - **AMENDMENT (designer request): Canary Islands moved europe→AFRICA, Azores
    stays europe.** The islands were originally lumped `Canary/Azores→europe`
    (basemap key) purely because both were "sliced from Spain/Portugal" — but
    the Canaries sit off the Moroccan coast and belong in the Africa region.
    Three coordinated changes: (1) the 7 Canary rings (lat ~27-29, lon ~-18…-13)
    were moved from the `europe` to the `africa` key in Basemap.json (europe
    93→86, africa 81→88 rings) so they render in the Africa AMBER hue #FFB700
    (was europe purple #A561FF); the 9 Azores rings (lat ~37-39.7) stay in
    `europe`/purple. (2) `LPA` (Gran Canaria) moved `europeCodes`→`africaCodes`
    in Airline.swift, so its background carrier draws from the Africa roster;
    `PDL` (Ponta Delgada, Azores) stays europe. (3) Binter Canarias (code NT,
    E195 — the Canaries' real carrier) moved europeRoster→africaRoster to follow
    LPA; Azores Airlines (S4) stays europe. Identifying the rings is trivial by
    coordinate range (they're the last 16 rings appended to europe) — see the
    one-off Python filter in git history if this needs redoing.
- **Competitive-Traffic slider split into its OWN box; DEV toggles compiled out
  of Release (designer request).** The old `devControls` container mixed the
  player-facing TRAFFIC slider with the Pro(DEV)/Demand(DEV) toggles — so
  TestFlight players saw dev switches, and hiding them would have left a gap.
  Now `trafficBox` (slider alone, ships everywhere, sits snug under the speed
  bar) + `devToggles` (Pro/Demand, wrapped in `#if DEBUG` at the call site —
  absent from Release builds entirely, not just hidden). Verified in a real
  Release-configuration build.
- **SOUTH AMERICA EXPANSION — DONE (designer: "next 10 by size"). 373 → 383
  airports.** Added FOR CWB FLN BEL CCS MAO CUZ VIX CGB BAQ — strictly the
  next tier by annual passengers, which lands 7 Brazilian regionals (accurate:
  Brazil's domestic market is huge) plus Caracas, Cusco, Barranquilla. Real
  lat/lon + runway/pax data; fees tier-estimated to the existing SA entries.
  NOTE for a future pass: Venezuela is now in, but Paraguay (ASU), Uruguay
  (MVD), and Bolivia (VVI/LPB) are still unrepresented — their largest
  airports fall below this size cut; add them if country coverage matters
  more than the strict ranking. Verified 27/27 headless.
- **ASIA EXPANSION — DONE (designer list). 363 → 373 airports.** Japan grew
  3 → 10 (designer: "Japan is large enough for 10"): added FUK CTS OKA ITM
  NGO KOJ SDJ alongside the existing HND/NRT/KIX — fees calibrated to the
  high HND/NRT tier; HND↔CTS and HND↔FUK correctly come out as
  widebody-grade trunk demand (they're two of the world's busiest routes).
  Central Asia: ASB (Ashgabat), TAS (Tashkent), ALA (Almaty) — largest in
  Turkmenistan/Uzbekistan/Kazakhstan. TPE was already in the game (checked,
  not duplicated). OKA (Okinawa) joined the leisure set (32 total) — Japan's
  island-beach destination, same principle as Hawaii. Okinawa's island
  geometry added to the asia basemap layer (110m Japan is main-islands only).
  Verified 32/32 headless + live Asia-start screenshot.
- **AFRICA EXPANSION + SOUTH ASIA TRIO — DONE (designer list). 343 → 363
  airports.** Parsed the designer's top-40 African airports list against the
  existing roster (23 already in game), added the 17 missing: ZNZ FIH MPM HRE
  MIR TNR DJE BFN LUN LBV KAN CKY PLZ EDL BSK SID DZA — plus the largest
  airport in Bangladesh (DAC Dhaka), Nepal (KTM Kathmandu), and Bhutan (PBH
  Paro). Real lat/lon + runways/passengers; fees are tier ESTIMATES calibrated
  to the existing Africa entries (same confidence tier as LatAm/leisure).
  Region sets: 17 → africaCodes, 3 → asiaCodes. LEISURE grew 29 → 31: ZNZ
  (Zanzibar) + SID (Sal, Cape Verde) added by the same island-leisure
  principle as NAS/PPT/MRU — flag if that extension isn't wanted.
  REAL-RUNWAY HONESTY (same principle as SBH/EIS): PBH Paro (7,431 ft valley
  strip, daylight/VFR-only in reality — modeled with a high ground-stop rate)
  and DZA Mayotte (6,345 ft) block widebodies; PLZ Gqeberha (6,496 ft) too.
  Island basemap geometry added in the same pass (Cabo Verde — NE names it
  "Cabo Verde" not "Cape Verde" — Mayotte via a France bbox slice, Zanzibar +
  Pemba via a Tanzania bbox slice) → africa layer. Verified 74/74 headless
  (count/dupes/regions/rosters/leisure/runway-blocks/demand/home-pool
  framing) + live Africa-start screenshot with every new airport on land.
- **GameKit (leaderboards/achievements) — still DEFERRED, reaffirmed this
  session.** Designer's friend suggested it; decision was to skip for now (it's a
  no-architectural-risk bolt-on). If revisited: rank on EFFICIENCY not
  accumulation (fastest-to-a-milestone / score-at-fixed-sim-day), NOT raw net
  worth (the sim is time-decoupled + 25× speed → raw net worth rewards grind).
  Achievements map ~1:1 to the existing milestone system. GameKit's aggregate
  achievement/leaderboard completion rates are useful balance signal but NOT
  gameplay telemetry — for that, a privacy-first SDK (TelemetryDeck) is the right
  tool, and the headless balance-sim is better still for PRE-launch tuning.

## Decided — Competitor Acquisition (1.1; step 1 of 5 BUILT)

Full design in **`ACQUISITIONS_SPEC.md`**. Prompted by testers reporting the
game goes flat past **$1B net worth** — a new route moves net worth by a
fraction of a percent, so the reward curve dies.

- **The feature is deliberately an INTEGRATION CHALLENGE, not an asset
  purchase.** Designer's framing: untangling double-covered routes, crew
  seniority fights, and inherited inefficiency should introduce *real peril*.
  Calibration target: a well-managed acquisition pays back in **24–36
  sim-months**; a passively-held one **never does**. That gap IS the feature —
  if the A/B ever shows passive holding also paying back inside 36 months, the
  numbers are wrong. Rejected alternative: "spend $X, receive planes" is the
  verb that already stopped being rewarding, at a bigger number.
- **INVERTED GUARDRAIL vs Hubs & Clubs — do not copy that one here.** Hubs
  measured "rivals on player routes roughly halved" as a SUCCESS. For
  acquisitions the identical measurement is a **FAILURE**: eating competitors
  removes the late-game pressure that makes the endgame interesting. Every
  completed acquisition must make SURVIVORS more aggressive (a multiplier on
  `competitorEntryDailyProbability`). Winning must not mean less game.
- **Real airline names: KEPT.** The trademark concern was raised and then
  explicitly walked back as over-cautious — text-only reference is already
  shipping and is the defensible end of the spectrum. Holding: no logos or
  liveries, and no real brands in App Store metadata (why Boeing/Airbus are
  excluded from the keywords).
- **OWNERSHIP MODEL — SUBSIDIARY, DECIDED (designer): "you now own the airline
  and it keeps FLYING under their original flag."** An acquired carrier is never
  erased or repainted; it operates as a subsidiary under player ownership. This
  is a fiction call that directly serves the hardest guardrail above — **the map
  never empties**, because consolidation removes a *competitor*, not a *carrier*.
  Consequences (see `ACQUISITIONS_SPEC.md` for the full list): inherited tails
  KEEP their original airline code (a Delta jet stays `N123DL`, not renumbered
  to the player's 2-letter code); the map needs a THIRD aircraft colour state
  (owned-mainline vs owned-subsidiary vs competitor — a subsidiary is yours but
  flies its own flag, and today's two states can't express that); reputation
  blends only PARTIALLY (a full blend would let a bought carrier's bad service
  instantly tank the mainline score — partial is both more realistic and gives
  the player a reason to invest in fixing it); and subsidiaries STAY in Market
  Intelligence flagged as owned, which quietly turns the scouting list into a
  portfolio view.
- **Game-appropriate scaling is a stated PRINCIPLE, not a shortcut** (designer,
  on the competitor financials): scaling fleets/revenue to the game's own economy
  "reinforces that this is a game" rather than importing real-world financials.
  Apply the same instinct to acquisition prices and integration costs.

### Step 3 — integration burden: BUILT and BALANCE-VERIFIED (12-seed sweep)

**Target met.** 12 seeds × 3 arms, 36 months, arms restored from one shared
snapshot per seed. Payback on NET WORTH (month-0 drop = price − assets received
= the deal's true cost). **Passive: $3.74M/mo, 13.5-year payback. Managed:
$9.69M/mo, 5.8-year payback.** A shrewd operator lands at the low end of the
designer's 5–10 window; passive holding struggles past 10. The **2.6×
managed/passive gradient held across every tuning round** — that consistency is
what says the skill expression is real.

- `acquisitionControlPremium` = **0.25**, SIZED BY THE SWEEP (0.80 → 22.9-year
  median payback). It is the single constant that sets payback: the deal's true
  cost is (premium × liquidation value) + goodwill.
- **Pricing builds on `fleetLiquidationValue`, never `estimatedValue` alone.** A
  loss-making carrier has NEGATIVE goodwill, which pushed estimatedValue below
  its own fleet value — the old `estimatedValue × 1.3` priced a carrier BELOW
  what its aircraft fetch (measured: ~$1,890M of aircraft for $2,051M). Buy,
  liquidate, profit. The floor is now structural.
- **⚠️ SYSTEMATIC: cross-region acquisitions ALWAYS fail.** The value-destroying
  seeds were the same 3 in both arms and all bought Air Canada (Canada carrier,
  US player) — every same-region target paid back. An out-of-region carrier's
  hubs and routes sit outside the player's network: no overlap, no hub synergy,
  no connecting traffic. Realistic and worth KEEPING, but currently an invisible
  trap — it belongs in stage-1 due diligence as a headline risk (designer's
  preferred route over gating), not something discovered by losing a billion.

**SWEEP METHODOLOGY — reuse it, and don't repeat these:** single-seed
measurement is worthless (identical code gave +$23.2M/mo and −$5.6M/mo on
consecutive runs); arms must share ONE `GameSnapshot` or they buy different
carriers; rationalisation must filter unserved PAIRS not AIRPORTS; both arms must
be crewed to ~2.2/aircraft or they're structurally loss-making and the control
flattens; and measure NET WORTH not cash, because cash payback penalises
reinvestment. The sweep binary takes seeds as argv and runs 6-way in parallel.

### Step 4 — TWO-STAGE DUE DILIGENCE: BUILT (23/23 headless + live)

Designer's framing: what you can see depends on how far into the deal you are.

- **`CompetitorProfile.fleetManifest(seed:)`** derives the real per-aircraft ages
  deterministically, and **`inheritFleet` now uses it** — so stage-2 books are
  exactly the fleet inherited (verified airframe-for-airframe). Ages are no
  longer rolled at acquisition time.
- **Stage 1** (free): wide renewal band, "LIKELY needing renewal", ESTIMATE chip,
  cross-region warning. Sees only the published AVERAGE age, so it cannot know
  the spread — that gap IS the uncertainty and is not to be "fixed".
- **Stage 2** (`openBooks`, 0.4% of estimated value, min $250k, persisted): tight
  band from the manifest, exact aged count, VERIFIED chip. Can reveal a bill
  WORSE than the estimate.
- **Scenarios** calibrated from the 12-seed sweep's per-aircraft rates
  (`perAircraftManagedMonthly` 290k / `perAircraftPassiveMonthly` 112k, BEFORE
  age drag), scaled by age drag and region fit. Cross-region → "never breaks
  even" in every scenario, which surfaces the systematic trap.
- **RENEWAL IS CAPITAL REQUIRED, NOT A SCENARIO DEDUCTION.** An early version
  subtracted it and made every deal unpayable: renewal is an asset swap (sell
  old, buy new), roughly net-worth neutral, and the calibration rates already
  include a renewing operator. Don't re-add it.
- Projections skew OPTIMISTIC vs the sweep's medians — deliberate, as real deal
  models do.

### Step 3 — the mechanics

Mechanics are complete and verified (27/27 headless). The first measured
economic run **fails the calibration target and needs a designer call before any
tuning** — full table + diagnosis in `ACQUISITIONS_SPEC.md` §MEASURED ECONOMICS.

- **`Integration`** (Acquisition.swift) + the lifecycle in Simulation.swift:
  18-month window, monthly bill (1.5% of price), seniority dispute (9 months, or
  settle for 8%), disputed families, bills paid. `integrationInProgress` is now
  REAL, so a second acquisition is blocked while one runs.
- **Seniority dispute** sidelines 35% of each crew family flown by BOTH airlines
  (reuses `.sidelined`; never yanks crew mid-flight) and is RE-APPLIED each tick,
  because crew released from a flight return `.available` and the dispute would
  otherwise drain away. Settling returns every sidelined crew immediately.
- **Double coverage**: `overlapDemandMultiplier` splits a pair's demand across
  every player route serving it, × `overlapCoordination`, which eases 0.70→0.92
  across the integration and then HOLDS AT THE FLOOR. Time never reaches 1.0 —
  only closing/reassigning one of the pair clears it.
- **Inherited routes are BIASED (45%) toward airports the player already
  serves.** Caught by the harness: with purely random hub-anchored generation the
  first target produced ZERO overlapping pairs and ZERO disputed families, so the
  entire burden was inert and a player could cherry-pick frictionless targets.
  You buy a competitor *because* they fly where you fly.
- **MEASURED RESULT (1 seed, 3 arms from an identical restored state):** neither
  passive nor managed ever pays back in 36 months, and **MANAGED LOSES TO
  PASSIVE** — the inverse of the intent. The integration bill is 27% of the
  purchase price (1.5%/mo × 18mo, never multiplied out in the spec) and accounts
  for ~¾ of the loss; the settlement (8%) is nearly pure cost; overlap relief is
  too shallow to fund it. **Underneath all of that: this game's aircraft take
  ~8 years to pay back individually (real prices vs. the locked ~6-hr cycle), so
  an airline priced at fleet value cannot pay back in 24–36 months at any
  integration tuning.**
- **HARD CONSTRAINT for any repricing:** the price must ALWAYS exceed the fleet's
  in-game `fleetMarketValue`, or the player buys a carrier and liquidates its
  fleet at a profit — pure arbitrage, the worst available failure mode.
- **A/B METHODOLOGY TRAP worth keeping:** the first run was invalid because each
  `Simulation` rolls its OWN `competitorSeed`, so the arms bought *different*
  carriers at different prices. Arms must be restored from one shared
  `GameSnapshot`. A second bug in the same run: the rationalization helper
  filtered for unserved AIRPORTS, which finds nothing once an inherited network
  covers the country — it must filter for unserved PAIRS.

### Step 2 — transaction + inheritance: BUILT (NOT SHIPPABLE ALONE)

⚠️ **Step 2 on its own IS the design the spec rejects** — spend money, receive
assets, pure upside. It reads as a money printer until step 3 (the integration
burden) lands. Do NOT ship a build with acquisitions enabled and step 3 missing.

- **`Sim/Acquisition.swift`** holds the TYPES + pure read-only logic
  (`Subsidiary`, `AcquisitionBlock`, gate constants, `askingPrice`,
  `acquisitionBlock`). The MUTATING core lives in Simulation.swift
  ("Competitor acquisition" MARK) because everything it touches
  (`playerBalance`/`aircraft`/`playerRoutes`/`hubs`/crew pools/`reputation`) is
  `private(set)` to that file — same reason the Hubs & Clubs core lives there.
- **Gate**: net worth ≥ $1B, carrier must be in `relevantCompetitors`, one
  integration at a time (inert until step 3), **lifetime cap 3**, price
  escalation ×1.0/1.4/1.9. `askingPrice` = `estimatedValue × 1.30 × escalation`
  (control premium — you never buy a company at book).
- **Inheritance**: fleet (real ages spread around the carrier's stated average,
  **tails KEEP the carrier's own code** — a Delta jet stays `N…DL`), routes
  (hub-anchored, in-region, **free but they consume slots**, capped at the
  aircraft inherited so nothing lands unstaffed, and gated by the real
  `routeBlock` range/runway check), hubs, and crew.
- **SPEC AMENDMENT — inherited aircraft come WITH crew.** The spec originally
  said unfamiliar types arrive with no crew; that's wrong on realism (you
  acquire the airline's people too) and would flood the alert queue at close.
  The merger's pain is the SENIORITY fight, which is step 3's job and bites into
  exactly this inherited pool.
- **Rival removal** clears the carrier from every `Route.competitors` (demand
  recovers immediately — the one instant, legible reward); unrelated rivals
  survive, and `competitionLevel` stays consistent with the list.
- **Reputation blends PARTIALLY**, weighted by relative fleet size and **capped
  at 0.5** so a subsidiary can never swing the mainline score by a majority.
- **Finance invariant EXTENDED** with `− totalAcquisitionPrice` (as
  `PeriodFigures.airlineAcquisition`, distinct from `acquisition`, which is
  aircraft purchases). `FinanceSnapshot`/`FinanceSave` carry it too (optional →
  legacy-safe). **Any future harness must include this term.**
- **Persistence**: `subsidiaries` + `totalAcquisitionPrice` on GameSnapshot, and
  `subsidiaryCode` on `AircraftSave`/`RouteSave` — all optional/nil-safe.
  Subsidiaries restore BEFORE the fleet so an inherited aircraft can resolve its
  carrier's name.
- **`#if DEBUG devInjectCash(_:)` is a TEST HOOK** (reaching $1B through the real
  economy takes sim-years). Injections are TRACKED via `devInjectedCash` so the
  cash invariant accounts for them explicitly rather than being excused.
  Verified absent from a real Release binary (`strings` → 0).
- Verified **51/51 headless** (gate refusal moves no cash, exact price
  deduction, invariant after acquisition AND after 20k ticks, full-fleet
  inheritance, tails keep the carrier code, every inherited route flyable by its
  assigned aircraft and none unstaffed, crew present for every inherited type,
  hubs transferred, partial-only reputation blend, re-acquire refused, price
  escalation, rival removal with unrelated rivals surviving, save/load
  round-trip, legacy-save load) + live in the Simulator (offer state showing
  $106.0M → $137.9M asking = exactly the 1.30× premium; post-acquisition
  "continues to fly under its own flag").
- **A harness lesson worth keeping:** the restore invariant check initially
  failed, and the fix was to assert the gap equals EXACTLY the untracked test
  injection rather than to relax the check — which is what proved persistence
  was actually correct instead of merely passing.

### Step 1 — competitor scouting: BUILT

- **`Sim/Competitor.swift`**: `CompetitorProfile` (fleet + composition + age,
  routes/cities/hubs, revenue/margin/load factor/service score, trend,
  `estimatedValue`) and `CompetitorIntel.generateAll(seed:airports:)`. 140
  profiles from the 142-entry roster (2 skipped: the Independent Operator
  fallback + a cross-roster duplicate).
- **DISCLOSURE PRINCIPLE (designer):** a profile shows what a PUBLIC FILING
  would show — real airlines' topline performance is open to scrutiny. Never
  per-route P&L. That boundary deliberately leaves due diligence as a later
  layer that reveals what the topline hides.
- **Numbers derive from REAL game data**, not invented: the airline's real
  `types`, real `AircraftType` seats/prices/weights, the real
  `FareModel.farePerSeat`, and its real region's airports. Fleets are GAME-scale
  (4–60), not real-world scale — a real major flies ~900 aircraft, which would
  price an acquisition beyond any reachable net worth. Roster `weight` (market
  share) drives relative size.
- **Determinism via ONE persisted field.** `Simulation.competitorSeed`
  (`GameSnapshot.competitorSeed`, optional → legacy saves roll a fresh seed and
  simply gain a market). Profiles are NOT persisted — they regenerate exactly
  from the seed, which keeps saves small AND stops a player re-rolling a
  carrier's books by quitting without saving.
- **A real bug the determinism check caught (inspection would not have):**
  summing revenue/fleet-value by iterating `fleetByType` — a Dictionary — made
  the last bits of the result vary between two generations from the SAME seed,
  because Dictionary iteration order isn't stable across instances and float
  addition isn't associative. 44 of 140 profiles differed. Both loops now
  iterate `.sorted(by: key)`. **Any future derived-from-seed value must sum in a
  sorted order** or the regenerate-on-load guarantee silently breaks.
- **`CompetitorIntelView.swift`**, presented from FINANCE (evaluating a rival is
  an investment question) via a MARKET INTELLIGENCE card. List → carrier detail.
  **Scouting is deliberately UNGATED** — it isn't behind the $1B threshold:
  public information is public, it enriches the world for every player, and it
  gives the endgame something visible to aim at.
- `Simulation.relevantCompetitors` scopes the list to the player's home region
  plus anywhere they've opened a route (~25 carriers on a US start, not 140);
  `rivalsOnMyRoutes` drives the red CONTESTING YOU chip.
- **CONSEQUENCE WORTH KNOWING: roster `types` data is now PLAYER-VISIBLE.**
  Previously `Airline.types` only decided which livery a background aircraft
  wore — invisible. The carrier profile now itemizes a fleet ("Airbus A320 ×12,
  Boeing 737 MAX 8 ×9"), so any roster inaccuracy is directly readable by a
  player who knows airlines. Spot-check `types` when touching the roster.
- Verified **1278/1278 headless** (`swiftc -O` on the real `Sim/*.swift` +
  `Persistence.swift`): bit-exact determinism, seed round-trip, legacy-save
  load, per-profile sanity across all 140, valuation reachability at the $1B
  gate (min ~$80M · median ~$730M · max ~$5B — a real ladder), lossmaking and
  shrinking carriers both present, region scoping. Plus live in the Simulator,
  both themes.

## Decided — Hubs & Clubs (built to the designer-reviewed spec)

- **The full mechanic from `HUBS_AND_CLUBS_SPEC.md` is BUILT (native app) —
  sim core, every economic hook, persistence, and 5 UI surfaces, in one
  pass.** Player idea (from real United Clubs membership): establish HUBS
  (unlocks at 5 routes touching an airport) and build CLUBS/lounges at
  operating hubs. Designer's guardrail, verbatim intent: hub+club must NOT
  be a money printer.
- **Sim core** (Simulation.swift, "Hubs & Clubs" MARK): `Hub` struct
  (Codable) in `hubs: [code: Hub]`; `rivalHubs: [code: rivalName]`;
  status is COMPUTED from live route count — `hubOperating` (≥5 routes),
  `hubUnderstaffed` (<5: benefits suspend, bills continue — the
  overextension trap). Costs anchor to the airport's REAL
  `annualPassengers`, RETUNED DOWN from the spec draft by the mandatory
  balance A/B (see the Balance bullet below — the draft numbers made the
  hub a pure value-sink): establish `$1.5M + $60k×paxM` (floor $2M, cap
  $8M), labor `$25k + $8k×routes`/mo, club build `$1M + $40k×paxM` (cap
  $5M), rent `$20k + $0.8k×paxM`/mo. Monthly billing rides the same
  recurring cadence as insurance/leases (`tickHubBilling`,
  `nextHubBillTick`). Decommission returns $0 (designer decision); the
  ONLY way to recoup is a rival's buyout offer (`tickHubOffers`, daily —
  1.5%/day healthy at 60% of establish cost, 8%/day at 35% when
  UNDERSTAFFED, vultures circling). Selling is PERMANENT: the airport
  becomes a rival hub (+50% competitor entry there, can never re-hub it,
  club closes). Blue `.hubOffer` decision card (`HubOffer` payload,
  aircraft-nil pattern like `.offer`).
- **Economic hooks (final, post-A/B values)**: demand 15%/spoke at an
  operating hub vs 8% base, SAME +80% cap (`hubDemandMultiplier` — NOTE:
  on a 10+ spoke network the BASE rate already saturates the cap, so this
  lever is worth ~nothing at scale; that finding is why the hub carries a
  fare lever now, see below); HUB FARE +3% on hub-touching routes
  (`hubFareMultiplier`, in `rollRevenue` — the hub's one benefit that
  scales with operation size; a deliberate AMENDMENT to the spec's strict
  lever separation, sized so the hub roughly pays for itself); fees at
  the hub −20% landing / −35% gate (`legEconomics`, player only); MX
  base: AOG standard repair 135 ticks (−25%) and repairs −20% at
  hub-touching routes (both resolvers); crew rest ×0.8 when released on a
  hub route; fortress: −50% competitor entry on hub-touching routes, +50%
  at sold (rival) hubs (`tickCompetition`); slot-buyout premium WAIVED at
  your operating hub (`routeOpeningCost`). Club (requires operating hub):
  +4% fare on top of the hub's +3% (`clubFareMultiplier` — the SPLIT
  total ≈7.1% is LOWER than the spec draft's club-only 6→8% experiments),
  reputation FLOOR `40 + 5×clubs` cap 60 (`reputationFloor`, dings clamp
  to it), competition share floor 0.35 vs 0.2
  (`Route.competitionShare(reputation:shareFloor:)`), and an FFR-surge
  liability −2%/club on fares (redemption exposure). Milestones:
  `first_hub` + `first_club`.
- **Persistence**: `hubs`/`rivalHubs`/`totalHubSpend`/`totalHubLabor`/
  `totalClubRent` as OPTIONAL GameSnapshot fields (nil-safe for pre-hub
  saves — the established pattern), FinanceSave gains optional
  hubSpend/hubLabor/clubRent; restore re-seeds `nextHubBillTick`. The
  master Finance cash invariant now includes `− totalHubSpend −
  totalHubLabor − totalClubRent` — extended in the regression harness the
  same session (any future harness must include these three terms).
- **UI surfaces**: airport card (`AirportInfoCard`, sim passed in) —
  eligibility progress ("Hub eligibility n/5 routes"), CREATE A HUB /
  BUILD CLUB actions with real costs, gold "Your hub — operating" or red
  "UNDERSTAFFED (n/5 routes)" status + labor/rent rows, purple rival-hub
  notice; map badges in `MapView.drawAirports` — gold double ring
  (operating), dim single ring (understaffed), purple ring `#D767FF`
  (rival hub); Ops "Hubs & Clubs" box (per-hub status/bills + rival
  entries); Finance rows ("Hub operations" + "Club rent" in overhead,
  "Hubs & clubs built" in capital); Alerts modal hub-offer card
  (Sell·+$X / Decline) with the permanence warning.
- **Verification (all clean)**: 70/70 headless hub/club suite (lifecycle,
  exact cost formulas, billing, suspension-and-revert, sale/decommission,
  persistence round-trip incl. legacy saves, AOG-at-hub timer 135 +
  −20% cost, invariant at every step) — the suite drives the REAL player
  API only (buys used jets + takes loans to fund it; `playerBalance` is
  private(set), which is by design); 3,100/3,100 economy regression
  (every-action invariant, 20 games × 3 sim-years, forced bankruptcy);
  9 visual fixtures on the iPad simulator (all five surfaces, operating +
  understaffed + pre-hub states, exact on-screen numbers verified against
  the formulas — Finance showed "Hubs & clubs built −$4,715,000" = OKC's
  $3M floor + $1.715M club exactly).
- **Balance A/B (the spec's mandatory pre-ship gate) — PASSED, after
  real iteration that changed BOTH the harness and the game's numbers.**
  Autopilot plays 36 sim-months per game: competent, strategy-neutral
  daily decision handling + weekly expansion (cheapest-effective USED jet,
  up-gauged by projected filled-seats-per-$M so the hub's demand bonus can
  actually convert to gauge — without up-gauging the bonus dies against
  the 0.92 LF cap on small jets and the A/B is meaningless). The DECISIVE
  test is the ISOLATION A/B — the SAME DEN-spoke network with vs without
  the hub (the spec's original sprawl-vs-hub framing conflates the hub
  mechanic's value with the PORTFOLIO cost of concentrating at one
  airport, which is a real strategic tradeoff the game keeps). FINAL
  (6 seeds/arm, 36mo): hub marginal value **+0.7%**, hub+club **−3.7%**,
  with the defensive perks visible (rivals-on-routes roughly HALVED,
  reputation pinned at 100) — not a printer, not a trap, resilience +
  identity as specced. History that got here: the spec-draft numbers
  measured **−41%** (hub) — a pure value-sink, because early capital
  compounds ~3-4× over 3 years and the draft hub had no benefit that
  scales (its demand bonus saturates at the +80% cap the BASE network
  effect already reaches at 10+ spokes). Fix: cheaper hub (see Costs),
  deeper fee discounts, and a +3%/+4% hub/club SPLIT of a REDUCED total
  fare premium. Also: three successive AUTOPILOT bugs produced false
  readings first (hub arm never establishing because jets ate the cash;
  sprawl's pair pool bled dry by a diagnostic that consumed a pair per
  check; nearest-first spokes flying cheap short legs) — when an A/B looks
  wildly out of band, audit the autopilot before touching game numbers.
  The separate sprawl-vs-hub strategy A/B still shows concentration
  trailing a cherry-picked national network (portfolio effect, working as
  intended); the harness lives at the session scratchpad's `ab.swift`.
- **A pre-existing flaw found DURING hub verification, fixed in the same
  pass**: Route Opportunities could suggest a class that can't fly the
  route (playtest fixture showed EWR↔Hilo, 4,235nm, tagged "Regional
  jet"). `suggestedClass(demand:distanceNM:)` now bumps the tier UP until
  the tier's real max range (computed from `AircraftType.all`) covers the
  distance.

## Open / not yet decided

- Xcode project shell doesn't exist yet — needs creating in Xcode itself on
  a Mac (can't be done from a Linux sandbox). See ROADMAP Phase 0.
- **Persistence — BUILT (native app), and NOT via SwiftData.** Went with a
  plain Codable snapshot to disk (JSON), not SwiftData/Core Data — the sim state
  is a self-contained object graph that serializes cleanly, and a single-slot
  save doesn't need a database. `Persistence.swift` has `GameSnapshot` (+ per-
  aircraft/route/crew/finance sub-structs) and `GameStore` (save/load/clear to
  Documents/savegame.json). `Simulation.snapshot()` exports and
  `Simulation.restore(from:)` imports (both live IN Simulation.swift so they can
  set the `private(set)` state). ONLY persisted: identity, balance, tick, all
  economy accumulators, PURCHASED aircraft, open+closed routes (with history),
  crew pools/reserves, finance snapshots, camera, firedMilestones, the traffic
  count. NOT persisted (regenerated on load): background/competitor traffic
  (`setFleetSize(savedCount)`), live event effects (reset to Normal), the used
  market (re-inited), airport ground-stops (cleared), slots (re-provisioned then
  decremented per open route). Aircraft reference type-by-id and airport-by-code;
  crew reconstruct by their per-family id. ContentView autosaves on scenePhase !=
  .active (background/quit) and, on cold launch, shows `ResumePromptView`
  (Continue / Start a New Airline) if a save exists — bankruptcy and "new
  airline" clear the save. Verified: JSON round-trip (7KB) restores every field
  exactly AND the restored sim keeps running/earning (29 new flights, balance
  advancing). SwiftData model classes are still present but unused; this
  supersedes the "SwiftData returns in Phase 5" plan.
- Figma → SwiftUI pipeline: designer has real mockups in Figma; pull via
  Figma MCP `get_design_context` against actual file/node URLs, don't
  guess at layouts from descriptions. Note the raster-export limitation
  documented above under Icons — full-screen mockups may hit the same
  wall the icon nodes did; verify early rather than assuming it'll work.
- **ROUTE COMPETITION — BUILT (native app), a first real version.** Rival
  carriers now REACT to the player: `tickCompetition()` (daily) has rivals ENTER
  the player's PROFITABLE, established (≥8-day-old) routes — up to 3 per route,
  ~6%/day, chasing the traffic — and occasionally EXIT (churn, ~2%/day). Each
  rival SPLITS the route's demand via `Route.competitionShare(reputation:)` =
  `1/(1 + level × (0.6 − 0.3·rep/100))`, floored at 0.2 — so 2 rivals at rep 70 ≈
  −44% demand. A strong REPUTATION both defends share (the factor shrinks with
  rep) AND deters entrants (entry rate halves at rep 100). Applied in `rollRevenue`
  for owned aircraft only. Entries/exits log to the Ops feed (MARKET) naming a
  Big-Four/ULCC rival; a dedicated Ops "Competition" box lists contested routes +
  rivals + the demand hit. Persisted (`competitionLevel`/`competitors` on Route).
  Verified 8/8 headless + live. STILL NOT modeled (deliberate, future): rivals
  competing for SLOTS at open time, or having their own economy/network — this is
  demand-share competition on the player's routes, which is the impactful, visible
  slice. The background-traffic airline NAMES are still separate cosmetic identity.
- The airline roster (`AIRLINE_ROSTER`) and its US-market-share weighting
  is hardcoded to the current US-only airport network. If a future
  version adds other regions/countries, the roster and weights need to
  become region-aware — right now there's no mechanism for that at all,
  it's a single fixed US-weighted list. Also has no way to detect real-
  world fleet/route changes on its own (an Alaska Airlines update this
  session was applied because it was reported and independently
  verified, not because anything in the game noticed).
- **REPUTATION — BUILT (native app).** A service-quality stat (0–100, starts 70)
  that feeds back into demand. FALLS when the operation fails passengers (an
  aircraft grounded −4 at AOG-hold start, a flight held for crew −2) and RECOVERS
  slowly through flights completed cleanly (+0.15 each). `reputationDemandMultiplier`
  = `0.85 + 0.30·rep/100` (0.85 at rep 0 · 1.0 at rep 50 · 1.15 at rep 100), applied
  to owned-aircraft demand in `rollRevenue`. It ALSO defends market share vs
  competitors (see ROUTE COMPETITION above). Dedicated Ops "Reputation" box: score
  bar + tier (Poor/Fair/Good/Excellent) + signed demand %. Persisted. The feedback
  loop: bad service → fewer pax → less revenue → harder to recover. Resolves the
  original-design-brief reputation item (demand curves + hub effect were already
  built).
- **HUB / NETWORK EFFECT — BUILT (native app).** Concentrating routes through
  an airport now pays: `Simulation.hubDemandMultiplier(originCode:destCode:
  excludingRouteId:)` gives a route `+hubBonusRate` (8%) demand per OTHER player
  route touching either endpoint, capped at `hubBonusCap` (+80%). So a coherent
  hub-and-spoke network beats scattered point-to-point (connecting passengers).
  Applied in `rollRevenue` for the player's own aircraft only (background traffic
  isn't part of the player's network); `excludingRouteId` stops a route counting
  itself. Folded into the `routeDailyDemand`/`projectedLoadFactor` UI helpers and
  shown as a "Hub bonus +X%" row in the route-confirm panel. Verified: 2 routes
  out of DEN give each DEN route +16%, an isolated pair stays ×1.00.
- **MICRO-INTERACTIONS / DELIGHT PASS — BUILT (native app; designer request for
  polish + "surprise and delight").** New `Delight.swift` holds the shared
  primitives: a `Motion` enum of standard spring curves (glide / pop / toast) so
  everything animates consistently; a `Pressable` ButtonStyle (`.pressable()`) —
  scale+fade on press — applied to the control-bar / speed-bar / eye buttons; a
  `PlaneFlyBy` easter egg; and the `MilestoneToast`. Wired in: (1) the Cash-on-
  hand value is a rolling counter (`.contentTransition(.numericText())`); (2) the
  Network control-bar panels, route-flow, tooltip and airport card GLIDE in/out
  (move+opacity transitions driven by `.animation(Motion.glide, value:)` on the
  overlay stack); (3) MILESTONE CELEBRATIONS — `Simulation` queues one-time
  `Celebration`s (first flight, fleet 5/10/25, net worth $50M/$100M/$250M/$500M/
  $1B — thresholds ABOVE the $30M start so they're real growth, and a route
  recouping its opening cost from `settleLeg`); ContentView shows the first as a
  gold-rimmed toast that glides down from the top and auto-dismisses (3.6s). Fired
  once each via a `firedMilestones` Set; `checkMilestones()` runs in the tick
  loop. **The badge now uses app-aesthetic SF SYMBOLS (not emoji), tinted gold:**
  `Celebration.symbol` (airplane / airplane.departure / trophy.fill /
  chart.line.uptrend.xyaxis / airplane.circle.fill). For a ROUTE milestone (a
  route recouping), `Celebration.originCode`/`destCode` drive a city-pair line
  rendered with the ⇄ `arrow.left.arrow.right` icon between the codes (matches the
  Figma "RT Route Arrows" 61:4824 + the Ops boxes) instead of a unicode ↔ in the
  title string. (4) MAP ROUTE-OPEN RIPPLE — `routeOpenPulse` (set in `openRoute`) drives
  two staggered expanding rings at both endpoints in `MapView.drawRoutePulse`
  (tick-driven over 48 ticks, no SwiftUI animation — the Canvas already redraws
  each tick; speed-dependent, acceptable). (5) EASTER EGG — tapping the "NETWORK"
  title zips a ✈️ across the header in an arc (`PlaneFlyBy`, replayed via `.id`).
  Milestone toast verified visually; the rest are standard SwiftUI transitions.
- **COLD-LAUNCH SPLASH — BUILT (designer request, "route-network reveal"
  chosen over a Star Wars-style logo fly-in).** `SplashView.swift`: ~2.6s on a
  brand-navy sky with a faint night grid — four dashed great-circle arcs draw
  themselves in the game's own colours (climb green / cruise blue / descent
  amber / competitor purple; the ArcShape reuses the in-game 12%-of-distance
  bulge proportion), destination endpoints pulse like the route-open ripple,
  then the logo badge springs in at the naming screen's badge position (soft
  crossfade handoff) with a "Build the sky." tagline — WORDING IS MINE, not
  designer-supplied; swap the string if wanted. Tap anywhere skips; Reduce
  Motion collapses it to a static network + calm logo fade. Shown once per
  process launch (ContentView `showSplash`, zIndex 10 over the load menu /
  naming screen). Verified via timed simulator frame captures.
- **HAPTICS + SUBTLE SFX — BUILT (native app; designer request, extends the
  delight layer).** `Feedback.swift` (UIKit/AVFoundation, VIEW layer only — the
  Sim layer stays framework-free for the headless harness, so every trigger is a
  SwiftUI action or an `.onChange` on observed sim state). Deliberately RESTRAINED
  per designer direction ("don't cartoon it up"): light haptics on the big
  moments, and exactly ONE sound — a short jet whoosh reserved for the flagship
  moment (acquiring an aircraft). Triggers: acquire aircraft (buy/lease/used) →
  success haptic + jet whoosh (`NetworkView.handleBought` + the three `FleetView`
  marketplace buttons); open route → medium impact (`openConfirmedRoute .success`);
  milestone celebration → success haptic + `Resources/Sounds/milestone.wav`
  congrats chime (designer-supplied, `MilestoneSound`, fired from the SAME
  `celebrations.first?.id` change as the badge toast, so chime + badge are synced);
  new decision/alert → warning haptic
  (`onChange decisionQueue.count` increasing); bankruptcy → error haptic; sell →
  light impact (Alerts sell + Fleet-detail sell). `JetSound` PREFERS a real bundled
  recording (`jet`/`jet_takeoff` .caf/.wav/.m4a/.mp3) over the synthesized fallback.
  **REAL RECORDINGS NOW SHIPPED (designer-supplied):** `Resources/Sounds/jet.wav`
  (Jet Overhead, 3.5s) is used on aircraft acquisition; the synthesized whoosh
  (band-passed noise swept 2200→400 Hz) is now the FALLBACK only. Files in
  `Resources/Sounds/` flatten into the app root (like the fonts), so
  `Bundle.main.url(forResource:"jet",withExtension:"wav")` finds them — confirmed
  in the built `.app`. TIMBRE/level are the designer's call on-device; swap the
  file to change the sound (no code change). Four clips now ship in
  `Resources/Sounds/`: `jet.wav` (acquire aircraft), `now_boarding.wav` (open
  route), `milestone.wav` (milestone), `new_crew.wav` (hire crew). Single-clip
  players are a shared `ClipSound(resource:volume:)`; `Feedback.crewHired()`
  (success haptic + `new_crew`) fires at all three hire sites (Crews tab, Network
  ADD CREW panel, CREW alert card's Hire option).
  - **AUDIO SESSION CATEGORY — was `.ambient`, now `.playback` + `.mixWithOthers`
    (real fix).** On-device testing FELT the haptics but heard NOTHING: `.ambient`
    is muted by the hardware ring/silent switch, and the test device was on silent.
    `.playback` makes the cues audible regardless of the ringer (a game the player
    opened should still make its sounds), while `.mixWithOthers` still lets their
    music keep playing. `GameAudio.prepareAmbientSessionOnce()` (shared by JetSound
    + GateAnnouncement) sets it. If a silent-switch-respecting option is ever
    wanted, that's the one line to flip back.
  - **"NOW BOARDING" GATE CALL (native app; designer spitball, shipped).** Opening
    a route plays a gate-style "now boarding" call. **REAL RECORDING NOW SHIPPED:**
    `Resources/Sounds/now_boarding.wav` (1.4s, designer-supplied) is played via
    `AVAudioPlayer` in `GateAnnouncement`. The on-device TTS path (in the player's
    own airline name — "Aster Air, now boarding.") is now the FALLBACK only, used
    if the recording is missing. Reserved for route-open only (a deliberate,
    infrequent action — a nod, not a nag), under the shared `.playback` session.
    Swap the file to change the call (no code change); the recording is generic
    (not airline-specific), which is the designer's choice.
- **Pinch-zoom on the mobile app**: still not built (this is a browser
  prototype), but the underlying mechanism is no longer blocked or even
  really "open" in the same sense — the camera system built for pan/zoom
  (see Map section) is the same math a mobile pinch-gesture handler would
  drive, just fed by touch events instead of drag+wheel. What's
  genuinely unbuilt: the touch gesture handling itself.
- **Label cluster detection doesn't re-evaluate on zoom.** A cluster
  fanned out with leader lines at the default zoom level (NYC, Bay Area,
  etc.) stays fanned out even after zooming in far enough that the
  underlying airports would naturally have enough room for normal,
  un-fanned labels — `computeAirportLabelPositions()` runs once at
  startup, not per-frame. Not broken, just static; a real fix means
  recomputing clusters against CURRENT on-screen distance each frame
  (or on zoom-change), which is more scope than this pass covered.
- **The map is not a true global projection.** WORLD_BOUNDS now spans
  Alaska-to-the-Americas-to-Asia-to-Oceania (every populated continent has
  airports), but it's still one fixed rectangular lon/lat box with a
  cosine-corrected equirectangular projection — that breaks down badly near
  the poles. **UPDATE: the native app DOES wrap horizontally now** (see the
  "Wrap-around map — DONE" note in the Native iOS Port section — tiled
  redraw, `wrapWidthUnits`, wrapped hit-testing), so panning east/west
  circles the globe; the antimeridian is no longer a hard edge. What's still
  NOT a true global projection: the pole distortion, and the ~30° mid-Pacific
  overlap from the 390°-content/360°-period mismatch (documented in that note,
  benign). The browser prototype still has neither wrap nor this.
- **BWI/FLL ground-stop data conflict** — two different source batches
  gave different numbers for the same two airports; kept the
  original/first-sourced values (see Economy section above for the exact
  numbers). Not resolved, just not silently overwritten either.
- **Regional-jet `crewsPerTail`**: defaulted to 6 (same as narrowbody),
  unverified — and its role changed this session. It's no longer consumed
  by any code at all (`resizeCrewPools()` was rewritten to not use it —
  see Fleet Lifecycle section); it's now purely a reference number the
  player might reason about themselves, or that a future UI might show
  as a suggestion. Still unverified either way.
- **Intra-family fleet-weight splits** for A320/737/A220 families, and ALL
  remaining regional-jet family totals: real but lower-confidence data,
  flagged in the Fleet section above. Revisit with dedicated sourcing if
  the designer wants higher precision here.
- **Bankruptcy / failure state — BUILT (native app).** Negative
  `playerBalance` now starts a 14-sim-day grace countdown (`insolventSinceTick`,
  `bankruptcyGraceTicks`, an Ops warning logged; actions are still blocked as
  before). `tickSolvency()` (in the tick loop) runs the countdown; when it
  expires, `forcedLiquidation()` sells owned-outright aircraft most-valuable-first
  until solvent, then hands back leased jets (no proceeds, but stops the bills),
  and if the fleet empties while still negative → `isBankrupt = true` (GAME OVER).
  `sellAircraft` was refactored to share a `liquidate(_,proceeds:)` teardown so a
  leased return is a $0-proceeds liquidation. `GameOverView` is a modal recap
  (days operated / routes flown / flights) with "Start a New Airline", which
  resets by `sim = Simulation()` + bumping `gameID`; ContentView's run loop is now
  `.task(id: gameID)` so the old sim's loop cancels (run() checks
  `Task.isCancelled`) and the new instance starts fresh (naming screen returns).
  Verified headlessly: a healthy 2-aircraft operator never false-bankrupts; a
  player who leases a $200M widebody with no revenue goes negative day 0 and
  bankrupts exactly at day 14 (grace) after the leased jet is returned with
  nothing left to sell. The browser prototype has no failure state.
- **Route-opening cost and starting capital are now REAL** — this item
  used to be open, resolved this session (see Fleet Lifecycle and Route
  Network sections). Real remaining gap in the same area: player-funded
  route marketing and the airport-incentive-offer mechanic (bottom-15
  airports, waived fees, real clawback penalty for abandoning early) were
  both explicitly scoped as later phases (C/D) and are still not built —
  only the foundational route-opening mechanic (A/B) shipped.
- **Routes profitability chart — RESOLVED (native app).** The designer's goal
  (an app view charting profitability over time, seeing exactly when a route
  became profitable) is built — see `RouteProfitChart` in the Native iOS Port
  section. The browser prototype still lacks it; this is native-app only.
- **Full 30-type fleet, 48 airports, the economic event system, the
  pan/zoom camera, the sell/buy/lease economy, the real player route
  network, AND the rebuilt crew-hiring/duty-rest system have never all
  run together in one real, sustained play session.** Each has been
  individually spot-checked and numerically verified, and SEVERAL of
  them (the `operatingCost` bug, three separate instances of the same
  decision-panel/dropdown/buy-panel flicker bug, the lease-proration bug
  that made leasing nearly dominant, the phantom-crew-family bug, the
  ownership-scoping gap letting background traffic generate real
  decisions, and the crew duty/rest reset bug) had real, user-facing
  issues that only surfaced through actual use or a direct question, not
  through the verification that shipped them. "Spot-checked" has a long,
  real, demonstrated catch rate at this point — not a theoretical safety
  net, a proven one. This is still the single most valuable next step
  before adding more scope, and has been true and repeated at nearly
  every major addition this session.
- **Why Sukhoi Superjet 100 was removed isn't documented anywhere.** The
  type and its crew family are fully gone from the code (confirmed clean
  — no orphaned references anywhere), but no record of the actual
  decision/reasoning exists in this file or the chat history available at
  time of this update. If that reasoning matters later, it may need to be
  re-asked rather than looked up.
- `README.md` is referenced in `TASKS.md`'s "Repo scaffolded" line but was
  never confirmed to actually exist in the repo — flagged once early in
  this project's history, never independently verified since. Check it.

## Release status (1.0 / build 26) — see `RELEASE_STATUS.md`

The live App Store submission state (build 26, screenshots, store metadata,
reviewer notes, the support/privacy site, the subscription products, and the
remaining ASC checklist) lives in **`RELEASE_STATUS.md`** at the repo root, not
here. A session picking up the launch should read that file — it's written to be
understood cold, with no conversation history. Delete it once 1.0 is live.

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
