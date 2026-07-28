# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 28 July 2026. **1.1 (build 35) is LIVE on the App Store** — the public
debut. <https://apps.apple.com/us/app/airline-architect/id6790569697>. Clean tree on
`main`, all pushed; nothing in flight._

## WHERE THINGS STAND

- **Shipped & live.** 1.1 (build 35) is public. It cleared review after a two-round
  Guideline **3.1.2** subscription saga (missing Terms-of-Use / EULA link — first in
  METADATA, then the IN-APP links). Resolved by shipping the in-app paywall Terms +
  Privacy `Link`s (build 35) + reviewer notes + a screen recording of the flow. The
  full rejection→approval arc is in git history (the old `RELEASE_STATUS.md` was
  retired at launch — see the git log around this date).
- **Monetization is LIVE and wired** (was previously a local stub): RevenueCat +
  RevenueCatUI SPM packages are in the build, real API key, `Purchases.configure`
  runs, and `isPro` is driven by the live entitlement **`Airline Architect Pro`**
  (dashboard identifier confirmed to match `Store.entitlementID`, with the real App
  Store Monthly + Yearly products attached). Two tiers ($5.99/mo, $49.99/yr); free
  tier caps at **3 aircraft / 2 routes**. Not-yet-run: a real sandbox purchase to
  prove the unlock on device (config checks out; this is confirmation, not a worry).
- **Build numbers:** repo is at `CURRENT_PROJECT_VERSION = 35` (Apple's latest). ASC
  has 31–35 uploaded; **the next NEW build must be 36+** (numbers can't repeat).

## NEXT — nothing is in flight; pick anywhere

1. **Post-launch watch (designer-side):** the sandbox purchase confirming Pro unlocks
   end-to-end, and an eye on early reviews / RevenueCat Overview for the first days.
2. **Top hands-on engineering item — the standing "never played end-to-end" concern.**
   The soak harness (`aa-1.1.x/SoakMain.swift`, 8/8 seeds × 2 sim-years) closed the
   numeric / state-integrity half (cash invariant, crew, ownership scoping, save/load).
   The RESIDUAL is the UI / "does it feel right" half — the panel/dropdown-flicker
   class a headless harness can't see — which still needs a real, sustained Simulator
   session with eyes. See CLAUDE.md's "Open" section.
3. **Future features / 1.2:** whatever's next goes in build 36+. The big systems
   (Go Public, Competitor Acquisition, Hubs & Clubs) are COMPLETE; their specs
   (`GO_PUBLIC_SPEC.md`, `ACQUISITIONS_SPEC.md`, `HUBS_AND_CLUBS_SPEC.md`) remain as
   reference.

## Standing conventions (unchanged, still bite)

- **Verify by DRIVING, not just building.** A clean `xcodebuild` proves nothing.
  Headless sim harnesses live in `aa-1.1.x/` (entry file must be `main.swift`); for UI,
  drive the Simulator (`simctl` + the iOS-Simulator MCP tool) and watch it.
- **The Finance cash invariant is SACRED.** Any new cash flow joins it,
  `PeriodFigures`, `FinanceSnapshot`, `FinanceSave`, AND the headless harness.
- **TEMPVERIFY / TEMPSHOT / `AA_*` / temp launch-arg hooks are NEVER committed** — grep
  before every commit. (Durable `#if DEBUG` harnesses like `-devScenario` /
  `-backdropTest` ARE keepers; the rule targets ad-hoc scaffolding.)
- **Update CLAUDE.md in the SAME commit as the code it describes.**
- **Balance changes need a MULTI-SEED sweep**, never a single run; measure NET WORTH.
- **A new persisted field needs one `decodeSafe` line in `Persistence.swift`**; a new
  nested Codable save type needs its own tolerant `init(from:)`. This is what fixed the
  lost-saves-on-new-build bug — never trust a bare `var x = 0` to survive decode.
- **Storage: staying on iCloud KVS, NOT CloudKit** (break-glass note in CLAUDE.md's
  iCloud section; the only trigger to revisit is a real save approaching the 1 MB KVS
  quota — today ~21 KB).

## Simulator gotchas that still bite

- **The sim's input channel dies mid-session** — surfaces as `Input send … timed out`,
  `machPortNotConnected`, or a tap that silently does nothing. A dropped tap looks
  exactly like a broken button; re-screenshot before concluding anything. One decisive
  tap per screenshot.
- **Tap coordinates are in POINTS** (iPhone 17 Pro = 402×874), NOT screenshot pixels —
  convert, or taps land off-screen.
- **`simctl ui <dev> appearance light|dark` doesn't repaint a foregrounded app** —
  relaunch fresh in the target appearance.
- **Typing via the automation `text` action can kick the app to the background** — use
  the software keyboard and tap keys, or seed state via a `#if DEBUG` launch arg.
- **SourceKit "cannot find X in scope" on a single file = false positive** (cross-file
  symbols); trust the full `xcodebuild`, not the per-file linter.
- **`simctl io recordVideo`** stops/finalizes cleanly only on **SIGINT** (`pkill -INT`),
  not SIGTERM — the exit-code-1 on interrupt is expected, the mp4 still writes.

## Orientation for a cold reader

1. `CLAUDE.md` — the persistent design/technical context. Long because it's thorough.
2. `APP_STORE_DESCRIPTION.md`, then the big feature specs (`GO_PUBLIC_SPEC.md`,
   `ACQUISITIONS_SPEC.md`, `HUBS_AND_CLUBS_SPEC.md`) — all COMPLETE.
3. `git log --oneline -30` — the rejection→approval→live arc is here.

Branch: everything on **`main`**, pushed to `origin/main` (GitHub `spikeatone/SkyOps`).
Open the Xcode project at `SkyOps/AirlineArchitect/AirlineArchitect.xcodeproj`.
