# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session (or a
remote session with no conversation history) in one read. It's a pointer, not the
source of truth — when it disagrees with CLAUDE.md, CLAUDE.md wins.

_Snapshot: 20 July 2026, at **1.1 (build 31)**._

## Orient yourself (in this order)
1. **`CLAUDE.md`** — the persistent design/technical context. Loads automatically
   as project instructions; it's long because it's thorough. Read it.
2. **`RELEASE_STATUS.md`** — the live App Store / TestFlight state (1.0 review +
   the 1.1 external-test cut). Written to be read cold.
3. **`GO_PUBLIC_SPEC.md`** and **`ACQUISITIONS_SPEC.md`** — the two big endgame
   features (both COMPLETE now). Read if you touch them.
4. **`git log --oneline -25`** — the blow-by-blow.

## Branch — the old warning is DEAD
Everything is on **`main`**, pushed to `origin/main`, working tree clean. The
`fix/restore-purchases-silent` branch that an older HANDOFF warned about is
history — ignore that warning. Commit to `main` (that's the established flow this
project uses). Remote is GitHub `spikeatone/SkyOps`.

## Where we are right now
- **1.1 (build 31) is archived and ready to distribute.** `MARKETING_VERSION 1.1`,
  `CURRENT_PROJECT_VERSION 31` (6 configs), pushed. The archive
  `~/Library/Developer/Xcode/Archives/2026-07-20/AirlineArchitect 1.1 (31).xcarchive`
  is built + opened in Organizer. **The DESIGNER does the credentialed
  Distribute → App Store Connect upload — Claude can't.** Do NOT distribute the
  old build 28 archive that's also in Organizer.
- **1.0 (build 27) is still in App Store review** ("Waiting for Review"). If Apple
  responds, that takes priority. ⚠️ **1.0 CONTAINS the save-crash bug below** (it
  predates 1.1) — decide whether to let it release as-is (fix follows in 1.1) or
  act. See RELEASE_STATUS.md.

## THE open item — the SAVE crash (confirmed, fixed, awaiting tester proof)
A tester reported crashes; an ASC feedback report **confirmed it's a crash on
SAVE** ("clicked save, it got hung up and then crashed", build 27/1.0, iPhone 13).
Root cause: **`Route.history` was persisted UNBOUNDED** → for a heavy player,
`snapshot()` + `JSONEncoder().encode` + the iCloud `kvs.set` on the **main thread**
spikes memory / hangs → watchdog/OOM kill. **Fixed in build 29+** (cap
`Route.history` to 60 with running-total aggregates; cold-launch `slotInfos`/
`reconcile` don't fully decode oversized legacy saves; don't mirror >900 KB to
KVS). 18/18 headless. **STILL UNCONFIRMED end-to-end for the tester** — the next
real signal is a heavy tester loading their game on build 31 and hitting Save a
few times cleanly. (If you want the exact original frame, their symbolicated
`.ips` is in ASC → TestFlight → Feedback/Crashes.)

## What shipped this session (the build 28 → 31 arc)
All on `main`. Detail in CLAUDE.md; highlights:
- **Save-size / launch hardening** — the fix above.
- **iPad responsiveness** — Crews/Fleet/Alerts moved to throttled `displayTick`;
  NetworkView map tick isolated into `LiveMap`; lighter foreground iCloud reconcile.
- **Hubs panel** (Network, 5th control-bar item once a hub exists) + per-hub
  Route-Opportunity drawers (Ops).
- **Route-competition player actions** (Ops "Competition" rows): Fare war / Ad
  campaign / Loyalty push — upfront MARKETING spend, a new cash-invariant term.
- **Load-menu delete UX** — bigger trash icon + swipe-left-to-delete (red box =
  slot height; slots stay compact).
- **Back-arrow navigation** — Market Intelligence + Go Public are now within-tab
  drill-downs (leading chevron, tab bar visible), NOT modals. Alerts + Paywall
  stay modal. (New standing NAV PATTERN — see CLAUDE.md.)
- **Ops reorder** (Route Opps + Fuel Hedge to top), **uniform control-bar font**,
  ESTIMATE due-diligence badge in theme-aware orange, Finance REPORTS/FUNDING split.
- **Go Public (IPO)** and **Competitor Acquisition** — both feature-COMPLETE and
  balance-verified earlier this arc (see the two SPEC files).

## Conventions that matter (don't relearn these the hard way)
- **Verify by DRIVING, not just building.** A clean `xcodebuild` proves nothing
  about runtime. Two proven lanes:
  - **Headless sim harness** — compile the real `Sim/*.swift` (exclude the two
    SwiftUI files `AircraftIcon.swift`/`SVGPath.swift`) + `Persistence.swift` with
    `swiftc -O -DDEBUG`, entry file named `main.swift`. Working examples live in
    the session scratchpad (`PromoMain.swift`, `LaunchFixMain.swift`). There's a
    `#if DEBUG cashInvariantResidual()` hook on `Simulation` that must always
    return 0 — assert it after any money move. `devInjectCash` is also DEBUG-only.
  - **Live in the Simulator** via `xcrun simctl` install/launch + screenshots.
- **The Finance cash invariant is SACRED.** `startingCapital + revenue − fees −
  … + loanProceeds − debtService … == playerBalance`. Any NEW cash flow joins it,
  `PeriodFigures`, `FinanceSnapshot`, `FinanceSave`, AND the headless harness.
- **TEMPVERIFY / TEMPSHOT hooks are NEVER committed.** This session used env-var
  seeds (`ProcessInfo.environment["AA_…"]`) to jump into states the Simulator
  couldn't reach by hand. Grep `TEMPVERIFY`/`AA_` before every commit; strip them.
- **Update CLAUDE.md in the SAME commit as the code it describes.** It has drifted
  before.
- **Balance changes need a MULTI-SEED sweep**, never a single run; measure NET
  WORTH; arms share one `GameSnapshot`. (Full lesson in CLAUDE.md.)

## Simulator gotcha you WILL hit
This session, computer-use **taps did not register on the Simulator** (a real
input glitch — restart/refocus didn't fix it), while **drag gestures DID** (map
pan, list scroll, swipe). So: to verify any tap-driven UI, don't fight it — seed
the target state with a temporary env-var hook and drive via `simctl` +
screenshots, then strip the hook. (The designer can tap normally on their end.)

## Release / versioning workflow
- Bump `CURRENT_PROJECT_VERSION` **+1 on every upload** (6 configs; ASC rejects a
  reused build number). Bump `MARKETING_VERSION` minor for a feature release,
  patch for a fix-only one. Then archive:
  `xcodebuild -scheme AirlineArchitect -configuration Release -destination
  'generic/platform=iOS' -archivePath "<…>.xcarchive" -allowProvisioningUpdates
  archive`, then `open` the archive → Organizer. **Designer distributes.**
- ⚠️ The archive signs with a *development* profile; Organizer's Distribute
  re-signs for the App Store. That distribution profile **must include the iCloud
  Key-Value storage capability** (an earlier launch-crash suspect) — worth a check.

## Suggested next steps
1. **Confirm the save-crash fix** with a heavy tester on build 31 (load + Save).
   Until then it's fixed-in-theory (18/18 headless) but not proven on-device.
2. **Decide 1.0's fate** — it has the save bug; the fix is only in 1.1.
3. Otherwise: new feature/polish work as the designer directs. Region selection
   at start, leisure-fare tuning, and the `HUBS_AND_CLUBS_SPEC` chart view are
   among the queued items (see CLAUDE.md "Open" + `TASKS.md`).
