# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

⚠️ **`LIVERY_SPEC.md` and the `aa-livery/` tooling exist ONLY on the `livery-prototype`
branch, not on `main`** — `git checkout livery-prototype` before looking for them.

_Written 17 August 2026, at the end of the session that fixed the T-tail and turboprop
fin masks, built the fleet-repaint economy, added the existing-player livery path, and
cut 1.2.1 for a customer-reported route-offer bug._

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, nothing blocked.
>
> **RELEASE STATE — three versions in flight, in this order (designer's plan):**
>
> 1. **1.2 (build 41) is WAITING FOR REVIEW** — the monetization pivot (subscription →
>    one-time unlock) plus two new IAPs. Checked via the ASC API on 17 Aug: it had NOT
>    entered review 6 days after submission. **Nothing is misconfigured** — build 41 is
>    attached and `VALID`, and the review submission holds 3 items (version +
>    `aa_unlock_founding_player` + `aa_unlock_standard`), all `READY_FOR_REVIEW`. It is
>    Apple queue time. **Do not resubmit** (that loses queue position); if it is still
>    stuck, the lever is a Contact Us / expedite request in ASC.
>    Re-check first thing:
>    `cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`
>
> 2. **1.2.1 (build 42) is ON `main`, committed and verified, but NOT archived/uploaded.**
>    It is the **fast follow**, to go up once 1.2 is APPROVED — do NOT submit it while 1.2
>    is pending; the pivot build and its IAPs must clear as a unit. When 1.2 is live, the
>    remaining work is: archive → validate → upload (the chain is in CLAUDE.md §Release,
>    ASC API key `25FXKWL48U`), then create the version record + submit in ASC
>    (designer-side).
>
> 3. **1.3 = PERSONALIZED LIVERY**, on branch `livery-prototype` (NOT merged; `main` is
>    deliberately clean of it). Feature-complete. Verified conflict-free against `main` —
>    the merge is `git checkout main && git merge livery-prototype`.
>
> **What 1.2.1 fixes (customer-reported):** a paying customer sent a screenshot showing
> **all 35 of his airport incentives were routes into ATL**. The destination was
> DETERMINISTIC — `hubs.first(where: served…)` on a traffic-sorted list, i.e. always the
> single busiest airport in his network. Reproduced at 100%. Now a weighted random pick
> (sqrt of passengers, ×3 if served, ×0.35 if not): top destination 100% → 12%, distinct
> destinations 1 → 30+, and **60% still land on a served hub** so the offers stay worth
> accepting. That 60% is the number to hold on any retune. Guarded by
> `aa-1.1.x/OfferSpreadVerify.swift`, validated against the pre-fix code (fails 3/5 there).
>
> **Two gates before cutting 1.3** (neither blocks the merge; both block shipping):
> - **Walk the full first-run flow on a REAL DEVICE** (naming → livery → launch). It has
>   never been done end-to-end because sim text entry keeps backgrounding the app. This is
>   the last unverified path in the livery feature.
> - Everything else in the livery feature is verified: fins on all 35 types (contact sheet
>   + live), the Fleet-detail render, repaint (47/47 headless + driven), the
>   existing-player free-first-choice path and its one-time prompt (4/4 + driven), both
>   themes.
>
> **If you want to work on the livery branch**, `git checkout livery-prototype` and read
> `LIVERY_SPEC.md` (branch-only — it is NOT on `main`) — it documents the painted-tail model, the fin-mask tooling in
> `aa-livery/`, the repaint economy, and the layout gotchas.
>
> **Simulator warning that cost real time this session:** the input channel degrades —
> taps land on the tab bar, and sibling Architect apps steal focus. If a tap seems to do
> nothing, RE-SCREENSHOT before concluding a control is broken, and terminate the other
> Postmark apps (`xcrun simctl terminate <udid> Postmark-Digital.GolfCourseArchitect`).
> When it gets bad, verify headlessly instead — that is how the repaint numbers were
> checked.

---

## Useful commands

```bash
# review status (all three versions at a glance)
cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"

# the offer-spread regression (the 1.2.1 fix) — verified to run as-is on `main`
mkdir -p /tmp/osv && cp aa-1.1.x/OfferSpreadVerify.swift /tmp/osv/main.swift
swiftc -O -DDEBUG -o /tmp/osv/osv AirlineArchitect/AirlineArchitect/Sim/*.swift \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/osv/main.swift && /tmp/osv/osv
# ON `livery-prototype` ONLY, add the catalog stubs — Livery.swift imports SwiftUI and
# can't compile headlessly:  cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/osv/  (and pass it)

# the soak (cash invariant + crew/route integrity) — run after ANY sim change
mkdir -p /tmp/soak && cp aa-1.1.x/SoakMain.swift /tmp/soak/main.swift
swiftc -O -DDEBUG -o /tmp/soak/soak AirlineArchitect/AirlineArchitect/Sim/*.swift \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/soak/main.swift && /tmp/soak/soak

# full-fleet livery contact sheet (on livery-prototype)
python3 aa-livery/contact_sheet.py --parts 2 --width 1400 --rowheight 140
```
