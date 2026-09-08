# Crew Training — re-imagined (scope + recommendations)

**Status: Phase 1 MERGED to `main` (8 Sep 2026, `162b865`) · Phase 2 BUILT on branch
`training-center` (8 Sep 2026). All 5 decisions confirmed (decision 4 = ratio + verdict; provider =
"Global Aviation Training"). Verified `CrewPipelineVerify` 63/63 + `TrainingCenterVerify` 69/69 +
`TrainingCenterABProbe` 5/5 + regressions + full build + German clean.**

## Phase 2 as BUILT (differs from the §3.5 draft — read this before touching the numbers)

- **Costs are GAME-SCALED, not real-world-scaled.** The draft priced a real Level D simulator
  (facility $6M + bays $6–16M, $270k/mo). The game's training VOLUME can't amortize that: a
  crew sits 2 recurrents a year, so a whole 16-aircraft narrowbody family only generates ~$1.3M
  of course fees a year. Shipped: **facility $750k** + **bay $2.5M widebody / $1.25M narrowbody /
  $800k turboprop**, opex **$4k/mo facility + $8k/mo per bay**. In-house course = **0.4×** the
  contract price, **30d** initial (vs 45), **2d** recurrent (vs 4).
- **The contract provider now has a LEAD TIME** (0–10 days for a class slot on a new hire), which
  the center removes — the scope's §3.3 wait, pulled forward into Phase 2 because it's most of
  what makes in-house feel different.
- **⚠️ THE CONCURRENCY CAP IS THE BAY CAPACITY — do not restore a fraction-based cap for a family
  with a bay.** The first A/B run had the auto-scheduler cap scale with pool size (20%) while a bay
  seats only 4, so each wave pushed its surplus to the CONTRACTOR at full price: 1-in-5 overflow at
  12 aircraft, 2-in-6 at 16, 6-in-10 at 24. Savings stopped scaling with the fleet and **16 aircraft
  paid back WORSE than 12** — the opposite of the intended shape. With the cap set to the bay's
  capacity, scheduled training all runs in-house (2-day courses inside a 30-day window churn 4 seats
  far faster than crews come due); urgent about-to-lapse crews still bypass the cap to the
  contractor, which is the safety valve.
- **BALANCE GATE PASSED** (`TrainingCenterABProbe`, 6 arms × 5 sim-years, payback = savings vs
  contract − facility − opex):

  | family | 24 mo | 36 mo | 48 mo | 60 mo |
  |---|---|---|---|---|
  | 6 × A320 (the build gate) | −$1.70M | −$1.53M | −$1.39M | **−$1.26M — never** |
  | 12 × A320 | −$1.27M | −$828k | −$622k | −$766k |
  | 16 × A320 | −$744k | −$32k | **+$596k** | +$1.16M |
  | 24 × A320 | −$117k | **+$812k** | +$1.32M | +$1.28M |
  | 8 × B788 | −$1.05M | **+$350k** | +$1.47M | +$2.47M |

  Value-sink for a small family, pays back for a large one — the Hubs-lesson threshold, never
  dominant. **Re-run this probe after touching ANY center/course constant.**
- **KNOWN TENSION worth a designer look: the build gate (6 aircraft) sits well below break-even
  (~14 narrowbodies, ~7 widebodies).** The gate is the confirmed decision, so it stands; the trap is
  defused in the UI instead — the bay row reads "Course savings repay it above ~N aircraft in this
  family" (`simBayPaybackAircraft`, derived from the course fee and the 2.1-crews-per-aircraft ratio,
  not hardcoded). Raise `simBayMinAircraft` to ~12 if you'd rather the game refuse the bad build
  outright.
- **The ledger IS the A/B** (methodology worth reusing): every in-house course books
  `savings = contract price − in-house price`, so `payback = savings − facility − opex` is exactly
  the delta against a contract-only twin with the same course volume. Economic events, AOG and
  weather all cancel because they never touch the ledger — no two-sim A/B, no event poisoning
  (the FareVerify lesson).
- **Harness lesson (cost me two false failures):** on a FLYING fleet, a graduated crew goes straight
  `.onDuty`, so asserting `.available` is wrong (assert `isLineReady`); and a cash-delta assertion
  also contains a day of flight revenue plus the monthly opex, so measure a training charge via
  `maintenanceSpend` minus the ledger's opex delta. `TrainingCenterVerify` test 5 parks the fleet
  first to make concurrency deterministic.
Designer ask (8 Sep 2026): make crew training real-world in timelines; hiring is not
instant — an acquired aircraft comes with ONE crew, the next has to be hired AND trained;
mid-game, build your OWN training center (early game = contracting out to a
FlightSafety/CAE-style third party) to cut cost + time; expand the CREWS tab with real
detail on how crews are trained, scheduled, deployed — WITHOUT "assign every crew to
every flight" tedium. Also: the recurrent-training cards move OFF Ops onto Crews.

---

## 1. What exists today (code-grounded — see the survey in this session)

| Piece | Today |
|---|---|
| Crew unit | `Crew {id, status, dutyTicks, restTicksLeft}` — one cockpit crew per family pool. No qualification state, no currency, no identity. |
| Statuses | available / onDuty / resting / sidelined. `sidelined` collapses to `available` on reload (labor/dispute/training downtime are NOT persisted). |
| Bundled crew | Buy/lease/used → `grantBundledCrew`: exactly 1 crew, +1 reserve seeded on the family's first aircraft. |
| Hiring | `hireCrew(family)` — INSTANT, line-ready, cost = 0.2% of a representative type's price (Dash 8 $9k · CRJ $72k · A320 $134k · 787 $400k · 777 $578k). Goes into `maintenanceSpend`. |
| Duty/rest | Part 117: 600/600 ticks; a crew flies ~55% of the time → ~1.8 crews/aircraft is the continuous-coverage break-even (balance-swept; bimodal cliff — don't retune casually). |
| Recurrent | One FAMILY-WIDE card every 150 days: "Train now" (25% of the pool sidelined 4 days, cost = hire cost) or "Defer 30 days" (1.6×). Fires for every family on its own clock → your screenshot: FIVE cards at once. |
| Crews tab | One card per owned family: 2×2 grid (Available / On duty / Resting / Reserve), HIRE button, labor-action box. **No training UI at all.** Training-sidelined crews just vanish from "Available". |
| Real-world refs in code | `crewsPerTail` (6 short-haul / 11 long-haul) exists only as a comment — the game deliberately doesn't compute a crew need for the player. |

---

## 2. Real-world anchors (what the model is calibrated against)

Confidence marked like the rest of this project: **real** = sourced practice, **approx** = commonly-cited
range, **designed** = game pacing.

- **New-hire initial training** (Part 121): indoc + ground school + fixed-base trainer + ~8–12 full-flight
  sim sessions + type-rating checkride + **IOE** (25+ hrs line flying with a check airman). Total footprint
  **~6–10 weeks** door-to-line. *(real, approx duration)*
- **Already-rated hire** (a pilot who holds the type rating): indoc + short IOE, **~2 weeks**. Airlines pay a
  premium to poach these because they skip the course. *(real)*
- **Transition training** (rated on another type): **~4–6 weeks**; **differences** (737NG→MAX, A320ceo→neo)
  is days — which is exactly why those pairs are ONE crew family here already. *(real)*
- **Recurrent**: FAA 14 CFR 121.441 proficiency check **every 6 months for a PIC**, 12 for an SIC; AQP
  carriers run continuing qualification on ~9-month cycles. Each event is **~2–3 days** of sim + ground.
  *(real)* The game's 150-day family clock is roughly this — the shape (one big shock per family) is what's
  wrong, not the cadence.
- **Currency lapse is a hard stop**: an expired check means the pilot legally cannot fly until requalified.
  *(real)* — this is the natural "teeth" for deferring.
- **Third-party vs in-house**: small/mid carriers buy sim time from CAE / FlightSafety / L3Harris / the OEMs
  (~$400–800/hr dry-lease for a Level D sim, subject to slot availability); majors run their own centers
  (United Denver, Delta Atlanta, American DFW). A Level D full-flight sim costs **~$10–20M** plus a
  purpose-built bay, ~$1M+/yr to run, and is worth it only above a fleet size where the sim stays busy.
  *(real, approx $)*
- **OEMs bundle initial-cadre training with a new aircraft purchase** (Boeing/Airbus training entitlements).
  *(real)* — this is the realism justification for keeping the 1-crew bundle.
- **Staffing**: ~5–6 crews per narrowbody, 10–14 per long-haul widebody. *(real; the existing `crewsPerTail`
  reference)*

---

## 3. Recommended design — "the crew pipeline"

The single new idea: **a crew has a qualification state, and getting from HIRED to LINE-READY takes
sim-days and money that depend on WHO trains them.** Everything else hangs off that.

### 3.1 Crew states (extends today's 4)

```
hired ─▶ TRAINING (readyTick) ─▶ line-ready: available ⇄ onDuty ⇄ resting
                                      │
                                      ├─▶ RECURRENT (2–4 days, rolling, then back)
                                      ├─▶ LAPSED  (currency expired — cannot be assigned until retrained)
                                      └─▶ sidelined (labor action / seniority dispute — unchanged)
```

- `Crew` gains `readyTick: Int?` (nil = line-ready) and `currencyExpiresTick: Int`.
- The boarding-gate `assignCrew` only takes `available` crews — TRAINING / RECURRENT / LAPSED are simply
  not available. No per-flight assignment anywhere; the gate stays automatic. **Zero new tedium in the
  flying loop.**
- Persisted (tolerant-decode): `CrewSave` gains `readyTick`, `currencyExpires`, extended status code.
  Legacy saves: every crew line-ready with currency **staggered** across the next cycle (real fleets are
  staggered; also dissolves the 5-cards-at-once for existing saves).

### 3.2 Hiring — two doors per family (the "hire AND train" ask)

| Option | Cost | Line-ready in | When you'd pick it |
|---|---|---|---|
| **Rated hire** (already type-rated) | 2.0 × course | **10 days** (indoc + IOE) | You're in a crew hold NOW and can pay for speed |
| **New hire → type-rating course** | 0.25 × course (recruit) + 1.0 × course | **45 days** contracted · **30 days** own center | Planned growth; cheaper per crew |

`course(family)` = today's `crewHireCost` (the 0.2%-of-price figure), reframed as the type-rating course.
Net: a rated hire costs 2× what a hire costs today and is 10 days out; a new hire costs 1.25× and is 45
days out; the own center brings a new hire to **0.75× / 30 days** (course −50%, time −33%). Every figure
is a single tunable constant.

**Early-game guard (hard requirement):** the bundled crew stays line-ready, so a $20M starter's first
aircraft flies immediately; its second crew is a 10-day rated hire — the existing `holdBurnRate = 0.4`
keeps a single-crew aircraft's holds a recoverable setback, not a spiral. Phase 1 is GATED on re-running
`aa-1.1.x/free-tier-probe` + a crew-pipeline probe proving a starter survives the first 45 days.

### 3.3 Recurrent — rolling, automatic, with teeth (replaces the family-wide card)

- Each crew carries its own currency: **180 sim-days** (the 6-month PIC check). Recurrent takes **4 days
  contracted / 2 days own center** per crew, costs **15% of course** (7.5% own).
- **AUTO-SCHEDULE policy (default ON)** per family: each day, a crew whose currency expires within 30
  days and is `available` is sent to recurrent — **at most max(1, 10%) of the family out at once**. So the
  disruption is a rolling trickle instead of 25% of a family vanishing for 4 days, and there is NO card to
  answer. Cost is billed per crew as it happens (visible on Crews + Finance).
- **Policy OFF = the old "defer" choice, made explicit and dangerous:** currency expires → the crew is
  **LAPSED** (can't fly), the Crews card goes red, a single "Retrain N lapsed · $X" action appears (1.6× per
  crew — the expedited-requal penalty, same multiplier as today's defer), and an exception alert reaches
  the bell. Exactly the MX "overdue = surcharge" pattern that made the service-vs-defer choice real.
- **Ops loses the training cards entirely** (designer: "off Ops"). Training lives on Crews; the bell keeps
  only the LAPSED exception (it's the global inbox).

### 3.4 CREWS tab v2 — the "trained, scheduled, deployed" detail

Per owned family, one card, three bands (no new screens, no drill-down needed):

1. **Deployment** — the 2×2 becomes a strip: *Available · On duty · Resting · Reserve*, plus a
   **coverage readout**: "6 line-ready for 3 aircraft · 2.0/aircraft" with a one-line verdict
   ("Continuous coverage" / "Expect crew holds — hire 1–2 more"). See Decision 4 — this reverses the
   "player figures out the ratio" call.
2. **Training pipeline** — rows for anyone not line-ready: "New hire · ready in 31d", "Recurrent · back in
   2d", "LAPSED · retrain $X". Plus the family's **next recurrent window** ("next 3 checks due in 12d ·
   auto-scheduled"). The AUTO toggle lives here.
3. **Hire** — the two doors from §3.2 side by side, priced live, with "line-ready in N days" on each.

A **TRAINING** section at the top of the tab (above the family cards) shows the provider: "Contract
training partner · slots available" today, and becomes the Training Center card in Phase 2 (§3.5).

### 3.5 Training Center — the mid-game facility (Phase 2)

- **Build at an OPERATING HUB** (real centers sit at a hub city; also reuses the hub's "concentrate here"
  identity). One facility per airline; **one SIM BAY per crew family** you choose to equip.
- **Costs** (designed, anchored to §2): facility **$6M** + bay by class (**turboprop/RJ $6M · narrowbody
  $10M · widebody $16M**); opex **$120k/mo** facility + **$150k/mo** per bay (instructors, maintenance).
- **Benefits for an equipped family**: course cost −50%, training time −33% (initial 30d, recurrent 2d),
  **no contract lead time** — Phase 2 also introduces a realistic **0–10-day wait for a contract class
  slot**, which the center removes — and rolling recurrent at 2× concurrency.
- **Capacity (the realism lever that makes it a decision, not a button)**: a bay trains up to **4 crews
  at once**; overflow silently uses the contractor (no dead ends, just no discount for the overflow).
- **Gate**: an operating hub AND ≥ **6 aircraft in the family** per bay (tunable; the free tier's 6-aircraft
  cap keeps this Pro-territory naturally).
- **Finance**: ONE new cash-invariant capital term (`totalTrainingCenterSpend`); course fees + opex keep
  flowing through the existing `maintenanceSpend` overhead line (displayed as its own "Crew training"
  sub-row). A **TRAINING P&L** payback line (savings vs contract − facility cost) in the same style as the
  hub chart, so the player can see whether the center is earning its keep.
- **Balance gate (the Hubs lesson, mandatory before ship)**: an A/B at 4 / 8 / 16 aircraft-per-family must
  show the center is a **value-sink for a small fleet and pays back for a large one** — a genuine
  threshold, never dominant.

### 3.6 Non-goals (deliberate)

- **No per-flight crew assignment** and no crew bases/commuting — the gate stays automatic.
- **No individual pilot identities, seniority lists, or captain upgrades** (seniority is already modeled
  where it matters — the acquisition dispute).
- **No cabin crew** — real cabin qualification is cheap and cross-type; modeling it is a cost line with no
  decision in it.
- **Duty/rest constants untouched** (the documented bimodal cliff). The 100-hr/month Part 121 cap is a
  possible Phase 3 realism add ONLY with a fresh balance sweep.

---

## 4. Phasing

| Phase | Scope | Verification gates |
|---|---|---|
| **1 — Pipeline + Crews v2** | Crew states + currency, rated/new-hire doors, rolling auto-recurrent with LAPSED, training cards off Ops, Crews tab v2, persistence, German | `CrewPipelineVerify` harness (states, timelines, costs, lapse teeth, save/load incl. legacy stagger, cash invariant), free-tier probe re-run, early-game survival probe, full Debug build, live Simulator drive |
| **2 — Training Center** | Facility + bays at a hub, contract lead time, capacity/overflow, Finance term + P&L line, German | Harness (gate, costs, discount/time math, overflow, invariant), **center-vs-contract A/B at 3 fleet sizes**, live drive |
| **3 — optional** | Rated-pilot MARKET (limited pool per family that regenerates), transition training across families (21d/14d), selling surplus sim hours, training subsidiaries' crews after an acquisition | Designer's call after 1–2 are felt in play |

Build on a branch (`crew-training`), Phase 1 first; commit this doc to `main` now.

---

## 5. Risks

1. **Early game** — any "hiring takes days" model can starve a 1-aircraft starter. Mitigated by the
   line-ready bundle + the 10-day rated door + `holdBurnRate`; PROVEN by the probe, not assumed.
2. **Crew balance cliff** — the 1.8/2.1 sweep assumed instant hires. The pipeline delays supply, so the
   sweep must be re-run with pipeline latency in the loop.
3. **Save migration** — currency for existing crews must be staggered or every legacy save gets a lapse
   wave on load.
4. **Scope creep** — Phase 3 items are tempting; none ship until 1–2 are played.

---

## 6. Decisions (designer answers, 8 Sep 2026)

| # | Decision | Answer |
|---|---|---|
| 1 | Timelines 45d / 30d / 10d; recurrent every 180d at 4d / 2d | **Confirmed — "feels right"** |
| 2 | Recurrent automatic + rolling by default; LAPSED is the deferral penalty; no family-wide card | **Confirmed** |
| 3 | Training Center: hub-required, one bay per family, ≥6 aircraft/family per bay, 4-crew capacity, contractor overflow | **Confirmed** |
| 4 | Coverage readout on the Crews card | **PENDING** — designer asked for more detail (answered in chat 8 Sep) |
| 5 | Provider naming | **"Global Aviation Training"** — a fictional house name (no real-brand reference); it's the contract provider named everywhere training is priced or scheduled |

The original questions, for the record:

1. **Timelines** — initial 45d contracted / 30d own; rated hire 10d; recurrent every 180d at 4d/2d.
   Right feel at 5×–100× speed, or compress further (e.g. 30/20/7)?
2. **Recurrent becomes automatic + rolling by default**, with LAPSED as the deferral penalty — replacing
   the family-wide card entirely. Confirm?
3. **Training Center gate + shape** — hub-required, one bay per family, ≥6 aircraft/family per bay, 4-crew
   capacity with contractor overflow. Confirm the threshold and the hub requirement?
4. **Coverage readout on Crews** ("2.0/aircraft · continuous coverage") — this REVERSES the earlier
   "the game doesn't calculate the crew need for the player" decision. Show it, or keep it to the raw
   counts + the crewsPerTail reference?
5. **Provider naming** — "Contract training partner" (generic, recommended), a fictional house name, or
   real names (CAE / FlightSafety) under the existing text-only-reference policy?

Reserve-crew mechanic ($5k one-time reserve per family): **keep as-is in Phase 1** (recommended — it's
orthogonal and churning it adds risk for no realism gain); revisit in Phase 3 if the rated-pilot market
lands.
