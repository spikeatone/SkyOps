# Go Public (IPO) — Design Spec (for designer review)

Status: **Steps 1–4 BUILT & verified (step 1: 30/30 headless + live; steps 2–4:
78/78 headless cumulative). Step 5 (balance sweep) pending.** All four forks
locked below.

### Decisions (designer, locked)
1. **Board severity: TEETH — can oust you.** Sustained poor performance + lost
   control = game over, a second failure path beside bankruptcy, with its own
   recap. Fully avoidable by performing or keeping control.
2. **The string: BOTH** — the market expects growth AND dividends; falling short
   on either sinks the price.
3. **Unlock gate: net worth ≥ $500M.** Not as late as acquisitions ($1B), further
   in than the mid-game. Deliberately interacts with acquisitions (see the
   net-worth note below) — going public is a real path TOWARD the acquisition
   game, mirroring real airline roll-ups.
4. **Float: NO hard cap — dilution is self-priced.** Sell as much as you like, but
   the IPO screen must make the risk visceral, and **the board-ouster trigger
   accelerates the more the player dilutes their own stake.** Below majority the
   board is dangerous; near-total dilution leaves almost no protection.

### The net-worth interaction (designer raised it; poked and kept)
An IPO credits real, spendable CASH to the balance, and net worth is cash + fleet
with NO offsetting liability for the public's stake. So going public genuinely
RAISES net worth and can move a $500M player toward the $1B acquisition gate —
which is the designer's intent and mirrors how real airlines IPO to fund
acquisitions. It is not a pure exploit: the cash is paid for with permanent
dilution + board risk and can't be cheaply undone. **Balance-pass must verify it
doesn't make organic growth pointless** — the one real risk of gating on net
worth that equity can inflate.

Origin: designer, mid-flight. A second route to capital alongside the existing
LOAN mechanism — list the airline on a stock market, raise money by selling
equity, and live with the consequences: activist investors, a rebellious board,
and a stock price that punishes mismanagement. Player picks a **ticker symbol**,
which then rides next to the CASH figure at the top of the screen.

---

## Why this is a good second capital route (the core tension)

The game already has **loans**: cash now, repaid with interest, full control kept.
Going public is the deliberate opposite:

| | Loan | Go Public |
|---|---|---|
| Capital | Bounded by credit line | A slice of the whole company's value — much larger |
| Repayment | Amortised, with interest | None — you sold equity, not borrowed |
| Cost | Interest (cash) | **Control + a permanent audience** |
| Downside | Debt service drags cash | Activists, the board, a falling price |
| Reversible | Pay it off | Buy shares back (expensive) |

So the fork is real: debt keeps you sovereign but costs cash; equity is cheaper
on cash but you answer to a market that watches every move. Neither dominates —
which is the test every mechanic in this game has to pass.

---

## The stock price model (the heart — get this right first)

Everything else hangs off one living number. Anchor it to what the game already
computes, so it can't drift into fantasy:

```
marketCap = netWorth × valuationMultiple × sentiment
sharePrice = marketCap / sharesOutstanding
```

- **`netWorth`** (cash + fleet value) is the fundamental. Already exists.
- **`valuationMultiple`** (~1.8) — a growing airline trades ABOVE book. A constant
  to start; the balance pass tunes it.
- **`sentiment`** ∈ ~[0.5, 1.6], the market's mood, recomputed each sim-month from
  things the game already tracks:
  - **Reputation** (0–100) — service quality = investor confidence.
  - **Profit trend** — the `FinanceSnapshot` month-over-month deltas already exist;
    a string of profitable months lifts sentiment, losses sink it.
  - **Active economic event** — an Oil Spike / Recession tanks ALL airline stocks
    (real-world accurate); a Boom lifts them. Reuses `currentEvent`.
  - **A bounded random walk** — a stock wiggles even when nothing changes, so the
    ticker feels alive.

Displayed price eases toward its target rather than snapping, so the ticker
animates smoothly (same value-input redraw discipline as everything tick-driven).

**Key property: the price is mostly EARNED, not rolled.** Run the airline well —
net worth up, reputation up, consistent profit — and the price rises and
activists never come. Mismanage and it falls on its own. Sentiment is the
seasoning, not the meal. That's what makes the pitfalls feel deserved.

---

## The IPO itself

Gated: unavailable until the airline is worth listing (see gate below). Then a
GO PUBLIC flow:

1. **Choose a ticker** — 1–4 letters, uppercased, player's own (the fun part).
   Light validation only (letters, length); stock tickers don't carry the
   trademark risk airline codes do, so no real-ticker collision check needed.
   **IPO PRICE SCALES WITH SIZE (designer):** share count is fixed, so a bigger
   airline lists at a higher per-share price (gate ~$25–31, 10× bigger ~$300).
   **The first 12 months are deliberately VOLATILE (designer):** a new issue is
   under pressure to perform — bigger swings + heightened performance sensitivity,
   decaying to a seasoned stock by month 12.
2. **Choose the float** — what fraction of the company to sell, **10%–40%**
   (DESIGNER CALL on the ceiling). More float = more cash now = less control =
   more exposure. This is the real decision, so it's a slider, not a fixed deal.
3. **Raise `float × marketCap` in cash.** Public owns `float`; player owns the
   rest. `sharesOutstanding` fixed at IPO; the player's shares are their stake.

After listing: the ticker + live price ride next to CASH; a new PUBLIC section
appears in Finance.

---

## The pitfalls (designer's three, made mechanical)

### 1. A dwindling stock price — emergent, not scripted
Falls out of the model above. Losses, a reputation hit, a stalled net worth, or a
bad economic event all push the price down with no special code. A low price is
itself a soft punishment (secondary offerings raise less; see below) and the
trigger for everything harsher.

### 2. Activist investors — the mid-tier threat
Trigger: the price sits below the IPO price (or a set floor) for a sustained
stretch. An activist accumulates a public stake, then pushes a **decision card**
with a concrete demand — e.g. *pay a special dividend*, *close a money-losing
route*, *buy back shares*, *cut costs*. 
- **Comply** → costs cash / forces the action, but they stand down and sentiment
  recovers a little.
- **Refuse** → they escalate: grow their stake, dent sentiment further, and if it
  compounds it reaches the board (below). Reuses the `decisionQueue`/blue-offer
  card pattern already built for slot buybacks and hub offers.

### 3. A rebellious board — the top-tier threat  (**DESIGNER CALL: how hard?**)
Triggers when performance is poor AND the player's control has slipped (activists
hold a big stake / player stake is low). Three severities to choose from:

- **(A) Soft** — the board can only impose costly constraints (forced dividend,
  blocked spending for a period). Never removes the player. Lowest stakes.
- **(B) Teeth** *(recommended)* — sustained failure + lost control → the board
  **ousts the player: game over**, a second failure path alongside bankruptcy,
  with its own recap screen. Matches the "rebellious board" energy and gives
  going public real weight. Avoidable entirely by running the airline well or
  keeping majority control.
- **(C) Forced sale** — the board sells the company out from under you; you cash
  out but the game ends. A "bought out" ending rather than a defeat.

I lean **(B)**: the feature needs a real consequence, bankruptcy already proves
players accept an avoidable failure state, and "keep your stake above 50% or
perform" is a legible rule.

---

## Player levers (how you manage being public)

- **Pay dividends** — appease shareholders, lift sentiment; drains cash. A special
  dividend is also the fastest way to end an activist campaign.
- **Buy back shares** — spend cash to shrink the float, raise the price, and claw
  back control. The direct counter to activists; expensive when the price is high.
- **Secondary offering** — sell more shares for more cash, diluting further. Raises
  a lot when the price is high, little when it's low — so you're punished for
  needing cash in a downturn, which is realistic.
- **Just run it well** — the real answer. Growth + reputation keep the price up and
  the board asleep.

**Ongoing obligation of being public (DESIGNER CALL):**
- **(i) Dividend expectations** — shareholders expect a periodic dividend; skipping
  is allowed but sinks sentiment and invites activists (classic income-stock).
- **(ii) Growth expectations** *(recommended)* — the market expects the airline to
  keep growing; stagnation alone sinks the price even without losses. Fits this
  game's growth arc and needs no new recurring-cash system.
- **(iii) Both.**

I lean **(ii)**: it reuses the net-worth trend the game already has, and turns
"going public means you can never coast again" into the string attached — which
is the honest cost of public markets.

---

## Gate — when GO PUBLIC unlocks  (**DESIGNER CALL: threshold**)

Designer's rule: not until a "certain valuation." Where it sits changes the
feature's role:

- **Early (~net worth $100–250M)** *(recommended)* — going public becomes the
  ACCELERATOR that funds getting to the $1B acquisitions game. A mid-game
  capital lever, distinct from the late-game acquisition lever.
- **Late (~$1B, like acquisitions)** — a parallel endgame system instead of a
  path INTO the endgame.

I lean early — it gives the mid-game its own headline decision and a reason to
weigh equity vs debt long before acquisitions are reachable.

---

## The invariant (non-negotiable — the Finance ledger must still tie out)

Every cash move joins the master invariant + the Finance cash-flow card, exactly
as loans/hubs/diligence did:
- **In:** IPO proceeds, secondary-offering proceeds.
- **Out:** share buybacks, dividends paid, activist settlements.

New accumulators (`totalEquityRaised`, `totalDividendsPaid`, `totalBuybackSpend`,
`totalActivistSettlement`) and the invariant term, asserted in the headless
regression the same way. Non-negotiable because the whole Finance tab depends on
cash reconciling to the penny.

---

## Persistence

New optional `GameSnapshot` fields (nil-safe for pre-IPO saves, the established
pattern): `ticker`, `isPublic`, `sharesOutstanding`, `playerShares`,
`ipoPrice`, `sharePrice` (or its sentiment inputs), `activistStake`, the four
accumulators, and any active activist/board campaign state.

---

## Scope & sequencing (build order, each independently verifiable)

1. ~~**Stock price model + IPO + ticker UI.**~~ **DONE (30/30 headless + live).**
   `Sim/GoPublic.swift` (types + valuation) + the "Public company" MARK in
   Simulation.swift (mutating), `GoPublicView.swift` (the IPO flow), the ticker
   chip in NetworkView's header, and a GO PUBLIC / PUBLIC COMPANY card in Finance.
   Gate $500M net worth; `marketCap = netWorth × 1.8 × sentiment`; sentiment
   updates monthly from reputation + net-worth trend + the active event + a small
   wiggle, clamped [0.5, 1.6]; `displaySharePrice` eases per sim-day for a live
   ticker. Ticker shows SYMBOL + price coloured vs the IPO price. Float has NO cap
   — the slider shows live dilution risk (controlling / exposed / vulnerable /
   powerless). Equity raised joins the Finance cash invariant (capital-in);
   everything persists nil-safe. Verified: gate, exact proceeds, invariant through
   IPO + 6 months public, sentiment stays bounded, price moves, save/load
   round-trip, legacy-save loads private.
2. ~~**Levers:** dividends, buybacks, secondary offerings + the Finance PUBLIC
   card.~~ **DONE (37/37 headless).** `payDividend`/`buyBackShares`/
   `secondaryOffering` in Simulation.swift + read-side option math in
   GoPublic.swift; the PUBLIC card gained dividend (2/5/8%) / buyback (10/25/50%
   of float) / secondary (+5/10/20%) chips. Dividends + buybacks joined the cash
   invariant (`totalDividendsPaid`/`totalBuybackSpend`, capital-out); secondary
   proceeds feed `totalEquityRaised`. The income half of the string is a
   dividend-drought sentiment penalty (grace 6mo, then −0.03/mo, reset on pay).
3. ~~**Activist investors** (decision cards, comply/refuse, escalation).~~
   **DONE (60/60 headless cumulative).** Triggers after 3 sim-months below the
   IPO price; demands escalate dividend → buyback → close-a-losing-route; comply
   forces the action (via the step-2 levers), refuse grows their stake + drops
   sentiment + increments `escalation` (which step 4's board reads). Paying any
   dividend or a recovering price ends the campaign. `ActivistCampaign` persists.
4. ~~**The board** (the chosen failure/constraint model) + its recap screen if
   (B/C).~~ **DONE (78/78 headless cumulative).** Teeth (B): `boardPressure`
   builds only when below majority AND performing poorly, accelerating with
   dilution + activist escalation; at 1.0 the board ousts (game over) with an
   "OUSTED" recap (GameOverView.Cause). Majority control = total immunity. A red
   "Board patience" bar in the PUBLIC card makes it visceral.
5. **Balance pass:** the multi-seed sweep discipline from acquisitions — is equity
   a real alternative to debt, is the price avoidably survivable, does mismanagement
   actually cost you? Tune `valuationMultiple`, float ceiling, trigger thresholds.

Comparable in size to acquisitions or hubs. **Recommend it lands in 1.1 with the
acquisition work, not 1.0.1.**

---

## Decisions needed from the designer

1. **Board severity** — Soft / **Teeth (game-over, recommended)** / Forced-sale.
2. **The ongoing string** — Dividend expectations / **Growth expectations
   (recommended)** / Both.
3. **Unlock threshold** — **early ~$100–250M (recommended)** or late ~$1B.
4. **Float ceiling** — how much of the company can be sold (recommended cap 40%,
   so the player can always retain majority control if they choose).
