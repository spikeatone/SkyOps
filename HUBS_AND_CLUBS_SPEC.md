# Hubs & Clubs — Design Spec (for designer review)

Status: **DRAFT — not built.** Nothing here is committed to code yet. Every number
below is DESIGNED pacing (tunable), not sourced — flagged per the project's usual
convention. Real-world anchors are noted where they exist.

---

## Problem / Concept

Mid-game Airline Architect has exactly one answer to "I have money": expand —
more aircraft, more routes. There is no way to invest in *depth*. Hubs & Clubs
add a second strategic axis: **concentrate and fortify** an airport instead of
sprawling. The player fantasy (designer's own words): the United-style hub with
its airline club — loyalty you can see on the map.

Two-tier investment ladder, each gated by the one below:

```
routes (5 at one airport)  →  HUB (capital + monthly labor)  →  CLUB (build + monthly rent)
```

**Design intent:** both build airline loyalty and feed the reputation system.

**Hard constraint (designer):** a hub + club must NOT turn that airport into a
money printer. Depth must be *competitive* with expansion, never dominant.
See Balance Guardrails — that section is load-bearing.

---

## Goals

1. A real mid-game decision: "another aircraft, or deepen DEN?" — with genuinely
   different payoffs (volume vs. resilience/yield).
2. Visible airline identity on the map (a fortress hub reads at a glance).
3. Loyalty made mechanical: clubs cushion reputation and defend share against
   competitors, without making reputation purchasable.
4. Zero balance regression: equal capital into "deep" vs "wide" strategies lands
   within the same net-worth band (verified headlessly before ship).

## Non-Goals

- **No frequent-flyer program (yet).** Clubs get one FFR-event tie-in as flavor;
  a full points/redemption economy is a separate future feature.
- **No competitor hubs.** Rivals don't build hubs; competition stays demand-share
  on the player's routes (consistent with the existing scope decision).
- **No per-club interior/upgrade levels.** One club per airport, binary. Tiers
  (Club → Polaris-style flagship) are a P2 future consideration.
- **No new currency or loyalty score.** Loyalty expresses through existing
  systems (reputation floor, competition share, yield) — no third meter.

---

## Mechanic 1 — HUBS

### Eligibility (the gate that creates the pacing)

- **5 player routes that use the airport** (DECIDED — designer confirmed the
  endpoint reading: a route "uses" the airport when the airport is one of its
  two endpoints; tap order is irrelevant since routes fly both directions).
- **Surfacing:** the moment the 5th route touching an airport opens, a
  STRUCTURAL Ops event fires ("DEN reached hub eligibility — 5 routes") and the
  airport's info card gains the `CREATE A HUB — $X` action. Before that, the
  card shows progress ("3/5 routes to hub eligibility").
- Eligibility is *live*: drop below 5 routes and the hub degrades (below).
- Natural Pro-gating: the free tier caps at 2 routes, so hubs are inherently
  Pro-tier content — a real upgrade motivator, no extra gating code needed.
- **No hard cap on number of hubs (DECIDED): costs are the limiting factor.**
  Establishment + growing labor + rent make each additional hub a real
  commitment; no artificial cap.

### Costs

| Cost | Formula (DESIGNED, tunable) | Range | Real-world analog |
|---|---|---|---|
| Establish (one-time) | `$2M + $150k × (airport annual pax / 1M)`, floor $3M, cap $15M | ~$3M (MCI-tier) → $15M (ATL-tier) | gate build-out, ops center |
| Monthly labor | `$60k + $20k × routes-at-hub` | $160k/mo at 5 routes, grows with the hub | ground staff, below-wing ops |

- Labor bills monthly via the existing recurring-billing machinery (same pattern
  as leases/insurance), and **keeps billing while suspended** — see Degradation.
- Scale check: establishment ≈ a used regional jet; labor ≈ a narrowbody lease.
  Real money at the moment it unlocks (5 routes ≈ 3–5 aircraft ≈ mid-game).

### Benefits — Phase 1 (ship first)

1. **Amplified connections:** the existing hub demand bonus (+8% per other
   route at the endpoint) rises to **+12% per spoke** on hub-touching routes.
   The +80% cap DOES NOT rise (anti-printer; see Guardrails).
2. **Negotiated fees:** −20% gate fees and −10% landing fees at the hub airport
   only. (Real analog: signatory-rate volume deals — the fee data is already
   real, this is a principled discount on it.)

### Benefits — Phase 2

3. **Crew base:** crew rest completes 20% faster at the hub (crew facilities) —
   fewer crew holds on hub routes. ⚠️ Duty/rest timing changes are the
   documented bimodal-cliff area: MUST re-run the crew balance sweep.
4. **Maintenance base:** AOG standard-repair timer −25% and repair costs −20%
   for aircraft whose route touches the hub. (Softens, not replaces, the
   Expedite-vs-Standard decision.)
5. **Slot priority:** slot-buyout premium waived at the hub.
6. **Fortress effect:** competitor entry rate −50% on hub-touching routes
   (stacks multiplicatively with the existing reputation deterrence).

### Degradation & exit

- Routes at hub < 5 → status **UNDERSTAFFED**: all benefits suspend, labor
  keeps billing (the overextension trap — deliberate, same philosophy as idle
  leases). Benefits resume automatically at 5.
- **Decommission any time = $0 back (DECIDED).** Walking away recovers nothing
  — the build-out is sunk. Labor stops, hub gone, airport can be re-hubbed
  later (pay full price again).
- **The ONLY way to recoup a hub: sell it to a competitor** — see below.
- Reputation: hubs have **no direct reputation effect**. They protect it
  indirectly (fewer AOG/crew holds = fewer reputation hits). Ops stay the only
  direct driver — deliberate.

### Selling a hub to a competitor (DECIDED — designer's design, "think ten times")

The tension: real money back **now**, in exchange for permanently arming a
rival at that airport.

- **The offer arrives; the player doesn't list it.** A named rival (Big Four /
  ULCC, drawn from the existing roster) periodically bids for a player hub via
  the blue **Offer** decision card (same pattern as the slot buyback):
  *"United wants your DEN hub — $6.2M offered."* Low daily probability for
  healthy hubs; **noticeably higher for UNDERSTAFFED hubs** (vultures circle a
  struggling hub — and that's exactly when the cash is most tempting).
- **Sale price (DESIGNED, tunable):** ~60% of establishment cost for a healthy
  hub, ~35% for an understaffed one. Real enough money to genuinely tempt.
- **Accepting hands the rival a permanent advantage at that airport:**
  - It becomes a **competitor hub** for the rest of the save — rendered on the
    map in the rival's purple (the anti-fortress reads at a glance).
  - Competitor entry rate on player routes touching it: **+50%** (the exact
    mirror of the fortress bonus the player just gave up).
  - The player **cannot re-establish a hub there** — the rival holds the gates.
    This is the irreversible part; it's what makes the decision worth thinking
    about ten times.
  - Any club at the airport closes with the sale (it was inside your hub
    footprint) — club build-out is sunk too.
- **Declining** costs nothing; offers recur occasionally.

---

## Mechanic 2 — CLUBS

### Eligibility

- Requires an **operating (non-suspended) hub** at that airport. One club per
  airport. If the hub suspends, the club's benefits suspend with it (rent
  continues — you signed the lease).

### Costs

| Cost | Formula (DESIGNED, tunable) | Range | Real-world analog |
|---|---|---|---|
| Build-out (one-time) | `$1.5M + $50k × (pax / 1M)`, cap $6.5M | ~$2M → $6.5M | club construction/fit-out |
| Monthly rent | `$35k + $1.2k × (pax / 1M)` | ~$45k → $155k/mo | airport real estate — deliberately painful |

Rent should read as one of the biggest recurring line items in Finance. That's
the point: a club at a weak hub genuinely bleeds.

### Benefits (the loyalty lever — deliberately DIFFERENT from the hub's)

**Design rule: hubs move VOLUME (demand), clubs move YIELD + RESILIENCE.
Neither touches the other's lever. This separation is the primary
anti-money-printer control.**

1. **Yield:** +6% fare on routes touching the club airport. Flat, not
   per-spoke, and **no double-dip** — a route touching two club airports still
   gets +6% once.
2. **Reputation floor (the loyalty cushion):** floor rises to
   `40 + 5 × clubs`, capped at **60**. Ops still move the score up and down
   exactly as today (clubs never ADD points) — loyal flyers just *forgive*, so
   a bad stretch can't crater you below the floor. Keeps reputation honest and
   un-buyable while making loyalty mechanical. (Score starts at 70; the floor
   only matters when things go wrong — it's insurance, not income.)
3. **Loyalty defense:** on club-airport routes, the competition demand-share
   floor rises 0.2 → 0.35 (loyal flyers don't defect to the rival).
4. **FFR liability tie-in:** the existing *FFR Redemption Surge* market event
   hits fares an extra −2% per club while active. Loyalty programs carry
   redemption liability — a small, fair cost that finally gives that event a
   mechanical anchor.

**Club naming (DECIDED):** auto-named "{Airline name} Club" — e.g. "Aster Air
Club" — shown in the airport card and Ops.

---

## Balance Guardrails (load-bearing — designer's hard constraint)

1. **Lever separation.** Hub = demand, Club = yield/resilience. No effect
   stacks on the same variable twice.
2. **The 0.92 load-factor ceiling is the natural printer-killer.** Demand
   bonuses saturate: once hub routes run full, more demand earns *nothing* —
   it pressures the player toward bigger aircraft instead, which is the
   intended strategic consequence (real hub economics), not free money.
3. **The demand cap stays at +80%.** The hub reaches the cap faster (12%/spoke
   vs 8%) but cannot exceed it.
4. **Payback discipline (tuning targets, verified headlessly):**
   - Hub: pays back establishment in **~8–12 sim-months** at 5 healthy routes.
   - Club: **12+ sim-months**, and much of its value is defensive (reputation
     floor, competition share) that only "pays" in bad times — insurance-like.
   - Benchmark: both must pay back *slower* than simply buying another aircraft
     and opening another route. Deep is resilience + identity, not superior ROI.
5. **Costs scale with success.** Labor grows per route; rent scales with
   airport size; suspension keeps billing. A big hub is a big obligation.
6. **Mandatory pre-ship verification (both, not optional):**
   - Extend the **525-check economy regression** with hub/club actions and the
     new invariant terms — must stay 100% green.
   - New **balance-harness A/B**: equal starting capital, 3 sim-years,
     "hub-deep" autopilot vs "sprawl-wide" autopilot. Acceptance: final net
     worth within **±15%** of each other, and the deep strategy must show its
     compensating advantages (higher reputation stability, fewer
     competition losses) rather than higher raw earnings.

---

## Systems & Engineering Integration (how it lands in this codebase)

- **New state:** `Simulation.hubs: [String: Hub]` (airport code → establishedTick,
  suspended), `clubs` likewise. All persisted in `GameSnapshot` (+ save-version
  tolerant decode, like `incentiveBonus` was).
- **Cash invariant (non-negotiable per the documented pattern):** new
  accumulators — `totalHubSpend` (establish, capital-out), `totalClubBuild`
  (capital-out), `totalHubLabor` + `totalClubRent` (overhead) — added to the
  master invariant, `FinanceSnapshot`, `PeriodFigures`, and the Finance cards
  ("Hub operations", "Club rent" lines). Re-run the invariant harness.
- **Billing:** one `tickHubClubBilling()` on the monthly cadence, same commit
  pattern as insurance/leases.
- **Demand/yield hooks:** hub amplification inside the existing
  `hubDemandMultiplier`; club yield inside `rollRevenue`'s fare path; reputation
  floor inside the reputation clamp; competition floor inside
  `competitionShare(reputation:)`.
- **Ops feed:** STRUCTURAL events (hub established / suspended / decommissioned,
  club opened) + an **"Airport Investments"** Ops box (pattern: the existing
  Airport Incentives box) listing each hub/club, monthly bills, status.
- **Milestones:** "First hub established!" and "First club opened!" (SF Symbol
  badges, e.g. `building.2.crop.circle` / `cup.and.saucer.fill`), haptic+chime
  free via the existing celebration hook.
- **Map:** hub airports get a distinct ring/badge (e.g. gold double-ring; club
  adds a small glyph). This is the "identity on the map" payoff — worth a Figma
  pass if you want it exact; otherwise I'll derive from the existing map style.
- **UI entry point:** the airport info card (tap an airport) gains
  `ESTABLISH HUB — $X` when eligible (shows the 5-route progress when not,
  e.g. "3/5 routes — open 2 more to unlock"), and `BUILD CLUB — $X` once a hub
  operates. iPad: docks in the side rail like every other card.

---

## Phasing

| Phase | Scope | Verification |
|---|---|---|
| **H1** | Declare hub: eligibility, establish cost, monthly labor, demand amplification, fee discount, suspension/decommission, map badge, Finance lines, persistence, Ops events, milestone | Invariant harness green; hub-vs-sprawl A/B sweep |
| **H2** | Hub ops benefits: crew rest, MX base, slot priority, fortress entry-rate | Crew-cliff re-sweep (documented bimodal risk); AOG lifecycle checks |
| **H3** | Clubs: build/rent, yield, reputation floor, loyalty defense, FFR tie-in | Invariant + A/B re-run with clubs; reputation-floor unit checks |
| **H4** | Polish: Airport Investments Ops box, iPad rail treatment, any Figma-driven map badge refinement | Visual pass both devices/themes |

Each phase ships independently playable; H1 alone is already a real feature.

---

## Resolved Decisions (designer review, this pass)

1. **Eligibility:** "CREATE A HUB" unlocks once **5 player routes use the
   airport** (endpoint count — tap order irrelevant). Surfaced via an Ops event
   + the airport card action.
2. **No hub cap:** costs are the limiting factor — establishment, growing
   labor, and rent make each hub expensive enough to self-limit.
3. **No decommission refund.** The ONLY recoup path is **selling the hub to a
   competitor** (rival's Offer card, ~60% healthy / ~35% understaffed) — which
   permanently arms that rival at the airport (+50% entry pressure, purple
   competitor-hub map badge, player can never re-hub there, any club closes).
   Deliberately a "think ten times" decision.
4. **Club naming:** auto-"{Airline name} Club."
5. **Map badge:** derived from the existing map style (no Figma frame needed) —
   player hubs get a distinct ring/badge in the player's visual language,
   competitor-owned hubs render in the rival purple.

## Remaining Tunables (my call, flagged for playtest)

- Sale-price percentages (60/35), takeover-offer daily probabilities, all cost
  formulas, benefit magnitudes — every number is DESIGNED pacing, to be
  calibrated by the balance-harness A/B and adjusted after on-device feel.

---

## Success Criteria

- A mid-game player with 5 routes at one airport faces a genuine fork
  (deepen vs expand) and both are viable 3 sim-years later (±15% net worth in
  the harness A/B).
- A hubbed+clubbed airline survives a bad stretch (AOG cluster, recession,
  competitor entry) measurably better than a sprawled one — resilience is the
  product being sold.
- The map visually communicates the player's strategy at a glance.
- 0 regressions: economy invariant stays green; crew sweep stays in the stable
  band; no change to non-hub play.
