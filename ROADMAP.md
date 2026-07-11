# SkyOps Roadmap

Phases are sequential but not rigidly time-boxed — each has an exit condition,
not a deadline. Don't start a phase until the previous one's exit condition
is genuinely met; that's how the JS prototype avoided building the wrong
thing (see: the takeoff-jolt bug, the landing-teleport bug, the "no crew
assigned" tooltip bug — all caught by validating each layer before building
the next one on top of it).

## Phase 0 — Native project foundation
**Exit condition:** an empty SwiftUI app runs on a simulator, in a real Xcode
project, under version control.

- [ ] Create the Xcode project shell (Xcode, on a Mac — can't be scripted
      from outside Xcode)
- [ ] Decide SwiftData vs Core Data (see CLAUDE.md "Open" — leaning SwiftData)
- [ ] Confirm minimum iOS version target
- [ ] Push this scaffold (README/CLAUDE.md/ROADMAP.md/TASKS.md/
      prototype-reference) into the real Xcode project repo
- [ ] Get the swiftui-pro / swift-concurrency-pro / swiftdata-pro skills
      into Claude Code's actual skill path on the dev machine (not just the
      chat sandbox they were reviewed in)

## Phase 1 — Port the validated tick engine
**Exit condition:** one aircraft flies one route in SwiftUI, on the same
state machine and timing as the JS prototype — takeoff/landing should NOT
visually jolt (that was already debugged once; don't reintroduce it by
re-deriving timings from scratch instead of porting them).

- [ ] Swift Concurrency-based tick loop (this is exactly why that skill
      was pulled in — an async tick source decoupled from render frame rate)
- [ ] Port state machine + tick durations from prototype-reference verbatim
- [ ] Port position interpolation (bezier arc between airports)
- [ ] Port the eased takeoff/landing/rejoin curves — these fixed real
      visual bugs, not stylistic choices

## Phase 2 — Multi-aircraft + fleet types
**Exit condition:** fleet slider equivalent works at 100+ aircraft without
frame drops; aircraft types are visually distinguishable across all 4 real
icon tiers (regional jet / narrowbody / 2-engine widebody / 4-engine
widebody — grew from the original 2-tier widebody/narrowbody distinction
as the fleet expanded, see CLAUDE.md Fleet + Icons sections).

- [ ] Scale to full fleet size, profile performance (the JS prototype's
      FPS/tick-cost overlay is worth porting as a dev tool, not shipping it)
- [ ] Port AIRCRAFT_TYPES config — grew significantly past "real
      hold-cost/revenue figures": now 31 real named variants across 13
      real crew-type-rating families (not 1:1 with the type list — see
      CLAUDE.md's Fleet section for the type-rating groupings, especially
      the E-Jets split that isn't obvious from the marketing name), plus a
      real load-factor x fare-per-seat revenue formula, real per-flight
      operating cost, and a working randomized economic-event system
      (oil price spikes, recessions, etc.) that modulates cost/fare/load
      together. This is a meaningfully bigger port than the phase's
      original framing implies — budget accordingly.

## Phase 3 — Crew + AOG + weather systems
**Exit condition:** per-family crew pools, AOG clustering, and weather holds
all behave identically to the validated prototype — including the parts
that were bugs and got fixed (crew backfill for staggered spawns, the
holding-pattern loiter loop instead of a frozen freeze-frame, the rejoin
easing between holding pattern and final approach).

- [ ] Port crew pool system — GREW substantially past "real crews-per-tail
      ratios" since this phase was first scoped. Crew provisioning is no
      longer automatic/ratio-based at all: buying/leasing an aircraft
      bundles exactly 1 crew, growing the pool further is a real
      player-driven action (the ADD CREW panel, real hire cost). Real
      `crewsPerTail` ratios still exist as data but are no longer
      consumed by any pool-sizing code — they're a reference figure only.
      Also port the corrected duty/rest timing faithfully: crew duty time
      accumulates ACROSS consecutive flight assignments (a real Flight
      Duty Period, not a per-flight allowance that resets), only clearing
      after a completed rest period — this was a real bug in an earlier
      version of the browser prototype, already fixed there, don't
      re-introduce the broken per-assignment-reset version when porting.
      `MAX_DUTY_TICKS`/`REST_TICKS` (600/600, i.e. 10hr/10hr) are real
      FAA 14 CFR Part 117-sourced figures, port the actual numbers.
- [ ] Port AOG onset + clustering
- [ ] Port weather ground-stop system + holding-pattern visual
- [ ] Port the player-decision system (AOG/crew cards, sim keeps running)

## Phase 4 — Figma-driven UI layer
**Exit condition:** the actual game screens match the designer's real Figma
mockups, pulled via MCP — not reinterpreted from memory or screenshots.

- [ ] Pull real Figma file/node context via `Figma:get_design_context`
- [ ] Build SwiftUI views against that context
- [ ] Reconcile prototype's dev-tool aesthetic (dark ops/ATC-scope look) vs
      the designer's actual intended player-facing visual direction — these
      may differ; the prototype was never meant to be final art direction
- [ ] Map view needs a real interaction-model decision for native: the
      browser prototype uses drag-to-pan + scroll-to-zoom as the
      desktop-appropriate stand-in for pinch-zoom (see CLAUDE.md Map
      section) — native should get real multi-touch pinch-zoom + drag,
      not a straight port of the desktop input handling. The underlying
      camera math (pan offset + zoom multiplier, one transform wrapping
      all world content) should port directly; only the gesture-input
      layer changes.

## Phase 5 — Economy layer
**Exit condition:** route-opening, passenger demand, and reputation feed
back into the fleet/crew/disruption systems from Phases 1-3.

- [ ] Passenger demand + load factor
- [ ] Reputation feedback loop
- [x] Aircraft purchase (revenue-gated) — REAL NOW in the browser
      prototype, not just design intent. Selling and buying both work:
      real per-type purchase price, real cycle-based lifespan triggering
      a sell decision, real linear depreciation, a real spendable balance
      (`playerBalance`) that accumulates flight revenue and sell
      proceeds and can actually be spent. See CLAUDE.md's "Fleet
      Lifecycle & Ownership Economy" section for the full mechanic,
      sourcing, and the real bugs caught building it.
- [x] Leasing, as a real alternative to buying — NOT in the original
      Phase 5 scope, added this session. 15% of purchase price upfront,
      real sourced monthly rate (industry lease-rate-factor data), billed
      as a genuine fixed monthly obligation regardless of aircraft
      utilization (a real bug in the first version charged lease cost
      per-flight instead, which made leasing nearly always dominant —
      see CLAUDE.md for the full story). Port the FIXED-OBLIGATION
      billing model, not a per-flight-prorated one.
- [x] Route-opening UI + cost — REAL NOW, was the one piece of the
      original purchase-economy vision missing as of the last update to
      this file. Real cost built from data already in the game (base fee
      + both endpoints' real gate fees), abstract airport slot scarcity
      (explicitly NOT real competitor-airline modeling — see Deferred
      list below, this didn't reopen that), click-to-select-on-map UI.
      Purchased aircraft now fly ONLY the routes the player has opened,
      not random destinations — this is the single biggest behavioral
      change to the simulation this phase produced, port it faithfully.
- [x] Starting capital — DECIDED and built: $20M, calibrated (not
      arbitrary) to cover the cheapest aircraft plus a typical
      route-opening cost with buffer. A fresh session now starts with
      real capital, zero aircraft, zero routes, zero background traffic.
- [x] Per-aircraft-type purchase price — RESOLVED for the browser
      prototype, still needs eventual native-app confirmation the same
      numbers hold, since they were sourced/computed in a browser-
      prototype context.
- [ ] Whether the fleet's real-world-proportional spawn weights (see
      CLAUDE.md Fleet section) should inform which aircraft the player
      can initially afford vs. which stay aspirational late-game
      purchases — genuinely undecided, purchase prices exist now but
      nothing ties them back to the spawn-weight tiers yet.
- [ ] Player-funded route marketing — view loads by route/origin, spend
      to boost them. Explicitly scoped as a separate feature from the
      item below, needs its own load-visibility UI, not built.
- [ ] Airport-incentive-offer mechanic — bottom-15 airports (by real fee
      data already in the game) periodically offering waived landing
      fees + real marketing support for a new route, with a genuine
      clawback penalty if the player abandons the route before the
      committed term ends. Designed and sequenced (explicitly staged as
      "Phase C/D" after the route-opening foundation), not built —
      the foundation it depends on (Phase A/B) is what actually shipped
      this session.
- [ ] Route profitability chart — full per-flight history data now
      exists per route (`route.history`, verified sufficient to
      reconstruct a complete profitability-over-time curve and identify
      the exact flight that crossed into profitability), including for
      CLOSED routes (archived, not deleted, specifically so this data
      survives). The actual chart visualization doesn't exist yet — this
      is real, ready-to-consume data waiting on a UI decision.
- [ ] Bankruptcy / negative-balance handling — `playerBalance` can
      currently go negative (confirmed via real lease billing, which
      doesn't check affordability before charging) with no consequence
      beyond red text and being blocked from new purchases. Whether
      that's intended long-term or a placeholder hasn't been decided.

## Deferred indefinitely (not "later," genuinely "not planned")

- Route competition / competitor airline AI — only revisit if Phase 5's
  economy feels flat without it
- CoreML anything — no justified use case yet (see CLAUDE.md)
- Hub connectivity modeling
- Ultra-long-haul crew tier (15-17 crews/tail) — current fleet has no
  airframe that actually earns this tier
