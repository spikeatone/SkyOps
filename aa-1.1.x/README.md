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
- **`HubChartMain.swift`** — verifies the per-hub payback ledger feeding the Hubs
  panel's payback chart: establish/club/labor/rent accrue exactly, monthly
  snapshots append + stay within `maxHubSnapshots`, `hubSpokeNet`/`hubFacilityCost`
  math, the cash invariant is UNTOUCHED (it only records already-tracked spend — the
  restored gap is exactly the un-persisted `devInjectCash`), a save/load round-trip
  preserves ledgers, a legacy no-ledger save is backfilled on restore, and
  decommission drops the ledger. (36/36 green when last run.)

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
