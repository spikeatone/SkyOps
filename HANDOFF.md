# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 12 September 2026._

**► ⭐⭐⭐ 1.8.0 (build 57) IS LIVE — APPROVED and `READY_FOR_SALE` (confirmed via the ASC API,
10 Sep 2026). Next new build = 58+.** The whole chain ran from the CLI: bumped 1.7.0→1.8.0 / 56→57
(6 configs), archived → exported → validated (VERIFY SUCCEEDED) → uploaded (UPLOAD SUCCEEDED,
**Delivery UUID `01c7b045-faea-4722-b178-9f5a942c9e44`**, 76 MB), build 57 attached, en-US + de-DE
What's New set, App Review notes set, Game Center enabled, submitted. ASC ids — version
`a6e6c4d1-d2bb-41e9-804b-131fcd0730a8`, review submission `dc118de8-0b52-49a3-8f1e-697fa1ea4587`.
⚠️ **1.8 is a FEATURE release, not the 1.7.1 patch it started as.** Build 56 was cut 3 Sep; everything
merged to `main` after that date goes in this build — the designer confirmed shipping it all together.
Contents: **multi-city rotations** · **crew training pipeline + Training Centre + Chief Pilot** ·
**MX moved to its own Fleet ▸ Maintenance segment** · the four gameplay fixes (real carrier hubs,
acquisition MX seeding, buyback repricing, live subsidiary P&L) · transpacific routing fix · Ops
drawers/red chips/auto-slow restore · **the eight hang fixes** below. Drafts kept at
`aa-1.1.x/whats-new-1.8.0.md` and `aa-1.1.x/app-review-notes-1.8.0.txt` (3975 chars — ⚠️ ASC caps
that field at 4000 and the first draft was 4571, which would have truncated the 4.3(a) argument
mid-sentence). German re-scanned against a fresh build: clean but for the 2 known DEBUG-only livery
strings. **4.3(a) note: Vineyard Architect is now APPROVED**, so the verifiable-titles line names
three independently-approved titles rather than two.

**► ⭐⭐ INTEGRATION IS VISIBLE NOW, AND THE SETTLE LEVER IS WIRED — built 12 Sep, on `main`,
NOT in a build.** A paying customer emailed asking *how* to "fully integrate" the subsidiary they'd
bought, because the game refused a second acquisition and told them to finish the first. **The
answer is that there was nothing to do** — integration completes on ELAPSED TIME alone (18
sim-months), so the honest reply is "raise the sim speed" (32 min at 100×, 2.2 h at 25×). But the
question was the game's fault, and the audit found two real gaps:
⚠️ **NO VIEW READ `activeIntegration`. AT ALL.** The window, the monthly bill, the seniority dispute
and the settlement price were all live sim state with ZERO UI surface — the only thing the player
ever saw was the refusal text.
⚠️ **`settleSeniority()` had ZERO CALL SITES anywhere.** The "settle for 8%" lever — built, tested,
persisted, balanced — was unreachable; the sidelined crews could only be waited out. **Second time
an orphaned sim lever has surfaced via a customer question rather than a harness** (see ASSIGN TO
NEW ROUTE). A headless harness calls the sim API directly, so it can never notice that no VIEW does.
Shipped: a new **OPS ▸ INTEGRATION drawer** (`OpsSection.integration`, auto-opened by
`beginIntegration`, defaults OPEN on old saves since the case is absent from their persisted
collapsed set) with the subsidiary, a progress bar, the bill, the dispute, and the plain-language
line the email asked for — *"Completes on its own in about N months — there's nothing to finish
early. Raise the sim speed to get there sooner."* — plus the green **`Settle now · $X`** button, six
new read-only readouts on `Sim/Acquisition.swift`, and a refusal text that now names the duration
AND where to watch it. No new persisted state; cash invariant untouched.
Verified: **`AcquisitionMXVerify` ALL GREEN, sections A+B+C+D all stamped** (C and D are new) ·
RoundTrip 13/13 · SaveCompat 12/12 (`OpsSection` is persisted) · OpsTweaks 43/43 · Release build
clean · 15 German entries added.
⚠️ **A HARNESS DEFECT FOUND IN THE SAME PASS: `AcquisitionMXVerify` section D was GREEN while never
executing.** It searched the 12 cheapest carriers for one that happened to dispute and on a miss ran
`check(true, "(skipped)")` — **53/53 ✅ with the whole settle-lever coverage absent.** Same worst
class as the `RotationVerify`/`MXCoverageVerify` silent no-ops, via a different route: a SKIP THAT
COUNTS AS A PASS. Setup is now derived (pick the target first, buy 3 aircraft in a family IT flies)
and a skip is a FAIL. ⚠️ **And do NOT cite this harness by its total** — section A emits 2 checks per
inherited aircraft and the carrier varies with `competitorSeed`, so the same code prints 53/56/63.
`printResult()` now prints a SECTION ROLL-CALL and fails on a missing stamp. **Check the roll-call,
not the ✅.** **DRIVEN LIVE on the iPad Air 13" sim** (`-devScenario integ`, committed): tapping
Settle now · $4.8M moved cash $19.605B → $19.600B, returned all 5 sidelined crews, dropped Needs
Attention 9 → 1, and correctly left the integration itself running at 18 mo left.
✅ **CUSTOMER REPLIED TO — the designer sent it 12 Sep**: integration finishes on its own (18
sim-months; ~32 min at 100×, ~2.2 h at 25×), nothing was stuck, and the next build adds the live Ops
countdown plus the early seniority settlement. ⚠️ **That makes this a PROMISE, not just a fix** — a
paying customer has been told the countdown is coming, so this should ride the next build (58+)
rather than sitting on `main`.
⚠️ **A localization FALSE POSITIVE to not "fix":** the Sim-layer `L()` scan reports `'%@ ↔︎ %@'` as a
German gap. It is not one — the catalog carries the escaped spelling `"%@ ↔\u{FE0E} %@"`, the
IDENTICAL string at runtime (verified by comparison). Re-adding the literal-spelling key
reintroduces a **duplicate key in a Swift dictionary literal, which is a runtime TRAP**.

**► THE 1.7 HANG FIXES — merged to `main`, shipping IN 1.8.0.**
TelemetryDeck on the LIVE app: `hang.under3s` ×43, a first-ever `hang.3to10s` ×1, and
`crash.sig9…rbsterminatecontext-domain-10` ×3 (a RunningBoard **watchdog SIGKILL** — launch/resume
took too long, so the crash and the hangs are ONE defect at two severities). A five-lens hunt with
adversarial verification produced 9 confirmed findings; all fixed. Full detail in CLAUDE.md
"Decided — The 1.7 hang fixes". **The root cause is a PAIR and 1.7 shipped both halves:**
(1) `run()`'s catch-up drain was capped in TICKS not TIME — unreachable below 100×, but at the 100×
1.7 added, 50 ticks is only 125ms of SIM time, UNDER the 250ms input clamp, so once per-tick cost
passed ~2.34ms the loop **pinned at the cap forever** (a permanent ~125–250ms non-yielding block).
Now a 6ms wall-clock budget + `accumulatorMs = min(accumulatorMs, intervalMs)`.
(2) `assignSpareToPendingRoutes()` ran an O(routes × fleet) scan EVERY tick behind the wrong guard
(*a spare exists*, not *a route is pending*) — and 1.7's MX program creates idle spares by design, so
on a big fleet it was permanently on. **Measured A/B: 250 routes/285 aircraft 0.575 → 0.291 ms/tick
(49%); growth for a ×178 routes×fleet increase ×11.0 → ×5.3.** ⚠️ At ≤120 routes the win is inside
the noise — measure at 250+ or you'll wrongly conclude the fix does nothing.
Also fixed: **`closedPlayerRoutes` was UNBOUNDED** (same class as the build-27 save crash — 13.2KB
per closed route crossed the 900KB iCloud limit at ~68 routes and silently killed cross-device sync);
`loadSlot()` was the last sync full-save decode on main; `AirportPhoto` was the only uncached image
loader (a 1456×816 JPEG re-decoded per layout pass); the splash decoded a 2.3MB PNG behind an opaque
cover; selecting an aircraft subscribed all of NetworkView to raw `tick` (**4th instance** of the
documented churn bug); OpsView had no `LazyVStack`.
⚠️ **ONE VISIBLE PRODUCT CHANGE NEEDING YOUR NOD:** `maxClosedRoutes = 40` means beyond 40 closures
the OLDEST leave the Routes panel — CLAUDE.md says routes are "archived, not deleted" so a route that
never recouped stays reviewable. One constant to raise.
⚠️ **AND A REAL SCARE: two harnesses were SILENTLY NO-OPING in the repo.** `RotationVerify` and
`MXCoverageVerify` never called `main()`, so they compiled to binaries that printed NOTHING — which
reads like a pass if you grep for "FAIL". `SaveCompatVerify` was separately DEAD on a compile error
(`GameSnapshot.crewTrainingDue`, removed by the crew-training pipeline), so the regression net for the
SAVE-LOSS bug class had been dark. All three repaired at the source: **55/55 · 81/81 · 12/12**.
Verified: RoundTrip 13/13 · SaveCompat 12/12 · Rotation 55/55 · MXCoverage 81/81 · Park 28/28 ·
SubFleet 15/15 · HubChart 38/38 · OpsTweaks 43/43 · TickCostProbe 5/5 · soak 6/6 seeds × 4 sim-years ·
Debug AND Release builds.
**DRIVEN LIVE on the iPad Pro 11" sim (9 Sep) — all five view-layer fixes, which no harness can see:**
the MX drawer caps at exactly 12 rows then "Show all 17" → expands to 17 → "Show fewer" (chip still
counts the FULL fleet, sort still nearest-date-first, the 4 actionable checks at the head); the
aircraft TOOLTIP updates live with the selected tail (route flipped SEA→SFO / SFO→SEA, status
TURNAROUND → HELD, revenue $13,730 → $14,407, clock 14:49 → 15:52) — **the Canvas/child freeze bug did
NOT recur**, `displayTick` is a sufficient changing input; airport HEROES still resolve in precedence
order (ABQ fell through to its desert archetype, top-bias crop intact); the launch BACKDROP is skipped
under the splash and renders correctly on the naming + livery screens afterwards; and the async
`loadSlot` round-trips (Quit → load menu → tap slot → game on screen at $20.0M, no hang, no empty
frame). Incidentally re-confirmed while driving: the auto-slow banner centres in the CONTENT COLUMN,
auto-slow restore gave 5× back once the cards cleared, red alert chips + drawer auto-open work, and
the map stayed smooth with the traffic slider at 150 background aircraft.

**► ⭐ ON `main`, NOT YET IN A BUILD (8 Sep session — all verified, all pushed):**
- **CREW TRAINING — Phases 1 AND 2 MERGED** (`162b865`, `8383f2c`; design + the designer's 5
  decisions in `aa-1.1.x/CREW_TRAINING_SCOPE.md`, which also records how the BUILT Phase 2 differs
  from its draft). **Phase 1:** hiring takes time (rated hire 10d at 2× course / new hire 45d at
  1.25×), the bundled crew stays line-ready, per-crew 180-day currency with rolling auto-recurrent
  (default ON) and LAPSED + requalify at 1.6× when it's off/unaffordable, a coverage readout (ratio
  + verdict), Crews tab v2, provider "Global Aviation Training"; training cards moved off Ops.
  **Phase 2 — the TRAINING CENTER:** a facility at an operating hub + one sim bay per crew family;
  in-house courses 0.4× price, 30d/2d instead of 45d/4d, no class-slot wait; 4 seats per bay with
  contractor overflow; `totalTrainingCenterSpend` is a new cash-invariant capital term; TRAINING P&L
  payback card on the Crews tab.
  ⚠️ **The recurrent concurrency cap IS the bay capacity for a family with a bay — do not restore a
  pool-fraction cap there.** The A/B probe caught the first version making a BIGGER fleet save LESS
  (surplus overflowed to the contractor at full price; 16 aircraft paid back worse than 12).
  **REPRICED TO REAL SIMULATOR COST + CREW TIME (`1faf20e`, `3bcaa10`) — this supersedes the
  original $8M-ish draft and its 6-aircraft gate.** The designer supplied real figures ($160–260M
  for a 10-bay centre; a Level D full-flight sim costs as much as an airplane), so the facility is
  **$35M** and a bay is **$22M WB / $18M NB / $12M TP-RJ**, opex $150k/mo + $85k/bay/mo, and the
  gate is now **20 aircraft in the family** (`simBayMinAircraft`, raised from 6 — the old gate was
  incoherent at real prices). At those prices the FEE saving alone can never repay a bay (~92 A320s,
  ~1,006 Dash-8s), so the ledger also books the **crew-DAYS an in-house course returns to the line**
  — a crew-day valued at the family's own `dailyNet` per flying aircraft ÷ `coverageContinuousRatio`,
  scaled 0→1 by whether crew is actually the BINDING constraint. Deep cover books ~nothing; stretched
  books real value. That split is the teaching point, so the card shows four lines (course savings ·
  crew time returned · facility + bays · running costs) plus the explainer. Bookkeeping only — no
  cash moves, invariant untouched. Verified `TrainingCenterVerify` **75/75** (test 9 covers the time
  value) + `CrewPipelineVerify` 63/63 + regressions + free-tier probe.
  ⚠️ **PRICES WALKED BACK (designer direction: "not too far — aircraft prices here ARE real world, so
  don't skew things just because sim centres are expensive"). TWO CORRECTIONS, both applying the
  designer's own source properly, NO device price below the real band — shortfall down 65%.**
  (1) The **facility was the building for a TEN-BAY CAMPUS** ($30–40M / 60–75k sq ft is a ten-sim
  figure, and the code said so) while the player builds a one-to-four bay centre. It is now an **$8M
  shell**, with each bay carrying its own ~$3M high-bay hall folded in beside the device: **WB $21M ·
  NB $17M · TP-RJ $13M**. The ten-bay total still lands inside the cited band ($8M + 10×$17M = $178M),
  and an NB bay is ~23% of this game's $74M A320 — the real device-to-aircraft ratio. (2) **Bay opex
  was the heavy-utilization rate** ($85k/mo is a sim run ~20 hrs/day, mostly variable cost); a bay
  running a handful of courses a month costs the FIXED side, **$30k/mo**. Facility opex $150k → $35k.
  Measured (large arm, 45×A320, 60 mo): **−$48.1M → −$21.8M → −$16.9M**. Full table in
  `CREW_TRAINING_SCOPE.md`. ⚠️ Variance across runs is large (that arm's fees came out $8.2M / $5.3M /
  $4.1M on three runs of the SAME config) — read the table as ranges, never tune off one run.
  ⚠️ **THE REMAINING GAP IS THROUGHPUT, NOT PRICE — don't cut prices again.** A new CAPTURE-RATE
  diagnostic in the probe measures actual fee savings against the ceiling if every crew's every
  recurrent ran in-house: **32% for the best arm, 10% for a crew-thin one.** At a price of ZERO the
  centre would still forfeit two-thirds of the saving. **Root cause:** the auto-recurrent scheduler
  filters `status == .available`, so it only ever sees crews idle at that instant — a crew flies ~55%
  of the time, so most of the family is never considered, and one that is flying when its currency
  window closes is never scheduled and **lapses instead of training**. That also means crews lapse
  more than intended in EVERY game, bay or no bay. Fixing it (queue on-duty/resting crews for their
  next release) should move capture toward ~80% and land payback near **~9 years** — the same
  timescale as buying an aircraft here, which is the right feel for real infrastructure.
  `TrainingCenterABProbe` stays a MEASUREMENT tool, not a gate (its old 6/8/12/16-aircraft arms can't
  build a bay at the 20 gate, and its thresholds were set against $750k facility costs).
  Second finding worth keeping: a crew-STRETCHED family books LESS time value than a deeply-covered
  one — the scarcity premium is real in isolation but is swamped because understaffing collapses both
  the `dailyNet` a crew-day is priced against and the number of courses to shorten. **Don't remove
  the shortfall factor to "fix" that** — it's what stops a deeply-covered airline booking value for
  crew it never needed.
- **THE CHIEF PILOT — a persona atop CREWS** (`dd41c23`; designer asked first "is that too much of a
  crutch?", then said build him). **Capt. Morgan Ellis** reads the crew pipeline you already have and
  says what it means: per-family outlooks (`crewOutlook(family:)` → shortfall / training block /
  lapse risk / healthy), so a player can finally tell a PERMANENT crew shortfall from a block that's
  merely IN TRAINING — the exact confusion the designer reported. He advises; he never acts. Portrait
  is `Resources/Brand/ChiefPilot.png` (512×512, designer-supplied via the MJ v8 prompt).
- **FOUR GAMEPLAY ISSUES from the designer's acquisition playthrough — 1, 2 and 3 FIXED; 4 DEFERRED
  to its own session (that's the next session's job):**
  1. **Real carriers hub where they really hub** (`a19f140`; "Air France out of LHR is very odd").
     Root cause was NOT missing data — competitor hubs were DERIVED from "busiest airport in the
     region", so a European carrier could hub anywhere in Europe. `Airline.hubs` is now a real,
     fact-checked field on all **141** roster entries (Air France CDG/NCE, Lufthansa FRA/MUC, Copa
     PTY…), and `Competitor.profile` uses it, falling back to region's-busiest ONLY when a carrier
     has no hub in the region being generated. `CarrierHubVerify` **650/650**.
  2. **Acquisition bugs** (`4484c5d`, `1faf20e`). (a) **Every inherited aircraft arrived grounded
     needing a D check** even though the open books said no capex — `inheritFleet` was the ONE
     owned-aircraft path that never called `seedMXState`, so every tail defaulted to "due at
     0 cycles". Measured 8/8 grounded and $83.5M (24% of the purchase price) in forced MX at close.
     (b) **The subsidiary's finance report showed pre-acquisition numbers forever** — that panel is
     the SCOUTING topline, which by design never moves. Owned subsidiaries now get a **CURRENT
     PERFORMANCE** box computed live (`subsidiaryFinancials`), and the old topline is relabelled
     "AT ACQUISITION". Routes are stamped with an operator of record at first assignment so a
     sub's P&L is attributable. (c) The "no open routes" half was expected — inherited routes are
     capped at the aircraft inherited — but the sub now shows its real live numbers either way.
     `AcquisitionMXVerify` **33/33**.
  3. **Buyback offers price off EARNING POWER, not sunk cost** (`09e49ee`; "why would I ever sell a
     highly profitable hub at 30% of my cost, or give back a slot for less than a month's profit?").
     A healthy hub now fetches **0.90–1.40× establish cost** (vulture 0.35× only when UNDERSTAFFED)
     and a slot offer is **3–8× that route's trailing monthly net** (`trailingMonthlyNet`). Verified
     non-exploitable by a shared-snapshot A/B: accept-every-offer finishes **$210M BEHIND**
     decline-every-offer. `BuybackPricingProbe` 7/7.
  4. ⏭️ **MX + training automation for a 200-plane fleet — NOT STARTED, deliberately deferred.**
     See "NEXT SESSION" below.
- **ROTATION ROUTES SERVE EVERY STOP** (`5dd73f9`, completed in `df49188`; player-reported "my
  multi-leg route doesn't show the dotted lines"). A rotation's `originCode`/`destCode` are only its
  FIRST and LAST stop, so the map drew one arc AND intermediate cities didn't count toward hub
  eligibility (`routesAt`, `hubRoutes`) or the competition fortress/rival-hub factors. All now read
  the full loop (`rotationLegs` / `stops.contains`). **The adversarial review caught that my first
  sweep was INCOMPLETE** — `hubSpokeNet` and `hubDemandMultiplier` were still endpoint-only, so a hub
  newly ALLOWED on an intermediate stop got a +0% bonus and an unrecoupable payback chart; and
  `rotationLegs` emits both A→B and B→A for a 2-stop route, which CoreGraphics drew as a near-solid
  line (my commit message had wrongly claimed "visually unchanged"). Both fixed; RotationVerify
  **55/55**. **If you add code keyed off a route's endpoint pair, ask whether a rotation makes it
  partial** — aircraft-based calls (the CURRENT leg) are correct as-is.
- **Ops tweaks** (`5a36c40`, `dd41c23`, `4484c5d`): every Ops box is a collapsible DRAWER (state on
  the sim, persisted, alerts auto-open their box) with a **red chip** carrying the count when a
  drawer holds something needing attention (so a collapsed drawer can't hide an alert); the auto-slow
  gives the player's SPEED BACK once the cards that arrived while slowed clear; the MX list sorts
  NEAREST DATE FIRST. **`.mxCheck` is EXEMPT from auto-slow** — measured 34% of wall-clock at 5× and
  91% at 100× spent pinned at 1× on a 200-plane fleet, exactly matching the designer's report.
  `OpsTweaksVerify` 43/43.
- **Alerts always centre in the CONTENT column, not the whole window** (`9b9805d`, `09e49ee`) — the
  iPad sidebar rail made the Alerts modal, the auto-slow banner and the milestone toast all read
  off-centre. `.centredInContentColumn(isPadLayout)` in SkySidebar.swift is the shared helper.
- **Graduation-cap icon replaced app-wide** with the designer's Figma art (`09e49ee`, node 158:862)
  via `MilestoneIconArt`, keeping the existing light/dark tints.
- **Transpacific routing fix** (`788fc10`): legs cross the antimeridian seam the short way
  (`FlightPath.nearestCopy`, fixed once at the shared `FlightPath.wrapWidth` level so every caller —
  arcs, suggestion, rotation preview, aircraft motion, weather rejoin — is fixed together and can't
  regress individually); `PathWrapVerify` 16/16; designer-confirmed on device.
- **MX re-imagining SCOPED + DECIDED** (`aa-1.1.x/MX_BASES_SCOPE.md`, all 5 decisions confirmed):
  auto A checks (no cards), MRO +25% / 0–7d slot wait, line stations + hangar bases at hubs or
  ≥3-route airports, MX moves to a Fleet ▸ Maintenance segment. **NOT built — this is issue 4 above
  and the next session's work.**
- **German**: the rotation UI's 21 missing strings (`21c7def`) plus every new string this session
  (crew pipeline, training centre, Chief Pilot, subsidiary P&L, buyback copy). `de-findgaps` is clean
  but for the 2 known DEBUG-only livery strings — run it against the DerivedData you actually built
  into.

**► ⭐⭐ MAINTENANCE AUTOMATION + THE MAINTENANCE NETWORK — BUILT 9 Sep, on `main`, NOT in a build.**
This is issue 4, the designer's "maintenance eats a third of my time at 5×". Full detail in CLAUDE.md
"Decided — Maintenance automation & the maintenance network".
**The headline is a measurement: a 60-aircraft fleet over 180 sim-days pushed 243 MX cards and 100%
of them were A checks. It now pushes 0, with flights unchanged.** A checks are serviced at the gate
with no card and one daily Ops roll-up (policy toggle, default ON, on FLEET ▸ MAINTENANCE); C and D
still ask, because they are real planning events and they are rare. Alongside it: the contract MRO
is now the default provider at +25% with a 0–7-day hangar-slot BOOKING the aircraft keeps flying
through (charged once, exempt from the card and from force-grounding), and you can build your own
**line stations ($4M) and hangar bases ($18M/$45M)** at a hub or any ≥3-route airport — −30% cost,
−25% downtime, no slot queue, **A checks overnight with zero lost legs**, 2-aircraft C/D capacity
with MRO overflow, and a per-base payback ledger that books fees saved AND flying days returned.
`totalMXBaseSpend` is a new cash-invariant term.
⚠️ **The cycles→days bug is fixed**: four sites converted at a hardcoded 2 while the engine flies
~3.52, so every maintenance DATE was ~76% too far out — now one derived constant. It was not only
cosmetic; `mxDaysPastDue` feeds the C/D calendar grace, so a "25-day" grace really ran ~44 days.
**BALANCE GATE — SETTLED.** The HANGAR passes exactly (−$8.0M at 6 aircraft, +$22.7M at 20). The
LINE STATION gates on NETWORK SHAPE rather than fleet size — a scattered network never pays one
back, a concentrated one pays back from ~4 served aircraft — which was raised with the designer and
**DECIDED 10 Sep 2026: KEEP the $4M price.** That is its intended role: the cheap on-ramp that
rewards concentrating a network, with the $18M/$45M hangar as the real fleet-size decision. The
~$14M alternative and reopening §6 decision 2 were both priced and declined. **Don't re-flag it as
a failed gate** — re-measure only if a later change makes it dominant in a NEW way. Table in
`MX_BASES_SCOPE.md` §7.
⚠️ **Two silently-wrong things found in passing:** 15 German keys were DEAD (written with a
different escape from their call sites, so they never matched — German players saw English), and
`OpsTweaksVerify` test 3 had been red at HEAD (39/43) while the handoff recorded 43/43, because the
crew-training pipeline invalidated its setup. Both fixed. **A recorded pass is not a pass.**
Verified: MXBaseVerify 86/86 · MXBaseABProbe 7/7 · MXCoverage 82/82 · RoundTrip 13/13 · SaveCompat
12/12 · AcquisitionMX 35/35 · OpsTweaks 43/43 · Rotation 55/55 · CrewPipeline 63/63 · soak 6/6 seeds
× 2 sim-years · Debug + Release builds · German clean · and driven live on the iPad sim via the
committed `-devScenario mxbase`.
**`MXProbe` IS GREEN AGAIN (10/10) — a real balance defect was found and fixed here.** Its AOG
counter was broken (one fleet-wide edge test collapsed every overlapping AOG into a single count —
it read 5 in both arms; `countAOGOnsets` counts per-aircraft edges now, with four self-checks). With
a working instrument, and re-measured at **20 runs** (5 could never resolve a ~1% margin), deferring
ALL maintenance turned out to beat servicing in **20 of 20 runs** — a real defect, already shipping
in 1.8.0. Fixed by raising **`mxOverdueCostSurcharge` 2.5 → 5.0** (designer direction): serviced now
wins **20/20** (+8.4 SE), deferring costs MORE maintenance than servicing rather than less, and
takes +15% more AOGs. Well targeted — with auto-A ON a normal player's A checks never go overdue, so
it bites the player who ignores a C or D card. ⚠️ **Re-measure with `MXProbe.swift 20` after any
change to that constant.** Detail in CLAUDE.md and TASKS.md.

**► ⭐⭐ ISSUE 4 IS COMPLETE — the TRAINING half is fixed too (10 Sep).** The auto-recurrent
scheduler filtered `status == .available`, so it only ever saw crews idle at that instant; a crew
flying when its currency window closed was never scheduled and **LAPSED instead of training**, then
requalified at 1.6×. Fixed on two paths sharing one booking helper: the daily sweep now also sees
**RESTING** crews, and **`releaseCrew` offers a landing crew to recurrent before it goes back on the
line** — the one guaranteed moment a continuously-flying crew is reachable (checked BEFORE the rest
branch, since a course zeroes duty/rest and outlasts a rest period).
**Measured: course-fee capture 32% → 101–112% across all four probe arms, and in an ordinary game
with NO training centre, 540 sim-days × 19 crews went from 3 lapses + 3 requalifications to ZERO —
with flights unchanged** (14,328 vs 14,370 cycles). The remaining training-centre shortfall is
PRICE, which the designer already settled (don't cut below real device cost).
⚠️ **Two more stale harnesses found doing it:** `TrainingCenterVerify` was 71/75 at HEAD (the bay
prices were walked back to NB $17M / WB $21M / TP $13M and its literals still said 18/22/12) — now
derived from `simBayCost` so a reprice can't break it again, **76/76**. And `CrewPipelineVerify`
test 4 has a real flake: nothing there answers the decision queue, so a random AOG parks the
aircraft and "the aircraft flies again" goes red for reasons unrelated to training. It now drains
AOG cards, like the labor-action guard beside it.

**► (historical framing of issue 4, kept for the quotes) MX + TRAINING AUTOMATION AT SCALE.** The designer's words: *"For my
200-plane fleet the maintenance stuff takes up 1/3 of my time at 5×, and near all-time at anything
faster. This really needs to be automated via maintenance bases or something as it's very tedious.
Same with training."* Half of it is already addressed — the auto-slow exemption stopped MX pinning
the sim at 1×, and the Chief Pilot answers "shortfall vs. in-training" — but the CARD VOLUME itself
is untouched. Build `aa-1.1.x/MX_BASES_SCOPE.md` (all 5 decisions already confirmed): auto A checks
with no cards, MRO +25% / 0–7d slot wait as the default provider, line stations ($4M) + hangar bases
($18–45M) at hubs or ≥3-route airports with 2-aircraft C/D capacity per hangar line, and MX moving to
a **Fleet ▸ Maintenance** segment with Ops keeping only alert cards + a one-line summary drawer.
⚠️ **A REAL BUG TO FIX IN THAT PASS, found while measuring:** four sites in Simulation.swift
(~lines 3715 / 3773 / 3827 / 3879, each commented "~2 cycles/sim-day") convert cycles→days at
**2 cycles/day** when the engine actually flies **~3.52**, so every maintenance date the player sees
is ~76% too far out. Make it one shared constant, and re-check `MXCoverageVerify`.

**► ⭐ MULTI-CITY ROTATIONS — MERGED to `main` (Phases 1–2), NOT yet in a build (4 Sep).** A route is
now an ordered rotation loop of 2–5 stops flown by an aircraft you pick FIRST (Open Route → WHICH
AIRCRAFT? → tap the sequence → confirm); each leg is range-checked; the loop auto-repeats; the classic
2-airport shuttle is the 2-stop case (nothing regressed). Full design + status in
`aa-1.1.x/MULTI_CITY_ROUTING_SCOPE.md`; CLAUDE.md "Decided — Route Network" has the summary. Verified
RotationVerify 34/34 + RoundTrip 13/13 + soak 6/6 + Debug build; designer confirmed it works on device.
**All three follow-ups CLOSED 4 Sep** — the balance pass (`RotationBalanceProbe` 6/6: a rotation is a
genuine tradeoff, no retune), the rotation-aware label audit (every whole-route display reads as a loop;
RotationVerify 40/40), and the German for its UI (8 Sep, `21c7def`). The feature is complete and
ships with the next build; the only residual is a nice-to-have live re-drive of the exact
pick→sequence→confirm gesture chain (designer already confirmed it works on device).

**► ⭐ 1.7.0 (build 56) IS LIVE — `READY_FOR_SALE` (confirmed via ASC 8 Sep; submitted 3 Sep and
approved since).** ⚠️ **Next new build = 57+.** Two consequences worth carrying: 1.7 is the first
build whose MetricKit reports carry **build-at-occurrence tagging**, so the TelemetryDeck Errors
dashboard can finally separate stale hangs from live ones (group by message, not by error id); and
1.7 put the **100× speed pill** in players' hands, on a sim whose tick loop runs on the MainActor —
the prime suspect for the ongoing `hang.under3s` signal. The whole release chain ran end-to-end from
the CLI: version bumped 1.6.0→1.7.0 / 55→56
(6 configs), archived → exported → validated (VERIFY SUCCEEDED) → uploaded (UPLOAD SUCCEEDED,
**Delivery UUID `40110d3c-3dfa-4587-991f-c6628f26ad98`**, 78.5 MB), build 56 attached to the v1.7
record, review submission created + submitted. **The 40 new city hero images landed and were
BUNDLED** (108 city + 9 archetype heroes; IPA grew ~67.7→78.5 MB, as predicted; `archetype-audit`
bundled-set updated to 108). ASC v1.7 record (id `e3ec8afb-6d8d-42fe-ad41-efbf301f2679`): en-US +
de-DE What's New set, App Review notes set (`aa-1.1.x/app-review-notes-1.7.0.txt`, §1 4.3(a) studio
block, 3980 chars), Game Center per-version checkbox enabled. Review submission id
`92dd48c8-b6a5-49fa-8f89-f375d5a29ef3`, submitted 2026-09-03T22:41Z. Commits `901bb53` (build) +
`2a5e5d3` (docs) pushed to `main`. **Next new build = 57+.** Watch review state:
`cd ~/Architect\ Universe/~PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`.
What's IN 1.7 (all verified, driven live):
- **MX MAINTENANCE PROGRAM** (was on `mx-program`, now merged) — player-driven SCHEDULED A/C/D
  checks (B obsolete) distinct from AOG, in a new **OPS ▸ MX** section, cycle+calendar-driven
  (D = lifespan/3). Deferral has teeth (overdue AOG ×6, repair ×4, hard-window force-grounding,
  2.5× overdue cost surcharge — the surcharge is what makes servicing early matter). Full spec:
  `aa-1.1.x/MX_PROGRAM_SPEC.md`.
- **MX EXPANDED DETAILS + LIKE-SIZE ROUTE COVERAGE** (this session, driven live with the designer)
  — tap a due row → Details (downtime, cost with overdue surcharge broken out, days-to-forced-
  grounding, route); C/D checks get **temporary substitution** coverage (a like-size idle spare
  covers the route, the original reclaims on shop-return); a **787 can't be covered by an A320**
  (seats ≥75% / range ≥85%); no suitable spare → **Acquire a replacement** (→ Fleet Marketplace,
  auto-covers on buy + returns to Ops) or **Suspend route** (pauses, then resumes). C/D forced-
  grounding uses a fixed CALENDAR grace (fixed the absurd "D due now, grounding in 3,660 days").
  Verified `aa-1.1.x/MXCoverageVerify.swift` **81/81** + soak 6/6 + RoundTrip 13/13.
- **THREE player-feedback fixes** (from the 1.6 review triage, `aa-1.1.x/PLAYER-FEEDBACK-1.6-TRIAGE.md`):
  crew tuning (labor ~0.5/sim-yr not ~1.25; training sidelines ¼), **100× speed pill +
  auto-slow-on-event**, route-swap discoverability hint. The 100× pill is eyeballed (renders
  fine); auto-drop confirmed live.
- **AUTO-SLOW ALERT BANNER** (this session) — when an event snaps the sim high-speed→1×, a banner
  drops naming what happened; **persists until tapped** (tap → Alerts to resolve). Custom Figma
  gauge icon.
- **ON-BRAND FIGMA ICONS** (designer-supplied, node 150:998) in all milestone toasts + cover-
  confirm banner + (contextual) hub badges/club/market/network. `MilestoneIconArt.swift` renders
  them via SVGPath keyed by the SF-Symbol name. The Finance Pro/verified seal stays SF.
- **REAL LAUNCH-DATE START** (this session) — a new game opens on the player's real date + season
  + year (was random), mapped onto the 30-day-month calendar. GameClockVerify 23/23.
- **GERMAN** folded for every new user-facing string (MX/coverage/auto-slow/naming). `de-findgaps.py`
  clean except 2 DEBUG-only livery-gallery strings. AI-drafted (native review still waived).
- **CrashReporter build-at-occurrence tagging** (earlier this week) — reads the TD `hang.under3s`
  signal correctly.
- **NOT app code, also on `main`:** `aa-1.1.x/HERO-PROMPTS-75.md` — the next-75 airport-hero list
  (city · MJ prompt · filename); the designer is producing/staging 50 of them. If those images
  land before the build, they're a bonus content add (bundle them, re-run `archetype-audit`); if
  not, 1.7 ships without them and they become a fast 1.7.1/1.8 content update. **Heroes are ~45%
  of the store download** (67.7 MB now; +50 heroes ≈ +20 MB → ~88 MB, still fine; JPGs don't thin).
- **SHELVED: the PM BUDGET** (`maint-budget-t22` branch) — two sweeps proved it trivial; MX
  supersedes it. Don't revive unless the AOG base rate is raised.

**► 1.6.0 (build 55) = German localization + city hero artwork + per-achievement GC icons — APPROVED +
LIVE (`READY_FOR_SALE`, 31 Aug; released AFTER_APPROVAL).** German shipped and CLEARED review — the 4.3(a)
localization-only reflex was dodged exactly as planned: the city artwork made 1.6 a real content update,
not a pure-localization diff (unlike FC's rejected localization-only 1.3). German is AI-drafted (native
review waived); watch post-launch DACH feedback and ship a native polish + `de-findgaps.py` re-scan in a
later version if awkward phrasing surfaces. Both feature branches merged
to `main` after 1.5 went live: `de-translation` (German, `3ed01e9`) + `airport-heroes-achievements` (77
city hero images total — 43 added this batch — + crop-toward-top framing fix + GC per-achievement icon
script, `396da4e`). Bumped to 1.6.0/build 55 (`d357217`, MARKETING_VERSION 1.5.0→1.6.0 + CURRENT_PROJECT_VERSION
54→55 ×6), archived → exported → validated → **uploaded via the CLI chain** (Delivery UUID
`b155182a-0351-4f4a-b324-0341fb0b16b1`), then the designer-side steps completed and the version submitted:
build 55 attached, `aa-1.1.x/app-review-notes-1.6.0.txt` (§1 4.3(a) studio block) pasted into App Review
notes, the 20 de screenshots (`App Store Screenshots/de/`) added to the de-DE localization. ASC v1.6 record
(id `cae19c1c…`) carries de-DE (Promo/Description/What's New/Keywords) + en-US What's New + version-agnostic
Promo. German shipped AI-drafted (native review waived by the designer; 1.6 dodges the 4.3(a) localization-only
reflex by ALSO shipping the city artwork — a text+visual update, not localization-only). Next new build = **56+**.

⚠️ **AIRPORT HERO FRAMING (1.6):** the hero band now crops toward the TOP (`AirportHero.biasFromTop = 0.38`,
`maxHeight` 220→300) so skyline heroes keep their sky — `scaledToFill` used to center-crop the 16:9 source
into the shorter 2.5:1 band and lop the sky off. When adding future heroes, keep the subject center-to-upper.
Full detail + the working-folder gotcha (`Resources/Airport Photos` with a space is the SOURCE library, NOT
the bundle `.../AirportPhotos/`) are in `AIRPORT_PHOTOS_SPEC.md` + the "Decided — Airport hero images" section
of CLAUDE.md.

**► 1.5.0 (build 54) = A350-1000 + 747-8i + map-render throttle — SUBMITTED FOR REVIEW (30 Aug).**
Merged to `main` (PR #2, branch `aircraft-and-thermal`). Fleet 35 → 37: **Airbus A350-1000** (`A35K`,
shares the `A350` crew rating) + **Boeing 747-8i** (`B748`, its OWN `B747-8` crew family) — a paying
player asked for the legendary jumbos + newer A350s; both pass the certified-and-in-service bar, with
real Figma side-view art + traced fin masks. The 747-8i REVERSES the earlier "skip the passenger -8"
call; the -400 (`B747`) stays too. Also a **thermal/battery fix**: `LiveMap` now reads the throttled
`Simulation.mapTick` (~30fps) instead of raw `tick`, cutting the full-world Canvas repaint from
~125/sec at 25× to ~30/sec (a paying player's "device gets hot" report). Build 54 uploaded via the CLI
chain (archive → export → validate → upload), attached to the 1.5 record; **What's New + promotional
text + App Review notes all set via the ASC API** (`aa-1.1.x/app-review-notes-1.5.0.txt`, 3990 chars,
carries the §1 studio-context block). Next new build = **55+**. Marketing bump to 1.5 (minor feature),
not a patch — the two aircraft are user-facing content.

**► 1.4.3 (build 53) = ASYNC SLOT DECODE — APPROVED + LIVE (`READY_FOR_SALE`, 28 Aug).** Merged to
`main`; the decode-side twin of the 1.4.2 save fix: `GameStore.slotInfos()` did up to 3 full save
decodes synchronously on the main thread from the load menu — a stall on large saves. Now
`slotInfosAsync` runs them on the shared serial `saveQueue` and populates on the main actor. **First
Airline release approved WITH the §1 studio-context block in the App Review notes** — approved same
day during the account-wide 4.3(a) cascade (see below). ⚠️ **App Review notes carry the §1
studio-context block (4.3(a) armor) — MANDATORY on every Architect submission now; reuse the latest
`aa-1.1.x/app-review-notes-1.5.0.txt`, just bump the version line.**

**► ⚠️ APPLE 4.3(a) IS ACCOUNT-WIDE (as of 27–28 Aug) — read before ANY submission.** Apple's
Guideline 4.3(a) "spam/repackaged-template" reflex rejected Vineyard 1.0, Foundry 1.0, AND FC
Architect 1.3 (localization-only, after 5 prior approvals) in one window; a formal appeal covering all
three was filed 28 Aug (awaiting Apple). Airline is SAFE (never rejected; 1.4.1/1.4.2/1.4.3 all cleared
or are clearing during the cascade) — but a trivial update gets NO immunity (FC's localization-only 1.3
proves it), so **every Airline submission now leads its App Review Notes with the studio-context block**
(Airline's own approval history + the Postmark Digital studio framing + Airline's unique-systems
paragraph). The canonical playbook + Airline's filled-in unique-systems paragraph live in
`PostmarkOps/APP_REVIEW_NOTES.md`. The 1.4.3 notes (3988 chars, under the 4000 limit) are the template
for the next one — reuse them, just update the version line.

**► 🇩🇪 GERMAN LOCALIZATION — MERGED TO `main` and SHIPPING IN 1.6.0 (31 Aug).** `de-translation` merged
to `main` (merge commit `3ed01e9`, direct no-ff, pushed) once 1.5.0 went `READY_FOR_SALE`. The whole app
is German (648 catalog keys + Sim `L()` shim + flavor prose); English byte-identical; build clean; the
comprehensive `de.lproj` gap scan (`aa-1.1.x/de-findgaps.py`) shows 0 real gaps. **Designer chose to ship
German AI-drafted — NO native review** (the standing gate was waived; the risk is a first-language market
noticing MT, and the 4.3(a) localization-only reflex, which 1.6 dodges by ALSO shipping the city assets).
**ASC de-DE localization CREATED on the v1.6 record** (id `c32607c7…` under version `cae19c1c…`): Promo /
Description (2688 chars) / What's New / Keywords all set via `asc.py`; en-US What's New set too. Designer
adds the 20 de screenshots (ready in `App Store Screenshots/de/`). Currency shows € on German devices
(symbol-only, no FX). Driven by TelemetryDeck (German = 16% of preferred language, #2). Register **du**.
⚠️ **1.6.0 BUILD NOT CUT YET** — held at 1.5/54 until the `airport-heroes-achievements` branch (city
assets + GC per-achievement icons) also merges to `main`, so build 55 carries BOTH. Then bump
`CURRENT_PROJECT_VERSION` (6 configs) → 1.6.0/build 55 → archive → upload. Reuse
`aa-1.1.x/app-review-notes-1.5.0.txt` (§1 studio block, bump the version line) + add a German line.

**DONE 30 Aug (5 commits on top of the earlier 12 — the whole app is now German):**
- **`main` MERGED IN** (0 behind — carries the 1.5 A350-1000/747-8i + map throttle; their 2 flavor lines
  came with the merge). Post-merge: still 646/646 view keys, 0 missing.
- **View catalog: complete** (648 keys). A scan of the SHIPPED `de.lproj` for `de==en` returns ONLY
  loanwords (Crew/Route/Reputation/Marketing), the brand wordmark, `Pro (DEV)` (DEBUG-only), and pure
  format specifiers — **zero real translatable strings left English.** (This scan is the reliable
  "did I catch the catalog-bypass gaps" check — re-run after any string touch.)
- **FLAVOR PROSE done** — `AircraftType.flavor` (37) + `Airport.destinationFlavor` (49) now route through
  the `L()` shim (were raw English `String`) and all 86 lines are German in `simLocalizationTables["de"]`.
  Verified live (A320 detail: "Das Single-Aisle-Arbeitstier").
- **Sim shim: complete** for every user-facing Sim string. **RoundTripVerify 13/13 + soak 6/6 GREEN**
  after the Sim-layer flavor touch (English byte-identical).
- **VISUAL PASS done** (iPhone portrait + **iPad landscape**) — found + fixed **~78 category-2 bugs** a
  key-count can't see (a String reaching `Text` via a param/computed-var/concatenation, not a literal, so
  it bypasses the catalog). iPhone found 5 (FleetView "All" value, crew "Reserve **$**5k" / AOG
  "Expedite **$**15,000" hardcoded `$`, fuel-hedge "premium" stale-key mismatch, Finance fleet footnote,
  `Boarding` phase). Then the **iPad-landscape docked rail** — which opens panels the iPhone floating
  overlay hides — exposed ~73 MORE across whole panels: the Network ACQUIRE card, RoutesPanel detail, the
  aircraft tooltip, the paywall pitch, AirportInfoCard hub strings, GameOverView. NONE device-specific
  (English on iPhone too). All fixed (param → `LocalizedStringKey`, value → `String(localized:)`, Sim →
  `L()` shim). **⚠️ The definitive check is `aa-1.1.x/de-findgaps.py`** (`DD=<root> python3
  aa-1.1.x/de-findgaps.py` after a Debug build) — it scans ALL `*.stringsdata`; a `de.lproj` `de==en`
  diff and a hand-picked file list both MISS category-2 gaps. Final: 641 keys, 0 real gaps.
- **Euro everywhere** + **20 de App Store screenshots** (in `App Store Screenshots/de/`).
- **AI-drafted, NO native review yet** (designer accepted the drafting risk).

**WHAT'S LEFT TO FINALIZE (next session):**
1. **NATIVE-GERMAN REVIEW** — the real remaining risk. Every string is AI-drafted; the flavor prose
   especially reads as marketing copy where a first-language market notices MT. A native speaker polishes
   the `de` catalog + `simLocalizationTables` (all editable in place). Cost/time item, not code.
2. **DEVICE STRING-LENGTH QA** — German runs ~30% longer. The iPhone-portrait visual pass found NO
   overflow (control-bar buttons at `minimumScaleFactor(0.7)`, stat chips all fit), but check iPad +
   landscape + the longest strings before ship.
3. **ASC German listing** (name/subtitle/description/keywords/screenshots — the 20 screenshots exist) +
   German Game Center achievement localizations (in ASC via `asc.py`).

⚠️ **THE KEY GOTCHA (in `aa-1.1.x/LOCALIZATION_SCOPING.md`):** SwiftUI only auto-localizes string
LITERALS in `Text("…")`. A string reaching `Text` as a `String` VARIABLE (data array, model prop, a
`String`-typed helper param, or a `String`-returning computed var built by concatenation) silently
bypasses the catalog even with a perfect translation. Fix = `LocalizedStringKey` param, or
`String(localized:)` at the build site, or `Text(LocalizedStringKey(theString))`. Verify by scanning the
built `de.lproj` for `de==en` (definitive) AND by force-launching in German. All 5 bugs this session were
this class — they're mostly gone now, but a NEW string can reintroduce one.
**Reference (both on `de-translation`):** `aa-1.1.x/LOCALIZATION_SCOPING.md` (done/remaining map + method)
+ `aa-1.1.x/de-glossary.md` (terminology — keep terms consistent with it). **SHIP GATE:** never release
standalone during the 4.3(a) cascade (FC's localization-only 1.3 was rejected) — bundle the `de` turn-on
with a content update, or wait for the account to cool. A native-German review pass before go-live is
strongly preferred.
**⚠️ SIMULATOR NOTE:** the input channel dropped taps CONSTANTLY this session (tab-bar/button taps silently
no-op'd while the app was alive). A fresh `simctl launch` resets it briefly; re-screenshot before calling a
control broken. Screenshots always worked.

**► 1.4.2 (build 52) = ASYNC SAVE fix — APPROVED + LIVE (`READY_FOR_SALE`, 27 Aug).** Merged to
`main`; fixes the `hang.under3s` TelemetryDeck signal by moving the save encode/write/mirror off the
main thread. FOLLOW-UP (still open, both fixes): the `hang.under3s` count in TelemetryDeck is the real
verdict — but MetricKit tags a hang with the version running when DELIVERED, not when it OCCURRED, so
1.4.1-vs-1.4.2-vs-1.4.3 attribution stays fuzzy. Read the count TREND over 1–2 weeks as adoption
grows, not an instant before/after. A future touch could tag hang telemetry with the app version at
occurrence to disambiguate — worth it only if the metric stays interesting.
The MetricKit CrashReporter shipped in 1.4.1 surfaced its first real signal — `hang.under3s` ×13 in
the TelemetryDeck Errors dashboard — traced to the synchronous main-thread save (encode + `.bak`
re-decode + write + iCloud mirror, all on the main actor). Fixed: `GameStore.saveInBackground` runs
the heavy work on a serial `DispatchQueue` off-main (snapshot still captured on main); autosave-on-
background holds a UIKit `beginBackgroundTask` assertion so the write finishes before iOS suspends.
Verified on device (SAVE + background both advance the save file, no hang, app survives) + harness
RoundTripVerify 13/13. DESIGNER STEP: create the 1.4.2 version record + attach build 52 + What's New
(a stability line) + submit. Next new build = **53+**. FOLLOW-UP: re-check the `hang.under3s` count in
TD after 1.4.2 is live — it should drop. Full detail: CLAUDE.md "ASYNC SAVE".

**► 1.4.1 (build 51) = ONE combined release — the Game Center WAKE fix + the Tech Ops
modernization. APPROVED + LIVE (`READY_FOR_SALE`, 24 Aug).** Both branches (`game-center-1.4.1`,
`tech-ops-modernization`) merged to `main`; build 51 carries both (build 50, the GC-only cut, was
superseded). The GC wake fix (`wakeAccountRecord`) is now public — achievements sync to the Apple
Games app; the rocket is OFF (blank in-app dashboard is a separate GameKit issue). Tech Ops
(RC/Telemetry externalization + Test Store + MetricKit) is now the shipped mainline pattern. Next
new build = **52+**.

**► ONE FOLLOW-UP worth remembering (no build needed):** ~1 week after this release (so ~31 Aug),
check whether Apple's Game Center rocket now populates on the LIVE build on-device (the store-side
GC-declaration propagation theory — FCA is checking the same on their side). If it populates, a
future 1.4.2 can re-enable the standard `GKAccessPoint` (wiring documented in `GameCenter.swift`).
Also parked: a custom in-app SwiftUI achievements view (FCA's pattern; shape saved in memory) —
build it if the rocket stays blank and the designer wants an in-app surface.

**What's in build 51 — the GC wake fix:** after 1.4 went live the App-Store build's Apple Games
dashboard was STILL EMPTY (the "public release heals the stale record" theory FAILED). FC Architect's
device A/B found the trigger: a `GKAchievement.report` → `loadAchievements` ROUND-TRIP from a signed-in
device. AA reported but NEVER loaded — the missing half. `GameCenter.wakeAccountRecord()` FIXES it
(verified on device: AA now shows in the Apple Games app "Now Playing", achievements pill 3/29, real
badges with dates). The native `GKAccessPoint` rocket STILL opens a BLANK in-app dashboard (a SEPARATE
GameKit issue, confirmed identically on FCA, not fixable in our code), so **the rocket stays OFF** — no
in-app GC entry point; players reach achievements via the Apple Games app + milestone toasts. DO NOT
re-add the dead workarounds. Possible 1.4.2 follow-ups: a custom SwiftUI achievements view, and a
~1-week re-check of the plain rocket (store-side-propagation theory). Full detail: CLAUDE.md's GameKit
note, "CORRECTION + FIX — 1.4.1".

**What's in build 51 — Tech Ops modernization (plumbing + observability, NO gameplay change):** a
Postmark Tech Ops audit found Airline behind its own siblings on the RC/TelemetryDeck patterns it
inspired. (1) RevenueCat key externalized to a gitignored `Secrets.xcconfig` → Info.plist →
`Store.resolveKey` with a Test Store path + the four `isConfigured` guards — the Test Store path is
LIVE-VERIFIED (the designer pasted the real `test_` key; a `-useTestStore` Debug launch logged
RevenueCat's "Using a Test Store API key"). (2) `Telemetry.isDriven` guard + externalized app ID + an
XCTest linkage proof (`TelemetryTests`, 9/9). (3) MetricKit `CrashReporter.swift` (crash/hang TYPE-only
→ Telemetry Errors). Full detail: CLAUDE.md "Decided — Tech Ops modernization" + TASKS.md.

_1.4.1 in one paragraph:_ after 1.4 went live the designer checked the App-Store build on-device —
the Apple Games dashboard was STILL EMPTY for AA (the "public release heals the stale record" theory
FAILED). FC Architect's device A/B found the real trigger: a `GKAchievement.report` →
`loadAchievements` ROUND-TRIP from a signed-in device. AA reported but NEVER loaded — that missing
half is why it stayed poisoned despite being live + reporting. `GameCenter.wakeAccountRecord()` (the
load call, once after auth) FIXES it — **verified on device (build 49): AA now shows in the Apple
Games app "Now Playing", the in-app achievements pill reads 3/29, and the Apple Games grid renders
our real badges with dates.** BUT the same device test showed the native `GKAccessPoint` rocket STILL
opens a BLANK in-app dashboard, and FCA confirmed the IDENTICAL split on FCA (record woken + Apple
Games populated, but rocket's in-app VC blank; restart doesn't clear it). So the blank dashboard is a
SEPARATE GameKit issue, not fixable in our code — **1.4.1 ships the wake with NO in-app GC entry
point; the rocket is re-stubbed OFF** (the `atLaunchScreen` + auth-gated wiring is documented at the
site for a clean re-enable later). Players reach achievements via the Apple Games app (now populated)
+ the app's milestone toasts. DO NOT re-add the dead workarounds (trophy button / `.pageSheet` /
floating Done). Two open probes may feed a 1.4.2: FCA is testing a
`GKGameCenterViewController(state: .achievements)` button vs the rocket's `.dashboard` state, and both
apps re-check the plain rocket in ~1 week for the "store-side GC declaration propagates after a GC
release" theory (FCA 1.2 live ~2 days, still blank). Next new build after 50 = **51+**. Full detail:
CLAUDE.md's GameKit note, "CORRECTION + FIX — 1.4.1".

**► 1.4 (build 48) = the GAMEPLAY PACK — LIVE (`READY_FOR_SALE`).**
(Builds 45–47 are SUPERSEDED. The Game Center ENTRY-POINT saga, condensed: an app that shipped
before its GC integration (AA 1.0–1.3, same as FCA) carries a stale server-side record that
poisons GameKit's own dashboard UI — Apple's rocket opens empty, and every client-side
workaround lost on device (47's trophy→grid dead-ended with no exit; GameKit forces its own
full-screen). Family decision (mirrors FCA build 35): **48 ships reporting-only, NO in-app GC
UI** — players view achievements in the Apple Games app; after 1.4 is publicly released, verify
the rocket heals on device and re-enable the standard GKAccessPoint in a 1.4.x (one line, site
documented in GameCenter.swift). Attach BUILD 48 to the 1.4 version record.)
Six features from the critical gameplay review (branch `gameplay-lever-pack`, now MERGED to
`main`): per-route FARE LEVER (Discount…Flagship, asymmetric elasticity), SESSION BRIEFING
(welcome-back ops card on load), FIRST QUEST (guaranteed curated airport offer for new
airlines + rewritten tutorial), GAME CENTER (29 achievements ← milestone ladder + 2
efficiency leaderboards; entitlement in the binary), RIVAL FLAVOR + free-tier depth teaser,
and SUBSIDIARY FLEET GROWTH (buy-for/transfer — a paying-player request). Verified:
FareVerify 17/17 · QuestBriefVerify 19/19 · SubFleetVerify 15/15 · OfferSpread 5/5 · soak
6/6 seeds ALL GREEN · live Simulator drive of every surface. Archived/validated/uploaded via
the CLI chain (build 48 Delivery UUID `db71f0fc-47fd-434b-90b1-3f3cb4544987`; superseded:
45 `a0a46258-…`, 46 `0ac75396-…`, 47 `e4e6ce5f-…`).
- **The ASC Game Center config is DONE, created via the API** (`aa-1.1.x/gc_setup.py` +
  `gc_upload_images.py`, both idempotent; shared gold-ring badge on all 29, delivery COMPLETE;
  see GAMEKIT_SETUP.md). It all goes live with the 1.4 release.
- **SUBMITTED (21 Aug):** designer's TestFlight passes on 45–47 confirmed auth + reporting
  ("Signed in as mdspike", 29 achievements counted, "First Jet" earned); 1.4 version record
  + fare-lever-led What's New + build 48 attached + the Game Center per-version checkbox
  enabled via API + App Review notes rewritten → `WAITING_FOR_REVIEW`. Auto-releases on
  approval. Next new build after 48 = **49+**.

**► WHAT THE NEXT SESSION SHOULD KNOW (21 Aug, end of the 1.4 session):**
- **App Review notes for 1.4 were REWRITTEN via the API** (they were stale: subscription-era
  $5.99/mo pricing + 3.1.2 auto-renew text, the old 3/2 free caps, and "no analytics SDKs" —
  false since TelemetryDeck shipped in 1.2.1). Now: one-time unlock, 6/5 caps + paths to the
  paywall, a GAME CENTER section explaining reporting-only/no in-app browser is deliberate,
  the livery + first-quest first-launch flow, the fare control, TelemetryDeck as anonymous
  aggregate analytics. Review details are editable while `WAITING_FOR_REVIEW`.
- **The `gameCenterAppVersion` checkbox:** ASC refuses to submit a build carrying the GC
  entitlement until the version's Game Center checkbox is enabled. Done for 1.4 via
  `POST /v1/gameCenterAppVersions` (relationship appStoreVersion; came back enabled). **FCA's
  1.2 will hit the same error** — same one-liner.
- **AFTER 1.4 IS LIVE — the one real follow-up:** check Apple's Game Center rocket on the
  live build. If the stale server record healed (the theory from FCA's device A/B; 1.4's
  release is the heal mechanism), re-enable the standard `GKAccessPoint` in a 1.4.1 on BOTH
  the load menu and the naming screen. `GameCenter.swift` documents the whole saga at the
  hard-off stub. No custom presentation hacks — they all dead-ended on device.
- Non-blocking: subsidiary aircraft render competitor-purple on the map (no third colour
  state); all 29 GC achievements share one badge (replaceable via `gc_upload_images.py`);
  remove Monthly/Yearly from the RevenueCat offering once the unlock dominates (never delete
  the sub products); Aerospace + Mars Colony have no Telemetry at all.
- Tooling that now exists: `aa-1.1.x/gc_setup.py` + `gc_upload_images.py` (ASC Game Center
  via API, idempotent), `FareVerify` / `QuestBriefVerify` / `SubFleetVerify` harnesses,
  `-devScenario subfleet`. The release chain (archive → export → altool validate/upload) ran
  four times this session from the CLI without touching Xcode.

**► 1.2 (build 41) is APPROVED + LIVE** — the MONETIZATION PIVOT is public (subscription →
one-time "Full Unlock", $9.99 founding rising to $19.99 on Dec 1, 2026; two non-consumables
`aa_unlock_founding_player`/`aa_unlock_standard` under RevenueCat packages `founding`/
`standard`; subs RETAINED for coexistence so existing subscribers keep Pro). It went
`WAITING_FOR_REVIEW` → `READY_FOR_SALE` early 18 Aug after ~6 days in Apple's queue (a
first-time monetization change + 2 IAPs drew a longer look than the ~1-day 1.1.x reviews).
**NOW THAT IT'S LIVE + once it's dominant:** remove Monthly/Yearly from the RevenueCat
offering (NEVER delete the sub products); watch trial→purchase conversion + founding-price WOM.

**► 1.2.1 (build 43) is APPROVED + LIVE** (`READY_FOR_SALE`, 19 Aug — cleared review fast,
as expected with no IAP re-review). It carries TWO things:
- **The airport-offer fix** (the customer-reported one): recruitment offers always targeted
  the player's single biggest served hub (`hubs.first(...)` on a traffic-sorted list) — an ATL
  customer got 35 consecutive offers all into ATL, repro'd at 100%. Now a weighted random pick
  (sqrt(pax), ×3 served / ×0.35 unserved): top dest 100%→12%, distinct 1→30+, **60% still land
  on a served hub** (hold that number on any retune). Guard: `aa-1.1.x/OfferSpreadVerify.swift`,
  validated against the pre-fix code (fails 3/5 there).
- **TelemetryDeck error reporting** (designer: "added TD error reporting to all builds/repos").
  `Telemetry.errorOccurred(id:category:detail:)` (Errors preset, stable slug — never
  localizedDescription/PII). This is WHY it's build 43, not 42: build 42 predated the Telemetry
  helper, so `Telemetry.errorOccurred` was cherry-picked from `livery-prototype` onto `main` and
  the build bumped 42→43 so error reporting ships WITH 1.2.1. ✅ The "to all builds/repos" intent
  is DONE for every SHIPPING sibling — Vineyard/Golf/FC/Flight Ops/Resort all already have
  `errorOccurred` (surveyed 19 Aug). Only Aerospace + Mars Colony lack Telemetry.swift entirely
  (no telemetry at all — a bigger separate job, likely pre-ship). GCA's `send()` is actually a bit
  AHEAD of AA's (an `isConfigured` guard + a DEBUG signal print); those two were back-ported into
  AA on 19 Aug (branch `telemetry-guard-and-doc-sync`, NOT yet in a shipped build — rides the next
  build after 44).
- **Verified + shipped:** clean Release build, offer-spread 5/5 on build-43 main, `altool
  --validate-app` + `--upload-app` both clean (Delivery UUID `689635df-0f22-4025-bc0f-6b1066f5ac38`).
  **DONE + APPROVED: version record created, build 43 attached, submitted 18 Aug, went
  `READY_FOR_SALE` 19 Aug. Both changes are LIVE.**

**► 1.3 = PERSONALIZED LIVERY — APPROVED + LIVE 19 Aug (`READY_FOR_SALE`, build 44).**
`livery-prototype` merged into `main` conflict-free; bumped to 1.3 / build 44; Release build
clean + offer-spread 5/5; archived → exported → `altool --validate-app` + `--upload-app` both
clean (Delivery UUID `234e9bf3-0636-4fc9-bd29-1b138455541a`). Feature: painted tails on all 35
types, the creation + re-customise flows, fleet repaint (itemized cost + shop queue + lost-revenue
opportunity cost), existing-player free-first-choice path + one-time update prompt. `LIVERY_SPEC.md`
+ `aa-livery/` tooling are now ON `main` too. **APP STORE SCREENSHOTS DONE** (6.9" iPhone + 13"
iPad, dark, "Air Tina" consistent create↔in-game) at `~/Desktop/Airline Architect Livery
Screenshots/`.
- **✅ SHIPPED (19 Aug):** all gates cleared (real-device first-run passed, version record +
  livery-led What's New + two livery screenshots), submitted, and APPROVED same day —
  `READY_FOR_SALE`. The personalized livery is public. Next new build after 44 = **45+**.

**► Note the Telemetry commit lives on BOTH branches** — `main` (147bbc1, cherry-picked) and
`livery-prototype` (3cb9558, the original), so the merge stayed conflict-free. Clean tree on
`main`, all pushed. App: <https://apps.apple.com/us/app/airline-architect/id6790569697>._

## What shipped in 1.1.2 (build 37)

**1.1.2 / build 37 is what's LIVE** (the repo has since moved to 1.1.3 / 38 — see the
next section for the current build-number rule). Signing is healthy (Postmark Digital
LLC, team `D2PVU8X5Q7`).

**The one change:** a **curated airport-archetype override table**. The
designer spotted SLC (ringed by the Wasatch) showing `plains`; a full 385-airport
audit found it was systemic — Europe's `lat >= 48 -> alpine` rule was INVERTED
(Berlin/Hamburg/Warsaw "alpine", Zurich/Geneva "coastal"), and `plains`/`coastal`
were dumping grounds (Honolulu, Cusco at 11,000 ft, Kathmandu, the whole Gulf).
`AirportPhoto.archetypeOverrides` (108 entries) now pins the clear errors; alpine is
override-only. Audit harness: `aa-1.1.x/archetype-audit` — **re-run it after adding
airports**.

## 1.1.5 (build 40) — SUBMITTED FOR REVIEW (11 Aug)

Repo at **1.1.5 / build 40**, uploaded from the CLI (export → `altool --validate-app`
→ `--upload-app`, VERIFY + UPLOAD both clean, Delivery UUID `f54fd353-…`) and submitted
for review by the designer 11 Aug. Next new build must be **41+**. Two customer-reported
items:

- **Fuel-hedge persistence fix.** A paying customer's bought 90-day hedge VANISHED on
  app close/reopen — `fuelHedgeExpiryTick` was set by `buyFuelHedge` but never in
  `GameSnapshot`/`snapshot()`/`restore()`, so the autosave→relaunch round-trip dropped a
  PAID asset. Fixed (field + `decodeSafeOpt` + snapshot + restore). A full persistence
  AUDIT found this was the ONLY material paid/earned gap. Guard: `aa-1.1.x/FuelHedgeVerify.swift` (11/11).
- **Close route / park aircraft — new lever.** There was NO way to close a route and
  keep the plane, or force a plane idle (only sell / reassign-to-a-new-route / accept a
  slot buyback). `Simulation.parkAircraft(_:)` archives the route (history kept, slots
  freed) and leaves the plane an idle spare — at-gate immediately, airborne deferred to
  arrival (`pendingPark`, persisted). UI on Fleet detail (**PARK (CLOSE ROUTE)**) + the
  Routes panel (**Close route · park aircraft**). Guard: `aa-1.1.x/ParkVerify.swift`
  (28/28); driven live on the sim (Fleet-detail flow confirmed; deferred park executes).

## 1.1.4 (build 39) — LIVE (approved 11 Aug)

Repo was at **1.1.4 / build 39**, uploaded + submitted 9 Aug, **approved and live 11 Aug**.
Contents:

- **Free 3-day trial on both plans (Monthly default) — the paywall UI.** "3 days free,
  then $X" line + "Start Free Trial" CTA, eligibility-gated (once per subscription
  group per Apple ID). The ASC introductory offers are ALREADY configured on both
  Monthly + Yearly (Free / 3 Days / all 175 territories, end 2026-12-31) — so once 39
  is live the trial appears for eligible new users. Decision + mechanics in
  `PRICING_EXPERIMENT_SPEC.md`. **Shipping to everyone (trial in the default offering),
  NOT A/B'd** — volume too low; A/B stays in reserve.
- **New cold-launch backdrop art** — full-bleed aerial-runway scene, 4 assets
  (iPhone/iPad × dark/light), `.fill` everywhere (no seams), light opacity 0.42 /
  dark 0.25. Superseded the pencil-sketch blend approach. See CLAUDE.md.
- **Two paywall fixes (from the pricing-experiment prep):** no stale-price flash
  (`Store.pricesAreLive` gates the price), and the savings badge is computed from real
  prices (`savingsNote`) instead of a hardcoded "Save 30%".
- **ASC Promotional Text** — the STANDING copy for all future releases lives in
  `APP_STORE_DESCRIPTION.md` (designer, 18 Aug): "Start with one jet and build an airline
  that spans the globe. 385 real airports, real economics. One-time unlock — no
  subscription, no tedious in-app spending." Promo text updates with NO review — a free
  lever, editable anytime. ⚠️ Keep "no tedious in-app spending" (NOT "no in-app
  purchases" — the one-time unlock IS an IAP); re-verify the 385 airport count if airports
  are added.

## What shipped in 1.1.3 (build 38) — LIVE

Repo WAS at 1.1.3 / build 38 (LIVE); it has since moved to 1.1.4 / 39 — the current
build-number rule is in the 1.1.4 section above. Notable: the upload was done ENTIRELY FROM THE CLI
with the ASC API key (export → `altool --validate-app` → `--upload-app`) — see
CLAUDE.md's correction; the old "Claude can't upload" note was wrong. Contents:

- **Free-tier caps raised 3 aircraft / 2 routes → 6 / 5**, sized so a free player can
  build exactly ONE hub (`hubMinRoutes` is 5) and hits the wall wanting a second.
  The old caps made hubs — and every system past them — structurally invisible, which
  is the likeliest cause of weak conversion. Paywall/cap copy now sells that depth
  rather than "more of the same". Re-verify with `aa-1.1.x/free-tier-probe` after ANY
  change to starting capital, aircraft prices, or `hubMinRoutes`.
- **Analytics: TelemetryDeck is wired (1.1.3/38).** Six funnel signals answer the one
  thing RevenueCat can't — whether players ever REACH the paywall. See
  `Telemetry.swift`; the family-level standard + traps live in PostmarkOps'
  `ARCHITECT_FAMILY.md`. Two things already handled, don't redo them:
  **App Store App Privacy is declared** (Usage Data → Product Interaction, *Used for
  Analytics*, **Data Not Linked to You** → no ATT prompt), and the SDK product IS
  linked to the app target (it silently wasn't at first — every signal compiled to a
  no-op). **That privacy declaration stays true only while signals carry NO
  identifying data** — the no-PII rule in Telemetry.swift is what keeps it honest.
  DEBUG builds tag signals as TEST MODE, so Simulator testing never pollutes the
  production numbers — flip the dashboard's "Test Mode" chip to see them (an empty
  Overview with Test Mode OFF is the expected false negative, not a broken pipeline).
  **CONFIRMED RECEIVING (6 Aug 2026):** a Simulator run landed 1 user / 3 events,
  SwiftSDK 2.14.2, 0 errors. **38 is live, so REAL PLAYER DATA is arriving now** —
  read it in the production view (Test Mode OFF).

## What shipped in 1.1.1 (build 36)

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

- **Shipped & live.** 1.1.4 (build 39) is public (approved 11 Aug) — as were 1.1.3 (38),
  1.1.1 (36) and 1.1.2 (37) before it, all clean reviews with no rejections.
  **1.1.5 (build 40) is uploaded + submitted for review** (fuel-hedge fix + close-route/park).
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
  tier caps at **6 aircraft / 5 routes** (raised in 1.1.3 — see above). **VERIFIED END-TO-END on device (3 Aug
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
- **Build numbers:** **1.1.4 / build 39** is LIVE; **1.1.5 / build 40** is submitted for
  review. ASC has 31–40 uploaded, so the next new build must be **41+**.
- **3-DAY FREE TRIAL is LIVE at the store level** (independent of the app binary): ASC
  introductory offers (Free / 3 Days, both Monthly + Yearly, all 175 territories, starts
  2026-08-09 / **ends 2026-12-31**) auto-apply to any eligible new subscriber NOW — verified
  by a real Yearly TRIAL in RevenueCat hours after config, even on build 38 (whose paywall
  doesn't advertise it). Build 39 ADVERTISES it (the "3 days free / Start Free Trial" CTA)
  to lift trial STARTS. Shipping to EVERYONE (trial in the default offering), NOT A/B'd —
  volume too low. Watch trial→paid conversion; ⚠️ the offer expires 2026-12-31 unless
  extended (can't edit — delete + recreate). Full decision/mechanics: `PRICING_EXPERIMENT_SPEC.md`.

## NEXT (ranked, as of 12 Sep 2026)

> **The live picture:** 1.8.0 (build 57) is LIVE / `READY_FOR_SALE`. A large body of
> verified work sits on `main` NOT yet in a build (integration Ops surface + settle lever,
> the crew-training capture fix, MX automation + maintenance network, Chief Pilot, the four
> gameplay fixes, rotations, hang fixes). **The next new build is 58+**, and cutting it is
> the near-term move. Detail on each item is in the ⭐ sections at the TOP of this file;
> this is the ranked to-do that falls out of them.

1. **CUT BUILD 58 — and it carries a PROMISE.** A paying customer was told (12 Sep, by the
   designer) that the next build adds the live Ops integration countdown + the early
   seniority settlement. Both are built, verified, and driven live on device, but sit on
   `main`. They shouldn't linger — this build has a customer waiting on it. Everything else
   on `main` (crew training, MX automation/network, Chief Pilot, rotations, the 1.7 hang
   fixes) rides the same build. Bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` (6
   configs) → archive → export → validate → upload → attach → What's New (en-US + de-DE) →
   App Review notes (§1 studio block, reuse the latest and bump the version line) → Game
   Center per-version checkbox → submit. The whole chain is scriptable from the CLI (it ran
   end-to-end for 1.6/1.7/1.8).
2. **ONE VISIBLE PRODUCT CALL STILL NEEDS THE DESIGNER'S NOD before/at that build:**
   `maxClosedRoutes = 40` — beyond 40 closures the OLDEST route leaves the Routes panel,
   which contradicts CLAUDE.md's "archived, not deleted". One constant to raise if the
   designer wants full history kept. (See the 1.7-hang-fixes ⭐ block above.)
3. **THE TRAINING-CENTRE PAYBACK GAP IS NOW PRICE, and the designer already settled it**
   (don't cut device prices below real cost). The throughput half was FIXED 10 Sep (capture
   32% → ~101–112%). If anyone reopens training-centre balance, re-measure with the probe as
   a MEASUREMENT tool, not a gate — and read the tables as ranges (variance across runs is
   large).
4. **VERIFY-BY-DRIVING remains the recurring catch.** Two orphaned sim levers
   (ASSIGN-TO-NEW-ROUTE, then `settleSeniority()`) reached customers because a headless
   harness calls the sim API directly and can never notice that no VIEW does. When you add a
   sim lever, confirm a view actually reaches it.

> The old `NEXT_SESSION_PROMPT.md` was retired 2026-09-12 (its "Issue #4" order shipped in
> 1.8.0). The 1.2-era next-session notes that used to sit here (personalized LIVERY —
> shipped LIVE in 1.3 / build 44 long ago — and the 1.1.3 monetization-signal watching)
> were moved to **CLAUDE_HISTORY.md → "Archived from HANDOFF.md — 1.2-era next-session
> notes (2026-09-12)"** so they can't be mistaken for current direction.

Low priority (unchanged, still valid): the explicit Restore Purchases button, and true
cross-device iCloud sync.

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

0. **This file's ⭐ items (top)** — the current next-work. (The old
   `NEXT_SESSION_PROMPT.md` was retired 2026-09-12; see CLAUDE_HISTORY.md if you need it.)
1. `CLAUDE.md` — the persistent design/technical context. Long because it's thorough.
2. `APP_STORE_DESCRIPTION.md`, then the big feature specs (`GO_PUBLIC_SPEC.md`,
   `ACQUISITIONS_SPEC.md`, `HUBS_AND_CLUBS_SPEC.md`) — all COMPLETE.
3. `git log --oneline -30` — the rejection→approval→live arc is here.

Branch: everything on **`main`**, pushed to `origin/main` (GitHub `spikeatone/SkyOps`).
Open the Xcode project at `SkyOps/AirlineArchitect/AirlineArchitect.xcodeproj`.
