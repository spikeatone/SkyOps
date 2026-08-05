# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 3 August 2026. **1.1.1 (build 36) is LIVE on the App Store**
(<https://apps.apple.com/us/app/airline-architect/id6790569697>) — cleared review
with no rejections. Clean tree on `main`, all pushed; **nothing in flight**._

## What shipped in 1.1.1 (build 36)

The repo is at **`MARKETING_VERSION = 1.1.1`, `CURRENT_PROJECT_VERSION = 36`**, which
is LIVE — **the next new build must be 37+** (numbers can't repeat).

**Account note (resolved):** the designer's personal Apple account migrated to an Org
account (Postmark Digital LLC) mid-cycle, which blocked distribution signing for a
few days. The migration **kept the same team id `D2PVU8X5Q7`**, so no project change
was needed and the iCloud KVS entitlement was unaffected. If a future migration
changes the team id, it's pinned in 6 configs in the pbxproj.

**Contents (all since build 35):**
- **Airport hero images** — tapping an airport shows real art. 34 JPGs (~13 MB):
  9 terrain/region archetypes + 25 marquee-city overrides (incl. Bozeman). See
  `AIRPORT_PHOTOS_SPEC.md`.
- **New cold-launch backdrop** — the drafting-tools motif replaced by the designer's
  aviation pencil sketch, with a separate iPad-composed asset. See CLAUDE.md.
- **Fix: ASSIGN TO NEW ROUTE was a silent no-op** since the custom-tab-bar refactor
  (`.onChange` never fires on a recreated view — adopt intents in `.onAppear`).
- **Fix: selling a route-assigned aircraft** now offers replace-or-close instead of
  silently archiving the route.
- **Fix: Finance ledger figures are compact (B/M/k)** so late-game totals stop
  churning at 25×; day/night terminator seam fixed.

## WHERE THINGS STAND

- **Shipped & live.** 1.1.1 (build 36) is public — a clean review, no rejections.
  The preceding 1.1 (build 35) debut cleared only after a two-round Guideline
  **3.1.2** subscription saga (missing Terms-of-Use / EULA link — first in METADATA,
  then the IN-APP links), resolved by shipping the in-app paywall Terms + Privacy
  `Link`s + reviewer notes + a screen recording of the flow. **Those links are still
  in the binary — don't remove them.** The full rejection→approval arc is in git
  history (the old `RELEASE_STATUS.md` was retired at the 1.1 launch).
- **Monetization is LIVE and wired** (was previously a local stub): RevenueCat +
  RevenueCatUI SPM packages are in the build, real API key, `Purchases.configure`
  runs, and `isPro` is driven by the live entitlement **`Airline Architect Pro`**
  (dashboard identifier confirmed to match `Store.entitlementID`, with the real App
  Store Monthly + Yearly products attached). Two tiers ($5.99/mo, $49.99/yr); free
  tier caps at **3 aircraft / 2 routes**. **VERIFIED END-TO-END on device (3 Aug
  2026)** via a TestFlight sandbox purchase: Apple's sheet completed, the paywall
  dismissed ITSELF, and the fleet cap lifted — i.e. offering loaded → package
  resolved → StoreKit purchase → RevenueCat validated → entitlement active →
  `customerInfoStream` pushed it into the UI. Nothing about monetization is unproven
  now. **Re-test recipe:** install the TestFlight build (orange dot next to the app
  name = TestFlight; NO dot = the App Store copy, where a tap is a REAL charge), hit
  a cap, tap Continue. `[Environment: Sandbox]` appears on APPLE'S sheet, never on
  our own paywall. **GOTCHA: the fallback plan prices are identical to the real ones
  ($49.99/$5.99), so correct prices do NOT prove the offering loaded** — the real
  tell is whether tapping Continue reaches Apple's sheet or errors with "That plan
  isn't available right now."
- **Build numbers:** repo is at **1.1.1 / build 36**, which is LIVE. ASC has 31–36
  uploaded; **the next new build must be 37+** (numbers can't repeat). A further
  point release is 1.1.2; a feature release, 1.2.

## NEXT — nothing is blocked; pick anywhere

1. **Post-launch watch (designer-side):** early reviews and the RevenueCat Overview.
   (The sandbox purchase is DONE — Pro unlocks end-to-end on device.) Optional
   follow-up: delete + reinstall and tap **Restore Purchases**, the one purchase path
   still unexercised.
2. **Top hands-on engineering item — the standing "never played end-to-end" concern.**
   The soak harness (`aa-1.1.x/SoakMain.swift`, 8/8 seeds × 2 sim-years) closed the
   numeric / state-integrity half (cash invariant, crew, ownership scoping, save/load).
   The RESIDUAL is the UI / "does it feel right" half — the panel/dropdown-flicker
   class a headless harness can't see — which still needs a real, sustained Simulator
   session with eyes. See CLAUDE.md's "Open" section. (Today's session is a live
   example of why: driving the app found the ASSIGN-TO-NEW-ROUTE no-op, which the
   headless suite had passed 41/41.)
3. **Future features:** the airport-hero + backdrop work that shipped in 1.1.1 was the
   art pass. The big systems
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
- **LANDSCAPE captures come out ROTATED** (`simctl io screenshot` grabs the raw
  framebuffer) — `sips -r 90` or `-r 270` to view upright; which one depends on the
  rotation direction. Rotating the device via `osascript` keystrokes is unreliable.
- **A capture taken right after `simctl launch` can be all-black** (grabbed mid-launch)
  — sleep ~3s and re-capture before concluding anything is broken.
- **`⌘⇧A` can't change the theme under `-backdropTest`** — that harness pins the scheme
  via `.preferredColorScheme` off `-backdropLight`. Relaunch with/without the flag.
- **`simctl io recordVideo`** stops/finalizes cleanly only on **SIGINT** (`pkill -INT`),
  not SIGTERM — the exit-code-1 on interrupt is expected, the mp4 still writes.

## Orientation for a cold reader

1. `CLAUDE.md` — the persistent design/technical context. Long because it's thorough.
2. `APP_STORE_DESCRIPTION.md`, then the big feature specs (`GO_PUBLIC_SPEC.md`,
   `ACQUISITIONS_SPEC.md`, `HUBS_AND_CLUBS_SPEC.md`) — all COMPLETE.
3. `git log --oneline -30` — the rejection→approval→live arc is here.

Branch: everything on **`main`**, pushed to `origin/main` (GitHub `spikeatone/SkyOps`).
Open the Xcode project at `SkyOps/AirlineArchitect/AirlineArchitect.xcodeproj`.
