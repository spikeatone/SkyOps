# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session (or a
remote session with no conversation history) in one read. It's a pointer, not the
source of truth — when it disagrees with CLAUDE.md, CLAUDE.md wins.

_Snapshot: 22 July 2026, at **1.1 (build 33)** in App Store review; build 34 accumulating._

## ⚠️ REPO MOVED — you are at a NEW path
The repo now lives at **`~/Architect Universe/Airline Architect/SkyOps`** (it used
to be `~/Documents/GitHub/SkyOps`). The move was clean; `.git`, GitHub remote, and
the Xcode project are all intact and unaffected (git/Xcode use relative paths).
Two consequences:
- **Open the Xcode project at `SkyOps/AirlineArchitect/AirlineArchitect.xcodeproj`.**
  A dead pre-rename `SkyOps/SkyOps/SkyOps.xcodeproj` husk used to sit alongside it
  and caused "missing project.pbxproj" errors — it's been DELETED. Only the real
  `AirlineArchitect.xcodeproj` remains.
- Claude's per-project memory is keyed to the absolute path, so the old
  `~/.claude/projects/-Users-michaelstevens-Documents-GitHub-SkyOps/` memory is
  orphaned. Not a problem — CLAUDE.md + this file (both IN the repo) carry the
  real context. The design-assets master folder (icons, illustrations, screenshots,
  Sounds, the two ASC `.p8` API keys, Website) lives one level up at
  `~/Architect Universe/Airline Architect/` — NOT in git, backed up only by Time
  Machine.

## Orient yourself (in this order)
1. **`CLAUDE.md`** — the persistent design/technical context. Loads automatically
   as project instructions; it's long because it's thorough. Read it.
2. **`RELEASE_STATUS.md`** — the live App Store / TestFlight state. Read cold.
3. **`APP_STORE_DESCRIPTION.md`** — the current ASC copy (description, promo,
   What's New, TestFlight What to Test, reviewer notes).
4. **`GO_PUBLIC_SPEC.md`** / **`ACQUISITIONS_SPEC.md`** / **`HUBS_AND_CLUBS_SPEC.md`**
   — big features, all COMPLETE. Read if you touch them.
5. **`git log --oneline -25`** — the blow-by-blow.

## Branch
Everything is on **`main`**, pushed to `origin/main`, working tree clean. Commit to
`main` (the established flow). Remote is GitHub `spikeatone/SkyOps`.

## Where we are right now
- **1.1 (build 33) is the PUBLIC DEBUT and is in App Store review.**
  `MARKETING_VERSION 1.1`, `CURRENT_PROJECT_VERSION 33` (6 configs). The designer
  swapped build 32 → 33 in ASC (edited the version record to 1.1 without a resubmit)
  and bundled it to Apple. **The DESIGNER does the credentialed Distribute/upload —
  Claude can't.** For a FIRST public release ASC shows the Description, not a
  "What's New" field (that appears on the first UPDATE after 1.1 is live).
- **1.0 (build 27) was PULLED** (never released) — it carried the save-crash bug
  below, so 1.1 was made the debut instead of fast-following. The old "decide 1.0's
  fate" open item is CLOSED.
- **Build 34 is accumulating on `main`** but NOT cut yet — the designer is waiting
  to roll a few more items in. So far build 34 = the **Game Clock** only (Day/Date/
  Time readout on the speed bar + randomized start date/season).

## The two SAVE issues — BOTH fixed
1. **Save CRASH** (1.0/build 27): `Route.history` persisted UNBOUNDED → a heavy
   player's `snapshot()`/encode/iCloud `kvs.set` on the main thread spiked memory
   → watchdog/OOM. Fixed build 29+ (history capped at 60 with running-total
   aggregates; oversized legacy saves not fully decoded on the launch path; >900 KB
   not mirrored to KVS). 1.0 was pulled, so this is moot for release.
2. **Save LOSS on app update** (THIS session, in build 33): testers lost games on
   new TestFlight builds. Root cause — **synthesized `Codable` throws `keyNotFound`
   on a missing key for a NON-optional field even when it has a default**, so every
   older save that predated a later build's new field failed to decode → swallowed
   to nil → slot looked "empty" → overwritten. Fixed structurally: tolerant
   `init(from:)` (`decodeSafe`/`decodeSafeOpt` → default) on every save struct in
   `Persistence.swift`, so add-a-field-then-lose-saves is impossible past+future;
   plus a last-known-good `.bak` and an occupied placeholder for undecodable files.
   Verified `aa-1.1.x/SaveCompatVerify.swift` 12/12 + `RoundTripVerify.swift` 13/13
   + live. **RULE: a new persisted field needs one `decodeSafe` line; a new nested
   Codable save type needs its own tolerant `init(from:)`.** DEFERRED (needs two
   physical devices on one Apple ID): full-body cloud validation before adopting,
   and async-correct iCloud restore-on-fresh-install.

## What shipped recently (the build 32 → 33 arc + this session)
All on `main`. Detail in CLAUDE.md; highlights:
- **Save-loss-on-update fix** (above) + **Glasgow (GLA)** airport (385 total).
- **Weather-glyph polish**: glyphs 50% larger, moved BELOW the airport ring,
  day/night terminator more pronounced, and weather is now regionally-plausible
  (curated `Airport.hurricaneProneCodes` — no more inland hurricanes; MCI →
  winter).
- **1.1.x LOD realism/delight batch**: national registration prefixes, expanded
  milestone ladder, seasonal weather + leisure yield, day/night terminator + real
  night curfews, aircraft/destination flavor. Caribbean carrier region. Leisure
  destinations + retuned leisure opening surcharge. Region selection at start.
- **Game Clock** (build 34): `Day N · Mon D, YYYY · HH:MM` on the speed bar,
  1-indexed day, randomized start date/season.

## Conventions that matter (don't relearn these the hard way)
- **Verify by DRIVING, not just building.** A clean `xcodebuild` proves nothing
  about runtime. Two proven lanes:
  - **Headless sim harness** — compile the real `Sim/*.swift` (exclude the two
    SwiftUI files `AircraftIcon.swift`/`SVGPath.swift`) + `Persistence.swift` with
    `swiftc -O -DDEBUG`, entry file named `main.swift`. Working, current examples
    live in **`aa-1.1.x/`** (see its README) — incl. `SaveCompatVerify.swift` and
    `RoundTripVerify.swift` from this session. `#if DEBUG cashInvariantResidual()`
    on `Simulation` must return 0 on a LIVE sim (on a RESTORED sim it equals
    `-(devInjectCash)`, since the injection isn't persisted — that's proof of an
    exact restore, not a failure).
  - **Live in the Simulator** via `xcrun simctl` install/launch + screenshots.
- **The Finance cash invariant is SACRED.** `startingCapital + revenue − fees − …
  + loanProceeds − debtService … == playerBalance`. Any NEW cash flow joins it,
  `PeriodFigures`, `FinanceSnapshot`, `FinanceSave`, AND the headless harness.
- **TEMPVERIFY / TEMPSHOT / `AA_*` env-var seed hooks are NEVER committed.** Grep
  `TEMPVERIFY`/`TEMPSHOT`/`AA_` before every commit; strip them.
- **Update CLAUDE.md in the SAME commit as the code it describes.** It has drifted
  before.
- **Balance changes need a MULTI-SEED sweep**, never a single run; measure NET
  WORTH; arms share one `GameSnapshot`. (Full lesson in CLAUDE.md.)

## Release / versioning workflow
- Bump `CURRENT_PROJECT_VERSION` **+1 on every upload** (6 configs; ASC rejects a
  reused build number — build 34 is next). Bump `MARKETING_VERSION` minor for a
  feature release, patch for a fix-only one. Then archive:
  `xcodebuild -scheme AirlineArchitect -configuration Release -destination
  'generic/platform=iOS' -archivePath "<…>.xcarchive" -allowProvisioningUpdates
  archive`, then `open` the archive → Organizer. **Designer distributes.**
- The distribution profile must include the **iCloud Key-Value storage** capability
  (a past launch-crash suspect) — worth a check.

## Suggested next steps
1. **Build 34 is open** — the designer is accumulating items before the cut. The
   Game Clock is in; add whatever's next, then bump to build 34 and archive.
2. **Build 33 is in Apple review** — if Apple responds, that takes priority.
3. Queued/possible work: see CLAUDE.md "Open / not yet decided" + `TASKS.md`. The
   deferred iCloud save-hardening (full-body cloud validation, fresh-install
   restore) needs two physical devices to validate.
