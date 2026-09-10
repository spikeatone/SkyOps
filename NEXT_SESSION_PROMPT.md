# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

_Written 9 September 2026, at the end of the session that: diagnosed the live
TelemetryDeck `hang.under3s` signal down to two compounding root causes and fixed
nine findings; repaired three harnesses that turned out not to be running at all;
repriced the training centre to real simulator cost and then proved it still
doesn't pay back; moved MX from Ops to its own Fleet segment; and shipped ALL of it
plus the previously-unreleased 8 Sep work as **1.8.0 (build 57)**, submitted for
review. **The release is done; the next session builds issue #4.**_

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, all pushed.
>
> **RELEASE STATE (verify, don't trust this snapshot):**
> `cd ~/Architect\ Universe/~PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`
> - **1.7.0 (build 56) is LIVE.** **1.8.0 (build 57) was SUBMITTED 9 Sep** and auto-releases on
>   approval. Next new build = **58+**.
> - 1.8 is a big feature release: multi-city rotations · crew training + Training Centre + Chief
>   Pilot · MX moved to Fleet ▸ Maintenance · four gameplay fixes · eight hang fixes.
> - ⚠️ **App Review 4.3(a) is account-wide** — every submission leads its notes with the §1
>   studio-context block. Reuse `aa-1.1.x/app-review-notes-1.8.0.txt` and bump the version line.
>   **ASC caps that field at 4000 characters** — check before pasting (1.8's is 3975; the first
>   draft was 4571 and would have truncated the argument mid-sentence). Vineyard Architect is now
>   approved, so the verifiable-titles line names three titles.
>
> **YOUR JOB: ISSUE #4 — MX AND TRAINING AUTOMATION AT SCALE.** The designer's words:
> *"For my 200-plane fleet the maintenance stuff takes up 1/3 of my time at 5×, and near all-time at
> anything faster. This really needs to be automated via maintenance bases or something as it's very
> tedious. Same with training."*
>
> Part of it already landed and part of it hasn't — know the difference before you start:
> - ✅ DONE: routine MX no longer pins the sim at 1× (`.mxCheck` is exempt from auto-slow); the
>   Chief Pilot distinguishes a real crew shortfall from a block sitting in training; and MX moved
>   OFF the alerts screen into **Fleet ▸ Maintenance** (`MaintenanceView.swift`).
> - ❌ NOT DONE, and this is the actual ask: **the CARD VOLUME.** Moving MX cut the screen real
>   estate, not the number of decisions.
>
> Build the rest of `aa-1.1.x/MX_BASES_SCOPE.md` — **all five decisions are already confirmed, so
> don't re-litigate them:**
> 1. **Auto A checks default ON** — no cards, an Ops event only; toggle lives on Fleet ▸ Maintenance.
>    This is the single biggest cut to card volume; do it first.
> 2. **Contract MRO as the default provider** — +25% cost and a 0–7-day C/D slot wait.
> 3. **Maintenance bases** — line stations ($4M) and hangar bases ($18–45M) at an operating hub OR
>    any airport with ≥3 of your routes; 2-aircraft C/D capacity per hangar line.
> 4. **Overnight at a base/hub line station = zero lost legs** (the existing 1-day downtime applies
>    elsewhere).
> 5. Placement — already shipped in 1.8.
>
> ⚠️ **FIX THIS BUG IN THE SAME PASS.** Four sites in `Sim/Simulation.swift` (~lines 3715 / 3773 /
> 3827 / 3879, each commented "~2 cycles/sim-day") convert cycles→days at a hardcoded **2** when the
> engine actually flies **~3.52**, so **every maintenance date the player sees is ~76% too far out.**
> Make it one shared constant and re-run `MXCoverageVerify`.
>
> ⚠️ **The bases need the mandatory balance A/B** (the Hubs lesson, and the Training Centre lesson
> right after it): a base must be a value-sink for a small fleet and pay back for a big one — a
> threshold, never dominant. `aa-1.1.x/TrainingCenterABProbe.swift` is the closest template, and
> `MX_BASES_SCOPE.md` §3.5 notes bases and the Training Centre are the same shape and should share
> one `Facility` model and one probe.
>
> **ALSO OPEN, smaller (ask the designer which they want):**
> - **The Training Centre still never pays back**, at any fleet size. Two price corrections already
>   landed (the facility was pricing a TEN-bay campus; bay opex was the heavy-utilization rate) and
>   took the shortfall from $48.1M to $16.9M, but the remaining gap is **throughput, not price**: the
>   probe's capture-rate diagnostic shows only **32%** of available course-fee savings are realised
>   (10% on a crew-thin family). Root cause is one line — the auto-recurrent scheduler filters
>   `status == .available`, so it only ever sees crews idle at that instant; a crew that is flying
>   when its currency window closes is never scheduled and **lapses instead of training**. That also
>   means crews lapse more than intended in EVERY game. Fixing it (queue on-duty/resting crews for
>   their next release) should move payback to ~9 years, the same timescale as buying an aircraft
>   here. **Do NOT cut prices again** — the next cut goes below real device cost, which the designer
>   ruled out.
> - **Spirit Airlines ceased all passenger operations in May 2026** but is still in the US roster.
>   Designer call: remove, or keep as period-accurate.
>
> **AFTER 1.8 GOES LIVE — the telemetry that judges the hang work.** Re-read the TelemetryDeck
> Errors dashboard **grouped by MESSAGE, not error id.** Since 1.7 every MetricKit report carries
> build-at-occurrence tagging (`b57 · 18.5`), and the dashboard row groups by error id, so the build
> tag only shows if you group by message. `b57` events are the ones that judge the fixes; anything
> tagged b39–b56 is stale drainage. Baseline before the fixes: `hang.under3s` ×43, `hang.3to10s` ×1,
> `crash.sig9…rbsterminatecontext-domain-10` ×3.
>
> **THE STANDING CONCERN:** the UI/"does it feel right" half that no harness reaches. It found the
> ASSIGN-TO-NEW-ROUTE no-op, the SLC artwork bug, and — this session — a Chief Pilot control that
> looked tappable and did nothing. It keeps paying. Drive the app.
>
> **HOW THIS CODEBASE VERIFIES (don't skip):** every sim change gets a headless harness in
> `aa-1.1.x/` (compile the real `Sim/*.swift` with `swiftc`, excluding AircraftIcon/SVGPath and
> adding `RepaintVerifyStubs.swift`; entry file MUST be `main.swift`) + the soak (`SoakMain.swift`,
> ~7 min for 6 seeds) + `RoundTripVerify.swift` (save path) + a Debug `xcodebuild` + a live
> Simulator drive of any new UI.
> ⚠️ **A HARNESS THAT PRINTS NOTHING IS NOT A PASS.** `RotationVerify` and `MXCoverageVerify` both
> defined `main()` and never called it, so they compiled to binaries that ran silently — which reads
> exactly like a clean run if you only grep for "FAIL". `SaveCompatVerify` was separately dead on a
> compile error, so the regression net for the SAVE-LOSS bug class was dark for a week. All three
> are fixed; if a harness prints nothing, suspect this before suspecting the code.
> **German:** the app ships `de` — any NEW user-facing string needs a translation, and the ONLY
> reliable gap check is `DD=<derivedDataRoot> python3 aa-1.1.x/de-findgaps.py` **after a Debug build
> that actually contains your change** (a stale DerivedData once reported 21 missing strings as
> clean). Expected residue: 2 DEBUG-only livery-gallery strings.
>
> **Simulator warnings:** tap coordinates are in POINTS, not screenshot pixels — the attach call
> reports the coordinate space. Small text targets (a bare `Text` button) are easy to miss; if two
> taps do nothing, re-screenshot before concluding the control is broken. Sibling Architect apps
> steal focus; LANDSCAPE captures come out rotated (`sips -r 90`/`-r 270`). `-devScenario`
> (`publicGate|listed|activist|ouster|fleet|bigfleet|legacyPlayer|subfleet|mx`) seeds otherwise-
> unreachable states — `mx` is a routed fleet staged at distinct MX due-states.

---

## Useful commands

```bash
# review status
cd ~/Architect\ Universe/~PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"

# headless harness pattern (entry file MUST be main.swift AND must call main())
cd AirlineArchitect/AirlineArchitect
mkdir -p /tmp/h && cp ../../aa-1.1.x/MXCoverageVerify.swift /tmp/h/main.swift
swiftc -O -DDEBUG $(ls Sim/*.swift | grep -vE 'AircraftIcon.swift|SVGPath.swift') \
  Persistence.swift ../../aa-1.1.x/RepaintVerifyStubs.swift /tmp/h/main.swift -o /tmp/h/run && /tmp/h/run

# per-tick main-thread cost vs fleet/route count (the hang-fix guard).
# ⚠️ measure at 250+ routes — below ~120 the effect is inside the noise.
cp ../../aa-1.1.x/TickCostProbe.swift /tmp/h/main.swift   # then compile as above

# German gap scan (the ONLY reliable check — after a Debug build containing your change)
DD=<your -derivedDataPath root> python3 aa-1.1.x/de-findgaps.py

# release chain, scriptable end-to-end (see CLAUDE.md "upload is SCRIPTABLE"):
#   xcodebuild archive → -exportArchive → altool --validate-app → altool --upload-app
#   → create version record → attach build → What's New → review notes → Game Center → submit
```
