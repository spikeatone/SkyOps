# HANDOFF — read this first

You're picking up **Airline Architect** (the repo dir is still named `SkyOps`;
the app was renamed — see CLAUDE.md). This file orients a fresh session in one
read. It's a pointer, not the source of truth — when it disagrees with
CLAUDE.md, CLAUDE.md wins.

_Snapshot: 18 August 2026._

**► 1.2 (build 41) is APPROVED + LIVE** — the MONETIZATION PIVOT is public (subscription →
one-time "Full Unlock", $9.99 founding rising to $19.99 on Dec 1, 2026; two non-consumables
`aa_unlock_founding_player`/`aa_unlock_standard` under RevenueCat packages `founding`/
`standard`; subs RETAINED for coexistence so existing subscribers keep Pro). It went
`WAITING_FOR_REVIEW` → `READY_FOR_SALE` early 18 Aug after ~6 days in Apple's queue (a
first-time monetization change + 2 IAPs drew a longer look than the ~1-day 1.1.x reviews).
**NOW THAT IT'S LIVE + once it's dominant:** remove Monthly/Yearly from the RevenueCat
offering (NEVER delete the sub products); watch trial→purchase conversion + founding-price WOM.

**► 1.2.1 is BUILD 43 — UPLOADED to ASC 18 Aug, submit is ASC-SIDE (designer TODO).**
It carries TWO things:
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
  the build bumped 42→43 so error reporting ships WITH 1.2.1. ⚠️ The "to all builds/repos" intent
  still needs applying to the OTHER Architect apps (Golf/Vineyard/etc.) — NOT done here.
- **Verified + shipped:** clean Release build, offer-spread 5/5 on build-43 main, `altool
  --validate-app` + `--upload-app` both clean (Delivery UUID `689635df-0f22-4025-bc0f-6b1066f5ac38`).
  **REMAINING (ASC-side, designer): create the 1.2.1 version record → attach build 43 → submit.**
  Build takes ~5–30 min to finish processing after upload before it can be attached.

**► 1.3 = PERSONALIZED LIVERY**, on branch `livery-prototype` (NOT merged; `main` is clean of
it). Feature-complete — painted tails on all 35 types, the creation + re-customise flows, fleet
repaint (itemized cost + shop queue + lost-revenue opportunity cost), and the existing-player
free-first-choice path with a one-time update prompt. See `LIVERY_SPEC.md` (branch-only — check
out the branch to read it). **APP STORE SCREENSHOTS ARE DONE** (18 Aug): 6.9" iPhone + 13" iPad,
dark, App-Store-valid dimensions, at `~/Desktop/Airline Architect Livery Screenshots/`; airline
reads "Air Tina" consistently across the create screen + in-game (the design-screen name was a
throwaway `-liveryPreview` default, reverted). Two gates before cutting 1.3 remain: **walk the
first-run flow on a REAL DEVICE** (sim text entry backgrounds the app — the one path never
verified end-to-end), and the merge (verified conflict-free). The 1.3 checklist in TASKS.md now
also includes **uploading the two livery screenshots to ASC**. Next new build after 43 must be **44+**.

**► Note the Telemetry commit lives on BOTH branches** — `main` (147bbc1, cherry-picked) and
`livery-prototype` (3cb9558, the original), so the merge stays conflict-free. Clean tree on
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
- **ASC Promotional Text updated** (9 Aug, new-user hook): "Start with one jet and
  build an airline that spans the globe. 385 real airports…". Promo text updates
  with no review — a free lever to re-tune anytime.

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
