# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

_Written 6 August 2026, at the end of the session that shipped 1.1.2, queued 1.1.3,
and rolled TelemetryDeck across the family._

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, nothing blocked.
>
> **State:** 1.1.2 (build 37) is LIVE. **1.1.3 (build 38) was uploaded and queued for
> review on 6 Aug** — check whether it's through. It carries two things worth watching
> together: the free-tier caps went **3 aircraft/2 routes → 6/5**, and **TelemetryDeck
> funnel analytics** shipped. Next new build must be **39+**.
>
> **Priority 1 — answer the conversion question with the data now arriving.**
> The caps were raised because `hubMinRoutes` is 5, so the old 2-route cap made hubs
> (and everything past them) structurally invisible — players were asked to pay for
> depth they'd never seen. Telemetry was added to find out whether that diagnosis was
> right. Once 1.1.3 has been live ~a week, look at **`Paywall.shown` ÷ `Game.started`**
> in TelemetryDeck (production view = **Test Mode OFF**; Debug/Simulator signals are
> quarantined in test mode):
> - **High ratio, few purchases** → they reach the wall and decline. Pricing/value
>   problem; the caps were the right lever and are now roughly correct.
> - **Low ratio** → they churn before ever seeing the paywall. The caps were never the
>   issue and the early game needs the attention instead.
> Also check **what share reach `Hub.established`** — the direct test of whether 6/5
> actually exposes the hook. If few get there even at 5 routes, the hub still isn't
> landing early enough.
> ⚠️ Don't tune on a few days of data, and re-run `aa-1.1.x/free-tier-probe` after ANY
> change to starting capital, aircraft prices, or `hubMinRoutes` — that probe is what
> proves a free player can still reach a hub.
>
> **Priority 2 — the standing "never played end-to-end" concern.** The soak harness
> (`aa-1.1.x/SoakMain.swift`) closed the numeric/state-integrity half. The RESIDUAL is
> the UI / "does it feel right" half, which no headless harness can see. This keeps
> paying: driving the app in the last two sessions found the **ASSIGN TO NEW ROUTE
> no-op** (headless suite passed it 41/41) and the **SLC-as-plains** artwork bug (which
> turned out to be a systemic mis-mapping across Europe and the Gulf). Sit with the app
> for a real stretch and watch it.
>
> **Priority 3 — Resort Architect's telemetry pointer.** Every other app in the family
> (+ Fruition) has TelemetryDeck wired and verified receiving; Resort was deliberately
> skipped because it had an in-flight vertical-slice pass. Once that lands, add the
> pointer to its `CLAUDE.md` (the stronger, pre-paywall wording — see the family doc)
> and flip its column in `ARCHITECT_FAMILY.md` §2. **Verify, don't trust the callback:**
> confirm the app-target linkage, not just that a `Telemetry.swift` exists.
>
> **Low priority, only if idle:** the explicit **Restore Purchases** button is still
> unexercised (auto-restore works, so it's a fallback; it's unreachable while Pro — let
> the sandbox sub lapse or clear the tester's purchase history to test it), and **true
> cross-device iCloud sync** (needs two devices on one Apple ID; the same-device
> delete/reinstall round-trip is already proven).
>
> **Conventions that bite** (full list in HANDOFF): verify by DRIVING, not just
> building — a clean `xcodebuild` proves nothing. The Finance cash invariant is sacred.
> Temp hooks are never committed. Update `CLAUDE.md` in the same commit as the code it
> describes. New persisted fields need a `decodeSafe` line.

---

## Deliberately NOT on the list

- **Feature work.** Go Public, Competitor Acquisition, and Hubs & Clubs are all
  COMPLETE; their specs remain as reference. The next feature should come from what
  the telemetry says, not from the backlog.
- **Storage rework.** Staying on iCloud KVS, not CloudKit — decided and recorded in
  CLAUDE.md with the single trigger that would justify revisiting (a save approaching
  the ~1 MB KVS quota; today ~21 KB).
- **Re-flagging resolved items.** `README.md` doesn't exist and doesn't need to;
  App Privacy is already declared for analytics; signing is healthy post-migration.
