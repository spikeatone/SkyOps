# aa-1.1.x — headless sim harnesses

Standalone Swift test drivers that compile the **real** `Sim/*.swift` engine (no
SwiftUI) and assert behaviour + the sacred Finance cash invariant. Preserved from
the 1.1.x work so future sessions don't have to re-derive them. They are NOT part
of the app target — they live at the repo root so the file-system-synchronized
group never compiles them into the build.

## What's here
- **`PromoMain.swift`** — verifies the route-competition player actions (fare war /
  ad campaign / loyalty push): exact cost math, cost ladder, broke-guard, the cash
  invariant after every action + 90 sim-days, and a save/load round-trip of the
  promo state. (22/22 green when last run.)
- **`LaunchFixMain.swift`** — verifies the save-size hardening: `Route.history`
  caps at `maxHistory`, the running-total aggregates tie to `cumulativeNet` across
  ALL flights (incl. dropped), the cash invariant holds under heavy flying, a
  save/load round-trip keeps history capped, and a pre-1.1 save (nil totals + full
  history) recomputes its aggregates and caps on load. (18/18 green when last run.)
- **`LeisureMeasure.swift`** — a MEASUREMENT tool (not assertions): flies representative
  leisure routes vs mainland controls and reports load / opening cost / per-flight net /
  recoup flights, isolating the leisure fare + opening effect. Used to retune the leisure
  opening premium (×1.75 multiplier → flat $500k surcharge). Also prints the cash-invariant
  residual (0 = holds). Reach for it if leisure economics get tuned again.
- **`RegionParityProbe.swift`** — a MEASUREMENT tool (not assertions): start-region
  difficulty parity. Per region, asks the region-aware opportunity finder for top
  markets, keeps those a starter-affordable (<= $20M) best-gauged aircraft can fly,
  flies the top few and reports per-flight net + load; then flies a 165-seat A320 on
  each region's top route to show the mid-game up-gauge ceiling. FINDING (1.1.x): no
  early traps/cakewalks — every region's starter routes are profitable with a 50-seat
  jet; 6/7 regions up-gauge to narrowbodies at ~90% load; Central America/Caribbean is
  the lone low-ceiling outlier (demand-thin small markets — data-accurate, not a bug).
  LESSON: a growth-autopilot version was tried first and kept tripping on the known
  early-game regional-jet trap (high-variance noise) — the opportunity-landscape probe
  is the robust framing. Under-gauging (buying the tiniest aircraft) also gives false
  "all routes lose money" reads — gauge-match to demand.
- **`CurfewVerify.swift`** — verifies the night-curfew mechanic (7/7): LHR active
  ~420 min/sim-day, JFK (no curfew) never, a curfew route still completes flights
  (NO deadlock) but fewer than a non-curfew control, cash invariant intact. Touches
  the core flight state machine, so this is the important safety net.
- **`SeasonVerify.swift`** — verifies seasonality (28/28): #2 weather zone
  classification, seasonal factors peaking in the right months, curves averaging
  ~1.0 (annual calibration preserved), empirical MIA onsets peaking in hurricane
  season; #3 a leisure route earning markedly more in winter than summer while a
  non-leisure control stays flat. NOTE: capture per-flight revenue DURING the run
  (route.history caps at 60, so a year-end read only shows the final months).
- **`RegDelightVerify.swift`** — verifies the LOD realism/delight batch (43/43):
  #1 national registration prefixes (well-known carriers map to the right prefix,
  every roster carrier has one, the real spawn path yields national tails —
  Lufthansa `D…`, Qantas `VH…`, player `N…`) and #5 the expanded milestone ladder
  (each new milestone fires on its trigger — first jet/route/flight/international/
  widebody/St. Barths). NOTE the `celebrations` 3-slot display cap: a test that
  fires >3 milestones in ONE tick (e.g. injecting cash trips the whole net-worth
  ladder) drops the earliest from the QUEUE — set up incrementally / on the real
  $20M start so each first-milestone gets its own tick.
- **`CaribbeanVerify.swift`** — verifies the Caribbean carrier region (18/18): the
  6-carrier roster, the caribbean/centralAmerica code split, weighted draws never
  yielding mainland carriers, domestic Caribbean legs drawing Caribbean carriers,
  every type resolving, the realCodes tail-collision guard, the "Central America &
  The Caribbean" start spanning both regions, background traffic actually flying
  Caribbean carriers on Caribbean airports (real `setFleetSize` path), and
  Market-Intelligence inclusion + determinism.
- **`HubChartMain.swift`** — verifies the per-hub payback ledger feeding the Hubs
  panel's payback chart: establish/club/labor/rent accrue exactly, monthly
  snapshots append + stay within `maxHubSnapshots`, `hubSpokeNet`/`hubFacilityCost`
  math, the cash invariant is UNTOUCHED (it only records already-tracked spend — the
  restored gap is exactly the un-persisted `devInjectCash`), a save/load round-trip
  preserves ledgers, a legacy no-ledger save is backfilled on restore, and
  decommission drops the ledger. (36/36 green when last run.)
- **`SaveCompatVerify.swift`** — the guard for the "testers lose saves on a new
  build" bug (12/12). Builds a real modern GameSnapshot, strips keys that later
  builds added (top-level + nested route/aircraft elements) to simulate an OLDER
  save, and asserts the current build STILL decodes it with defaults filled. Also:
  an empty `{}` decodes to defaults, and the normal round-trip is intact. Run it
  against pre-fix Persistence.swift and it REPRODUCES the bug (older save → nil);
  against the tolerant `init(from:)` decoders it's green. **Re-run after ANY change
  to the save structs** — it's the regression net that makes add-a-field-→-lose-
  saves impossible.
- **`RoundTripVerify.swift`** — end-to-end save path (13/13): a REAL Simulation
  (2 aircraft, 2 routes, a loan, 20 sim-days flown) → `snapshot()` → JSON encode →
  JSON decode → `restore()` into a fresh sim, asserting name/tail/balance/tick/
  fleet/routes/reputation/finance-snapshots/loans all restore exactly and the
  restored sim keeps running. The restored residual is `-(devInjectCash)` exactly
  (the injection isn't persisted — that's the proof of an exact restore, per the
  Acquisition-harness lesson), NOT 0.

## How to run
The entry file must be named `main.swift` (top-level `MainActor.assumeIsolated {…}`).
From the repo root:

```sh
cd AirlineArchitect/AirlineArchitect
cp ../../aa-1.1.x/PromoMain.swift /tmp/main.swift      # or LaunchFixMain.swift
swiftc -O -DDEBUG \
  $(ls Sim/*.swift | grep -vE 'AircraftIcon.swift|SVGPath.swift') \
  Persistence.swift /tmp/main.swift -o /tmp/harness
/tmp/harness
```

Notes:
- Exclude the two SwiftUI files (`AircraftIcon.swift`, `SVGPath.swift`) — the sim
  layer is otherwise framework-free by design.
- `-DDEBUG` is required: `devInjectCash` and `cashInvariantResidual()` are
  `#if DEBUG` test hooks on `Simulation`.
- `cashInvariantResidual()` must always return 0. Assert it after any money move.
- To exercise the history cap, `LaunchFixMain` flies a route for up to ~600k ticks
  (crew rest gaps mean ~1 flight per few thousand ticks); trim if it runs long.

## When to reach for these
Any change that touches the economy, persistence, or a cash flow. Copy the closest
harness, add asserts, re-run. New cash flows must also join the invariant in
`Simulation`, `PeriodFigures`, `FinanceSnapshot`, and `FinanceSave` — then verify
here. (See CLAUDE.md "cash invariant is sacred".)
