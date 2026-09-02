# Player feedback triage — App Store review (post-1.6)

A domain-literate AA player left a detailed review after 1.6. Source quote at the bottom.
This triages every item against the ACTUAL code (verified 31 Aug, `main` @ 1.6.0 / build 55),
effort-ranked, decision-ready. No code changed yet — this is a backlog for the designer to pick from.

**The reframe worth leading with:** several requests are near-hits on systems that ALREADY EXIST or are
one-constant tunes — not new engineering. One (their #1) is fully built and just undiscovered. So the
cheap tier is unusually cheap. The "larger changes" are the genuine multi-session redesigns.

Effort key: **XS** = a constant / one-liner + balance re-sweep · **S** = small feature, hours · **M** =
real feature, a session · **L** = multi-session redesign with balance risk.

---

## TIER 1 — cheap wins (answer the reviewer, touch built systems, low risk)

### T1.1 — "straightforward way to add/remove/substitute a plane on a route" (their #1) — **ALREADY BUILT**
**This feature EXISTS.** The player couldn't find it — a DISCOVERABILITY problem, not a missing feature.
- `Simulation.reassign(_:from:to:)` — move any owned aircraft (idle or flying) to a new route; the old
  route archives. Airborne aircraft finish the current leg first (`pendingRouteId`).
- `Simulation.replaceRouteAircraft(sell:with:)` — swap a new plane onto a route and sell/hand back the old
  one in one step (the "SELL a routed aircraft → replace-or-close" modal).
- `Simulation.parkAircraft(_:)` — close a route and KEEP the plane as an idle spare (PARK / CLOSE ROUTE).
- UI: Fleet detail → **ASSIGN TO NEW ROUTE** + **PARK (CLOSE ROUTE)**; Routes panel → **Close route · park
  aircraft**; selling a routed jet → the replace-or-close modal.
- **The reviewer's exact ask — "substituting a new plane… even with a small fee"** — is `reassign`, which
  DOES charge a real route-opening cost. So it even matches their fee expectation.
- **Action (XS–S, NOT code-heavy):** improve discoverability. Options, cheapest first: (a) a one-line
  tutorial/coach note pointing at ASSIGN/PARK on the Fleet detail; (b) rename/relabel if "ASSIGN TO NEW
  ROUTE" doesn't read as "substitute the plane"; (c) a short "moving planes around" help blurb. Consider a
  reply to the review saying it's already possible via Fleet detail → ASSIGN TO NEW ROUTE / PARK.
- ⚠️ Do NOT rebuild the mechanic — it's done and 41/41 headless-verified. This is a UX/wording fix.

### T1.2 — labor actions "arbitrary and very frequent" (their #2, frequency half) — **XS tune**
- Current: `laborActionDailyProbability = 0.02` (Simulation.swift:3589) = ~1 labor action / 50 sim-days per
  eligible family; with several owned families that stacks into the "very frequent" the player feels.
  Sidelines **40%** of one family (`0.4`, line ~3657) for **3–8 sim-days**.
- The player is right it's higher than real life. **Action:** drop the daily probability (e.g. 0.02 → 0.008,
  ~1/125 days) and/or the sideline fraction (0.4 → 0.25). Both are single constants.
- ⚠️ Re-run the balance probe after (labor sidelining feeds crew-shortage cascades — see the crew-cliff note
  in CLAUDE.md). XS to edit, the sweep is the real cost.
- NOTE: the "concrete demand you can negotiate/meet" half of their #2 is NOT a tune — see T3.1.

### T1.3 — crew training "half the crews suddenly out" (their #3) — **XS tune + optional S stagger**
- Current: `crewTrainingSidelineFraction = 0.5` (Simulation.swift:3243) — literally half a family at once,
  exactly their complaint. 150-day cycle, 4-day downtime, or defer 30 days at 1.6× cost.
- **Action (XS):** lower the fraction (0.5 → 0.25) so training degrades but doesn't gut a family.
- **Optional (S):** stagger — instead of one big hit, sideline a small rolling slice over several days, or
  split the family's training into 2–3 smaller waves. More realistic; more code. Fraction-drop alone
  addresses 80% of the complaint.

### T1.4 — 125× speed + auto-drop to 1× on critical alerts (their #6) — **S, genuinely good**
- Current: `speedOptions = [0.25, 0.5, 1, 5, 10, 25]` (Simulation.swift:739). No 125×, no auto-drop.
- **The auto-drop-to-1×-on-critical-alert is the strong idea here** — it fits the "sim never pauses but
  surfaces decisions" thesis perfectly (you don't pause, but you stop fast-forwarding past a decision).
- **Action:** (a) add 125× to speedOptions (XS); (b) "sans animation" at 125× ties into the existing
  `mapTick` throttle — cap redraw harder or skip the map repaint above 25× (S); (c) auto-drop: when a
  decision is pushed to `decisionQueue` (AOG/crew/board/etc.) and speed > 1×, snap to 1× — reuse the
  existing quarter-speed snap-to-1× pattern (S). Define "critical" = anything that pushes a decision card.
- ⚠️ 125× stresses the tick loop (50-tick catch-up cap per wake) — verify it doesn't drop ticks or overheat
  (the same class as the 1.5 thermal fix). The animation-skip is partly what makes 125× safe.

---

## TIER 2 — real features, bounded scope

### T2.1 — move crew available ↔ reserve to cut cost, pay to reactivate (their #4) — **M**
- Current reserve model is COARSER than the ask: `reserveCrewsByFamily` is an **Int count** per family
  (Simulation.swift:3187), seeded on a family's first aircraft, drawn down by "call in reserve." There is
  no per-crew reserve STATE and no available→reserve move, and reserves don't currently carry a reduced
  ongoing cost (crew cost isn't per-head-billed at all yet — see T3.2).
- So this is a real feature, not a toggle: needs (a) a way to move a crew from the active pool to reserve,
  (b) a reduced carrying cost for reserve crew, (c) a reactivation cost + delay. It also only makes sense
  once crew has an ongoing per-head cost to reduce — which is T3.2 territory.
- **Action:** M if built standalone with a simple "reserve = X% of active cost" model; couples naturally
  with T3.2 (salaries) — probably build them together or not at all.

### T2.2 — adjustable preventive-maintenance budget → affects readiness/groundings (their #7) — **M**
- Current: AOG onset = `aogProbPerTick × event multiplier × ac.aogAgeMultiplier` (Simulation.swift:3161).
  There is NO preventive-maintenance budget lever — maintenance is reactive (you pay to fix an AOG) plus
  the passive age/upkeep escalators.
- This fits cleanly: add a per-airline (or per-aircraft) PM spend level that multiplies AOG onset down
  (more PM → fewer groundings), as a standing monthly cost. Mirrors the real trade the player names.
- **Action:** M. New standing cost + a multiplier into `aogProbPerTick`, a UI control (Finance or Fleet),
  and a Finance cash-invariant term (`totalMaintenanceBudgetSpend` — must join the invariant + harness).
  Balance-sweep to find the PM-cost ↔ AOG-reduction curve that's a real choice, not a free win.

---

## TIER 3 — the deep bets (multi-session redesigns, deferred by design)

### T3.1 — labor actions as a concrete negotiate/meet demand (their #2, the real half) — **M–L**
- Today a labor action just sidelines crew for N days — no player agency, which is exactly why it reads
  "arbitrary." The ask: a concrete demand (pay raise / better conditions) the player can MEET, NEGOTIATE,
  or REFUSE, with consequences. This is the decision-card pattern (like the slot/hub offers) applied to
  labor — but it only has teeth if crew has adjustable pay/conditions to demand against (T3.2).
- **Action:** M on its own (a `.laborDemand` decision card with meet/negotiate/refuse), L if it pulls in
  salaries. Big realism + agency payoff; the player explicitly wants this over the current arbitrary hit.

### T3.2 — adjustable crew salaries; underpaid crew strike/quit (their #5) — **M–L**
- No per-crew or per-family salary lever today; crew cost is a one-time hire cost + decision-cost charges,
  not an ongoing wage the player sets. This is the connective tissue the player wants under #2/#4: set pay
  → competitive pay lowers strike/quit risk, low pay raises it and cuts cost.
- **Action:** M–L. New ongoing wage cost (Finance invariant term), a pay control, and a pay→satisfaction→
  strike/quit model wired into the labor-action + crew-availability systems. This is the spine that makes
  T2.1 + T3.1 cohere — the three are really one "crew economics" feature family.

### T3.3 — point-to-point multi-stop schedules (their LARGER #1) — **L (fundamental)**
- The route model is A↔B dedicated back-and-forth (`assignedRouteId`, direction swap each cycle). The ask
  is a real per-aircraft daily SCHEDULE with multiple stops, which determines crew availability/rest at
  each served airport and enables ticketable through-connections. This is a **ground-up rewrite** of the
  route/aircraft-cycle model and cascades into crew, demand, and the whole UI.
- **Action:** L, multi-session, high balance risk. The single biggest realism lever the player names, and
  the natural "if the game goes deep" direction — but it's a different game's core loop. Pairs with T3.4.

### T3.4 — true O&D endpoint-to-endpoint demand + connection penalties (their LARGER #2) — **L**
- Today hubs use a universal `hubBonusPercent` demand bonus (capped). The ask: compute demand (and price)
  endpoint-to-endpoint with a non-stop bump and a steep falloff for out-of-the-way routings (their
  IAD→ATL→LGA example), replacing the flat hub bonus. This is the "real network model" the codebase
  deliberately simplified. Only fully meaningful WITH T3.3 (schedules/connections).
- **Action:** L. Deep demand-model rework; would supersede the current hub bonus. Do together with T3.3 or
  not at all — a connection-aware demand model needs connections to exist first.

---

## NON-FEATURE — community signal (cheap, compounding)
> "If there were a forum somewhere to post and discuss about this app, I would do so."
- An engaged player asking for a community. **Action (XS, non-code):** stand up a subreddit or Discord and
  link it (App Store description + maybe an in-app "Community" link). Low effort, compounds into retention +
  a feedback channel + word-of-mouth. Worth doing regardless of the feature backlog.

---

## Recommended sequencing
1. **T1.1 discoverability** (their #1 is already built — cheapest possible reviewer win) + a review reply.
2. **T1.2 + T1.3 tunes** (labor freq + training fraction) — one small patch, one balance sweep, directly
   answers two complaints.
3. **T1.4** (125× + auto-drop-to-1× on alerts) — small, and the auto-drop is a genuinely good UX idea.
4. **Community link** — parallel, non-code.
5. Then decide on the **crew-economics family (T2.1 + T3.1 + T3.2)** as a themed release — they cohere and
   the player clearly wants that whole cluster.
6. **T3.3 + T3.4** (schedules + O&D demand) — only if committing to a deeper-sim direction; biggest work,
   biggest realism payoff, its own multi-session project.

A T1-only patch (items 1–3, ~a session incl. sweeps) would answer most of this reviewer's concrete gripes
and touches only already-built systems. Everything past T2 is a design-direction decision, not a quick fix.

---

## Source (App Store review, verbatim)
> I like the game/simulation. The 5-route free intro and the low one-time price are a welcome improvement
> over pay-to-win and subscription models. If there were a forum somewhere to post and discuss about this
> app, I would do so.
>
> The game/simulation is reasonably detailed, but I think a few small changes could make it better:
> 1. There should be a straightforward way of adding and removing planes (or at least substituting a new
>    plane) on a route, even if accompanied by a small fee. Having to close and reopen it doesn't seem
>    realistic.
> 2. The "labor actions" are rather arbitrary and very frequent, much more so than in real life. There
>    should at least be a concrete demand that the player might decide to negotiate or even just meet.
> 3. Crew training should be capable of being spread out. It is not realistic for half the crews to
>    suddenly be out on training.
> 4. It should be possible to move crews from available to reserve, reducing ongoing cost, but of course
>    incurring cost to reactivate.
> 5. Crew salaries should be adjustable by the player (as part of #2-#4). Some crew might do a labor action
>    or just quit if pay isn't competitive.
> 6. There should be an even faster 125x (perhaps sans animation), but the simulation should automatically
>    drop to 1x from anything higher when critical alerts pop up.
> 7. An adjustable budget for prevetative maintenance ought to affect aircraft readiness (groundings).
>
> Larger changes to improve realism:
> 1. It would be cool if planes were scheduled point to point, with multiple points possible, rather than
>    just dedicated back-and-forth on a route. Each plane having a daily schedule would suffice, and this
>    would of course affect crew availability, resting, etc. at each served airport. The totality of these
>    would determine possible ticketable through-connections.
> 2. It would make hubs and larger route structures more realistic if demand (and pricing?) were calculated
>    endpoint-to endpoint, assuming a bump for non-stop, and falling way off for out of the way connections
>    (like IAD->ATL->LGA, for example), rather than using a universal hub demand bonus.
