# CLAUDE.md — Persistent Context for SkyOps

Read this before doing anything else. It exists so a new session (different
day, different context window, possibly a different agent) doesn't have to
re-derive decisions that were already made and validated. If you're about to
suggest something that contradicts a "Decided" item below, stop and check
whether there's a reason logged here before overriding it.

## What SkyOps actually is

NOT a combat RTS. It's an airline operations/logistics tycoon sim — closer to
Airline Tycoon / Transport Fever than Command & Conquer. Player automates the
boring parts (aircraft fly assigned routes automatically, PAX loads simulated,
revenue collected on arrival) and makes strategic decisions: open/close routes,
hire crew, decide maintenance response, manage fleet composition.

Core tension: **the sim never pauses for disruptions.** AOG and crew-shortage
events surface as decisions the player must resolve, but every other aircraft
keeps flying while they think. This is deliberate and load-bearing — do not
add a global pause button back in. (A dev/QA-only pause is fine; a player-facing
one contradicts the design thesis.)

## Decided (don't re-litigate without a real reason)

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
- **Crew are type-locked and pooled per family, not globally shared.**
  Families = type-rating groups: A320_FAMILY (A321neo), B737_FAMILY
  (737-900/MAX8/MAX9 — these share a real type rating), B777, B787. Pool
  size = crews-per-tail ratio × ACTUAL current fleet count of that family
  (not a nominal split — composition varies since spawn is weighted-random).
  Ratios: 6 crews/tail short-haul narrowbody, 11 crews/tail long-haul
  widebody (both 777-300 and 787 sit in this tier — neither is a true
  ultra-long-haul airframe as specified, so the 15-17 ultra tier is unused
  for now). Reserve crew pool is ALSO per-family (2 each, placeholder), for
  the same reason.
- **Consequence of the above**: baseline crew shortage should be RARE under
  normal ops (the ratio already accounts for duty/rest cycling). Shortage
  tension is meant to emerge from cascading disruptions depleting a specific
  family's pool faster than normal cycling replenishes it — not from
  everyday scarcity. If playtesting shows this feels wrong, the lever is
  `crewsPerTail`, not the pool architecture.
- **Aircraft types** (fleet mix ratios are real, given by the designer):
  A321neo ×7, 737-900 ×14, MAX8 ×12, MAX9 ×12, 777-300 ×6, 787 ×9 (=60,
  used as WEIGHTS for a proportional random spawn, not a hard cap — works
  at any fleet size). Hold-cost and revenue figures are real-world-referenced
  (SimpleFlying/AirInsight, 2025-26 sourcing) — see prototype-reference
  comments for the specific numbers and sourcing per type.
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
- **Landing fee model**: real signatory rate ($/1,000 lbs of aircraft max
  landing weight) at the destination airport, not a flat per-airport number.
  `AIRCRAFT_TYPES` carries `mlwLbs` per type (public type-cert data,
  approximate — see prototype-reference comments); fee = airport rate ×
  (mlwLbs / 1000). This is why a 777-300 and an A321neo landing at the same
  airport now correctly pay different amounts — flat fees couldn't express
  that.
- **Gate fee model**: real per-turn gate fee, tiered by `bodyType`
  (`narrowbody` / `widebody`) — a single explicit field on each aircraft
  type, also reused for the on-scope rendering scale (previously a separate,
  undocumented `seats >= 250` check existed for rendering only; now one
  definition drives both, so they can't silently drift apart). Where a
  source airport listed no widebody rate ("N/A"), the narrowbody rate is
  used as a floor — a widebody turn is never assumed cheaper than a
  narrowbody one at the same field.
- **Airport network**: expanded from the original 7 placeholder airports to
  the real top-25 U.S. airports by landing/gate fee (designer-sourced,
  definitive list — see prototype-reference for the exact fee figures per
  airport). Ground-stop onset rate is now per-airport too (real average
  monthly ground-stop count, designer-sourced), replacing one flat rate that
  was applied uniformly to every airport (~25.9 events/month regardless of
  airport — the real per-airport range is 0.1 to 14.2/month, so this was a
  real reduction in overall frequency, not just added variance). Ground-stop
  *duration* per event is still generic (90-330 ticks) — no source data
  exists yet for per-airport duration, only frequency.
- **Airport position source**: airport x/y are no longer hand-placed. Each
  airport carries real lat/lon (public reference coordinates); a
  lightweight equirectangular projection with a longitude cosine correction
  at the map's center latitude (`projectAirports()` / shared `projectPoint()`)
  converts these to canvas coordinates once at startup, fixed to
  continental-US bounds (not just this airport set's bounding box, so
  airports added later still project correctly without shifting everyone
  else). This is NOT a true Albers/conic projection — it's a defensible
  approximation at this latitude range and scale, not survey-grade. Real
  geography means some airports land genuinely close together on screen
  (JFK/EWR/LGA in the NYC area, MIA/FLL in South Florida) —
  `computeAirportLabelPositions()` fans their text labels out with leader
  lines so they stay legible; the dots themselves stay at true projected
  positions. This declutter fix stays even with the real basemap below —
  it's about screen-space label crowding, not missing geographic context.
- **Real basemap** (reversal of an earlier call): the map renders an actual
  continental-U.S. outline and state borders under the airports, not just
  accurately-projected points on the bare scope grid. Source data is real —
  Natural Earth via the `us-atlas` npm package, topology-aware simplified
  (won't tear adjacent state borders apart, unlike naive point decimation),
  Alaska/Hawaii/territories filtered out to match the game's fixed
  continental-only projection bounds. Embedded inline as static coordinate
  arrays (`US_NATION_RINGS` / `US_STATE_RINGS`), projected once at startup
  via the same shared `projectPoint()` airports use — outline, state
  borders, and airports are guaranteed to share one coordinate space, not
  three approximations that could drift apart. State borders render
  fainter than the national outline by design — background context, not a
  focal element. This was originally deferred (see prior "Open" entry) to
  keep the prototype simple; revisited and built once it was clear the
  primary player-facing UI needed real geographic legibility, not just
  correct relative positions. Rendered fresh every frame — cheap at ~1,800
  total points now, but a candidate to pre-render to an offscreen canvas
  and blit if more visual layers stack on top later.

## Open / not yet decided

- Xcode project shell doesn't exist yet — needs creating in Xcode itself on
  a Mac (can't be done from a Linux sandbox). See ROADMAP Phase 0.
- SwiftData vs Core Data for persistence — leaning SwiftData (iOS 17+) for
  developer-ergonomics reasons, not finalized.
- Figma → SwiftUI pipeline: designer has real mockups in Figma; pull via
  Figma MCP `get_design_context` against actual file/node URLs, don't
  guess at layouts from descriptions.
- Route competition / competitor airlines: designed to be deferred until
  the core loop (this doc's "Decided" section) is solid in Swift.
- Hub connectivity, reputation, passenger demand curves: named in the
  original design brief, not yet modeled in the prototype or planned in
  detail — bigger systems, deliberately last.
- **Pinch-zoom on the map**: the mobile game is intended to support it.
  Would still help with NYC/South Florida label crowding beyond what the
  leader-line declutter fix does (zoom in, labels separate on their own),
  but is no longer blocked on a map-style decision — the real basemap is
  now built (see "Decided" above). Not built in the browser prototype
  (viewport transform + touch/wheel gesture handling is real scope,
  arguably Phase 4 UI work rather than core-loop validation — see
  ROADMAP.md's Phase 0-3 vs Phase 4 boundary).

## Working agreement for future sessions

1. Read this file. Read `TASKS.md` for what's actually in flight.
2. If you make a decision that should bind future sessions, ADD it to the
   "Decided" list above, in the same terse style, with the real-world
   reasoning if there is one. Don't just fix code — update this file in the
   same commit.
3. If you find a "Decided" item that's wrong, don't silently override it —
   flag it explicitly, explain why, and update this file to reflect the
   correction with a short note on what changed and why.
4. The prototype-reference numbers (tick durations, AOG rates, crew ratios,
   revenue ranges) came from real back-and-forth tuning, not arbitrary
   placeholders (aircraft types/costs are the one exception — genuinely
   sourced from public 2025-26 data, see comments in that file). Port them
   faithfully when writing the Swift equivalent; don't casually re-round
   numbers "for cleanliness."
