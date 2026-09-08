# Maintenance — backgrounded A checks, MRO premium, own maintenance bases (scope)

**Status: DECIDED 8 Sep 2026 — all 5 decisions CONFIRMED by the designer as proposed (§6). Build
order: crew training Phase 1 first (branch `crew-training`), then MX Phase 1. Sibling of
`CREW_TRAINING_SCOPE.md`; read them together — they share one "facility" pattern (§3.5).**

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

### 3.1 A checks go to the background (Phase 1 — the ⅓-of-player-time fix)

- **Policy: "Service A checks automatically" — default ON**, on the new Fleet ▸ Maintenance section.
  A due A check is serviced at the aircraft's next gate WITHOUT a card: fee charged, logged once in
  Ops Events (not an alert), downtime per §3.3. **No `.mxCheck` card for A checks.**
- Policy OFF keeps today's per-aircraft card (for the player who wants to micro-manage).
- **C and D stay decisions** — they're real planning events with real downtime, and the coverage
  flow already makes them interesting. They're also RARE (C every ~18 months, D 2–3× per airframe
  life), so the alert load collapses to the checks that deserve a look.
- Overdue/forced-grounding teeth are unchanged.

### 3.2 Third-party MRO — the default provider, with a premium (Phase 2)

- With no base of your own, every check goes to a contract MRO: **+25% on the check cost** and, for
  C/D, a **0–7-day wait for a hangar slot** before the downtime starts (the aircraft keeps flying
  while it waits — no dead time, just a later shop date). A checks have no wait (line stations are
  everywhere) but keep the premium.
- This is what makes a base worth building: it removes BOTH the premium and the wait.

### 3.3 Maintenance bases (Phase 2 — the mid-game facility)

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

### 3.4 FLEET ▸ MAINTENANCE — the new home (Phase 1)

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
