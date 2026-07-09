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
frame drops; aircraft types with correct weighted spawn ratios are visually
distinguishable (widebody vs narrowbody).

- [ ] Scale to full fleet size, profile performance (the JS prototype's
      FPS/tick-cost overlay is worth porting as a dev tool, not shipping it)
- [ ] Port AIRCRAFT_TYPES config (real hold-cost/revenue figures — see
      prototype-reference)

## Phase 3 — Crew + AOG + weather systems
**Exit condition:** per-family crew pools, AOG clustering, and weather holds
all behave identically to the validated prototype — including the parts
that were bugs and got fixed (crew backfill for staggered spawns, the
holding-pattern loiter loop instead of a frozen freeze-frame, the rejoin
easing between holding pattern and final approach).

- [ ] Port crew pool system (per-family, real crews-per-tail ratios)
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

## Phase 5 — Economy layer
**Exit condition:** route-opening, passenger demand, and reputation feed
back into the fleet/crew/disruption systems from Phases 1-3.

- [ ] Passenger demand + load factor
- [ ] Reputation feedback loop
- [ ] Route-opening UI, aircraft purchase (revenue-gated, per original brief).
      Design intent captured but not yet built: player starts with a small
      fleet (size TBD) and limited capital, and must accumulate real
      in-game revenue to afford buying a 2nd/3rd/etc. aircraft — purchase
      is meant to be a genuine constraint the player saves toward, not a
      free/instant unlock. Opening a new route also costs money (amount
      TBD), separate from the aircraft purchase itself. This explicitly
      reverses/supersedes the current browser prototype's fleet slider,
      which is a stress-test control with no economic meaning — when this
      phase is built, the slider goes away and starting fleet size becomes
      a real game-balance decision, not a dev convenience. NOT yet decided:
      starting capital amount, per-aircraft-type purchase price (real
      aircraft list prices run into the hundreds of millions — will need
      real game-balance work against per-flight revenue figures already in
      the prototype, not a direct real-price import), route-opening cost
      formula, and whether the fleet-slider's real-world-proportional spawn
      weights (see CLAUDE.md) inform which aircraft the player can
      initially afford vs. which stay aspirational late-game purchases.

## Deferred indefinitely (not "later," genuinely "not planned")

- Route competition / competitor airline AI — only revisit if Phase 5's
  economy feels flat without it
- CoreML anything — no justified use case yet (see CLAUDE.md)
- Hub connectivity modeling
- Ultra-long-haul crew tier (15-17 crews/tail) — current fleet has no
  airframe that actually earns this tier
