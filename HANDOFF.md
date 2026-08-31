# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 30 August 2026._

**► 1.5.0 (build 54) = A350-1000 + 747-8i + map-render throttle — SUBMITTED FOR REVIEW (30 Aug).**
Merged to `main` (PR #2, branch `aircraft-and-thermal`). Fleet 35 → 37: **Airbus A350-1000** (`A35K`,
shares the `A350` crew rating) + **Boeing 747-8i** (`B748`, its OWN `B747-8` crew family) — a paying
player asked for the legendary jumbos + newer A350s; both pass the certified-and-in-service bar, with
real Figma side-view art + traced fin masks. The 747-8i REVERSES the earlier "skip the passenger -8"
call; the -400 (`B747`) stays too. Also a **thermal/battery fix**: `LiveMap` now reads the throttled
`Simulation.mapTick` (~30fps) instead of raw `tick`, cutting the full-world Canvas repaint from
~125/sec at 25× to ~30/sec (a paying player's "device gets hot" report). Build 54 uploaded via the CLI
chain (archive → export → validate → upload), attached to the 1.5 record; **What's New + promotional
text + App Review notes all set via the ASC API** (`aa-1.1.x/app-review-notes-1.5.0.txt`, 3990 chars,
carries the §1 studio-context block). Next new build = **55+**. Marketing bump to 1.5 (minor feature),
not a patch — the two aircraft are user-facing content.

**► 1.4.3 (build 53) = ASYNC SLOT DECODE — APPROVED + LIVE (`READY_FOR_SALE`, 28 Aug).** Merged to
`main`; the decode-side twin of the 1.4.2 save fix: `GameStore.slotInfos()` did up to 3 full save
decodes synchronously on the main thread from the load menu — a stall on large saves. Now
`slotInfosAsync` runs them on the shared serial `saveQueue` and populates on the main actor. **First
Airline release approved WITH the §1 studio-context block in the App Review notes** — approved same
day during the account-wide 4.3(a) cascade (see below). ⚠️ **App Review notes carry the §1
studio-context block (4.3(a) armor) — MANDATORY on every Architect submission now; reuse the latest
`aa-1.1.x/app-review-notes-1.5.0.txt`, just bump the version line.**

**► ⚠️ APPLE 4.3(a) IS ACCOUNT-WIDE (as of 27–28 Aug) — read before ANY submission.** Apple's
Guideline 4.3(a) "spam/repackaged-template" reflex rejected Vineyard 1.0, Foundry 1.0, AND FC
Architect 1.3 (localization-only, after 5 prior approvals) in one window; a formal appeal covering all
three was filed 28 Aug (awaiting Apple). Airline is SAFE (never rejected; 1.4.1/1.4.2/1.4.3 all cleared
or are clearing during the cascade) — but a trivial update gets NO immunity (FC's localization-only 1.3
proves it), so **every Airline submission now leads its App Review Notes with the studio-context block**
(Airline's own approval history + the Postmark Digital studio framing + Airline's unique-systems
paragraph). The canonical playbook + Airline's filled-in unique-systems paragraph live in
`PostmarkOps/APP_REVIEW_NOTES.md`. The 1.4.3 notes (3988 chars, under the 4000 limit) are the template
for the next one — reuse them, just update the version line.

**► 🇩🇪 GERMAN LOCALIZATION — IN PROGRESS on branch `de-translation` (NOT merged, NOT ship-ready).**
Driven by TelemetryDeck data (German = 16% of preferred language, #2 after English) — framed as a
DACH market-ENTRY/conversion bet, not a demand response. Two things exist:
(1) **Infra — MERGED to `main`, English-unchanged, shippable anytime:** a view-layer String Catalog
    (`Resources/Localizable.xcstrings`), `de` in knownRegions, a framework-free `Sim/Localization.swift`
    `L()` shim (for the Sim layer's ~124 strings — compiles in the headless harness), `SimLocale.current`
    wired at launch. Does nothing until a `de` column is filled, so zero 4.3(a) exposure.
(2) **Translation — on `de-translation`, ~141 of ~370 strings done + 7 category-2 code fixes, verified
    live in German** (tab bar, control bar, Finance, Fleet/Marketplace, Save/Quit, naming/paywall).
    Register **du**; AI-drafted, no native review (designer accepted the risk). NOT ship-ready — partial
    German is worse than none.
⚠️ **THE KEY GOTCHA (documented in `aa-1.1.x/LOCALIZATION_SCOPING.md`):** SwiftUI only auto-localizes
string LITERALS in `Text("…")`. A string reaching `Text` as a `String` VARIABLE (data array, model prop,
or a `String`-typed helper param) silently bypasses the catalog even with a perfect translation. Fix =
change the display param to `LocalizedStringKey`. Verify by force-launching in German (`-AppleLanguages
'(de)'`); English text despite a catalog entry = a code gap, not a locale problem.
**To finish:** `aa-1.1.x/LOCALIZATION_SCOPING.md` has the exact done/remaining map + method + the
`aa-1.1.x/de-glossary.md` terminology. **SHIP GATE:** never release standalone during the 4.3(a) cascade
(FC's localization-only 1.3 was rejected) — bundle the `de` turn-on with a content update, or wait for
the account to cool. Ideally a native-German review pass before it goes live.

**► 1.4.2 (build 52) = ASYNC SAVE fix — APPROVED + LIVE (`READY_FOR_SALE`, 27 Aug).** Merged to
`main`; fixes the `hang.under3s` TelemetryDeck signal by moving the save encode/write/mirror off the
main thread. FOLLOW-UP (still open, both fixes): the `hang.under3s` count in TelemetryDeck is the real
verdict — but MetricKit tags a hang with the version running when DELIVERED, not when it OCCURRED, so
1.4.1-vs-1.4.2-vs-1.4.3 attribution stays fuzzy. Read the count TREND over 1–2 weeks as adoption
grows, not an instant before/after. A future touch could tag hang telemetry with the app version at
occurrence to disambiguate — worth it only if the metric stays interesting.
The MetricKit CrashReporter shipped in 1.4.1 surfaced its first real signal — `hang.under3s` ×13 in
the TelemetryDeck Errors dashboard — traced to the synchronous main-thread save (encode + `.bak`
re-decode + write + iCloud mirror, all on the main actor). Fixed: `GameStore.saveInBackground` runs
the heavy work on a serial `DispatchQueue` off-main (snapshot still captured on main); autosave-on-
background holds a UIKit `beginBackgroundTask` assertion so the write finishes before iOS suspends.
Verified on device (SAVE + background both advance the save file, no hang, app survives) + harness
RoundTripVerify 13/13. DESIGNER STEP: create the 1.4.2 version record + attach build 52 + What's New
(a stability line) + submit. Next new build = **53+**. FOLLOW-UP: re-check the `hang.under3s` count in
TD after 1.4.2 is live — it should drop. Full detail: CLAUDE.md "ASYNC SAVE".

**► 1.4.1 (build 51) = ONE combined release — the Game Center WAKE fix + the Tech Ops
modernization. APPROVED + LIVE (`READY_FOR_SALE`, 24 Aug).** Both branches (`game-center-1.4.1`,
`tech-ops-modernization`) merged to `main`; build 51 carries both (build 50, the GC-only cut, was
superseded). The GC wake fix (`wakeAccountRecord`) is now public — achievements sync to the Apple
Games app; the rocket is OFF (blank in-app dashboard is a separate GameKit issue). Tech Ops
(RC/Telemetry externalization + Test Store + MetricKit) is now the shipped mainline pattern. Next
new build = **52+**.

**► ONE FOLLOW-UP worth remembering (no build needed):** ~1 week after this release (so ~31 Aug),
check whether Apple's Game Center rocket now populates on the LIVE build on-device (the store-side
GC-declaration propagation theory — FCA is checking the same on their side). If it populates, a
future 1.4.2 can re-enable the standard `GKAccessPoint` (wiring documented in `GameCenter.swift`).
Also parked: a custom in-app SwiftUI achievements view (FCA's pattern; shape saved in memory) —
build it if the rocket stays blank and the designer wants an in-app surface.

**What's in build 51 — the GC wake fix:** after 1.4 went live the App-Store build's Apple Games
dashboard was STILL EMPTY (the "public release heals the stale record" theory FAILED). FC Architect's
device A/B found the trigger: a `GKAchievement.report` → `loadAchievements` ROUND-TRIP from a signed-in
device. AA reported but NEVER loaded — the missing half. `GameCenter.wakeAccountRecord()` FIXES it
(verified on device: AA now shows in the Apple Games app "Now Playing", achievements pill 3/29, real
badges with dates). The native `GKAccessPoint` rocket STILL opens a BLANK in-app dashboard (a SEPARATE
GameKit issue, confirmed identically on FCA, not fixable in our code), so **the rocket stays OFF** — no
in-app GC entry point; players reach achievements via the Apple Games app + milestone toasts. DO NOT
re-add the dead workarounds. Possible 1.4.2 follow-ups: a custom SwiftUI achievements view, and a
~1-week re-check of the plain rocket (store-side-propagation theory). Full detail: CLAUDE.md's GameKit
note, "CORRECTION + FIX — 1.4.1".

**What's in build 51 — Tech Ops modernization (plumbing + observability, NO gameplay change):** a
Postmark Tech Ops audit found Airline behind its own siblings on the RC/TelemetryDeck patterns it
inspired. (1) RevenueCat key externalized to a gitignored `Secrets.xcconfig` → Info.plist →
`Store.resolveKey` with a Test Store path + the four `isConfigured` guards — the Test Store path is
LIVE-VERIFIED (the designer pasted the real `test_` key; a `-useTestStore` Debug launch logged
RevenueCat's "Using a Test Store API key"). (2) `Telemetry.isDriven` guard + externalized app ID + an
XCTest linkage proof (`TelemetryTests`, 9/9). (3) MetricKit `CrashReporter.swift` (crash/hang TYPE-only
→ Telemetry Errors). Full detail: CLAUDE.md "Decided — Tech Ops modernization" + TASKS.md.

_1.4.1 in one paragraph:_ after 1.4 went live the designer checked the App-Store build on-device —
the Apple Games dashboard was STILL EMPTY for AA (the "public release heals the stale record" theory
FAILED). FC Architect's device A/B found the real trigger: a `GKAchievement.report` →
`loadAchievements` ROUND-TRIP from a signed-in device. AA reported but NEVER loaded — that missing
half is why it stayed poisoned despite being live + reporting. `GameCenter.wakeAccountRecord()` (the
load call, once after auth) FIXES it — **verified on device (build 49): AA now shows in the Apple
Games app "Now Playing", the in-app achievements pill reads 3/29, and the Apple Games grid renders
our real badges with dates.** BUT the same device test showed the native `GKAccessPoint` rocket STILL
opens a BLANK in-app dashboard, and FCA confirmed the IDENTICAL split on FCA (record woken + Apple
Games populated, but rocket's in-app VC blank; restart doesn't clear it). So the blank dashboard is a
SEPARATE GameKit issue, not fixable in our code — **1.4.1 ships the wake with NO in-app GC entry
point; the rocket is re-stubbed OFF** (the `atLaunchScreen` + auth-gated wiring is documented at the
site for a clean re-enable later). Players reach achievements via the Apple Games app (now populated)
+ the app's milestone toasts. DO NOT re-add the dead workarounds (trophy button / `.pageSheet` /
floating Done). Two open probes may feed a 1.4.2: FCA is testing a
`GKGameCenterViewController(state: .achievements)` button vs the rocket's `.dashboard` state, and both
apps re-check the plain rocket in ~1 week for the "store-side GC declaration propagates after a GC
release" theory (FCA 1.2 live ~2 days, still blank). Next new build after 50 = **51+**. Full detail:
CLAUDE.md's GameKit note, "CORRECTION + FIX — 1.4.1".

**► 1.4 (build 48) = the GAMEPLAY PACK — LIVE (`READY_FOR_SALE`).**
(Builds 45–47 are SUPERSEDED. The Game Center ENTRY-POINT saga, condensed: an app that shipped
before its GC integration (AA 1.0–1.3, same as FCA) carries a stale server-side record that
poisons GameKit's own dashboard UI — Apple's rocket opens empty, and every client-side
workaround lost on device (47's trophy→grid dead-ended with no exit; GameKit forces its own
full-screen). Family decision (mirrors FCA build 35): **48 ships reporting-only, NO in-app GC
UI** — players view achievements in the Apple Games app; after 1.4 is publicly released, verify
the rocket heals on device and re-enable the standard GKAccessPoint in a 1.4.x (one line, site
documented in GameCenter.swift). Attach BUILD 48 to the 1.4 version record.)
Six features from the critical gameplay review (branch `gameplay-lever-pack`, now MERGED to
`main`): per-route FARE LEVER (Discount…Flagship, asymmetric elasticity), SESSION BRIEFING
(welcome-back ops card on load), FIRST QUEST (guaranteed curated airport offer for new
airlines + rewritten tutorial), GAME CENTER (29 achievements ← milestone ladder + 2
efficiency leaderboards; entitlement in the binary), RIVAL FLAVOR + free-tier depth teaser,
and SUBSIDIARY FLEET GROWTH (buy-for/transfer — a paying-player request). Verified:
FareVerify 17/17 · QuestBriefVerify 19/19 · SubFleetVerify 15/15 · OfferSpread 5/5 · soak
6/6 seeds ALL GREEN · live Simulator drive of every surface. Archived/validated/uploaded via
the CLI chain (build 48 Delivery UUID `db71f0fc-47fd-434b-90b1-3f3cb4544987`; superseded:
45 `a0a46258-…`, 46 `0ac75396-…`, 47 `e4e6ce5f-…`).
- **The ASC Game Center config is DONE, created via the API** (`aa-1.1.x/gc_setup.py` +
  `gc_upload_images.py`, both idempotent; shared gold-ring badge on all 29, delivery COMPLETE;
  see GAMEKIT_SETUP.md). It all goes live with the 1.4 release.
- **SUBMITTED (21 Aug):** designer's TestFlight passes on 45–47 confirmed auth + reporting
  ("Signed in as mdspike", 29 achievements counted, "First Jet" earned); 1.4 version record
  + fare-lever-led What's New + build 48 attached + the Game Center per-version checkbox
  enabled via API + App Review notes rewritten → `WAITING_FOR_REVIEW`. Auto-releases on
  approval. Next new build after 48 = **49+**.

**► WHAT THE NEXT SESSION SHOULD KNOW (21 Aug, end of the 1.4 session):**
- **App Review notes for 1.4 were REWRITTEN via the API** (they were stale: subscription-era
  $5.99/mo pricing + 3.1.2 auto-renew text, the old 3/2 free caps, and "no analytics SDKs" —
  false since TelemetryDeck shipped in 1.2.1). Now: one-time unlock, 6/5 caps + paths to the
  paywall, a GAME CENTER section explaining reporting-only/no in-app browser is deliberate,
  the livery + first-quest first-launch flow, the fare control, TelemetryDeck as anonymous
  aggregate analytics. Review details are editable while `WAITING_FOR_REVIEW`.
- **The `gameCenterAppVersion` checkbox:** ASC refuses to submit a build carrying the GC
  entitlement until the version's Game Center checkbox is enabled. Done for 1.4 via
  `POST /v1/gameCenterAppVersions` (relationship appStoreVersion; came back enabled). **FCA's
  1.2 will hit the same error** — same one-liner.
- **AFTER 1.4 IS LIVE — the one real follow-up:** check Apple's Game Center rocket on the
  live build. If the stale server record healed (the theory from FCA's device A/B; 1.4's
  release is the heal mechanism), re-enable the standard `GKAccessPoint` in a 1.4.1 on BOTH
  the load menu and the naming screen. `GameCenter.swift` documents the whole saga at the
  hard-off stub. No custom presentation hacks — they all dead-ended on device.
- Non-blocking: subsidiary aircraft render competitor-purple on the map (no third colour
  state); all 29 GC achievements share one badge (replaceable via `gc_upload_images.py`);
  remove Monthly/Yearly from the RevenueCat offering once the unlock dominates (never delete
  the sub products); Aerospace + Mars Colony have no Telemetry at all.
- Tooling that now exists: `aa-1.1.x/gc_setup.py` + `gc_upload_images.py` (ASC Game Center
  via API, idempotent), `FareVerify` / `QuestBriefVerify` / `SubFleetVerify` harnesses,
  `-devScenario subfleet`. The release chain (archive → export → altool validate/upload) ran
  four times this session from the CLI without touching Xcode.

**► 1.2 (build 41) is APPROVED + LIVE** — the MONETIZATION PIVOT is public (subscription →
one-time "Full Unlock", $9.99 founding rising to $19.99 on Dec 1, 2026; two non-consumables
`aa_unlock_founding_player`/`aa_unlock_standard` under RevenueCat packages `founding`/
`standard`; subs RETAINED for coexistence so existing subscribers keep Pro). It went
`WAITING_FOR_REVIEW` → `READY_FOR_SALE` early 18 Aug after ~6 days in Apple's queue (a
first-time monetization change + 2 IAPs drew a longer look than the ~1-day 1.1.x reviews).
**NOW THAT IT'S LIVE + once it's dominant:** remove Monthly/Yearly from the RevenueCat
offering (NEVER delete the sub products); watch trial→purchase conversion + founding-price WOM.

**► 1.2.1 (build 43) is APPROVED + LIVE** (`READY_FOR_SALE`, 19 Aug — cleared review fast,
as expected with no IAP re-review). It carries TWO things:
- **The airport-offer fix** (the customer-reported one): recruitment offers always targeted
  the player's single biggest served hub (`hubs.first(...)` on a traffic-sorted list) — an ATL
  customer got 35 consecutive offers all into ATL, repro'd at 100%. Now a weighted random pick
  (sqrt(pax), ×3 served / ×0.35 unserved): top dest 100%→12%, distinct 1→30+, **60% still land
  on a served hub** (hold that number on any retune). Guard: `aa-1.1.x/OfferSpreadVerify.swift`,
  validated against the pre-fix code (fails 3/5 there).
- **TelemetryDeck error reporting** (designer: "added TD error reporting to all builds/repos").
  `Telemetry.errorOccurred(id:category:detail:)` (Errors preset, stable slug — never
  localizedDescription/PII). This is WHY it's build 43, not 42: build 42 predated the Telemetry
  helper, so `Telemetry.errorOccurred` was cherry-picked from `livery-prototype` onto `main` and
  the build bumped 42→43 so error reporting ships WITH 1.2.1. ✅ The "to all builds/repos" intent
  is DONE for every SHIPPING sibling — Vineyard/Golf/FC/Flight Ops/Resort all already have
  `errorOccurred` (surveyed 19 Aug). Only Aerospace + Mars Colony lack Telemetry.swift entirely
  (no telemetry at all — a bigger separate job, likely pre-ship). GCA's `send()` is actually a bit
  AHEAD of AA's (an `isConfigured` guard + a DEBUG signal print); those two were back-ported into
  AA on 19 Aug (branch `telemetry-guard-and-doc-sync`, NOT yet in a shipped build — rides the next
  build after 44).
- **Verified + shipped:** clean Release build, offer-spread 5/5 on build-43 main, `altool
  --validate-app` + `--upload-app` both clean (Delivery UUID `689635df-0f22-4025-bc0f-6b1066f5ac38`).
  **DONE + APPROVED: version record created, build 43 attached, submitted 18 Aug, went
  `READY_FOR_SALE` 19 Aug. Both changes are LIVE.**

**► 1.3 = PERSONALIZED LIVERY — APPROVED + LIVE 19 Aug (`READY_FOR_SALE`, build 44).**
`livery-prototype` merged into `main` conflict-free; bumped to 1.3 / build 44; Release build
clean + offer-spread 5/5; archived → exported → `altool --validate-app` + `--upload-app` both
clean (Delivery UUID `234e9bf3-0636-4fc9-bd29-1b138455541a`). Feature: painted tails on all 35
types, the creation + re-customise flows, fleet repaint (itemized cost + shop queue + lost-revenue
opportunity cost), existing-player free-first-choice path + one-time update prompt. `LIVERY_SPEC.md`
+ `aa-livery/` tooling are now ON `main` too. **APP STORE SCREENSHOTS DONE** (6.9" iPhone + 13"
iPad, dark, "Air Tina" consistent create↔in-game) at `~/Desktop/Airline Architect Livery
Screenshots/`.
- **✅ SHIPPED (19 Aug):** all gates cleared (real-device first-run passed, version record +
  livery-led What's New + two livery screenshots), submitted, and APPROVED same day —
  `READY_FOR_SALE`. The personalized livery is public. Next new build after 44 = **45+**.

**► Note the Telemetry commit lives on BOTH branches** — `main` (147bbc1, cherry-picked) and
`livery-prototype` (3cb9558, the original), so the merge stayed conflict-free. Clean tree on
`main`, all pushed. App: <https://apps.apple.com/us/app/airline-architect/id6790569697>._

## What shipped in 1.1.2 (build 37)

**1.1.2 / build 37 is what's LIVE** (the repo has since moved to 1.1.3 / 38 — see the
next section for the current build-number rule). Signing is healthy (Postmark Digital
LLC, team `D2PVU8X5Q7`).

**The one change:** a **curated airport-archetype override table**. The
designer spotted SLC (ringed by the Wasatch) showing `plains`; a full 385-airport
audit found it was systemic — Europe's `lat >= 48 -> alpine` rule was INVERTED
(Berlin/Hamburg/Warsaw "alpine", Zurich/Geneva "coastal"), and `plains`/`coastal`
were dumping grounds (Honolulu, Cusco at 11,000 ft, Kathmandu, the whole Gulf).
`AirportPhoto.archetypeOverrides` (108 entries) now pins the clear errors; alpine is
override-only. Audit harness: `aa-1.1.x/archetype-audit` — **re-run it after adding
airports**.

## 1.1.5 (build 40) — SUBMITTED FOR REVIEW (11 Aug)

Repo at **1.1.5 / build 40**, uploaded from the CLI (export → `altool --validate-app`
→ `--upload-app`, VERIFY + UPLOAD both clean, Delivery UUID `f54fd353-…`) and submitted
for review by the designer 11 Aug. Next new build must be **41+**. Two customer-reported
items:

- **Fuel-hedge persistence fix.** A paying customer's bought 90-day hedge VANISHED on
  app close/reopen — `fuelHedgeExpiryTick` was set by `buyFuelHedge` but never in
  `GameSnapshot`/`snapshot()`/`restore()`, so the autosave→relaunch round-trip dropped a
  PAID asset. Fixed (field + `decodeSafeOpt` + snapshot + restore). A full persistence
  AUDIT found this was the ONLY material paid/earned gap. Guard: `aa-1.1.x/FuelHedgeVerify.swift` (11/11).
- **Close route / park aircraft — new lever.** There was NO way to close a route and
  keep the plane, or force a plane idle (only sell / reassign-to-a-new-route / accept a
  slot buyback). `Simulation.parkAircraft(_:)` archives the route (history kept, slots
  freed) and leaves the plane an idle spare — at-gate immediately, airborne deferred to
  arrival (`pendingPark`, persisted). UI on Fleet detail (**PARK (CLOSE ROUTE)**) + the
  Routes panel (**Close route · park aircraft**). Guard: `aa-1.1.x/ParkVerify.swift`
  (28/28); driven live on the sim (Fleet-detail flow confirmed; deferred park executes).

## 1.1.4 (build 39) — LIVE (approved 11 Aug)

Repo was at **1.1.4 / build 39**, uploaded + submitted 9 Aug, **approved and live 11 Aug**.
Contents:

- **Free 3-day trial on both plans (Monthly default) — the paywall UI.** "3 days free,
  then $X" line + "Start Free Trial" CTA, eligibility-gated (once per subscription
  group per Apple ID). The ASC introductory offers are ALREADY configured on both
  Monthly + Yearly (Free / 3 Days / all 175 territories, end 2026-12-31) — so once 39
  is live the trial appears for eligible new users. Decision + mechanics in
  `PRICING_EXPERIMENT_SPEC.md`. **Shipping to everyone (trial in the default offering),
  NOT A/B'd** — volume too low; A/B stays in reserve.
- **New cold-launch backdrop art** — full-bleed aerial-runway scene, 4 assets
  (iPhone/iPad × dark/light), `.fill` everywhere (no seams), light opacity 0.42 /
  dark 0.25. Superseded the pencil-sketch blend approach. See CLAUDE.md.
- **Two paywall fixes (from the pricing-experiment prep):** no stale-price flash
  (`Store.pricesAreLive` gates the price), and the savings badge is computed from real
  prices (`savingsNote`) instead of a hardcoded "Save 30%".
- **ASC Promotional Text** — the STANDING copy for all future releases lives in
  `APP_STORE_DESCRIPTION.md` (designer, 18 Aug): "Start with one jet and build an airline
  that spans the globe. 385 real airports, real economics. One-time unlock — no
  subscription, no tedious in-app spending." Promo text updates with NO review — a free
  lever, editable anytime. ⚠️ Keep "no tedious in-app spending" (NOT "no in-app
  purchases" — the one-time unlock IS an IAP); re-verify the 385 airport count if airports
  are added.

## What shipped in 1.1.3 (build 38) — LIVE

Repo WAS at 1.1.3 / build 38 (LIVE); it has since moved to 1.1.4 / 39 — the current
build-number rule is in the 1.1.4 section above. Notable: the upload was done ENTIRELY FROM THE CLI
with the ASC API key (export → `altool --validate-app` → `--upload-app`) — see
CLAUDE.md's correction; the old "Claude can't upload" note was wrong. Contents:

- **Free-tier caps raised 3 aircraft / 2 routes → 6 / 5**, sized so a free player can
  build exactly ONE hub (`hubMinRoutes` is 5) and hits the wall wanting a second.
  The old caps made hubs — and every system past them — structurally invisible, which
  is the likeliest cause of weak conversion. Paywall/cap copy now sells that depth
  rather than "more of the same". Re-verify with `aa-1.1.x/free-tier-probe` after ANY
  change to starting capital, aircraft prices, or `hubMinRoutes`.
- **Analytics: TelemetryDeck is wired (1.1.3/38).** Six funnel signals answer the one
  thing RevenueCat can't — whether players ever REACH the paywall. See
  `Telemetry.swift`; the family-level standard + traps live in PostmarkOps'
  `ARCHITECT_FAMILY.md`. Two things already handled, don't redo them:
  **App Store App Privacy is declared** (Usage Data → Product Interaction, *Used for
  Analytics*, **Data Not Linked to You** → no ATT prompt), and the SDK product IS
  linked to the app target (it silently wasn't at first — every signal compiled to a
  no-op). **That privacy declaration stays true only while signals carry NO
  identifying data** — the no-PII rule in Telemetry.swift is what keeps it honest.
  DEBUG builds tag signals as TEST MODE, so Simulator testing never pollutes the
  production numbers — flip the dashboard's "Test Mode" chip to see them (an empty
  Overview with Test Mode OFF is the expected false negative, not a broken pipeline).
  **CONFIRMED RECEIVING (6 Aug 2026):** a Simulator run landed 1 user / 3 events,
  SwiftSDK 2.14.2, 0 errors. **38 is live, so REAL PLAYER DATA is arriving now** —
  read it in the production view (Test Mode OFF).

## What shipped in 1.1.1 (build 36)

**Account note (resolved):** the designer's personal Apple account migrated to an Org
account (Postmark Digital LLC) mid-cycle, which blocked distribution signing for a
few days. The migration **kept the same team id `D2PVU8X5Q7`**, so no project change
was needed and the iCloud KVS entitlement was unaffected. If a future migration
changes the team id, it's pinned in 6 configs in the pbxproj.

**Contents (all since build 35):**
- **Airport hero images** — tapping an airport shows real art. 34 JPGs (~13 MB):
  9 terrain/region archetypes + 25 marquee-city overrides (incl. Bozeman). See
  `AIRPORT_PHOTOS_SPEC.md`.
- **New cold-launch backdrop** — the drafting-tools motif replaced by the designer's
  aviation pencil sketch, with a separate iPad-composed asset. See CLAUDE.md.
- **Fix: ASSIGN TO NEW ROUTE was a silent no-op** since the custom-tab-bar refactor
  (`.onChange` never fires on a recreated view — adopt intents in `.onAppear`).
- **Fix: selling a route-assigned aircraft** now offers replace-or-close instead of
  silently archiving the route.
- **Fix: Finance ledger figures are compact (B/M/k)** so late-game totals stop
  churning at 25×; day/night terminator seam fixed.

## WHERE THINGS STAND

- **Shipped & live.** 1.1.4 (build 39) is public (approved 11 Aug) — as were 1.1.3 (38),
  1.1.1 (36) and 1.1.2 (37) before it, all clean reviews with no rejections.
  **1.1.5 (build 40) is uploaded + submitted for review** (fuel-hedge fix + close-route/park).
  The preceding 1.1 (build 35) debut cleared only after a two-round Guideline
  **3.1.2** subscription saga (missing Terms-of-Use / EULA link — first in METADATA,
  then the IN-APP links), resolved by shipping the in-app paywall Terms + Privacy
  `Link`s + reviewer notes + a screen recording of the flow. **Those links are still
  in the binary — don't remove them.** The full rejection→approval arc is in git
  history (the old `RELEASE_STATUS.md` was retired at the 1.1 launch).
- **Monetization is LIVE and wired** (was previously a local stub): RevenueCat +
  RevenueCatUI SPM packages are in the build, real API key, `Purchases.configure`
  runs, and `isPro` is driven by the live entitlement **`Airline Architect Pro`**
  (dashboard identifier confirmed to match `Store.entitlementID`, with the real App
  Store Monthly + Yearly products attached). Two tiers ($5.99/mo, $49.99/yr); free
  tier caps at **6 aircraft / 5 routes** (raised in 1.1.3 — see above). **VERIFIED END-TO-END on device (3 Aug
  2026)** via a TestFlight sandbox purchase: Apple's sheet completed, the paywall
  dismissed ITSELF, and the fleet cap lifted — i.e. offering loaded → package
  resolved → StoreKit purchase → RevenueCat validated → entitlement active →
  `customerInfoStream` pushed it into the UI. Nothing about monetization is unproven
  now. **Re-test recipe:** install the TestFlight build (orange dot next to the app
  name = TestFlight; NO dot = the App Store copy, where a tap is a REAL charge), hit
  a cap, tap Continue. `[Environment: Sandbox]` appears on APPLE'S sheet, never on
  our own paywall. **GOTCHA: the fallback plan prices are identical to the real ones
  ($49.99/$5.99), so correct prices do NOT prove the offering loaded** — the real
  tell is whether tapping Continue reaches Apple's sheet or errors with "That plan
  isn't available right now."
- **Build numbers:** **1.1.4 / build 39** is LIVE; **1.1.5 / build 40** is submitted for
  review. ASC has 31–40 uploaded, so the next new build must be **41+**.
- **3-DAY FREE TRIAL is LIVE at the store level** (independent of the app binary): ASC
  introductory offers (Free / 3 Days, both Monthly + Yearly, all 175 territories, starts
  2026-08-09 / **ends 2026-12-31**) auto-apply to any eligible new subscriber NOW — verified
  by a real Yearly TRIAL in RevenueCat hours after config, even on build 38 (whose paywall
  doesn't advertise it). Build 39 ADVERTISES it (the "3 days free / Start Free Trial" CTA)
  to lift trial STARTS. Shipping to EVERYONE (trial in the default offering), NOT A/B'd —
  volume too low. Watch trial→paid conversion; ⚠️ the offer expires 2026-12-31 unless
  extended (can't edit — delete + recreate). Full decision/mechanics: `PRICING_EXPERIMENT_SPEC.md`.

## NEXT — see `NEXT_SESSION_PROMPT.md`

> **⭐ IN-FLIGHT FEATURE: personalized aircraft LIVERY** (surprise-&-delight). A
> designer-approved prototype lives on the **`livery-prototype`** branch (pushed to
> origin), NOT on `main` — the player's airline name is painted on the fuselage (window-
> line titles with the windows cutting through them) + a recolourable tail emblem, all
> palette-driven. **`git checkout livery-prototype` and read `LIVERY_SPEC.md`** (on that
> branch). The designer set the next-session plan: **(1) normalize the 5 tail emblem PNGs
> (trim to artwork bounds + centre), (2) build the livery creation flow** (2-colour +
> emblem picker on the naming screen, persistence, wire into Fleet/Acquire). Keep `main`
> clean until 1.2 is live; ship the livery as its own later version.

The prioritised brief for the next session lives in **`NEXT_SESSION_PROMPT.md`** —
a paste-ready block written to be understood cold. In short:

1. **Read the monetization signals (give them ~2 weeks).** (a) RevenueCat
   **trial→paid conversion** — trials start NOW (store-level), but conversion after the
   3 days is the number that matters. (b) TelemetryDeck **`Paywall.shown` ÷
   `Game.started`** (production view = Test Mode OFF) + the `Hub.established` share —
   does the 1.1.3 free-cap change (3/2 → 6/5) fix conversion. (c) The next pricing lever
   (`PRICING_EXPERIMENT_SPEC.md`) is a RevenueCat A/B, GATED on ~1k paywall-views/week —
   not yet.
2. **The standing "never played end-to-end" concern** — the UI/"does it feel right"
   half no harness can reach. It found the ASSIGN-TO-NEW-ROUTE no-op and the
   SLC-artwork bug in the last two sessions; it keeps paying.
3. **Resort's telemetry pointer**, once its vertical-slice pass lands (it was
   deliberately skipped mid-flight). Verify the target linkage, don't trust a callback.

Low priority: the explicit Restore Purchases button, and true cross-device iCloud sync.

## Standing conventions (unchanged, still bite)

- **Verify by DRIVING, not just building.** A clean `xcodebuild` proves nothing.
  Headless sim harnesses live in `aa-1.1.x/` (entry file must be `main.swift`); for UI,
  drive the Simulator (`simctl` + the iOS-Simulator MCP tool) and watch it.
- **The Finance cash invariant is SACRED.** Any new cash flow joins it,
  `PeriodFigures`, `FinanceSnapshot`, `FinanceSave`, AND the headless harness.
- **TEMPVERIFY / TEMPSHOT / `AA_*` / temp launch-arg hooks are NEVER committed** — grep
  before every commit. (Durable `#if DEBUG` harnesses like `-devScenario` /
  `-backdropTest` ARE keepers; the rule targets ad-hoc scaffolding.)
- **Update CLAUDE.md in the SAME commit as the code it describes.**
- **Balance changes need a MULTI-SEED sweep**, never a single run; measure NET WORTH.
- **A new persisted field needs one `decodeSafe` line in `Persistence.swift`**; a new
  nested Codable save type needs its own tolerant `init(from:)`. This is what fixed the
  lost-saves-on-new-build bug — never trust a bare `var x = 0` to survive decode.
- **Storage: staying on iCloud KVS, NOT CloudKit** (break-glass note in CLAUDE.md's
  iCloud section; the only trigger to revisit is a real save approaching the 1 MB KVS
  quota — today ~21 KB).

## Simulator gotchas that still bite

- **The sim's input channel dies mid-session** — surfaces as `Input send … timed out`,
  `machPortNotConnected`, or a tap that silently does nothing. A dropped tap looks
  exactly like a broken button; re-screenshot before concluding anything. One decisive
  tap per screenshot.
- **Tap coordinates are in POINTS** (iPhone 17 Pro = 402×874), NOT screenshot pixels —
  convert, or taps land off-screen.
- **`simctl ui <dev> appearance light|dark` doesn't repaint a foregrounded app** —
  relaunch fresh in the target appearance.
- **Typing via the automation `text` action can kick the app to the background** — use
  the software keyboard and tap keys, or seed state via a `#if DEBUG` launch arg.
- **SourceKit "cannot find X in scope" on a single file = false positive** (cross-file
  symbols); trust the full `xcodebuild`, not the per-file linter.
- **LANDSCAPE captures come out ROTATED** (`simctl io screenshot` grabs the raw
  framebuffer) — `sips -r 90` or `-r 270` to view upright; which one depends on the
  rotation direction. Rotating the device via `osascript` keystrokes is unreliable.
- **A capture taken right after `simctl launch` can be all-black** (grabbed mid-launch)
  — sleep ~3s and re-capture before concluding anything is broken.
- **`⌘⇧A` can't change the theme under `-backdropTest`** — that harness pins the scheme
  via `.preferredColorScheme` off `-backdropLight`. Relaunch with/without the flag.
- **`simctl io recordVideo`** stops/finalizes cleanly only on **SIGINT** (`pkill -INT`),
  not SIGTERM — the exit-code-1 on interrupt is expected, the mp4 still writes.

## Orientation for a cold reader

0. **`NEXT_SESSION_PROMPT.md`** — the paste-ready brief for what to do next.
1. `CLAUDE.md` — the persistent design/technical context. Long because it's thorough.
2. `APP_STORE_DESCRIPTION.md`, then the big feature specs (`GO_PUBLIC_SPEC.md`,
   `ACQUISITIONS_SPEC.md`, `HUBS_AND_CLUBS_SPEC.md`) — all COMPLETE.
3. `git log --oneline -30` — the rejection→approval→live arc is here.

Branch: everything on **`main`**, pushed to `origin/main` (GitHub `spikeatone/SkyOps`).
Open the Xcode project at `SkyOps/AirlineArchitect/AirlineArchitect.xcodeproj`.
