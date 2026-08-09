# PRICING EXPERIMENT — spec

How to A/B test AA's subscription pricing and trial using **RevenueCat Experiments**,
which assigns cohorts server-side, serves each a different Offering, and tracks the
full funnel per variant (impressions → conversion → retention → revenue).

_Written 6 Aug 2026, after 1.1.3 shipped the free-cap change (3/2 → 6/5) and the
TelemetryDeck funnel. Nothing here is built yet — this is the plan._

---

## 0. ⚠️ THE GATE — do not start until volume supports it

Price tests are statistically hungry. Detecting a **2% → 3%** conversion move (a large
50% relative lift) needs roughly **2,000–2,500 paywall views per arm**; realistic price
effects are smaller and need far more. At AA's current subscriber count an experiment
started today would run for months and still be indistinguishable from noise — and the
real damage isn't the wait, it's being tempted to *act* on a noisy result.

**The funnel shipped in 1.1.3 is the feasibility input.** Watch `Paywall.shown` for
2–3 weeks:

| Weekly `Paywall.shown` | Verdict |
|---|---|
| **~1,000+** | A test can conclude in a sensible window. Run it. |
| **~100** | Don't. Pick a price on judgment and revisit later. |
| **In between** | Run it, but pre-commit to a long window and **don't peek early**. |

⚠️ **Pre-register the decision rule before launching** (see §4). Peeking at a running
experiment and stopping when it looks good is how underpowered tests produce confident
wrong answers.

---

## 1. Why this needs no app code

`Store.loadOfferings()` reads `Purchases.shared.offerings().current` — exactly the call
RevenueCat Experiments overrides per cohort. Package lookup is
`current.annual ?? package("yearly")` / `current.monthly ?? package("monthly")`, so **any
variant Offering must reuse those package identifiers**. Get that right and the app is
already experiment-ready; no build, no review.

---

## 2. Experiment A — price

**Control** `default`: $5.99/mo · $49.99/yr
**Treatment** `value_pricing`: $4.99/mo · $39.99/yr

Setup:
1. **App Store Connect** — a product's price can't vary per cohort, so create **two new
   subscription products** at the new prices, in the **SAME subscription group** as the
   current ones (same group = clean upgrade/downgrade, no double subscriptions). These
   need product review, not app review.
2. **RevenueCat** — import them, create Offering `value_pricing` with `monthly` /
   `yearly` packages (identifiers must match §1).
3. **Experiments** — control `default`, treatment `value_pricing`, 50/50.

⚠️ **A price cut must clear a bar, not just win.** Dropping 20% needs a **>25%**
conversion lift merely to break even. Judge on revenue, never conversion rate (§4).

---

## 3. Experiment B — free trial (probably the better first test)

At low volume, effect size decides how long you wait. A trial typically moves conversion
far more than a $1 price change, so it reaches significance sooner. **If only one
experiment gets run, this is the higher-information one.**

### 3a. Two different things, easy to conflate

| | **Apple intro free trial** (recommended) | **Custom timed unlock** |
|---|---|---|
| How it starts | User subscribes; billing deferred | App grants a local pass |
| Payment method | **Required up front** | None |
| At expiry | **Auto-converts to paid** unless cancelled | Nothing — user must decide to buy |
| Build | RevenueCat/ASC config only | Custom code + persistence + clock-tamper handling |
| A/B-able via Experiments | **Yes** | No |

The designer's phrasing — *"a total unlock for 3–4 days"* — describes the right side.
**The left side better serves the stated worry.** If someone plays hard for three days
and feels finished, the custom unlock simply loses them; the Apple trial has already
captured the payment method and converts unless they actively cancel. It's also
config-only, and it's the only one Experiments can test.

### 3b. Duration: 3 days vs 7 days

Apple's presets are **3 days · 1 week · 2 weeks · 1 month · 2 months · 3 months ·
6 months · 1 year** — **there is no 4-day option**, so the real choice is 3 or 7.

- **3 days** — matches the designer's instinct. Less room to feel "done"; creates urgency.
  Risk: possibly too short to form a habit, and a busy 3 days can pass unused.
- **7 days** — more chance to reach the hub payoff and build routine. Risk: exactly the
  satiation the designer flagged, and a full week to forget and cancel.

**Recommended first test: 3-day trial (treatment) vs no trial (control), prices held at
$5.99/$49.99.** Change one variable. If the trial wins, a follow-up can test 3 vs 7.

⚠️ **Trial economics need a renewal cycle to judge.** Trials reliably lift *starts* and
often lower *retention*; a variant can look like a big winner at day 7 and be a loser at
day 60. Do not call it before at least one paid renewal has landed for the cohort.

---

## 4. Decision rules — pre-register these

- **Primary metric: revenue per paywall view** (not conversion rate, not trial starts).
- **Minimum runtime:** until each arm clears the §0 volume bar **and** at least one
  renewal cycle has completed.
- **No early stopping.** Write the stop date down before launch.
- **Ship the winner only if it wins on the primary metric.** A conversion-rate win with
  flat revenue is not a win.

---

## 5. Code readiness — two real defects (FIXED 6 Aug 2026)

Both would have polluted results; both are fixed in `Store.swift` / `PaywallView.swift`:

1. **Hardcoded fallback prices.** `plans` began as `fallbackPlans` ($49.99/$5.99) and was
   replaced only `if !built.isEmpty` — so a network hiccup showed a **treatment** user the
   **control** prices, a mismatch between what they saw and what they'd be charged.
   Fixed via `Store.pricesAreLive`: until the real Offering loads, the paywall shows a
   neutral placeholder instead of a specific wrong number.
2. **Hardcoded "Save 30%".** The badge was a literal in both the fallback and the
   RevenueCat-derived path. At $4.99/$39.99 the true saving is **33%**, so the treatment
   arm would have shipped a false claim. Now computed from the two packages' real prices.

---

## 6. Not doing / deliberately out of scope

- **Regional price variants.** More arms fragment already-thin traffic.
- **Changing the free caps during a pricing test.** They just moved (3/2 → 6/5) in 1.1.3;
  moving them mid-experiment confounds both results. Let the cap change settle first.
- **Testing price and trial simultaneously.** One variable at a time at this volume.
