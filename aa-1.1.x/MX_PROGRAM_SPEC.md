# Maintenance Program (MX) — design spec

The real replacement for the shelved T2.2 "PM budget slider." Player-driven, cycle-
and-calendar-driven scheduled maintenance (Line / A / C / D checks) as a distinct
system from AOG emergencies, surfaced in a new **OPS ▸ MX** section. Designer-directed,
grounded in real-world maintenance data (researched). NOT yet built — this is the
sign-off spec.

## Why (the shelved-T2.2 lesson)
A passive "PM budget" that only nudged AOG cost/frequency was economically trivial —
AOG is deliberately rare (~6 incidents/2 sim-yr/14 a/c, the real 2/100/month anchor),
so per-incident levers vanish in the noise (verified across two balance sweeps). The
fix, per the designer: **model PM and AOG as the DISTINCT real events they are.**

- **PM = SCHEDULED, planned.** The airline knows it's coming and plans tail coverage.
  In-game: predictable, cycle+calendar-driven checks the player sees approaching and
  schedules. This is a recurring obligation on EVERY aircraft — not 6 rare events —
  so it's economically + operationally meaningful by construction.
- **AOG = EMERGENCY, unplanned.** The existing random, cycle-scaled system. Stays.
- **Both are driven by cycles.** More cycles → more PM demand AND higher AOG risk
  (`aogAgeMultiplier` already does the AOG half). Deferring mandated PM raises AOG
  risk — the coupling that gives PM teeth.

## The check hierarchy (real-world, researched)
B checks are **obsolete** (merged into A in modern MSG-3 practice) — confirmed. So the
program is **Line → A → C → D** (4 tiers). "Heavy maintenance" = C + D. Real figures
(modern narrowbody, honest ranges — vary by type/operator/MRO):

| Check | Real interval | Real downtime | Real cost (narrowbody) | Basis |
|---|---|---|---|---|
| Line | 24–60 flight HOURS | overlaps ground time (no lost service) | negligible | FH |
| A | 200–300 cyc / 400–600 FH / 1–2 mo | overnight (~1 day) | low (tens of $k) | whichever first |
| C | ~5,000 cyc / 4–6k FH / 18–24 mo | 1–2 weeks (up to 4) | ~$1–3M | whichever first |
| D | ~20–25k FH / 6–12 yr; **2–3 per airframe life** | 1–2 months | ~$1M (737) → $6M (747) | calendar/FH |

Real logic: each check has FH + cycle + calendar limits; **whichever comes first**
triggers. Cost/downtime/man-hours rise steeply A→D (A ~50–70 mh → C ~6,000 → D ~50,000).
(Sources: Wikipedia *Aircraft maintenance checks* incl. the 2018 D-cost table, Simple
Flying, Aviation Week A320-interval reporting, SKYbrary MSG-3.)

## Game-scale mapping (the compression)
The game tracks **cycles per aircraft** + **sim-calendar time**; it does NOT track flight
hours separately (fixed ~flight cycle, so cycles stand in for the FH+FC wear axes). And
it accrues only **~2 cycles/sim-day** with large lifespans (20k–75k cyc), so RAW real
cycle intervals never surface. So: **two triggers, whichever comes first — cycles OR
calendar** (matching the real "whichever first" logic on the two axes the game has),
compressed to session scale, real ratios preserved.

| Check | Game trigger (whichever FIRST) | Downtime (sim-days) | Cost | Cadence as played |
|---|---|---|---|---|
| **Line** | continuous (folded into a small ops-readiness effect) | none | negligible/continuous | always |
| **A** | **150 cycles OR 3 sim-months** | ~1 day | ~0.05% of purchase price | ~every 2.5 mo (busy) |
| **C** | **1,200 cycles OR 18 sim-months** | ~7 days | ~1.2% of purchase price | ~every 1.7 yr (busy) |
| **D** | **expectedLifespanCycles / 3** (cycles only) | ~21 days | ~4% of purchase price | ~2–3 per airframe LIFE |

**Why these choices:**
- **Calendar co-trigger on A/C** solves the low-utilization problem: a spare that barely
  flies still ages into checks (corrosion/rubber-aging don't care about flying — real).
  A busy trunk jet hits the CYCLE limit first (utilization → maintenance demand ✓).
- **D pegged to lifespan/3** → exactly ~2–3 D checks per airframe (matches reality),
  auto-scales across all 37 types, D is a rare momentous lifecycle event. Zero blast
  radius on the sell/retirement economy (doesn't touch lifespans). No calendar co-trigger
  on D (the cycle fraction IS the lifecycle clock).
- **Costs as % of purchase price** auto-scale A→D and across types; a 737-tier D ≈ real
  ~$1M anchor, a widebody D far more (its price is higher). Verified against the real
  2018 D-cost table (737 ~$1M / 747 ~$6M) — % of price reproduces that spread.

## The mechanic (OPS ▸ MX)
1. **Each owned aircraft tracks progress toward its next A / C / D** (cycles since last +
   sim-time since last, per check). "X check due in ~N cycles / ~N months" — the tighter
   of the two shown.
2. **When a check comes DUE**, the aircraft is flagged (not auto-grounded — it's PLANNED).
   The player **schedules** it: take it offline now for the downtime, incurring the cost.
   The decision is *when* (tail-coverage planning — pull it during a slow stretch, or
   line up a spare) — the real gameplay.
3. **Deferral has teeth**: an aircraft flown past its mandated band (some cycle/calendar
   margin past due) gets a **sharply elevated AOG risk** until serviced (skipping mandated
   maintenance → emergencies). This is the PM↔AOG coupling.
4. **Line maintenance** is continuous/automatic (no scheduling) — a small always-on
   readiness factor + tiny cost, representing the daily/transit checks.
5. **AOG stays as-is** — unplanned, random, cycle-scaled, resolved via Needs Attention.
   PM reduces its likelihood only via the deferral coupling (well-maintained = fewer
   surprises), not a separate multiplier.

## OPS ▸ MX section (new)
A new group in OpsView (same `karla(20,.heavy)` header + card pattern as Hubs/Reputation/
Competition), listing per owned aircraft:
- Tail · type · next-check-due (type + ETA in cycles/months, tighter axis) · status
  (in service / due / IN SHOP with return date / OVERDUE-red)
- A **Schedule / Send to shop** action per due aircraft (downtime + cost shown)
- Overdue aircraft flagged red with the AOG-risk warning
- A fleet summary line (how many due / in shop / overdue)
Scheduled checks in progress also surface; AOG emergencies remain in Needs Attention.

## EXPANDED DETAILS VIEW + COVERAGE (designer request, added post-v1)
The row's due-aircraft action is now **Details ▼** (blue, chevron), not an inline Service —
tapping expands an in-row card (`OpsView.mxDetails`) so the player sees the full picture
BEFORE committing:
- **Downtime** — "~N days in the shop".
- **Cost**, with the **overdue surcharge BROKEN OUT** when overdue ("Base cost $X" +
  "Overdue surcharge ×2.5 → $Y", red) so the "service early is cheaper" signal is visible,
  not just the final number. On-time checks show a single "Cost" row.
- **Forced grounding** — "in ~N days if deferred" (from `mxDaysUntilForcedGrounding`, the
  days until the 1.5× hard legal window on whichever axis is tighter; red at ≤3 days or
  overdue). The deferral clock, made explicit.
- **Current route** (informational, if routed).
- The action: **Service now · $X** (green) for an A check or an idle spare.

**COVERAGE — temporary substitution for the LONG (C/D) checks only** (the designer's call:
A checks are ~1 day and service freely; C/D are 7–21 days, where a real airline subs an
aircraft rather than pause the route — "real world, airlines don't just cancel a route when
a plane is down, they have coverage"):
- `mxCoverageRequired(ac)` = the due check is C or D **and** the aircraft is routed. When
  true, the Details view **requires** the player to pick an in-range idle spare before the
  check can start (one tappable "Cover with · <tail>" row per candidate from
  `spareCandidates(for:)`). **A checks never require coverage** and show no revenue-impact
  line at all — a ~1-day pause is negligible; it's a quick in-and-out (an earlier draft
  showed a "Revenue impact" line for A checks — dropped as noise per the designer).
- **`serviceMXWithCoverage(ac, coverWith: sub)`**: hands the route to the sub NOW (the sub
  starts flying it), records `ac.mxReclaimRouteId` + `sub.coveringForTail = ac.tail`, then
  shops the original. **Swap-back on shop-return** (`completeMXReclaim`, in the
  `.mxCheckCompleted` hook): the original RECLAIMS its route and the sub returns to the
  bench as an idle spare. So it's genuinely TEMPORARY — the juggle self-resolves (designer's
  fun-vs-realism call: temp substitution over "permanently give the route away").
- **NO in-range spare on a C/D check → Service is BLOCKED** (designer's call): the Details
  view says why and to free/acquire a spare. The safety valve is the existing hard-window
  auto-grounding — an un-airworthy aircraft is force-grounded regardless, so a cash-poor
  player can't be permanently trapped flying it (the Details view says "will be
  force-grounded if left too long").
- **Two new persisted Aircraft fields** (`mxReclaimRouteId`, `coveringForTail`, both nil-safe
  in AircraftSave) so a save mid-cover restores the swap-back links. An in-shop aircraft's
  MX row shows a "<sub> covering · ~Nd" tag instead of the plain "in shop · ~Nd".
- **Advance-guard fix**: `Aircraft.advance` bailed early for any routeless idle spare
  (`if isIdleSpare { return nil }`), which would have skipped the shop-exit for a COVERED
  aircraft (routeless-while-in-shop) → the swap-back never firing. Now it only bails for a
  spare that ISN'T in the shop, and returns the `.mxCheckCompleted` event so the reclaim runs.
- **LATENT DECODE BUG fixed in passing**: the hand-written `AircraftSave.init(from:)` didn't
  decode ANY `mx*` field, so MX progress + in-shop state were silently dropped every
  save/load (the restore always re-seeded). Now all the mx clocks decode via `decodeSafeOpt`.
  Caught before MX shipped. (The exact "never trust a bare `var x = nil` in a hand-written
  decode" trap the codebase documents.)
## D-CHECK FORCED-GROUNDING = A FIXED CALENDAR GRACE (bug fix, designer-caught)
The Details view showed **"D check due now" but "forced grounding in ~3,660 days"** (real
bug). Cause: the hard window was `mxHardGroundingMultiple` (1.5) × the CYCLE INTERVAL —
right for the short A/C intervals, but D's interval is `lifespanCycles/3` (~15k cyc for a
787), so 1.5× of THAT is ~7k cycles ≈ a decade at ~2 cyc/day. A due D check is a real,
near-term legal obligation, not a decade away.
- **Fix**: D checks now use a FIXED calendar grace PAST DUE (`mxDaysPastDue` = cycles-past-
  due ÷ 2): `mxDOverdueGraceDays` = 20 (→ "OVERDUE" + the 2.5× surcharge + AOG-risk ramp
  begins), `mxDHardGroundingGraceDays` = 45 (→ force-grounded). **A/C keep the 1.5×-interval
  rule** (their intervals are short, so the multiple is the right model).
- All four consumers are D-aware: `mxIsOverdue`, `mxPastHardWindow`, `mxOverdueAOGMultiplier`
  (ramps over the calendar grace for D, over the cycle band for A/C), `mxDaysUntilForced-
  Grounding` (D returns `graceDays − daysPastDue`), and the `mxNextCheckETA` OVERDUE label.
- Numeric proof: a just-due 787 D-check now reports **~40 days** to forced grounding (45d
  grace − 5d already past due), not 3,666.
- **NOTE for a future balance pass**: the 2-year MXProbe sweep spawns aircraft at 0 cycles,
  so a D check (~15k cyc) NEVER fires in it — D-grace is untested by that harness by
  construction. The `mx` devScenario is how D-grounding is exercised (it stages a due D
  check). MXProbe is also genuinely SLOW (~2–3 min/run: `tickWeather`'s system-RNG entropy
  draws dominate — confirmed by a stack sample, NOT any MX code) and its SERVICED-vs-DEFERRED
  check is flaky by construction (non-seeded RNG + random spawn cycles → the ~0.6% margin
  flips run to run). Don't read a single sweep run as a balance verdict.
- Verified: **`aa-1.1.x/MXCoverageVerify.swift` 45/45** (covered service, swap-back,
  A-check no-coverage, no-spare block, save/load mid-cover, the mx-clock decode fix, AND the
  D-grace fix: sane near-term deadline, calendar-grace overdue+surcharge, force-grounding) +
  **soak 6/6 GREEN** (full multi-system, MX integrated) + RoundTripVerify 13/13 + clean build.
  The Details buttons + gating were confirmed rendering live in the Simulator; the expanded-
  card internals were blocked from a live tap by the documented sim input-channel failure
  (screenshots worked, taps silently no-op'd), so the card CONTENT rests on the harness.

## COVERAGE FLOW — the full loop (designer-driven, live-verified this session)
Iterated live with the designer; all of the below is DRIVEN + verified (MXCoverageVerify 81/81):
- **C-check grace too** (not just D): C's 1,200-cyc interval made the 1.5× hard window ~265
  days — same class of bug as D, milder. C now uses a fixed calendar grace like D
  (`mxCOverdueGraceDays` 25 / `mxCHardGroundingGraceDays` 60; D is 20 / 45). A keeps the
  interval-multiple (its 150-cyc interval already gives a tight ~18d window). All four
  consumers (`mxIsOverdue` / `mxPastHardWindow` / `mxOverdueAOGMultiplier` /
  `mxDaysUntilForcedGrounding`) branch on `mxCalendarOverdueGraceDays`/`…HardGrounding…`
  (nil for A). Shared helper `mxDaysPastDue` = (accrued − due)/2 (~2 cyc/day).
- **LIKE-SIZE coverage only** (a 787 D-check can't be covered by an A320 — designer caught
  the exact case): `mxIsSuitableCover(sub, ac)` / `mxTypeIsSuitableCover(type, coveredType)`
  = sub seats ≥ 75% of covered (`mxCoverSeatFloorFraction`) AND range ≥ 85%
  (`mxCoverRangeFloorFraction`). `mxCoverageCandidates(for:)` = route-capable idle spares
  that ALSO pass it. `serviceMXWithCoverage` enforces it server-side.
- **A-check: NO coverage, NO revenue-impact line** (a ~1-day pause is negligible — quick
  in-and-out). Coverage/suspend UI is C/D only.
- **The Details Suspend section** shows the cost UNAMBIGUOUSLY (the designer flagged a lone
  "$9M" as ambiguous): a **"Check cost (either way)"** row (paid whether you cover OR suspend)
  + a **"Lost revenue (~Nd paused)"** row (red — the EXTRA cost of suspending vs covering).
  `mxForegoneRevenue` = ONGOING per-leg net (`legEconomics.net`, no opening cost) × legs in
  the downtime (`1440/legCycleTicks` legs/sim-day) — NOT `dailyNet` (which amortizes the
  route's one-time opening cost, so a not-yet-recouped route read ~$0 — a bug the designer
  caught). NB: at the sim's fixed ~3.5 legs/sim-day, a 21-day D-suspend on a profitable
  long-haul route forgoes several $M — large but internally consistent; the lever if it ever
  feels punishing is the sim's leg-cycle rate, not this formula.
- **No suitable cover → Acquire or Suspend.** The Details view offers **"Acquire a
  replacement"** (→ Fleet ▸ Marketplace via `pendingMarketplace`, the full buy/lease/used
  catalog with size filters — NOT the cramped Network Acquire panel) + a **"Suspend route"**
  button (plain `sendToMX` — the route KEEPS `assignedRouteId`, pauses during downtime, and
  the aircraft RESUMES it on return; distinct from coverage, which hands the route to a sub).
- **ACQUIRE → AUTO-COVER → RETURN loop.** "Acquire a replacement" sets `pendingCoverFor`
  (the covered tail). On the Marketplace, buying/leasing a SUITABLE like-size jet
  auto-assigns it as the cover (`tryAutoCoverAfterPurchase`) and returns the player to Ops
  with a green confirmation banner ("N9ZQ now covering DFW↔ATL … when the check finishes it
  idles and is assignable"). Buying an UNSUITABLE type shows an **AA-styled modal**
  (`UnsuitableCoverModal`, mirroring ReplaceOrCloseModal's chrome) — "Not a suitable cover …
  Acquire anyway as a spare? / Cancel". `pendingCoverFor`/`pendingMarketplace` are transient
  (not persisted); cleared on leaving Fleet without buying. **Dev note:** `-devScenario mx`
  grants `store.isPro` (all dev scenarios inject billions + exercise gated features, so the
  free cap/paywall mustn't block them) and routes widebodies on LONG-HAUL (JFK↔LHR etc., where
  they're profitable — a widebody on a short domestic hop loses money, so its suspend "lost
  revenue" reads $0). The seed leaves only NARROWBODY spares so the D-check demonstrates the
  no-suitable-cover → Acquire path; buy a widebody on the Marketplace to cover it.
- **LATENT DECODE BUG fixed in passing** (before MX ships): the hand-written
  `AircraftSave.init(from:)` decoded NO `mx*` field, so MX progress + in-shop state were
  silently dropped every save/load. Now all mx clocks + the two coverage links
  (`mxReclaimRouteId`/`coveringForTail`) decode via `decodeSafeOpt`.

## Plumbing (the real-build checklist)
- **Aircraft state**: per-check "last serviced at (cycle, tick)" ×3 (A/C/D); an in-shop
  state (return tick) reusing/parallel to the AOG hold path so it doesn't fly while in MX.
- **Cycle+calendar due-check** in the tick loop (cheap: only owned aircraft, daily).
- **Cost** charged on schedule; a new `totalMaintenanceCheckSpend` **Finance invariant
  term** (+ PeriodFigures + FinanceSnapshot + the harness) — folds into "Maintenance &
  crew" on the ledger like the shelved PM did.
- **AOG coupling**: overdue → onset multiplier in `tickAOGOnset` (the one real reuse of
  the shelved work).
- **Persistence**: per-aircraft check timestamps + in-shop state + the spend total, all
  nil-safe (legacy saves: initialize "last serviced" to the aircraft's current cycles/tick
  so nothing is instantly overdue on load).
- **German**: all new MX strings (the app ships de).
- **Balance sweep**: a new probe — confirm the maintenance drumbeat is a real recurring
  cost + planning pressure, the cash invariant holds, no bankruptcy under competent play,
  and deferral→AOG is a real (avoidable) risk not a death spiral.

## ⭐ INTENDED EMERGENT DYNAMIC: "sell before the D check" (designer)
Real majors frequently **phase out, retire, or sell older aircraft just before a major
D check is due** — the heavy check isn't worth it on an airframe near end of life. The
D-pegged-to-lifespan/3 model produces this naturally and it should be a deliberate,
sometimes-correct strategic choice:
- A D check lands at ~⅓, ~⅔, and ~end of `expectedLifespanCycles`. The **2nd/3rd D check
  coincides with an aging, depreciated airframe** — so the D-check cost (~4% of NEW price)
  becomes a large fraction of what the old aircraft is now WORTH (sellValue is linear-
  depreciated from purchase price). Paying a ~$X heavy check on a jet worth ~$2X is a real
  "is it worth it?" moment.
- **The lever already exists**: `sellValue` + the used market + the existing SELL flow. The
  MX system just needs to surface the pending D check ENOUGH IN ADVANCE that the player can
  choose to sell first (the OPS ▸ MX "D due in ~N cycles/months" readout does this). No new
  sell mechanic — the D check just adds the *reason* to use it.
- **Calibration note for the sweep**: the numbers must make "sell just before D" a GENUINE
  choice, not always-right or always-wrong. If the D check is trivially cheap vs the
  airframe's value, nobody sells (dynamic dead); if it always exceeds residual value,
  everybody dumps every aging jet (also degenerate). Target: near end-of-life, the D-check
  cost is *comparable to* the resale value, so it's a real judgment call weighing remaining
  earning life vs. the heavy-check bill. Verify in the balance probe.
- A nice consequence: this feeds the USED MARKET realistically — aircraft sold "just before
  D" are exactly the high-cycle used airframes a bargain-hunting player might buy cheap and
  then immediately owe a D check on (buyer beware — the used-market listing carries real
  cycles, so a used jet may be due for a heavy check soon after purchase). That's a real,
  emergent buyer-beware layer, free from the existing used-cycle inheritance.

## Scope / honesty
This is a **real feature (T2/T3-scale), not a tune** — new per-aircraft state, a
scheduling mechanic, a new OPS section, persistence, invariant, and a balance sweep.
Bigger than anything in this feedback pass so far. It's the correct answer to "make PM
matter" (the designer's call) and it's grounded in real maintenance practice. Build it as
its own branch; ship in a content release (never standalone during the 4.3(a) cascade).

## Deferred / not in v1 (real levers for later)
- **MSG-3 / phased maintenance** as an upgrade path (trade one big grounding for many
  short ones → higher availability) — a genuine strategic maintenance choice the research
  surfaced. Great v2. Not v1.
- **Flight-hours as a separate axis** — the game doesn't track FH; cycles+calendar is the
  faithful 2-axis reduction. Only revisit if variable leg length ever lands.
- Line maintenance as anything more than a continuous background factor.
