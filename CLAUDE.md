# CLAUDE.md — Persistent Context for SkyOps

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
triangle to real Figma-sourced vector art, and a real (if partial) aircraft
ownership economy now exists — cycle-based lifespan, selling, and buying,
with a genuine spendable balance. If you're picking this up cold, don't
assume the smaller original scope — read this whole file, not just skim
it. If you're the one updating this file next, note that comments and
counts elsewhere in this codebase have gone stale between updates more
than once already (see the `TYPE_WEIGHT_TOTAL` stale-comment note in the
Fleet section for a concrete example) — spot-check numbers against the
actual code rather than trusting a prior description at face value,
including the numbers in THIS file.

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

## Decided — Fleet (rewritten this session, was 6 types / 4 families, now 30 / 13)

- **Fleet size**: 30 distinct playable aircraft types. Running history:
  32 (initial big expansion) -> 31 (Sukhoi Superjet 100 removed) -> 30
  (Bombardier CRJ700 removed — aging out of most real fleets, nearing
  retirement, per designer direction). `CRJ_FAMILY` stays real (CRJ900/1000
  remain). See the "stale comment" note near the end of this section for a
  real gotcha this kind of repeated change has already surfaced once. This
  is still a major expansion from the original locked 6 — the "locked"
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
    (777, 787) is its OWN separate family — no real-world commonality
    between manufacturers or airframe generations at that size.
  - ARJ21 is its own standalone family — no other type shares its rating.
    (Sukhoi Superjet 100 / `SSJ100_FAMILY` was in this category too, before
    removal — see stale-comment note below.)
  - **Net result: 13 crew families total** (`A320_FAMILY`, `B737_FAMILY`,
    `A220_FAMILY`, `B777`, `B787`, `B747`, `A380`, `A340`, `E170_FAMILY`,
    `E190_FAMILY`, `CRJ_FAMILY`, `ERJ_FAMILY`, `ARJ21_FAMILY`), covering 31
    aircraft types. `CREW_FAMILIES` is auto-derived from
    `AIRCRAFT_TYPES.map(t => t.family)` — adding or removing an aircraft
    type automatically updates this list, no separate maintenance needed.
    `FAMILY_LABELS` (crew status display) is NOT auto-derived — it's a
    separate hardcoded lookup that must be updated by hand every time a
    family is added OR removed, or the UI silently shows `undefined` (add)
    or carries a harmless-but-stale unused entry (remove). This bit twice
    this session on the add side; check it every time in both directions.
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

## Decided — Fleet Lifecycle & Ownership Economy (cycles, sell, buy)

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
  the correct and sufficient trigger. Traded away: the live-eroding
  dollar figure inside an OPEN AOG/CREW card no longer visibly ticks
  down in real time while the card sits unresolved (the underlying
  number still updates every tick, just not the display). Acceptable —
  a human resolves these quickly. **If a future session wants that
  live-tick-down back, it needs a throttled refresh (e.g., from the
  animation loop, gated to ~1x/second), NOT a raw per-tick call — that
  exact pattern is what caused this bug.**
- **Not yet playtested**: the sell/buy loop end-to-end, across a real
  session, including whether the 80% threshold and randomized starting
  cycle distribution actually produce a reasonable pace of sell offers
  (not too rare to matter, not so frequent it's spam) once real people
  are clicking through it rather than the numeric verification this was
  shipped with.

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
  Alaska-to-Hawaii-to-East-Coast, but it's still one fixed rectangular
  lon/lat box with a cosine-corrected equirectangular projection — that
  breaks down badly near the poles and doesn't wrap at the antimeridian.
  A genuine global map (which the designer has stated as the eventual
  direction — players opening routes worldwide) needs a real projection
  decision, not just wider bounds on the current one.
- **BWI/FLL ground-stop data conflict** — two different source batches
  gave different numbers for the same two airports; kept the
  original/first-sourced values (see Economy section above for the exact
  numbers). Not resolved, just not silently overwritten either.
- **Regional-jet `crewsPerTail`**: defaulted to 6 (same as narrowbody),
  unverified. Real research not done for this tier specifically.
- **Intra-family fleet-weight splits** for A320/737/A220 families, and ALL
  remaining regional-jet family totals: real but lower-confidence data,
  flagged in the Fleet section above. Revisit with dedicated sourcing if
  the designer wants higher precision here.
- **No starting capital and no route-opening cost.** A fresh session
  begins with `playerBalance = 0` — buying any aircraft requires
  accumulating flight revenue or selling one first, not a real "player
  starts with a real fleet + real capital" experience yet. Route-opening
  as a costed player action doesn't exist either (routes are still
  randomly assigned, same as always) — this is the exact gap
  `ROADMAP.md` Phase 5 already flagged, now sharper since the sell/buy
  half of it is real and the route-opening half still isn't.
- **Full 30-type fleet, 48 airports, the economic event system, the
  pan/zoom camera, AND the sell/buy economy have never all run together
  in one real, sustained play session.** Each has been individually spot-
  checked and numerically verified, and two of them (the `operatingCost`
  bug, the decision-panel flicker bug) had real ship-blocking issues that
  only surfaced through use, not through the verification that shipped
  them — meaning "spot-checked" has a real, demonstrated failure rate
  here, not just a theoretical one. This is the single most valuable
  next step before adding more scope, and has been true and repeated at
  every major addition this session — its repetition doesn't make it
  less urgent, if anything it's evidence this keeps getting deprioritized
  in favor of new features.
- **Why Sukhoi Superjet 100 was removed isn't documented anywhere.** The
  type and its crew family are fully gone from the code (confirmed clean
  — no orphaned references anywhere), but no record of the actual
  decision/reasoning exists in this file or the chat history available at
  time of this update. If that reasoning matters later, it may need to be
  re-asked rather than looked up.
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
