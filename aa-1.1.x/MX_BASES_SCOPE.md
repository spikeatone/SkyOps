# Maintenance — backgrounded A checks, MRO premium, own maintenance bases (scope)

**Status: ✅ PHASES 1 AND 2 BUILT (9 Sep 2026). All 5 decisions were CONFIRMED as proposed (§6)
and are implemented as written; the one measured DEVIATION from the balance gate's wording is
recorded in §7. Phase 3 remains optional and unbuilt.** Sibling of `CREW_TRAINING_SCOPE.md`; read
them together — they share one "facility" pattern (§3.5).

## ✅ What shipped (9 Sep 2026)

| Piece | Where |
|---|---|
| Auto-A policy (default ON), no cards, one daily Ops roll-up | `Simulation.tickAutoAChecks` · toggle on FLEET ▸ MAINTENANCE |
| Contract MRO: +25% on every check, 0–7-day hangar-slot wait on C/D | `mxProviderCostMultiplier` · `mxSlotWaitDays` · `tickMXBookings` |
| Line stations / hangar bases, capacity + overflow, network coverage | `Sim/MaintenanceBase.swift` · the "Maintenance network" MARK in Simulation.swift |
| `totalMXBaseSpend` as a new cash-invariant capital term | `cashInvariantResidual()` |
| Per-base payback ledger (fees saved + flying days returned) | `MaintenanceBase.MXBaseLedger` · the bases card |
| **The cycles→days bug** — four sites converted at a hardcoded `2` while the engine flies ~3.52, so every maintenance DATE was ~76% too far out | `Simulation.mxCyclesPerSimDay`, derived from `legCycleTicks` |

**Measured, 60 aircraft × 180 sim-days:** MX decision cards **243 → 0**, with flights unchanged
(35,895 → 35,777, inside noise). **100% of the card load was A checks** — which is why
backgrounding them is the whole fix. Harnesses: `MXBaseVerify` 86/86 · `MXBaseABProbe` 7/7 ·
`MXCoverageVerify` 82/82. Driven live on the iPad sim.


Player feedback (relayed 8 Sep 2026, and it's good): *"dealing with A-checks for an airline of 180
planes takes about ⅓ of player time — too much. There should be a way to pay for maintenance hubs
with a given capacity, and then most of this should be backgrounded. Most A-checks are done
overnight on the line without disrupting a plane's flight schedule much."* Designer direction: a
mid-game **maintenance base** at hubs and other strategic locations (not cheap; faster; cheaper
than the **third-party MROs** small/new airlines outsource to, which are scalable but carry a
premium), and **all MX moves to a new section under the FLEET tab.**

---

## 1. What exists today (`MX_PROGRAM_SPEC.md`, shipped in 1.7)

| Piece | Today |
|---|---|
| Checks | Line/A/C/D on the tighter of a CYCLE or CALENDAR limit; D pegged to lifespan/3. Cost = % of purchase price (A 0.05% · C 1.2% · D 4%); downtime blocks at the gate. |
| The decision | **Every due check pushes a `.mxCheck` card** — Service (pay, downtime) or defer. Overdue → 2.5× surcharge, AOG ×6, hard legal window → forced grounding. C/D on a routed aircraft get the like-size **coverage** flow (spare covers, or acquire, or suspend). |
| Where | OPS ▸ Maintenance box (nearest-date-first as of today's fix) + Needs Attention cards + the bell. |
| The pain | A checks are the FREQUENT ones (short interval), so at 180 aircraft the player is answering an A-check card every few sim-hours — a chore with no decision in it (nobody defers an A check). |

---

## 2. Real-world anchors

- **A check**: every ~400–600 flight hours (roughly every 1–2 months for a busy narrowbody), **6–10
  hours, done OVERNIGHT at a line station** — the aircraft flies its schedule the next morning.
  *(real)* This is the whole point: an A check is not a scheduling event, it's a night.
- **C check**: every ~18–24 months, **1–2 weeks** in a hangar; **D (heavy) check**: every 6–10 years,
  **3–6 weeks**, $1–6M. *(real)* — these ARE planning events, and the game already treats them as such.
- **Who does the work**: airlines run their own **line maintenance at hubs/bases** (where aircraft
  overnight); most **outsource heavy checks** to MROs (AAR, HAECO, ST Engineering, Lufthansa Technik,
  AFI KLM E&M; Delta TechOps SELLS capacity to others). Roughly half or more of airline MX spend is
  outsourced; small/new carriers outsource nearly all of it. *(real, approx share)*
- **The MRO premium is mostly SLOTS, not just rate**: hangar slots book months out; labor rates run
  modestly above in-house fully-loaded cost. *(real, approx)* → in the game: a cost premium AND a
  lead time.
- **Hangars are capital**: a narrowbody hangar ~$20–50M, widebody-capable $50–150M, plus staff.
  *(real, approx)* Airlines build them at hubs first, then at strategic outstations.

---

## 3. Recommended design

### 3.1 A checks go to the background (Phase 1 — the ⅓-of-player-time fix) ✅ BUILT

- **Policy: "Service A checks automatically" — default ON**, on the new Fleet ▸ Maintenance section.
  A due A check is serviced at the aircraft's next gate WITHOUT a card: fee charged, logged once in
  Ops Events (not an alert), downtime per §3.3. **No `.mxCheck` card for A checks.**
- Policy OFF keeps today's per-aircraft card (for the player who wants to micro-manage).
- **C and D stay decisions** — they're real planning events with real downtime, and the coverage
  flow already makes them interesting. They're also RARE (C every ~18 months, D 2–3× per airframe
  life), so the alert load collapses to the checks that deserve a look.
- Overdue/forced-grounding teeth are unchanged.

### 3.2 Third-party MRO — the default provider, with a premium (Phase 2) ✅ BUILT

- With no base of your own, every check goes to a contract MRO: **+25% on the check cost** and, for
  C/D, a **0–7-day wait for a hangar slot** before the downtime starts (the aircraft keeps flying
  while it waits — no dead time, just a later shop date). A checks have no wait (line stations are
  everywhere) but keep the premium.
- This is what makes a base worth building: it removes BOTH the premium and the wait.

### 3.3 Maintenance bases (Phase 2 — the mid-game facility) ✅ BUILT

- **Build at an operating HUB, or at any "strategic" airport with ≥ 3 of your routes touching it**
  (the designer's "other strategic locations" — a real outstation with line maintenance).
- **Two tiers**: **Line station** (A checks only — cheap: **$4M** + $60k/mo) and **Hangar base**
  (A + C/D: **$18M** narrowbody-class / **$45M** widebody-capable, + $250k/mo per hangar line).
  Figures are designed pacing anchored to §2, scaled to the game's economy like hubs/clubs.
- **Benefits at a base**: check cost **−30%** (vs the MRO's +25% → ~45% cheaper than outsourcing),
  downtime **−25%**, **no slot wait**. A checks at a base or hub-with-line-station are **overnight =
  zero lost legs** (the realism the feedback describes); elsewhere an auto A check costs the
  existing `mxADowntimeDays`.
- **Capacity is the decision lever**: a hangar line holds **2 aircraft in C/D at once**; overflow
  goes to the MRO (premium + wait) — so an under-built network feels it in the wallet, never in a
  dead end. Line stations have no capacity cap (A checks are quick).
- **Location matters through the network**: an aircraft uses a base only if its ROTATION touches that
  airport (that's where it overnights). A hub-and-spoke network gets near-total coverage from one
  hub base; a scattered point-to-point network doesn't — the same strategic pull as hubs.
- **Finance**: ONE new cash-invariant capital term (`totalMXBaseSpend`); base opex + all check fees
  keep flowing through the existing `totalMaintenanceCheckSpend` (displayed split). A **MX P&L**
  payback line (MRO premium avoided − facility cost), the hub-chart pattern.
- **Balance gate (mandatory, the Hubs lesson)**: A/B at 6 / 20 / 60 aircraft must show a base is a
  value-sink for a small fleet and pays back for a big one — a threshold, never dominant.
  **✅ RUN (`aa-1.1.x/MXBaseABProbe.swift`, 36 sim-months, 7/7). Result in §7 — the hangar meets it
  exactly; the line station gates on NETWORK SHAPE instead of fleet size, which is flagged, not
  silently accepted.**

### 3.4 FLEET ▸ MAINTENANCE — the new home (Phase 1) ✅ SHIPPED in 1.8.0 (9 Sep 2026)

> **DONE — do not rebuild.** The segment exists (My Fleet · Marketplace · Maintenance),
> `MaintenanceView.swift` owns the due list / Details / coverage flow, and Ops is reduced to the
> one-line summary row that links here. What is still OUTSTANDING from this section is the POLICY
> TOGGLE (auto A checks) and, from Phase 2, the Bases card and the Provider line — the placement is
> settled, the automation is not. See CLAUDE.md "Decided — MX lives on FLEET, not Ops".
> ⚠️ Moving it cut the SCREEN REAL ESTATE, not the CARD VOLUME. The card volume is the auto-A work
> below, and it is the thing the designer actually asked for.

The Fleet tab's segmented control grows a third segment: **My Fleet · Marketplace · Maintenance**.
It holds, top to bottom: the **policy** toggle (auto A checks); the **due list** (nearest date first
— today's fix — with the existing Details/coverage flow per row); **In shop** (with return dates);
and, from Phase 2, the **Bases** card (build / capacity / per-base P&L) and the **Provider** line
("Contract MRO · +25% · slot wait ~N days"). **Ops keeps only what's an ALERT**: the C/D and
overdue cards in Needs Attention, plus a one-line summary drawer ("Maintenance · 3 due · 1 in shop
→ Fleet") so a player scanning Ops still sees the state. The Ops Maintenance box goes away.

### 3.5 Shared facility pattern (with the Training Center)

Training Center and Maintenance Base are the same shape: **contract-out early (premium + wait) →
build your own mid-game (capital + opex, capacity, −cost, −time, no wait) → overflow falls back to
the contractor**. Build them on ONE `Facility` model (site airport, class, capacity, opex, ledger,
payback series) and one balance-probe harness, so the second is cheap once the first exists. Both
sit at hubs by default, which quietly makes hubs the game's mid-game capital anchor — on-intent.

### 3.6 Non-goals

- No per-check parts/labour/technician modeling; no engine shop visits as a separate system.
- No MX for background traffic (cosmetic, unchanged).
- Selling MRO capacity to other airlines (the Delta TechOps play) is Phase 3 at most.

---

## 4. Phasing

| Phase | Scope | Gates |
|---|---|---|
| **1 — Background A checks + Fleet ▸ Maintenance** | Auto-A policy (no cards), Ops slimmed to alerts + summary drawer, the MX section on Fleet (due list, in-shop, policy), German | `MXProbe` extended (auto-A charges + downtime, C/D cards still fire, overdue teeth intact, cash invariant), full build, live drive on a large-fleet save |
| **2 — MRO premium + bases** | +25%/slot-wait provider, line stations + hangar bases at hubs/strategic airports, capacity + overflow, network-coverage rule, Finance term + MX P&L, German | Harness + **base-vs-MRO A/B at 3 fleet sizes**, live drive |
| **3 — optional** | Sell hangar capacity (income), subsidiaries' fleets use your bases, engine shop visits | After 1–2 are played |

Phase 1 alone answers the player's complaint and can ship on its own.

---

## 5. Risks

1. **Auto-A makes MX invisible** → the C/D decisions + the visible bill keep it a game; the policy
   toggle keeps the option to micro-manage.
2. **Coverage rule too punishing for point-to-point players** → the MRO fallback always works; it just
   costs more (no dead ends).
3. **Two facility systems drifting apart** → build both on the shared `Facility` model (§3.5).

---

## 6. Decisions needed (5)

1. **Auto A checks default ON** (no cards; Ops event only), toggle on Fleet ▸ Maintenance. Confirm?
2. **Overnight = zero lost legs at a base/hub line station; existing 1-day downtime elsewhere.**
   Confirm, or make ALL auto A checks zero-downtime (simpler, less reason to build line stations)?
3. **Base placement rule**: operating hub OR any airport with ≥3 of your routes. Two tiers (line
   station $4M / hangar base $18M–$45M), 2-aircraft C/D capacity per hangar line. Confirm the
   thresholds and the hub-or-strategic rule?
4. **MRO premium +25% and a 0–7-day C/D slot wait** as the default provider. Confirm the size?
5. **Fleet ▸ Maintenance as a third SEGMENT** (My Fleet · Marketplace · Maintenance) with Ops keeping
   only alert cards + a one-line summary drawer. Confirm the placement?

---

## 7. Measured results, and the one deviation from the gate's wording

`aa-1.1.x/MXBaseABProbe.swift`, 36 sim-months per arm, A320 fleets.

**THE METHOD IS THE REUSABLE PART, and it is the Training-Centre lesson applied:** the base's own
ledger *is* the A/B. Every check a base delivers books (what the MRO would have charged − what the
base charged) plus the flying days it handed back, so `payback = feeSavings + timeValue − build −
opex` is exactly the delta against a contract-only twin flying the same schedule. No two-sim A/B,
so economic events, weather and AOG cannot poison it — the trap that invalidated the first
acquisition run and the first FareVerify attempt.

| arm | payback | fees saved | time returned | opex |
|---|---|---|---|---|
| line station · 6 a/c · hub-spoke | **+$4.46M** | $2.91M | $7.71M | $2.16M |
| line station · 20 a/c · hub-spoke | **+$30.40M** | $9.81M | $26.75M | $2.16M |
| line station · 54 a/c · hub-spoke | **+$92.38M** | $26.27M | $72.27M | $2.16M |
| line station · scattered (3–4 served, any fleet size) | **−$0.5M … −$0.8M** | ~$1.7M | ~$3.9M | $2.16M |
| hangar base · 6 a/c · hub-spoke | **−$7.99M** | $9.79M | $9.22M | $9.00M |
| hangar base · 20 a/c · hub-spoke | **+$22.74M** | $20.09M | $29.66M | $9.00M |
| hangar base · 54 a/c · hub-spoke | **+$87.02M** | $39.46M | $74.57M | $9.00M |

- **The HANGAR BASE meets the gate exactly as written**: a value-sink at 6 aircraft, a payback at
  20, better at 54. $18M of hangar is a real fleet-size threshold.
- **⚠️ THE LINE STATION GATES ON NETWORK SHAPE, NOT FLEET SIZE — a real deviation, flagged for the
  designer rather than fixed unilaterally, because §6 decision 3 confirmed the $4M price.** A
  SCATTERED network never pays one back at any size (the strategic pull the spec asked for, arriving
  on the other axis), but a CONCENTRATED one pays it back from about **4 served aircraft** — and the
  eligibility bar is 3 routes at one airport, so the moment you *can* build it, it is close to
  break-even and profitable thereafter. It is an unlock, not a dilemma.
- **Why**: value is ≈ **$1.64M per served aircraft per 3 years**, and roughly two-thirds of that is
  the flying DAY an A check no longer costs (decision 2: overnight at a base, one day elsewhere).
  The fee saving alone would not repay it.
- **If the designer wants a strict size threshold on the line station too, it is ONE constant.**
  Raising `mxBaseBuildCost(.lineStation)` from $4M to ~$14M puts break-even near 10 served aircraft
  — but $4M is the realistic price of a crew, a van and a small facility, so the honest alternative
  is decision 2: make ALL auto-A checks zero-downtime (the option §6 offered and the designer
  declined), which removes most of the line station's value at a stroke.
- Do NOT tune off one run. Course volume rides on random events and crew availability; read the
  table as ranges.
