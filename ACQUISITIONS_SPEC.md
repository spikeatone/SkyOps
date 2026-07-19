# Competitor Acquisition — Design Spec (for designer review)

Status: **Steps 1–2 BUILT & verified. Steps 3–5 not built — and step 2 is NOT SHIPPABLE without step 3.** Numbers below are first-pass and WILL move; the
mandatory balance A/B (§Balance Guardrails) is what settles them, exactly as it
retuned Hubs & Clubs from a −41% value-sink to +0.7%.

Target release: **1.1**, not 1.0.1 (see §Scope & Sequencing).

---

## Problem / Concept

Testers who reached **$1B net worth** report the game stops rewarding them: a
new route or aircraft moves net worth by a fraction of a percent, so the
feedback loop that carried the first ten hours goes flat. There is no late-game
action whose *scale* matches the player's position.

Acquisition is the answer — but deliberately **not** as a shopping spree.

**Design intent (designer, verbatim):** make untangling double-covered routes,
crew seniority fights, and the other inherited inefficiencies so demanding that
it introduces *real peril* to the state of the player's game. A well-managed
acquisition "could reasonably start to pay off in 24–36 months, but it's no
promise."

So the fantasy is not *I bought them*. It is **I survived buying them.**

### Why not a simpler version

Two designs were considered and rejected:

- **Acquisition as asset purchase** ("spend $800M, receive 40 aircraft and 25
  routes") is the verb that already stopped being rewarding, at a bigger number.
  It thrills once, maybe twice.
- **Buying a rival's *exit*** (pay to remove a competitor from your markets, no
  assets) is far cheaper to build and nearly risk-free — but it's a fee, not a
  challenge, and it doesn't give the endgame a new verb.

### Two hard constraints

1. **Not a money printer** (the Hubs & Clubs guardrail, restated). Price must
   exceed inherited asset value; the return must come from *operating the
   combined network well*, never from the transaction itself.
2. **It must not empty the map.** Removing rivals removes the main late-game
   pressure. Every completed acquisition must make the *survivors* more
   aggressive — consolidation is the in-fiction reason, and it's one multiplier
   on `competitorEntryDailyProbability`. Winning must not mean less game.

---

## The engineering reality that shapes everything

`Airline` (Sim/Airline.swift) is `{name, code, weight, types}` — 142 entries
across 10 regional rosters. Competitors have **no fleet, no network, no books**.
On the player's routes they exist only as strings in `Route.competitors` with a
demand-splitting `competitionLevel`; background traffic wears their livery but
is cosmetic.

So a target must be **materialized**: a plausible fleet, network, and set of
books generated from its roster weight and region.

**Recommendation — materialize at UNLOCK, not at offer.** When the player first
crosses $1B, generate the full target set once and persist it. Consequences:

- Targets are **scoutable** — the player can study a rival's network, fleet age,
  and overlap with their own *before* committing, which is what makes this a
  decision rather than a gamble.
- Targets are **stable** across save/load and can't be re-rolled by quitting.
- It costs one generation pass, not a live competitor simulation.

The alternative (generate at offer time) is cheaper still but makes the purchase
blind, which undercuts the whole "informed peril" framing.

---

## Gate & availability

| Rule | Value | Reasoning |
|---|---|---|
| Unlock | Net worth ≥ **$1B** | Testers' own ceiling; the `$1B` milestone already exists |
| Eligible targets | Carriers in regions where the player **operates routes** | Grounds it — you buy rivals you actually compete with |
| Concurrent | **One integration at a time** | The integration IS the content; stacking them hides it |
| Lifetime cap | **3** (recommended), price escalating per acquisition | Prevents roster-eating; keeps the map populated |
| Reversible? | **No.** Permanent, like a sold hub | Consequence is the point |

---

## Ownership model: SUBSIDIARY, not absorption (DECIDED)

**Designer's call:** you own the airline, and **it keeps flying under its own
flag.** An acquired carrier is not erased and not repainted — it becomes a
subsidiary operating under the player's ownership, the way real acquisitions
run for years before (or instead of) a brand merge.

This is a fiction decision that happens to serve the hardest guardrail in this
spec: **the map never empties.** Every livery the player buys stays in the sky.
Consolidation removes a *competitor*, not a *carrier*.

Consequences that follow from it, and must be decided together:

- **Inherited tails keep their original code.** A Delta aircraft stays `N123DL`
  rather than being renumbered to the player's 2-letter code. Free, and it makes
  ownership legible in the Fleet list at a glance.
- **Map colour needs a third state.** Today: owned = flight-phase colours,
  competitor = constant `#D767FF`, held = red (shared). A subsidiary is *yours*
  but flies its own flag, and currently has no way to read as either. Options:
  player phase-colours with a subsidiary marker; or a dedicated subsidiary hue
  that reads as "yours, but not mainline." **Designer call.**
- **Reputation blends only PARTIALLY.** The spec's original full blend is wrong
  under this model: a subsidiary's bad service shouldn't instantly tank the
  mainline score. A weighted, partial blend is both more realistic and gives the
  player a reason to *invest in fixing* what they bought rather than just
  enduring it.
- **Subsidiaries stay in MARKET INTELLIGENCE, flagged as owned.** The scouting
  list quietly becomes a portfolio view — you keep watching the books of the
  airline you now own, which is exactly how a holding company sees it.
- **Double-coverage still bites.** Separate flags don't spare the player the
  rationalization problem; real merged carriers cut overlapping routes
  regardless of brand. The integration burden is unchanged.

---

## What the player inherits

Generated per target, scaled by roster `weight` (American 21 → large; a regional
brand 1–3 → small):

- **Fleet.** Real `AircraftType`s drawn from that carrier's real `types` set,
  with a realistic **age spread** — a meaningful share near end-of-life. Some of
  what you buy is junk you'll retire, and that should be visible when scouting.
- **Routes**, including **overlaps with the player's own network** (see below).
- **Their hubs** become player hubs (or contested, if the player already hubs
  there).
- **Their presence on player routes is removed** — every `Route.competitors`
  entry for that carrier clears, and demand recovers immediately. This is the
  one instant, legible reward, and it should feel great.
- **Their reputation blends** into the player's, weighted by relative size. Buy
  a badly-run airline and your own service score drops.

---

## The integration burden (the heart of the feature)

Five simultaneous pressures, all on existing machinery:

**1. Crew families you don't operate.** Inherited aircraft of an unfamiliar type
arrive with **no crew in your pools**. They sit idle — earning nothing, still
accruing maintenance and any lease obligation — until you hire and train.
`CREW_FAMILY_INFO` and the hire-cost model already express exactly this pain.

**2. Seniority dispute** (designer's addition, and the best flavour in the
feature). Merging two seniority lists is the most contested part of a real
airline merger. Model it as an escalated, longer-running labor action across
**both** airlines' overlapping families: a fraction sidelined, elevated hire
costs, running months not days. Reuses `.sidelined` /
`laborActionExpiryByFamily` wholesale. **Recommended:** the player can spend to
settle it early — a real lever, expensive, and the clearest "manage it well"
skill expression in the whole feature.

**3. Double-covered routes — DECAYING TOWARD A FLOOR, not flat (DECIDED).**
Where both airlines flew the same city pair, the player **competes with
themselves**: the pair's demand splits across both routes.

Designer's refinement, and it's real: merged carriers recover much of that lost
efficiency over time, as schedules are deconflicted and connections coordinated.
A permanent flat penalty would be wrong.

But a penalty that decays purely on a TIMER breaks the feature — the player can
simply wait it out, which turns the untangling into a passive countdown and
directly violates the "passive holding never pays back" target.

**Resolution — split it the way reality splits it:**

- **Schedule optimization is automatic.** Deconflicting departure banks and
  coordinating connections is integration-team work that genuinely happens on its
  own. This is the decay, and it should be substantial: the overlap penalty
  starts severe and eases over the merger period (~18–24 months).
- **Overcapacity is not.** Two aircraft actually flying the same city pair split
  that pair's demand, and no amount of schedule work fixes it. So the decay
  asymptotes to a **FLOOR** that time never crosses.
- **The floor clears only through a real network decision** — closing one of the
  pair, or reassigning its aircraft to an uncontested market.

Net shape: the curve improves on its own (so a fresh acquisition doesn't feel
hopeless) but plateaus short of healthy (so passive holding never reaches
payback). The player feels the integration team working *and* still has to make
the hard capacity calls.

**The FLOOR DEPTH is the load-bearing number for the balance A/B.** Too shallow
and passive holding pays back inside 36 months — the feature is a printer. Too
deep and the decay is cosmetic. Sweep it explicitly; do not eyeball it.

Optional lever, flagged not decided: let the player FUND faster integration to
accelerate the decay (the same shape as the seniority settlement). Real, but it
may be one lever too many — decide after the A/B.

**4. Reputation hit at close**, recovering slowly — the disruption passengers
actually feel. Feeds demand through the existing multiplier.

**5. A monthly integration bill** for N months (systems, repainting, training)
on top of the purchase price. This is the drag that makes the payback curve
*look* like the real thing: deep negative first, crossing later.

Net shape: **cash and net worth should get visibly worse before they get
better** — with an in-app profitability curve like the one `RouteProfitChart`
already draws for routes.

---

## Price (first pass — the A/B will move these)

```
askingPrice = fleetMarketValue + routeGoodwill + controlPremium
  routeGoodwill  ≈ 12 × combined monthly net of the target's routes
  controlPremium ≈ 30% of (fleet + goodwill)
  × escalation   (1.0 / 1.4 / 1.9 for the 1st / 2nd / 3rd acquisition)
```

Payback is then governed by integration cost, not the price alone:

```
monthly integration bill ≈ 1.5% of asking price, for 18 months
seniority settlement (optional)  ≈ 8% of asking price, one-off
```

**Calibration target: 24–36 sim-months to recoup, when well-managed
(rationalize overlaps promptly, settle seniority, retire the junk).
Never — or well past 48 — when passively held.** That gap between the two is
the skill expression; if the A/B shows passive holding also pays back inside
36 months, the feature is a printer and the numbers are wrong.

---

## Balance guardrails (load-bearing — this section is why Hubs & Clubs shipped sane)

1. **Isolation A/B, mandatory before ship.** Same seed, same network, acquire vs.
   don't, ≥6 seeds × 36 sim-months, using the existing `ab.swift` autopilot
   pattern. Report marginal net-worth delta at 12 / 24 / 36 months.
2. **A second arm: passive vs. managed.** Acquire-and-ignore must clearly
   underperform acquire-and-rationalize. If it doesn't, the integration burden
   isn't real.
3. **Survivor aggression check.** Rivals-on-player-routes must not fall after an
   acquisition — the consolidation multiplier should roughly hold the line.
   (Hubs & Clubs measured this and found rivals halved; here that would be a
   failure, not a pass.)
4. **Bankruptcy reachability.** A player who over-extends on an acquisition
   *should* be able to fail. The grace/liquidation system already exists. Verify
   it triggers rather than soft-locking.
5. **Finance cash invariant extended** — new terms `− totalAcquisitionPrice
   − totalIntegrationSpend − totalSenioritySettlement`, asserted in the
   regression harness at every money-moving step, same as every prior feature.

---

## Persistence

New optional `GameSnapshot` fields (nil-safe for pre-1.1 saves, the established
pattern): the materialized target set, the active integration (target, phase,
months remaining, bills paid), completed-acquisition count, and the three
accumulators above. Inherited aircraft and routes persist through the **existing**
`AircraftSave` / `RouteSave` — they're ordinary owned assets the moment the deal
closes.

---

## Scope & sequencing

Comparable in size to Hubs & Clubs: sim core, five-ish UI surfaces, persistence,
invariant, and a balance sweep. **Recommend 1.1.** 1.0.1 should stay the Restore
Purchases fix plus whatever App Review surfaces — bundling a headline feature
delays that fix and puts a large untested system in front of the first cohort of
real customers.

Suggested build order (each independently verifiable):

1. ~~Target materialization + scouting UI~~ — **DONE.** `Sim/Competitor.swift` +
   `CompetitorIntelView.swift`, reached from a MARKET INTELLIGENCE card in
   Finance. Deterministic from one persisted seed; 1278/1278 headless. See
   CLAUDE.md "Decided — Competitor Acquisition" for the implementation map.
2. ~~The transaction + inheritance + immediate rival-removal.~~ **DONE.**
   `Sim/Acquisition.swift` + the "Competitor acquisition" MARK in
   Simulation.swift; 51/51 headless. ⚠️ Pure upside until step 3 lands.
   AMENDMENT: inherited aircraft come WITH crew (you acquire the airline's
   people); the merger's pain is the seniority fight, not an absence of crew.
3. The integration burden (crew gaps, seniority, double-coverage, bills).
4. Consolidation pressure on survivors.
5. Balance A/B → retune → ship.

---

## Decisions needed from the designer

1. ~~**Real named airlines.**~~ **RESOLVED: keep them.** The trademark concern
   was over-cautious — text-only reference is already shipping and is the
   defensible end of the spectrum. Holding: no logos/liveries, no real brands in
   App Store metadata. Leaning **subsidiary-over-erasure** for fiction reasons
   (a vanished Delta empties the map), not legal ones.
2. ~~**Scoutable before offer?**~~ **RESOLVED: scoutable**, and built — see
   step 1. Scouting is ungated (not behind $1B): public information is public.
3. **Can an acquisition genuinely ruin a player?** (Recommendation: yes. "Real
   peril" without a real failure state is theatre — and bankruptcy already
   exists.)
4. **Lifetime cap of 3?** Or uncapped with steep escalation?
