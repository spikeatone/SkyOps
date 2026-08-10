# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

_Written 9 August 2026, at the end of the session that shipped the free-cap change +
TelemetryDeck (1.1.3), built the pricing-experiment groundwork + the 3-day free-trial
paywall UI, and replaced the cold-launch backdrop art (1.1.4, in review)._

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, nothing blocked.
>
> **State:** **1.1.3 (build 38) is LIVE.** **1.1.4 (build 39) is SUBMITTED FOR APPLE
> REVIEW** (uploaded + submitted 9 Aug) — it adds the **3-day free-trial paywall UI**
> (Monthly-default, trial on both plans) and a **new full-bleed aerial-runway cold-launch
> backdrop**. Next new build must be **40+**. First thing to do: **check whether 1.1.4
> cleared review** (`python3 ~/Architect\ Universe/PostmarkOps/ASCTools/asc.py builds
> 6790569697`, or ASC). If it BOUNCED, the likeliest reason is **Guideline 3.1.2**
> (subscription/trial disclosure) — the paywall already states full terms + Terms/Privacy
> links, so a bounce would be a quick copy/link fix, not a rebuild.
>
> **THE FREE TRIAL IS ALREADY LIVE AT THE STORE LEVEL — don't be confused by this.** The
> ASC introductory offers (Free / 3 Days, both Monthly + Yearly, all 175 territories,
> `starts 2026-08-09` / `ends 2026-12-31`) are a STORE-config change independent of the
> app binary. Apple auto-applies the trial to any eligible new subscriber RIGHT NOW, even
> on the live build 38 whose paywall doesn't advertise it (verified: a Yearly TRIAL
> transaction appeared in RevenueCat hours after the offer went live). Build 39 doesn't
> "turn on" the trial — it **advertises** it (the "3 days free / Start Free Trial" CTA),
> which should increase trial STARTS. ⚠️ The `ends 2026-12-31` date means the offer stops
> being available after year-end unless extended (can't edit — delete + recreate).
>
> **Priority 1 — read the monetization signals now accumulating (give them ~2 weeks).**
> Three separate things to watch, in order:
> 1. **RevenueCat trial→paid conversion.** Trials are starting NOW (store-level). Trial
>    STARTS are easy to inflate; the number that matters is whether they CONVERT after
>    3 days. This is the payoff of the whole trial + pricing thread.
> 2. **TelemetryDeck funnel: `Paywall.shown` ÷ `Game.started`** (production view =
>    **Test Mode OFF**; Debug/Simulator signals are quarantined in test mode). This
>    answers whether the 1.1.3 free-cap change (3 aircraft/2 routes → **6/5**, sized so a
>    free player can reach ONE hub) fixed conversion. HIGH ratio + few purchases →
>    pricing/value problem, caps were right. LOW ratio → they churn before the wall, caps
>    weren't the issue. Also check the **`Hub.established`** share — the direct test of
>    whether 6/5 exposes the hub hook.
> 3. **The next pricing lever is scoped, not built.** `PRICING_EXPERIMENT_SPEC.md` has the
>    full plan: a RevenueCat price A/B and/or a default-Monthly-vs-Annual A/B, GATED on
>    ~1k paywall-views/week (don't start an A/B below that — it can't conclude). The trial
>    is shipped to EVERYONE (not A/B'd) precisely because volume is too low for a clean
>    experiment; the A/B stays in reserve.
> ⚠️ Re-run `aa-1.1.x/free-tier-probe` after ANY change to starting capital, aircraft
> prices, or `hubMinRoutes` — it proves a free player can still reach a hub.
>
> **Priority 2 — the standing "never played end-to-end" concern.** The soak harness
> (`aa-1.1.x/SoakMain.swift`) closed the numeric/state-integrity half. The RESIDUAL is
> the UI / "does it feel right" half, which no headless harness can see. It keeps paying:
> driving the app this session found the **ASSIGN TO NEW ROUTE no-op** (headless passed
> it 41/41) and the **SLC-as-plains** artwork bug (a systemic mis-mapping across Europe +
> the Gulf). Sit with the app for a real stretch and watch it.
>
> **Priority 3 — Resort Architect's telemetry pointer.** Every other family app
> (+ Fruition) has TelemetryDeck wired + verified receiving; Resort was skipped mid
> vertical-slice pass. Once that lands, add the pointer to its `CLAUDE.md` (the stronger,
> pre-paywall wording — see the family doc) and flip its column in `ARCHITECT_FAMILY.md`
> §2. **Verify the app-TARGET linkage, don't trust a callback** — the whole reason
> Airline's telemetry silently no-op'd at first was a package added to the project but not
> linked to the target.
>
> **Low priority, only if idle:** the explicit **Restore Purchases** button is still
> unexercised (auto-restore works; it's unreachable while Pro — let a sandbox sub lapse to
> test it), and **true cross-device iCloud sync** (needs two devices on one Apple ID; the
> same-device delete/reinstall round-trip is already proven).
>
> **Conventions that bite** (full list in HANDOFF): verify by DRIVING, not just building —
> a clean `xcodebuild` proves nothing (both bugs above passed the build). The Finance cash
> invariant is sacred. Temp hooks are NEVER committed (grep TEMPSHOT/forceTrial before any
> commit — this session used a `-forceTrial` hook to verify the trial UI, then stripped
> it). Update `CLAUDE.md` in the SAME commit as the code. New persisted fields need a
> `decodeSafe` line. The App Store upload is scriptable end-to-end (archive → altool
> validate → upload with the ASC API key; see CLAUDE.md / ARCHITECT_FAMILY.md §4).

---

## Deliberately NOT on the list

- **Feature work.** Go Public, Competitor Acquisition, and Hubs & Clubs are all COMPLETE;
  their specs remain as reference. The next feature should come from what the telemetry
  says, not from the backlog.
- **A pricing A/B right now.** Scoped in `PRICING_EXPERIMENT_SPEC.md` but GATED on volume
  (~1k paywall views/week). Don't start one below that — it can't conclude, and acting on
  a noisy result is the real risk.
- **Storage rework.** Staying on iCloud KVS, not CloudKit — decided in CLAUDE.md with the
  one trigger that would justify revisiting (a save approaching the ~1 MB KVS quota; today
  ~21 KB).
- **Re-flagging resolved items.** `README.md` doesn't exist and doesn't need to; App
  Privacy is declared for analytics (Usage Data → Product Interaction, not linked to
  identity → no ATT prompt); signing is healthy post-migration; the trial UI is built and
  verified; the intro offers are configured and generating trials.
