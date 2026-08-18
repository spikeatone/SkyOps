# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

⚠️ **`LIVERY_SPEC.md` and the `aa-livery/` tooling exist ONLY on the `livery-prototype`
branch, not on `main`** — `git checkout livery-prototype` before looking for them.

_Written 18 August 2026, at the end of the session where 1.2 (the monetization pivot)
was APPROVED + went live, 1.2.1 was rebuilt as build 43 to fold in the designer's
TelemetryDeck error reporting and UPLOADED to ASC, and the 1.3 livery App Store
screenshots were captured (iPhone + iPad, "Air Tina")._

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
> 2. **1.2.1 is BUILD 43 — UPLOADED to ASC (18 Aug), submit is ASC-SIDE (designer TODO).**
>    Build 43 = the airport-offer fix + TelemetryDeck error reporting (it's 43 not 42
>    because 42 predated the Telemetry helper; `Telemetry.errorOccurred` was cherry-picked
>    onto `main` and the build bumped 42→43 so error reporting ships with 1.2.1). It's
>    verified (Release build clean, offer-spread 5/5) and the upload was clean (Delivery
>    UUID `689635df-…`). **THE REMAINING STEP IS ASC-SIDE, designer-only: create the 1.2.1
>    version record → attach build 43 → submit for review.** FIRST THING: check whether
>    build 43 finished processing and whether the designer already submitted it —
>    `cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`
>    and `python3 asc.py GET "/v1/apps/6790569697/builds?limit=3&sort=-version"`.
>
> 3. **1.3 = PERSONALIZED LIVERY**, on branch `livery-prototype` (NOT merged; `main` is
>    clean of it). Feature-complete. Verified conflict-free against `main` — the merge is
>    `git checkout main && git merge livery-prototype`. **Screenshots DONE** (6.9" iPhone +
>    13" iPad, dark, "Air Tina", at `~/Desktop/Airline Architect Livery Screenshots/`).
>    The 1.3 TASKS.md checklist includes uploading those two screenshots to ASC at cut time.
>
> **⚠️ TD ERROR REPORTING → "all repos":** the designer wants `Telemetry.errorOccurred`
> in every Architect app, not just this one. It's in THIS repo (main + livery-prototype).
> The OTHER apps (Golf Course Architect, Vineyard Architect, …) still need it — NOT done.
>
> **THE ONE GATE LEFT before cutting 1.3** (blocks shipping, not the merge):
> - **Walk the full first-run flow on a REAL DEVICE** (naming → livery → launch). Never
>   done end-to-end because sim text entry backgrounds the app. Last unverified path.
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
# NOTE: exclude the two SwiftUI-importing Sim files (AircraftIcon.swift, SVGPath.swift)
# or the headless build fails; the `Sim/*.swift` glob below pulls them in.
mkdir -p /tmp/osv && cp aa-1.1.x/OfferSpreadVerify.swift /tmp/osv/main.swift
swiftc -O -DDEBUG -o /tmp/osv/osv \
  $(ls AirlineArchitect/AirlineArchitect/Sim/*.swift | grep -vE 'AircraftIcon|SVGPath') \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/osv/main.swift && /tmp/osv/osv
# (compile can take ~30s under -O; if a foreground run times out, compile then run separately.)
# ON `livery-prototype` ONLY, add the catalog stubs — Livery.swift imports SwiftUI and
# can't compile headlessly:  cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/osv/  (and pass it)

# the soak (cash invariant + crew/route integrity) — run after ANY sim change
mkdir -p /tmp/soak && cp aa-1.1.x/SoakMain.swift /tmp/soak/main.swift
swiftc -O -DDEBUG -o /tmp/soak/soak AirlineArchitect/AirlineArchitect/Sim/*.swift \
  AirlineArchitect/AirlineArchitect/Persistence.swift /tmp/soak/main.swift && /tmp/soak/soak

# full-fleet livery contact sheet (on livery-prototype)
python3 aa-livery/contact_sheet.py --parts 2 --width 1400 --rowheight 140
```
