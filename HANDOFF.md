# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 23 July 2026. **1.1 (build 33)** in App Store review; build 34
accumulating (Game Clock + the architect's-tools brand motif + the Go Public
live tap-through)._

## GOAL

Close the **Go Public pre-beta gate** — the whole IPO feature (steps 2–5) was
headless-verified only, and CLAUDE.md flagged a live Simulator run as the thing
standing between it and a beta cut. **Done: every surface driven, both themes,
no defects found.** Build 34 is the open cut; nothing is half-finished.

## DONE — verified live this session

**The Go Public live tap-through, in full.** Every number reconciled on screen;
the 78/78 headless suite turned out to be right about all of it.

1. **IPO flow (light theme)** — gate card → ticker → float slider → List.
   Valuation/proceeds/cash-after all tie out exactly; the ≤4-letter ticker clamp
   was verified AT THE FIELD; dragging past majority flips the summary red
   ("Minority — little protection"); listing fired the `went_public` milestone
   toast and the ticker came up at **$31.00** (spec predicted $25–31 at the gate).
2. **The three levers (light)** — dividend **−$14.7M**, buyback **−$73.5M** with
   the stake rising **75.0% → 80.0%**, secondary **+$110.3M** with it falling to
   **72.7%**. All exact.
3. **Activist card (dark), BOTH paths** — Refuse: cleared, cash unchanged,
   escalation logged. Comply: **exactly −$10.0M** and two ops entries (dividend +
   "activist stands down").
4. **The board (dark)** — the red **"Board patience · Weighing your removal"** bar,
   then the **OUSTED** recap dropping over it in the same run. Second game-over
   path, on screen.

**New, and committed:** `-devScenario <publicGate|listed|activist|ouster>`
(`Simulation.DevScenario` + `devSeed(_:)`, `#if DEBUG`). The feature gates on a
$500M airline and an activist needs 3 sim-months of slump, so its UI was
otherwise unreachable by hand. Full detail — including why `currentSlot` stays
nil and why `.ouster` uses `tick + 240` — is in CLAUDE.md's Go Public section.

## NEXT — concrete, in order

1. **Nothing is in flight.** Safe to start anywhere.
2. **Cut build 34** when the designer is ready: bump `CURRENT_PROJECT_VERSION`
   to 34 across **6 configs** → archive → Organizer. **The DESIGNER does the
   credentialed Distribute/upload — Claude cannot.**
3. If Apple responds on build 33, that takes priority over everything.
4. **The standing "never played end-to-end" concern** is now the top open item
   (CLAUDE.md "Open" section). Go Public is driven, but the full 30-type fleet /
   48 airports / events / crew systems have still never run together in one
   sustained session. That list has a long, real catch rate.
5. Optional polish: the motif's light opacity is **0.08** in AA but **0.10** in
   Golf Course Architect. May be correct (different pages), but it's the one
   number that differs across the series if you want them identical.

## KEY DECISIONS (don't relitigate)

- **Each cold-launch screen draws its OWN `ArchitectBackdrop` instance** — NOT
  one shared layer. The geometry is a pure function of container size, so all
  three land pixel-identically and the tools never shift on handoff, while each
  screen keeps its own opaque background. Sharing one layer would force screens
  to give up their backgrounds for no visual gain.
- **The two opacities differ ON PURPOSE.** `figmaOpacity` 0.10 (dark, the Figma
  value) vs `lightOpacity` 0.08. Dark ink on white carries further than white
  line-art on `#2B303D` — equal alpha does not read equal. Tuned by eye on
  device: 0.06 vanished, 0.12 competed with the form fields. **Don't "unify" them.**
- **Geometry is FRACTIONAL, not fixed points.** Figma's frame is 440 wide; real
  devices are 402/430/iPad. Hard-coded points would drift off-screen.
- **Load menu got the motif too** (a judgment call, easily reverted — one
  parameter). Without it a *returning* player gets splash → load menu and
  watches the motif pop away.
- **One PNG, both themes**, because the art is a `.template` image tinted at
  draw time. This is also what makes it portable across the series.
- HANDOFF lives in `HANDOFF.md`, not a GitHub issue — CLAUDE.md records the
  deliberate "TASKS.md, not GitHub Issues" choice (designer isn't a dev by
  background). `gh` IS authenticated if that ever changes.
- **`-devScenario` is a KEEPER, not a throwaway seed.** The "never commit seed
  hooks" rule targets ad-hoc `TEMPVERIFY`/`AA_*` scaffolding. This is the
  `-backdropTest` pattern: a durable, documented `#if DEBUG` harness for a
  feature whose UI is otherwise unreachable by hand. It compiles out of Release.
- **A seeded session must never touch a real save** — `currentSlot` stays nil, so
  the autosave path can't fire. Keep that if you add scenarios.

## FILES TOUCHED

Nothing half-done; every file below builds.

| File | What changed |
|---|---|
| `Sim/Simulation.swift` | **NEW, `#if DEBUG`:** `DevScenario` + `devSeed(_:)`, beside `devInjectCash`. In-file because it writes `private(set)` state and calls the private monthly ticks. |
| `ContentView.swift` | **NEW, `#if DEBUG`:** reads `-devScenario`, skips splash/load-menu/naming, opens FINANCE, leaves `currentSlot` nil. |
| `CLAUDE.md` | Go Public "LIVE TAP-THROUGH STILL PENDING" → the verified results + the harness + two simulator gotchas. |
| `HANDOFF.md` | This file. |
| _(previous session, already on `origin/main`)_ | `ArchitectBackdrop.swift`, `ArchitectBackdropTestView.swift`, `Resources/Brand/ArchitectTools.png`, `SplashView.swift`, `AirlineNamingView.swift`, `SaveSlotsView.swift`, `NetworkView.swift` — the brand motif. |

## GOTCHAS (real traps hit this session)

- **The automation `text` action repeatedly kicked the app to the BACKGROUND** —
  a sibling Architect app came forward — even with the caret visibly in the
  field. Fix: use the SOFTWARE keyboard (`defaults write
  com.apple.iphonesimulator ConnectHardwareKeyboard -bool false`, restart the
  Simulator app, then TAP the keys), which is also the path a real player uses.
  Two wrinkles: restarting the Simulator app boots a DIFFERENT default device, so
  re-`boot` the one you installed to; and reverting the default is polite (done).
- **The simulator's input channel dies mid-session** (the already-documented
  glitch). It surfaces as `Input send … timed out; the simulator likely
  rebooted`, `machPortNotConnected`, or a tap that silently does nothing. **A
  dropped tap looks exactly like a broken button** — re-screenshot before
  concluding anything. A "failed" Refuse was a lost tap; foregrounding the app
  showed the same PID with state intact. One decisive tap per screenshot.
- **A price that moves between render and tap is the sim working, not a bug.**
  The 5% dividend chip read −$13.9M and charged −$14.7M because a sim-day passed
  while the screen sat idle and `displaySharePrice` eased toward target. Levers
  transact at the LIVE price. Don't "fix" it.
- **A preview harness that wraps a real view will LIE to you if you don't thread
  every styling input through it.** My harness's naming mode didn't pass the
  tint → drew white-on-white → looked like "the light treatment doesn't work."
  The shipping path was correct the whole time. Cost a full debug round.
- **Figma export bakes in an opaque frame background** — use the `rawImages`
  entry from `download_assets`, never `export`. (Documented previously for the
  aircraft art; it bit again here.)
- **`backdropOpacity` is declared BEFORE the trailing closure** (`onLaunch` /
  `onDone`) on those views, purely so trailing-closure call syntax compiles.
  Reordering them will break call sites.
- **Splash screenshots:** `simctl io screenshot` takes ~1s and the splash is
  only ~3.3s including cold start, so polling for a mid-animation frame is
  unreliable — you'll usually catch the launch-zoom or the post-splash screen.
  The live attached panel is the honest way to judge motion.
- **`simctl ui <dev> appearance light|dark` does not repaint reliably while the
  app is foregrounded** — relaunch fresh in the target appearance.
- **Portability:** `ArchitectBackdrop.swift` + the PNG is a two-file drop-in for
  sibling apps (GCA and Vineyard Architect already have it). `ArchitectBackdropLayer`
  is the ONE place that references an app token (`Sky.darkBG`) — strip that when copying.

## Standing conventions (unchanged, still bite)

- **Verify by DRIVING, not just building.** A clean `xcodebuild` proves nothing.
  Headless sim harness examples live in `aa-1.1.x/`; entry file must be `main.swift`.
- **The Finance cash invariant is SACRED.** Any new cash flow joins it,
  `PeriodFigures`, `FinanceSnapshot`, `FinanceSave`, AND the headless harness.
- **TEMPVERIFY / TEMPSHOT / `AA_*` seed hooks are NEVER committed** — grep before
  every commit.
- **Update CLAUDE.md in the SAME commit as the code it describes.**
- **Balance changes need a MULTI-SEED sweep**, never a single run; measure NET WORTH.
- A new persisted field needs one `decodeSafe` line in `Persistence.swift`; a new
  nested Codable save type needs its own tolerant `init(from:)`.

## Orientation for a cold reader

1. `CLAUDE.md` — the persistent design/technical context. Long because it's thorough.
2. `RELEASE_STATUS.md` — live App Store / TestFlight state.
3. `APP_STORE_DESCRIPTION.md`, then the big feature specs (`GO_PUBLIC_SPEC.md`,
   `ACQUISITIONS_SPEC.md`, `HUBS_AND_CLUBS_SPEC.md`) — all COMPLETE.
4. `git log --oneline -25`.

Branch: everything on **`main`**, pushed to `origin/main` (GitHub `spikeatone/SkyOps`).
Open the Xcode project at `SkyOps/AirlineArchitect/AirlineArchitect.xcodeproj`.
