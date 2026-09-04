# Multi-city routing (aircraft rotations) — scoping

_Scoped 4 Sep 2026. A DESIGN doc, not built. Prompted by the designer: "not every plane
should fly point-to-point and loop. When you open a route, tap multiple cities in the order
you want to fly them; each leg checked against the assigned aircraft's range — which means you
pick the aircraft first, then route it."_

## The two design questions, answered

### Does a route just reverse the next day? Is that realistic?
Today, yes literally: `Aircraft.advance` does `swap(&origin, &dest)` at leg completion
(`Aircraft.swift:364`), so every owned aircraft flies A→B→A→B forever. It's not *un*realistic
for one pair (Southwest really does shuttle A↔B), but it's the ONLY thing every aircraft does,
so a 20-plane fleet is 20 disconnected shuttles with no network shape.

### How real airlines route aircraft (the useful version)
- Aircraft fly **rotations**, not routes: one tail flies a CHAIN of legs (SEA→LAX→SEA→SFO→SEA),
  and the chain is a **loop that returns to base over 1–3 days** — not necessarily same-day.
- Hub-centric but not hub-exclusive: most legs touch a hub, classic pattern is hub-out-and-back
  with a "tag" (SEA→BOI→SEA), plus deliberate **overnights (RON)** so a plane is positioned for
  an early departure from an outstation next morning.
- The plane always eventually cycles home to a maintenance base — which is exactly the hook the
  new MX program wants (a plane has to GET BACK for a heavy check).

## RECOMMENDATION — build "rotations" (ordered loops), not scheduling

A route becomes an **ordered sequence of airports that forms a closed loop**. You tap cities in
order; the last leg implicitly returns to the first. The plane flies the sequence, then repeats.

Why this is the right middle ground:
- **Realistic**: rotations are how real fleets actually fly; overnighting emerges (see below).
- **Not chore-like**: the loop AUTO-REPEATS — no daily timetable, no "next day" planning. The
  sim is time-decoupled at up to 100×; asking the player to build a schedule would be misery.
- **The reverse is just a special case**: a 2-stop rotation [A, B] IS A→B→A. So the existing
  behaviour is the N=2 degenerate case — nothing regresses for a player who only wants a shuttle.
- **Makes existing systems better**: the hub network effect finally has teeth (a real hub→spoke
  →hub→other-spoke shape), and MX gives the plane a reason to cycle home.
- **Overnighting is FREE and unmanaged**: if a leg lands while the day-clock is inside a curfew
  window (curfews already exist), it departs next morning. The player never PLANS the overnight;
  it emerges from the clock. (Optional later polish — see Phase 3.)

Explicitly NOT doing: time-of-day scheduling, per-leg departure times, a daily planner. That's
the line between "strategic depth" and "spreadsheet chore," and we stay on the depth side.

### Aircraft-first flow (as the designer asked)
Open Route flow becomes: **pick the aircraft first → then tap cities in order → confirm.** This
is a real inversion of today's flow (today you tap origin→dest, and the spare is chosen for you
as `idleSpares.first` — `NetworkView.swift:760`). Picking the aircraft first is REQUIRED because
each leg is range-checked against THAT aircraft (`routeBlock(for: ac, from:, to:)` already
exists, `Simulation.swift:2726`), and because the confirm panel's projected load / runway checks
need to read the specific aircraft.

## Why this is far less invasive than it looks

The economics are ALREADY per-leg-computable. `Demand.dailyOneWay(a,b)`, `rollRevenue`,
`settleLeg`, and `hubDemandMultiplier(originCode:destCode:)` all take TWO airports and compute
for that pair (`Simulation.swift:97-101`). They're *called* per-route today, but nothing in the
math assumes a route is only 2 airports. A rotation of N legs is just N independent leg-economics
calls the model already supports. **The sim math barely changes; the route DATA SHAPE and the UI
change.**

## What actually changes

### 1. Route data model (`Route.swift`) — the core change
- Add `var stops: [String]` (ordered airport codes, length ≥ 2). The loop legs are
  `stops[0]→stops[1], …, stops[n-1]→stops[0]`.
- KEEP `originCode`/`destCode` as computed shims (`stops.first!` / `stops.last!` or the current
  leg's endpoints) so the ~30 call sites that read them (competition, incentives, Ops logs, fare
  war, chart labels) don't all have to change at once. Audit which need the CURRENT leg vs the
  whole rotation — most only want a display label, for which "ORD→BOI→SEA" is fine.
- `FlightRecord` already has `tail`; it should also carry the leg (`fromCode`/`toCode`) so the
  P&L log/chart can show which leg earned what. Per-leg records, one per completed leg.
- P&L stays route-level (cumulativeNet vs openingCost) — a rotation's profitability is the sum
  of its legs, which is what the player judges. No per-leg P&L accounting needed.

### 2. Aircraft leg progression (`Aircraft.swift`) — replace the swap
- The plane needs to know WHERE IT IS in the rotation. Add `var legIndex: Int` (persisted).
- Replace `swap(&origin, &dest)` (line 364) with: advance `legIndex` (mod stops.count), set
  `origin = stops[legIndex]`, `dest = stops[(legIndex+1) % count]`. The N=2 case reproduces the
  swap exactly.
- The aircraft currently stores `origin`/`dest` directly; it will still do so (derived from the
  route's `stops` + its own `legIndex`), so `position()`/rendering are unchanged.
- ⚠️ PERSISTENCE: `legIndex` is a new saved field → one `decodeSafe` line in `Persistence.swift`
  (default 0), and `Route.stops` needs saving (`RouteSave` gains `stops: [String]?`, legacy saves
  with only origin/dest → `[originCode, destCode]`). Tolerant-decode rule (CLAUDE.md) applies.

### 3. Range check per leg — ALREADY EXISTS, just loop it
`routeBlock(for: ac, from:, to:)` (`Simulation.swift:2726`) checks range AND runway for one pair.
The multi-city confirm runs it over EVERY leg in the sequence (including the closing leg back to
stops[0]) and blocks the route if ANY leg fails, naming the offending leg. This is the designer's
"each leg checked against the assigned aircraft's range" — the primitive is done, it just needs to
be called in a loop instead of once.

### 4. UI — the biggest lift (all view-layer)
- **Aircraft-first Open Route**: new first step "pick the aircraft," then a multi-tap city picker.
- **`routeMode`** (currently `.off / .pickOrigin / .pickDest(o) / .confirm(o,d)`,
  `NetworkView.swift`) becomes a growing ordered list: `.picking(aircraftId, [codes])`. Each map
  tap appends a stop (tap an already-selected stop to remove/reorder, or a "done" control to
  close the loop). The marching-dashed-arc preview (`drawSuggestion`) extends to draw the whole
  chain.
- **Confirm panel**: list every leg with its distance + range/runway check (green/red per leg),
  total rotation distance, projected load per leg (demand vs the chosen aircraft's seats — the
  interesting new decision: a big jet is wasted on a thin tag leg), and the opening cost.
- **Opening cost**: today it's base + both endpoints' gate fees + slot premium. For a rotation it
  should be base + gate fees at EACH stop + slot consumption at each stop. Slots are consumed per
  airport in the rotation (each stop needs a slot). This is a real balance knob — a 5-stop
  rotation costs more to open and eats 5 slots.
- **Reassignment / park / MX-coverage**: all of these already move "an aircraft off/onto a route."
  They keep working, but the coverage/like-size check (MX) must range-check the substitute against
  EVERY leg of the rotation, not one pair. `mxCanCover` and `spareCandidates(for:)` extend the same
  way as the confirm (loop the leg check).

### 5. Everything that reads a route for DISPLAY
Ops logs, competition box, incentive box, the Routes panel, the P&L chart, milestone city-pair
strings — all currently print "ORIG ↔ DEST". They need a rotation-aware label ("ORD→BOI→SEA→ORD"
or "ORD +2 stops"). Mostly a formatting helper (`Route.label`) applied everywhere the ↔ string is
built today (grep `↔\u{FE0E}` — ~8 sites).

## DESIGNER DECISIONS (4 Sep 2026 — locked)
1. **Each leg earns its own point-to-point demand.** No connecting-passenger / itinerary model.
2. **No hub double-count** — a rotation touching a hub at multiple stops counts ONCE per hub.
3. **Max 5 stops** per rotation.
4. **Cost/slot scales per stop** (base + gate fee at each stop + a slot at each stop) — balance-pass it.
5. **Overnight/RON**: out of Phase 1; emerge from curfews in Phase 3 (no player planning).

## Balance / design questions to settle BEFORE building
1. **Demand on a multi-stop leg**: today demand is O&D between the two leg endpoints. In a rotation
   ORD→BOI→SEA, the BOI→SEA leg's demand is just BOI↔SEA O&D — we do NOT model connecting
   passengers routing ORD→SEA via BOI (that's a whole itinerary/network-flow model, out of scope).
   Each leg earns its own point-to-point demand. This is a simplification worth stating to the
   player implicitly (the projected-load-per-leg display makes it obvious).
2. **Hub bonus interaction**: `hubDemandMultiplier` counts routes touching a hub. A rotation
   touching a hub at multiple stops shouldn't double-count — decide whether a rotation counts once
   per hub it touches (probably yes) or per leg (no).
3. **Max stops**: cap it (e.g. 5–6) so the UI and the opening-cost/slot math stay sane, and so a
   player can't build one absurd 30-stop mega-loop.
4. **Cost/slot model** for N stops (above) — needs a balance pass (the harness + a multi-seed
   check, per the standing rule) so a rotation isn't strictly better or worse than N separate
   2-stop routes.
5. **Overnight/RON**: Phase 1 can ignore it (legs fly back-to-back regardless of clock). Phase 3
   could gate a departure on the origin's curfew window so overnighting emerges — nice realism,
   not required for the core feature.

## Phasing (each shippable, verified before the next)
- **Phase 1 — data + sim: BUILT (branch `multi-city-routing`, 4 Sep 2026).** `Route.stops: [String]`
  (2…5, defaults to `[originCode, destCode]` so every existing route is a 2-stop rotation with zero
  behaviour change) + a stops-aware `Route` init + `Route.label`/`uniqueStops`. `Aircraft.legIndex`
  walks the loop; the old `swap(&origin,&dest)` is now driven by a `nextLeg` closure (default = the
  swap, so background traffic + the N=2 case are unchanged). New `Simulation` API:
  `openRotation(stops:using:)`, `rotationBlock(for:stops:)` (range/runway on EVERY leg incl. the
  closing one), `rotationOpeningCost(_:)` (base + gate fee + slot per DISTINCT stop + leisure
  surcharge — hub-visited-twice counts once), `rotationNextLeg` (the closure), `rotationLegs`.
  Persistence: `RouteSave.stops` + `AircraftSave.legIndex`, both tolerant-decode (nil → legacy
  default), wired through snapshot/restore. **`openRoute`/`reassign`/`openRouteCore` and the whole
  UI are UNTOUCHED** — the 2-airport paths still produce a [origin,dest] rotation, so nothing in
  Phase 2's list has to change before Phase 1 ships.
  - **Verified: `aa-1.1.x/RotationVerify.swift` 25/25** (loop flies in order, 2-stop == the classic
    reverse-shuttle, openRoute still yields a 2-stop rotation, each leg settles its own economics +
    cash invariant, range blocks the offending leg, stop-count bounds + adjacent-dup trim,
    distinct-stop cost, save/load of stops+legIndex resumes on the right leg + stays reconciled).
    Both critical guards BITE-TESTED (sabotaging `rotationNextLeg`→swap fails the loop-order check;
    sabotaging `rotationBlock`→nil fails the range check). No regression: RoundTripVerify 13/13,
    MXCoverageVerify 81/81, soak green, full Debug app build SUCCEEDED (view layer compiles against
    the model change — the new `advance` param defaults to nil, `Route.stops` defaults in init).
- **Phase 2 — UI: BUILT (branch `multi-city-routing`, 4 Sep 2026).** Aircraft-first flow:
  `RouteMode` gained `.pickAircraft` / `.rotate(UUID,[String])` / `.confirmRotation(UUID,[String])`
  (the old `.pickOrigin`/`.pickDest`/`.confirm` cases stay — the Ops route-SUGGESTION path still
  uses them, since a suggestion is inherently a 2-airport pair). "Open Route" → `startRouteFlow()`:
  goes to `.pickAircraft` (a new `RouteAircraftPicker` listing idle spares with tail/type/seats/
  range) unless there's exactly one spare (skip straight to `.rotate`) or a Fleet ASSIGN target
  (`pendingAssignment` → `.rotate` for THAT aircraft). In `.rotate`, each map tap appends a stop
  (dupe-adjacent ignored, capped at `Route.maxStops`); a `rotateControlBar` shows the live loop +
  Done (≥2 stops) / Undo stop / Abandon. `.confirmRotation` shows `RotationConfirmPanel`: every leg
  with distance + a range/runway/projected-load read, total loop nm, opening cost, Open/Edit/Abandon
  (Open disabled if any leg is un-flyable or unaffordable). `openConfirmedRotation` calls the sim's
  `openRotation(…, replacingCurrentRoute: true)` so a Fleet-assigned aircraft trades its old route.
  Map preview: `sim.rotationPreview` (transient, view-synced via `.onChange(routeMode)`) drives
  `MapView.drawRotationPreview` — marching dashed arcs between consecutive stops PLUS a fainter
  closing leg back to the base, with a double ring on the first stop. `detachFromRoute` now frees a
  slot at EVERY distinct stop (was just origin/dest) + uses `route.label` — correct for any
  multi-stop route being torn down (sell/park too). iPad: the picker + confirm dock in the rail
  (`isRouteConfirm` covers them); the `.rotate` tap-hint floats over the map.
  - **Verified**: full Debug app build SUCCEEDED (twice — with and after stripping the throwaway
    `-devScenario rotate`). `RotationVerify` **34/34** (added tests 9–10 for the new
    `replacingCurrentRoute` path: reassign archives the old route + frees its slots + resets
    legIndex; a FAILED replacing-open leaves the existing route intact — validation-before-detach).
    No regression: RoundTrip 13/13, soak green. **Live-drive PARTIAL**: on the iPhone 17 sim the
    tab nav + "Open Route" button + the aircraft-first "WHICH AIRCRAFT?" picker were confirmed
    rendering with the correct spare data (N1ZQ A320 165/3300, N2ZQ A321 200/3200, N3ZQ CRJ900
    82/1550) — the brand-new entry step. The pick→tap-sequence→confirm steps were NOT driven
    end-to-end because the Simulator's input channel wedged this session (the documented glitch:
    tab/control-bar taps landed, but the picker's ScrollView button cards stopped receiving taps;
    NO bug observed — a fresh CoreSimulator reboot didn't clear it). ⚠️ NEXT SESSION: drive the
    remaining picker→sequence→confirm→open flow live before merging (the logic is harness-covered,
    but the gesture composition isn't — exactly what the standing rule says needs eyes). Also
    still TODO for Phase 2 completeness: rotation-aware labels are done in the confirm panel + Ops
    "Route opened" log + `detachFromRoute`, but audit the OTHER `↔`-string display sites (RoutesPanel
    detail, competition/incentive boxes, milestone city-pair strings) so a 3-stop route reads as a
    loop there too, not just "ORIG ↔ DEST".
- **Phase 3 — polish (optional)**: emergent overnighting via curfews, reorder-stops UX, connecting
  demand only if it ever proves worth the complexity (probably never — flag it as deliberately
  out).

## Effort estimate
- Phase 1 (sim + persistence + harness): ~1 focused session. The math already being per-leg is
  what keeps this small; the risk is the ~30 `originCode`/`destCode` call sites (mitigated by
  keeping them as computed shims).
- Phase 2 (UI): ~1–2 sessions. This is the real work — the multi-tap picker, per-leg confirm, and
  making every route-display surface rotation-aware, then driving it.
- Phase 3: opportunistic.

## The one-line pitch to keep the scope honest
A route becomes an ordered loop of cities flown by one aircraft you pick first; every leg is
range-checked against it; the loop auto-repeats so it's never a chore; overnighting emerges from
the clock rather than being planned. The reverse-shuttle we have today is just the 2-stop case.
