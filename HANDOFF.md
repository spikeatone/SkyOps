# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 23 July 2026. **1.1 (build 33)** in App Store review; build 34
accumulating (Game Clock + the architect's-tools brand motif)._

## GOAL

Ship the Architect-series **brand motif** across the app's cold-launch surfaces
(done, both themes), and keep the project docs honest. Build 34 is the open
cut; nothing is half-finished.

## DONE — verified live this session, from committed HEAD

All three commits are on `origin/main`; working tree clean, local == remote.

1. **`f50f0ff` — doc reconciliation.** TASKS.md + CLAUDE.md's "Open" section
   claimed a pile of shipped features were unbuilt. Verified against real code
   and corrected: route-profitability chart, bankruptcy, airport incentives,
   player route marketing, leasing/used market, ROUTES panel, Figma pipeline,
   Phase-2 economy — **all were already built.** Also killed the line claiming
   "Xcode project shell doesn't exist yet" (the app has shipped through 33).
   _Evidence: only 2 `[ ]` items remain in TASKS.md, both correct (the standing
   "never played end-to-end" concern + a "nothing blocked" placeholder)._
2. **`ab52ca5` — architect's-tools motif** (Figma `90:4819` "home - dark"),
   wired into the real cold-launch flow: **SplashView / AirlineNamingView /
   SaveSlotsView**.
3. **`dfe34de` — light-mode treatment.** Same PNG, tinted at draw time.

**Re-verified at hand-off time (not transcribed):** Debug **and** Release both
`BUILD SUCCEEDED` from committed HEAD; app launched with **no debug args** on
the iPhone 17 Pro sim and the splash was captured mid-animation showing the
route arcs playing **over** the motif, logo crossfading in — i.e. the designer's
sequencing idea works in the shipping path. Light mode verified separately on
the naming screen and the real cold launch (load menu).

## NEXT — concrete, in order

1. **Nothing is in flight.** Safe to start anywhere.
2. **Go Public live tap-through** — the highest-value open item. Steps 2–5
   (levers / activists / board ouster) are **headless-verified only**; CLAUDE.md
   flags a live Simulator run as the pre-beta gate. Needs a `#if DEBUG
   devInjectCash` seed to reach the $500M gate fast.
3. **Cut build 34** when the designer is ready: bump `CURRENT_PROJECT_VERSION`
   to 34 across **6 configs** → archive → Organizer. **The DESIGNER does the
   credentialed Distribute/upload — Claude cannot.**
4. If Apple responds on build 33, that takes priority over everything.
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

## FILES TOUCHED

Nothing half-done; every file below is committed and building.

| File | What changed |
|---|---|
| `ArchitectBackdrop.swift` | **NEW.** The motif + `figmaOpacity` / `lightOpacity`. Self-contained — see Gotchas re: portability. |
| `ArchitectBackdropTestView.swift` | **NEW, `#if DEBUG`.** Tuning harness; absent from Release. |
| `Resources/Brand/ArchitectTools.png` | **NEW.** The artwork (892×1200, alpha). |
| `SplashView.swift` | `backdropOpacity` param; motif drawn over navy sky, UNDER the arcs. |
| `AirlineNamingView.swift` | `backdropOpacity` + `backdropTint`. |
| `SaveSlotsView.swift` | Same two params. |
| `ContentView.swift` | `coldLaunchBackdrop` / `coldLaunchTint` per theme; passes to all three. |
| `NetworkView.swift` | Promoted `Sky.darkBlue` (#4E67A0) to a named token. |
| `CLAUDE.md`, `TASKS.md` | Motif documented; stale backlog reconciled. |

## GOTCHAS (real traps hit this session)

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
