# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file exists so a new session gets
oriented in one read. It's a pointer, not the source of truth — when it
disagrees with CLAUDE.md, CLAUDE.md wins.

## Orient yourself (in this order)
1. **`CLAUDE.md`** — the persistent design/technical context. Loads automatically
   as project instructions; it's long because it's thorough. Read it.
2. **`GO_PUBLIC_SPEC.md`** and **`ACQUISITIONS_SPEC.md`** — the two features in
   flight, written to be read cold: decisions made, what's built, what's next.
3. **`RELEASE_STATUS.md`** — the live 1.0 App Store submission state.
4. **`git log --oneline -20`** — the blow-by-blow of recent work.

## ⚠️ Branch — this will bite you if you miss it
All recent work is on branch **`fix/restore-purchases-silent`**, NOT `main`.
The name is badly misleading: it began as a one-line paywall fix and has grown
to include the **entire competitor-acquisition feature** and **Go Public (IPO)** —
12+ commits, two major features. Confirm you're on this branch (`git branch
--show-current`) before doing anything. None of this is merged to `main` yet.

## Where we are right now
- **1.0 (build 27) is in App Store review** ("Waiting for Review"). **If Apple
  responds, that takes priority over all feature work.** See RELEASE_STATUS.md
  for the outstanding ASC checklist items (manual-release toggle, sandbox
  purchase test post-approval).
- **Restore Purchases fix** — done (the original reason for the branch). Silent
  "nothing to restore" now shows a neutral message. Queued for 1.0.1.
- **Competitor Acquisition** — feature COMPLETE and balance-verified (scout →
  buy → inherit → integration burden → two-stage due diligence → consolidation
  pressure). 5.8-year managed / 13.5 passive payback. See ACQUISITIONS_SPEC.md.
- **Go Public (IPO)** — **step 1 of 5 DONE** (stock price model, IPO flow,
  ticker next to CASH). Steps remaining: (2) levers — dividends/buybacks/
  secondary offering, (3) activist investors, (4) the board (can OUST you —
  a 2nd game-over path), (5) the balance sweep. **Step 1 is pure upside and NOT
  shippable alone** — the pitfalls (steps 3–4) are what make it a real tradeoff.
  Designer decisions are locked in GO_PUBLIC_SPEC.md.

## How this session works (conventions that matter)
- **Verify by driving, not just building.** A clean `xcodebuild` proves nothing
  about runtime. Headless suites compile the real `Sim/*.swift` with
  `swiftc -O -DDEBUG` (entry file must be `main.swift`); live checks drive the
  Simulator via `xcrun simctl` + screenshots. Both catch real bugs here.
- **The Finance cash invariant is sacred.** Every money-moving action must keep
  `startingCapital + revenue − … + equityRaised == playerBalance` (the full term
  list is in Simulation's finance code). Any new cash flow joins it AND the
  headless regression.
- **TEMPVERIFY / TEMPSHOT hooks are never committed.** Grep for them before any
  commit. `#if DEBUG devInjectCash` is a test hook; it's absent from Release
  (verified via `strings`).
- **Update CLAUDE.md in the SAME commit as the code it describes** — it has
  drifted out of sync before; don't let it.
- **Balance changes need a MULTI-SEED sweep, never a single run.** Single-seed
  measurement gave opposite answers on identical code. Arms must share one
  `GameSnapshot`. Measure NET WORTH, not cash. (Full lesson in CLAUDE.md.)

## Remote Control keeps dropping on this project
It attaches only **at launch** and can't be re-attached to a running session.
Start with `claude --remote-control airline-architect` from the repo dir, or
enable the default in the Claude desktop app and start a NEW session. A
"reconnect or run remote control" error usually means session-not-found, not
auth. (Cause of any specific drop isn't observable from inside a session.)

## Suggested next step
Continue Go Public at **step 2 (levers: dividends / buybacks / secondary
offering)** — the player needs ways to fight back before step 4's board can end
the game. Unless 1.0 comes back from review, in which case handle that first.
