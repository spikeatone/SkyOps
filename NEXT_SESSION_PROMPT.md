# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

✅ **The livery branch is MERGED into `main` (18 Aug), so `LIVERY_SPEC.md` + the `aa-livery/`
tooling now exist on `main`.** (The `livery-prototype` branch still exists for history.)

_Written 18 August 2026, at the end of the session where: 1.2 (the monetization pivot) was
APPROVED + went live; 1.2.1 (build 43 — airport-offer fix + TelemetryDeck error reporting) was
uploaded AND submitted for review; and 1.3 (livery) was merged to `main`, built as build 44, and
uploaded to ASC. The livery App Store screenshots (iPhone + iPad, "Air Tina") were captured._

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, all pushed.
>
> **RELEASE STATE (designer's plan: 1.2 → 1.2.1 fast follow → 1.3):**
>
> 1. **1.2 (build 41) is APPROVED + LIVE** (`READY_FOR_SALE`) — the monetization pivot
>    (subscription → one-time unlock, $9.99 founding → $19.99 on Dec 1, two IAPs
>    `aa_unlock_founding_player`/`aa_unlock_standard`) is public. Once it's dominant:
>    remove Monthly/Yearly from the RevenueCat offering (NEVER delete the sub products);
>    then watch trial→purchase conversion + founding-price WOM.
>
> 2. **1.2.1 (build 43) is SUBMITTED FOR REVIEW** (`WAITING_FOR_REVIEW`) — the airport-offer
>    fix + TelemetryDeck error reporting. Uploaded via CLI, then the designer created the
>    version record + attached build 43 + submitted in ASC. No IAP re-review (the two unlock
>    products cleared with 1.2), so it should move faster than 1.2's ~6-day queue. Nothing to
>    do but watch: `cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`.
>
> 3. **1.3 = PERSONALIZED LIVERY — MERGED to `main`, BUILD 44 UPLOADED to ASC (18 Aug).**
>    `livery-prototype` merged into `main` conflict-free; bumped to 1.3/build 44; Release
>    build clean + offer-spread 5/5; validated + uploaded (Delivery UUID `234e9bf3-…`).
>    **⚠️ NOT YET SUBMITTED — two ASC-side steps remain (designer):**
>    - **(a) The real-device first-run walkthrough** (naming → livery → launch) from the
>      TestFlight build 44 — the ONE path never verified end-to-end (sim text entry
>      backgrounds the app). Must pass before submitting.
>    - **(b) In ASC: create the 1.3 version record → What's New → attach build 44 → ADD THE
>      TWO LIVERY SCREENSHOTS (iPhone 6.9" + iPad 13", in `~/Desktop/Airline Architect Livery
>      Screenshots/`) → submit.** Without the screenshots, 1.3 inherits 1.2's shots and the
>      livery isn't shown. A `_READ_BEFORE_SUBMITTING_1.3.txt` note sits in that folder.
>    Next new build after 44 = **45+**.
>
> **⚠️ TD ERROR REPORTING → "all repos":** the designer wants `Telemetry.errorOccurred`
> in every Architect app, not just this one. It's in THIS repo (on `main`). The OTHER apps
> (Golf Course Architect, Vineyard Architect, …) still need it — NOT done here.
>
> **Everything in the livery feature is verified EXCEPT the real-device first-run flow**
> (see 3a above): fins on all 35 types (contact sheet + live), the Fleet-detail render,
> repaint (47/47 headless + driven), the existing-player free-first-choice path and its
> one-time prompt (4/4 + driven), both themes.
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
# NOTE: exclude the two SwiftUI-importing Sim files (AircraftIcon.swift, SVGPath.swift)
# or the headless build fails; the `Sim/*.swift` glob below pulls them in.
mkdir -p /tmp/osv && cp aa-1.1.x/OfferSpreadVerify.swift /tmp/osv/main.swift
swiftc -O -DDEBUG -o /tmp/osv/osv \
  $(ls AirlineArchitect/AirlineArchitect/Sim/*.swift | grep -vE 'AircraftIcon|SVGPath') \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/osv/main.swift && /tmp/osv/osv
# (compile can take ~30s under -O; if a foreground run times out, compile then run separately.)
# NOW ON `main` TOO (livery merged 18 Aug): Livery.swift imports SwiftUI, so add the catalog
# stubs for the headless build:  cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/osv/  (and pass it)

# the soak (cash invariant + crew/route integrity) — run after ANY sim change
mkdir -p /tmp/soak && cp aa-1.1.x/SoakMain.swift /tmp/soak/main.swift
swiftc -O -DDEBUG -o /tmp/soak/soak AirlineArchitect/AirlineArchitect/Sim/*.swift \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/soak/main.swift && /tmp/soak/soak

# full-fleet livery contact sheet (on livery-prototype)
python3 aa-livery/contact_sheet.py --parts 2 --width 1400 --rowheight 140
```
