# Competitor Acquisition — Design Spec (for designer review)

Status: **Steps 1–3 BUILT & verified (27/27 + 51/51 headless). NOT SHIPPABLE —
the first economic measurement FAILS the calibration target and needs a designer
call before tuning. See §MEASURED ECONOMICS below.** Numbers below are first-pass and WILL move; the
mandatory balance A/B (§Balance Guardrails) is what settles them, exactly as it
retuned Hubs & Clubs from a −41% value-sink to +0.7%.

Target release: **1.1**, not 1.0.1 (see §Scope & Sequencing).

---

## MEASURED ECONOMICS — target REDEFINED, three real bugs found, not yet closed

**Designer's call on the ambiguity: model real M&A. Full capital payback in
5–10 years — a shrewd player pushes for the low end, a first-timer may struggle
to break even at 10.** That replaces the earlier 24–36 month reading.

Measured with 3 arms (control / acquire-and-hold / acquire-and-manage) restored
from ONE shared `GameSnapshot`, so every arm faces the same competitor market and
buys the same carrier. **Payback is measured on CASH, not net worth** — you spend
cash, so the question is when you get it back; net worth double-counts the
inherited fleet at month 0 and then penalises its depreciation.

### Where it stands (latest run, ~46-aircraft target at $3,394M)

| Month | Passive cash gap | Managed cash gap |
|---|---|---|
| 0 | −$3,394M | −$3,394M |
| 6 | −$3,156M | −$3,179M |
| 12 | **−$3,042M** | −$3,144M |
| 24 | −$3,097M | −$3,199M |
| 42 | −$3,132M | −$3,227M |

**The first 12 months work: the gap closes at ~$29M/month — a ~10-year payback
pace, inside the designer's window.** Then it stalls and slowly reverses.

**Diagnosis of the reversal:** the inherited fleet ages. Aircraft arrive at ~0.5
of design life (some past it) and accrue cycles at 2 legs/day, so the quadratic
escalators bite — `maintenanceAgeMultiplier` 1+0.4·age² and especially
`aogAgeMultiplier` 1+3·age² (4×+ at design life). A bought airline harvests good
months and then decays into a money pit. That is a GOOD dynamic — it makes fleet
renewal the real post-merger job — but nothing in the managed arm does it yet.

### THE CLOSING LEVER (next step, not yet built)

**Fleet renewal as a fourth management action.** The managed autopilot currently
retires only junk that is already *unassigned*, which is almost none. It must
sell/replace inherited aircraft past ~0.85 of life on a rolling basis. That is
what should separate a 5-year shrewd outcome from a 10-year struggling one — and
it is exactly the skill the designer described.

### Three methodology bugs found (each produced a confident WRONG answer)

1. **Arms bought different carriers.** Every `Simulation` rolls its own
   `competitorSeed`. Arms must restore from one shared snapshot.
2. **Rationalization moved 0 routes** — it filtered for unserved AIRPORTS, which
   finds nothing once an inherited network covers the country. Must filter PAIRS.
3. **Both arms were under-crewed** (1 bundled crew per aircraft; the sim needs
   ~2.1). An under-crewed airline is structurally loss-making, so the control was
   flat and every comparison was meaningless.

### Two real GAME bugs the measurement exposed

1. **Inherited routes ignored economics.** Aircraft were assigned to any route
   they could *physically* fly, putting widebodies on short domestic hops where
   they lose enormous money (an A380 is −$63k at 300nm). FIXED: inheritance now
   matches each aircraft to a stage length it is built for, and refuses a
   badly-mismatched pairing outright.
2. **Inherited spokes were uniform-random**, giving the network a tail of dead
   markets. FIXED: spokes are drawn weighted by real airport traffic.

### Retuned since the first measurement

- Integration bill **1.5% → 0.4%/month** (was 27% of the purchase price over 18
  months, ~¾ of the entire loss — the spec never multiplied it out).
- Seniority settlement **8% → 2.5%** (was nearly pure cost, which inverted the
  skill expression and made managed lose to passive).

### 12-SEED SWEEP — TARGET MET, and a systematic finding

Run at 12 seeds × 3 arms (control / passive / managed), 36 months, arms restored
from one shared snapshot per seed so every arm faces the same competitor world.
Payback measured on NET WORTH (the month-0 drop — price minus assets received —
is the deal's true economic cost; recovering it means you are as wealthy as if
you had kept the cash).

| Arm | Median value created | Median cost | Median payback | Destroys value |
|---|---|---|---|---|
| Passive | $3.74M/month | $608M | **13.5 years** | 3/12 |
| Managed | $9.69M/month | $673M | **5.8 years** | 3/12 |

**This is the designer's brief, met:** a shrewd operator lands near the low end
of 5–10 years; a passive one struggles past 10. The **2.6× managed/passive
gradient held across every tuning round**, which is what says the skill
expression is real rather than an artifact.

`acquisitionControlPremium` was sized BY this sweep, not by intuition: at 0.80
the median cost was $1,551M → 22.9 years managed. At **0.25** it is ~$673M →
5.8 years. The premium is the single constant that sets payback, because the
deal's true cost is (premium × liquidation value) + goodwill.

### ⚠️ SYSTEMATIC FINDING: cross-region acquisitions always fail

The 3 value-destroying seeds in each arm are **the same 3 seeds, and all three
bought Air Canada** — a Canada-region carrier acquired by a US-region player.
Every same-region target (Delta, American) paid back. This is not variance:

| Seed | Target | Managed payback |
|---|---|---|
| 104, 106, 206 | Air Canada (cross-region) | **never**, all three |
| 101, 103, 105, 202, 204, 205 | Delta / American (same region) | 1.3 – 4.5 years |
| 102, 201, 203 | American (same region) | 11.0 – 20.6 years |

Cause: an out-of-region carrier's hubs and routes sit entirely outside the
player's network, so there is no overlap to rationalise, no hub synergy, and no
connecting traffic — you inherit a separate airline rather than a bigger one.

**That is realistic and worth KEEPING — but it is currently an invisible trap.**
Nothing tells the player that buying across regions is structurally different.
This is precisely what stage-1 due diligence should surface: region fit belongs
in the scenario as a headline risk, not something a player discovers by losing a
billion dollars. (Alternative if it should not be a trap at all: gate acquisitions
to the player's own regions. Designer's call — the diligence route is better,
because it makes the knowledge the reward.)

### Methodology notes (each of these produced a confident WRONG answer first)

1. **Single-seed measurement is worthless here.** Identical code gave managed
   +$23.2M/mo and −$5.6M/mo on consecutive runs. Always sweep.
2. **Arms must share one `GameSnapshot`** — each `Simulation` rolls its own
   `competitorSeed`, so unseeded arms buy different carriers.
3. **Rationalisation must filter unserved PAIRS**, not unserved airports.
4. **Both arms must be crewed to ~2.2/aircraft.** One bundled crew per aircraft
   is structurally loss-making, which flattens the control and voids every
   comparison.
5. **Measure on net worth, not cash** — cash payback penalises reinvestment, so
   an arm that renews its fleet looks worse while actually building wealth.

⚠️ **Repricing constraint stands:** any price must ALWAYS exceed the fleet's
in-game `fleetMarketValue`, or the player buys a carrier, liquidates its fleet,
and profits — pure arbitrage.

---

## TWO-STAGE DUE DILIGENCE (designer design — not yet built)

Designer's framing: acquisitions should mirror real deal-making, where what you
can see depends on how far into the process you are.

**Stage 1 — "sniffing around" (pre-NDA).** Public information only, the same
thin, estimated numbers a real buyer works from before the books open. Enough to
decide what is worth pursuing, not enough to be sure. This is what
`CompetitorProfile` already provides — fleet size, average age BAND, network
size, topline revenue/margin, service score, an estimated value. The player runs
**best-guess scenarios** off these: bad / average / good.

**Stage 2 — post-NDA, "open the kimono".** The real books. Per-aircraft ages
rather than an average band, the actual route-by-route quality, the true
maintenance exposure, and a firm renewal bill. Gated behind an explicit step
(and plausibly a cost, or the target's consent), so choosing WHICH targets to
diligence is itself a decision.

**Projections must NOT be iron-clad (designer, explicit).** Real projections are
best guesses that reality diverges from — that divergence is the feature, not an
error to eliminate. The model supports this honestly and for free: a profile
carries an AVERAGE `fleetAgeFraction`, while the fleet actually inherited is
generated with a real per-aircraft spread (0.6–1.35× that average). So a stage-1
estimate is genuinely uncertain, a stage-2 view is much tighter, and neither is a
guarantee. **Do not "fix" that divergence.**

**Fleet renewal cost belongs in the scenarios (designer).** The measurement
established why: an acquired fleet harvests good months and then decays, so
renewal is the real post-merger job. A scenario that omits it is lying to the
player. Stage 1 should estimate it from the average age band (wide); stage 2
should compute it from the actual aircraft (tight). `fleetLiquidationValue` is
already on the profile and is the honest companion number — how much of the
asking price is metal versus business.

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
