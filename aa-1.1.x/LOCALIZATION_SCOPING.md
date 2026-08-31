# German Localization — Scoping Assessment (2026-08-28)

## ⏳ PROGRESS (branch `de-translation`, NOT merged, NOT ship-ready) — read this first

**ALL FUNCTIONAL UI IS NOW TRANSLATED — the view layer (620 catalog keys) AND the Sim layer (237 `L()`
shim keys) are both done.** Register: **du**. AI-drafted (no native review — designer accepted that risk).
Everything is on the `de-translation` branch, twelve commits, pushed. English is unchanged throughout (the
catalog only adds a `de` column; the shim returns the English key at the "en" locale — RoundTripVerify
13/13 + the 6/6-seed soak both GREEN). **The ONLY things still in English are the marketing FLAVOR PROSE
(deliberately deferred for native review — see below) and the ASC store listing.** NOT ship-ready until
the flavor prose is natively written AND timing clears the 4.3(a) cascade.

**THE SIM `L()` SHIM IS FILLED (batch 11).** `Sim/Localization.swift`'s `simLocalizationTables["de"]` now
has 237 entries covering every user-facing Sim string: all 67 `logOps` title+subtitle pairs (the Ops event
feed), the ~25 `celebrate()` milestone toasts, all 9 session-briefing items, the EconomicEvent labels +
`opsEventSubtitle`, `seasonalWeatherReason`, the airport-recruitment pitches, and the assorted reason/note/
clubName literals. Every Sim string is wrapped `L("… %@", args)` (%@ only — the shim's positional
formatter; Ints pass via `String(describing:)`), with nested-ternary/String-var interpolations pre-computed
into clean per-branch keys. **KEY GOTCHA (handled):** the table keys must be the RUNTIME string, so the
route-arrow keys use the actual U+FE0E character (not the literal `\u{FE0E}` source text) — the generator
evaluates the Swift escapes. Verified with a standalone shim test AND a live German drive (the Alerts modal
is fully German — "N1ZQ — keine legale Crew in ORD", Reserve/Einstellen/Warten). Re-run `RoundTripVerify`
+ the soak after ANY further `Sim/` string touch.

**The ONLY untranslated view-layer keys left are intentional non-translations:** bare symbols/emoji
(`·` `—` `✈️` `:` `9+` `%lld` `%lld/%lld` `%@:`), the `Airline Architect` / `Architect` brand wordmark
(proper noun), and the `ArchitectBackdropTestView` + LiveryDesignView-gallery strings (both `#if DEBUG`,
compiled out of Release). All render identically in German or don't ship.

**Assets created:**
- `Resources/Localizable.xcstrings` — the view-layer String Catalog (518 keys, all with a `de` value).
- `Sim/Localization.swift` — the framework-free `L()` shim (its `de` table is still EMPTY — Sim strings
  are NOT translated yet).
- `aa-1.1.x/de-glossary.md` — the terminology glossary (du; Route/Slot/Gate/Crew kept as German
  loanwords; Drehkreuz = hub; Lounge = club; etc.). **Use this for every remaining string — consistency
  is the whole game.**

**DONE (verified in German on the sim):** tab bar (Netzwerk/Flotte/Crews/Betrieb/Finanzen) · Network
control bar (Erwerben/Route eröffnen/Routen/Crew einstellen) · Finance tab (FINANZEN, NETTOVERMÖGEN,
GRATIS-VERSION, all ledger/card labels, REPORTS/FUNDING + period selectors) · Fleet/Marketplace (FLOTTE,
Meine Flotte, Marktplatz, status boxes, aircraft labels, OWNED/LEASED, empty state) · Save/Quit (shared,
all 5 tabs) · core Naming + Paywall strings · **Crews tab — FULL** (CREW-ZENTRALE, the 2×2 data boxes
Verfügbar/Im Dienst/Ruhephase/Reserve, KNAPP BESETZT, Neue Crew/EINSTELLEN, hire banner + labor-action
plurals) · **Tutorial — FULL** (all 5 coach cards, title + body, verified stepping through in German) ·
**Session Briefing — strings translated + compiled** (BETRIEBS-BRIEFING / "Willkommen zurück bei %@" /
"Übernimm die Steuerung"; not eyeballed rendering — the briefing only shows on loading a save with real
progress, and `-devScenario` seeds skip the load path, but all three keys are confirmed in `de.lproj`) ·
**`LiveryDesignView` — FULL** (Gestalte/Passe deine Lackierung an, "Bringe %@ auf die Flotte.",
RUMPFBESCHRIFTUNG/SCHRIFTART/FARBPALETTE/HECKEMBLEM, the fuselage helper line, commit buttons
Airline starten / Lackierung speichern / Flotte neu lackieren — verified live via the in-game Livery
re-customise flow) · **Ops tab — VIEW LAYER FULL** (BETRIEBS-ZENTRALE, Routen-Chancen + subtitle,
Drehkreuze & Lounges, Flughafen-Anreize, Reputation/Passagiernachfrage, Konkurrenz + the 3 promo levers
Preiskampf/Werbekampagne/Treue, Ereignisse, the free-tier depth teaser, relative timestamps "vor N
Min./Std./Tagen", and the interpolated "~N/Tag" opportunity rows — verified live to the Fuel Hedge card;
the Competition/Reputation/Events groups below it are plain-Text literals + the two code-fixed helpers,
all confirmed compiled into `de.lproj` but not eyeballed because the sim ScrollView wouldn't respond to
the automation drag — a known tooling flake, not an app issue) · **`FuelHedgePanel` — FULL** (its whole
prose body incl. the "(%lld Flugzeuge im Besitz)" interpolation, the 30/60/90-day slots "%lld-Tage-Hedge:",
"$%@ Prämie", active-hedge + empty-fleet states — verified live on the Ops tab; the title/BUY were already
done in the earlier Figma restyle) · **`FleetDetailView` — FULL** (FLUGZEUGDETAILS, the identity block,
Aktueller Status card incl. the phaseLabel phases + ETA, Wartung & Wert (Zyklen/Marktwert/Wertverlust +
the interpolated upkeep line), Wirtschaftlichkeit letzter Flug (Umsatz/Flughafengebühren/Betriebskosten/
Nettoergebnis), the action buttons (NEUER ROUTE ZUWEISEN / PARKEN (ROUTE SCHLIESSEN) / FLUGZEUG VERKAUFEN /
TRANSFER WITHIN GROUP), the sell/park/terminate confirm dialogs, the `ReplaceOrCloseModal`, and the
`ReplacementPicker` — verified live: the whole detail scrolled through in German + the ReplaceOrCloseModal
driven, all correct incl. the split-ternary bodies).

**DELIBERATE DEFERRAL (not a miss):** `LiveryPalette.name` — the 10 palette names (Atlantic, Cardinal,
Pacific, Meridian, Evergreen, Copper, Azure, Tropic, Burgundy, Velocity, in `Livery.swift`) stay ENGLISH.
They're aesthetic brand/style labels, not domain terms, and translating them is a genuine judgment call
(keep "Burgundy" or "Burgunder"? "Velocity" reads fine in German as-is) — exactly the kind of call the
glossary flags for a NATIVE reviewer, not AI. To localize later: `Livery.swift` is a view-layer file
(imports SwiftUI), so wrap the display site `Text(LocalizedStringKey(p.name))` in `LiveryDesignView`
(+ the swatch label) and add catalog entries; the `name` field stays `String` (it's model data).

**Category-2 code gaps FIXED so far** (the pattern — see the CRITICAL FINDING section below): tab bar
(`SkyTabIcons`/`SkySidebar`), `NetworkView.barButton`, `FinanceView` sectionTitle/ledgerLine/ledgerRow/
miniStat/leverSection + the section/period `Text(rawValue)` selectors, `FleetView` segButton/statusBox,
`SaveQuitBar.pill`, **`CrewsView.dataBox`** (param → `LocalizedStringKey`) + **`successMessage`/
`successBanner`** (`String?` → `LocalizedStringKey?`, so the interpolated hire banner localizes),
**`Tutorial`** (`Text(LocalizedStringKey(step.title/step.body))` — the tutorial title/body are `String`
array fields, so they need the wrap; the extractor CANNOT auto-add them, so their keys were added to the
catalog manually with the exact English source), **`LiveryDesignView.section`** (title param →
`LocalizedStringKey`, localizes the 4 section headers) + **`commitTitle`** (`String` → `LocalizedStringKey`
default; its callers in `FleetView` only ever pass literals, so no call-site change) + the subtitle
restructured to `"Paint \(paintTarget) onto the fleet."` where `paintTarget` resolves the empty-name
fallback via `String(localized:)` so the format key stays clean `"Paint %@ onto the fleet."` instead of a
ternary-garbled literal, **`OpsView`** three helpers retyped to return/take `LocalizedStringKey`
(`pendingStatus`, `relativeTime`, and `promoButton`'s `idle` param — the last localizes the Fare war /
Ad campaign / Loyalty labels) + the `"%lld rival\(...s)"` plural split into two clean keys like the Crews
labor-action string, **`FleetDetailView`** five helpers/sites — `statusChip`'s `(text, color)` tuple typed
`(LocalizedStringKey, Color)` (GROUNDED/IDLE/FLYING), `econRow`/`labeled`(label)/`outlineButton`/
`ReplaceOrCloseModal.button` params → `LocalizedStringKey`, `phaseLabel` returns `String(localized:)` per
case + the inline "Idle — no route"/"At gate"/"a route" fallbacks wrapped in `String(localized:)`, the park
confirm title moved to a `LocalizedStringKey` computed var, and 3 nested-ternary-in-interpolation bodies
(ReplaceOrClose + ReplacementPicker) split into clean per-branch literals. **Every custom label helper with
a `String` title/label param is a suspect** — audit each and change the DISPLAY param to
`LocalizedStringKey` (keep VALUE params `String` — they carry data). **And a `.confirmationDialog` / `Button`
/ `Menu` title built via `.map{}??` or any String-returning expression takes the StringProtocol overload →
NOT localized; give it a `LocalizedStringKey` computed var instead** (the FleetDetailView park-dialog gotcha).

**REMAINING — only the FLAVOR PROSE and the ASC listing are left:**
1. **Flavor prose — the ONE thing deliberately NOT machine-translated (native writer, do LAST):**
   `AircraftType.flavor` (35 lines, e.g. "Dreamliner, stretched for range", shown in Fleet detail) +
   `Airport.destinationFlavor` (~50 evocative one-liners, shown on the airport card). These read as
   marketing copy; AI/MT German is worst exactly here, and a first-language market notices. They live in
   `Sim/` (AircraftType.swift / Airport.swift) so they route through the SAME `L()` shim as everything
   else — the mechanism is ready, they just need real German written by a person, then added to
   `simLocalizationTables["de"]`. Leave them English until that pass.
2. **ASC-side (separate from the binary):** German App Store listing (name/subtitle/description/
   keywords/screenshots) + German Game Center achievement localizations.

**Deliberately left untranslated in the app (NOT gaps — none ship in Release or differ in German):**
bare symbols/emoji (`·` `—` `:` `✈️` `9+` `%lld`), the `Airline Architect`/`Architect` wordmark and the
pure-proper-name crew families (Beechcraft 1900 / ATR 42 / Dornier 328 / De Havilland Dash 8 — no English
word), and the `#if DEBUG` harness strings (`ArchitectBackdropTestView`, the LiveryDesignView emblem
gallery). Aircraft type names, airline names, airport codes, and tickers are proper nouns throughout.

**Method note that saved time this pass:** the exact auto-extracted catalog KEYS (esp. the `%lld`/`%@`
format specs for interpolated strings) can be read from Xcode's per-file extraction output —
`DerivedData/…/Build/Intermediates.noindex/AirlineArchitect.build/…/Objects-normal/arm64/<File>.stringsdata`
(`strings <File>.stringsdata | grep '"key"'`). Dynamic `LocalizedStringKey(someString)` conversions do
NOT appear there (the extractor can't see the literal), so those keys must be added to the catalog by
hand with the exact English source text. After editing the catalog, `xcodebuild` compiles it into
`AirlineArchitect.app/de.lproj/Localizable.strings` — grep that to CONFIRM a key made it in
(`plutil -convert xml1 -o - …/de.lproj/Localizable.strings`).

**Method for the next session:** work screen-by-screen; for each, force-launch in German
(`xcrun simctl launch … -AppleLanguages '(de)' -AppleLocale de_DE`), screenshot, and any string that
stays ENGLISH despite being translatable is a category-2 code gap (fix the helper's param type) — German
number formatting (17.646.949) confirms the locale is active, so English text = a code bug, not a locale
problem. Batch-add translations via a small Python merge into the `.xcstrings` (keys = exact English
source). Re-run `RoundTripVerify` after any Sim-layer touch. Keep it on `de-translation` until COMPLETE.

**Why:** TelemetryDeck "New Users by Preferred Language" shows **German 16%** — the #2 language
after English (76%), and 10× Spanish (1.3%). Region chart barely shows Germany, so these are
German-language-device users spread across DE/AT/CH.

**⭐ THE REAL CASE IS ACQUISITION, NOT SERVING EXISTING USERS (designer, 28 Aug).** The current
German user count is nearly irrelevant to the decision. German localization is a **market-entry /
conversion lever**, not a response to demand: DACH is one of the largest, highest-spending premium
mobile-games markets, and a paid sim is exactly the genre where German players expect native
localization and reward it with installs + purchases. The low current German count is plausibly a
CONSEQUENCE of being English-only, not a reason to skip — you localize to ACQUIRE the users who
aren't installing/buying because there's no German. So DO NOT read this as "park until the audience
grows"; read it as **"a market-entry investment, gated on TIMING and done PROPERLY."** (The
sample-size question still matters for PRIORITIZATION vs other work, but it does not veto the bet.)

**⚠️ TIMING (do NOT ship standalone during the 4.3(a) cascade):** FC Architect 1.3 was rejected 4.3(a)
for a **localization-only** update. Apple's spam reflex flags a pure-localization diff. So German
localization must ride WITH a real gameplay/content change, or wait until the account-wide cascade
cools (see `PostmarkOps/APP_REVIEW_NOTES.md`). This is scoping-ahead, not a ship order.

## Current state

> **STATUS (30 Aug): translation is FUNCTIONALLY COMPLETE on branch `de-translation` — this doc's
> "what's left = the translation pass" below is now HISTORICAL.** Verified on that branch: the view
> catalog is **646/646 keys translated (0 missing)**, the Sim `de` shim table has **~238 entries** (all
> functional Ops-log/decision/offer copy), money shows in **Euro** (`Currency.symbol` +
> `SimLocale.currencySymbol`), and 20 German App Store screenshots are captured. What actually REMAINS
> to finalize: (1) a **visual pass** through every German screen on the sim (the designer's next ask);
> (2) **flavor prose is still raw English** — `Airport.flavorByCode` (~50) and `AircraftType.flavorByID`
> (37) are plain `String` maps NOT routed through the catalog/shim, so they bypass localization (the
> catalog-bypass gotcha below); route them through `L()`, then translate; (3) **merge `main` in** —
> `de-translation` is 7 commits behind (missing the 1.5 A350-1000/747-8i + map throttle); (4) native
> review + device QA (German runs ~30% longer); (5) ASC German listing + Game Center localizations.
> The infra history below is retained for how the plumbing works.

- **INFRASTRUCTURE BUILT (28 Aug, branch `localization-infra`) — English unchanged, no shippable
  localization diff.** What now exists:
  - **`Resources/Localizable.xcstrings`** — the view-layer String Catalog (empty; source language en).
    The synchronized group auto-registered it (the build runs `xcstringstool` — no manual pbxproj file
    ref needed, unlike FC's hand-authored project). SwiftUI `Text("…")` localizes through this for free
    once a `de` column is filled.
  - **`de` added to `knownRegions`** in the pbxproj (alongside en, Base).
  - **`Sim/Localization.swift`** — the framework-free shim for the Sim layer's ~124 user-facing
    strings. `L("… %@ …", args)` looks up a per-language format table (empty today → English
    passthrough) and substitutes `%@` positionally so translations can reorder words. NO imports
    (pure Swift) → compiles in the headless harness. Verified: 4/4 shim unit checks + harness 13/13.
  - **`SimLocale.current` set at launch** from the system locale (in `AirlineArchitectApp.init`, view
    side — Sim/ has no Locale access). No-op until a table is filled.
  - **One reference conversion** done as the pattern example: `Simulation.establishHub`'s
    "Hub established at %@" now flows through `L(...)`. The other ~123 Sim strings convert the same way
    during the TRANSLATION pass (not part of this infra commit).
- **What's left = the translation pass** (fill the `de` catalog column + the Sim `de` table with NATIVE
  German) + device QA + ASC listing. All gated on timing per the top of this doc.
- Deployment target iOS 18 → String Catalogs are the modern approach (Xcode extracts, one file,
  per-language columns, handles plurals/interpolation ordering).

## ⚠️ CRITICAL FINDING (28 Aug) — many strings need a CODE change, not just translation

SwiftUI **only auto-localizes string LITERALS passed directly to `Text("…")`** (they become
`LocalizedStringKey`). A string that reaches `Text` as a **`String` variable** — from a data array,
a model property, or a function parameter typed `String` — is treated as ALREADY RESOLVED and
**bypasses the catalog entirely**, even with a perfect translation in it. This is not a translation
gap; it's a code gap, and it's widespread in AA.

Confirmed + fixed examples (the pattern to copy):
- **Tab bar** (`SkyTabIcons.swift` / `SkySidebar.swift`): titles live in a `[(title: String, …)]`
  array → `Text(item.title)` didn't localize. Fix: `Text(LocalizedStringKey(item.title))`.
- **Control bar** (`NetworkView.barButton`): `barButton(_ title: String, …)` → `Text(title)` didn't
  localize the literal call-site strings. Fix: change the PARAM TYPE to `LocalizedStringKey` — then
  the literals at the call sites (`barButton("Open Route", …)`) localize with NO call-site changes.

**So localizing AA is THREE kinds of work, not one:**
1. Plain `Text("literal")` → translate only (works for free once the catalog has the key).
2. Variable/array/param-fed `Text(someString)` → **code fix** (`LocalizedStringKey` wrap or param
   retype) PLUS translate. Audit every custom label helper's param type.
3. Sim-layer strings → the `L()` shim (framework-free) PLUS fill its `de` table.

The verification method that catches #2: force-launch in German (`-AppleLanguages '(de)'
-AppleLocale de_DE`) and eyeball each screen — a string that stays English despite being in the
catalog is a category-2 code gap. German number formatting (17.646.949) confirms the locale IS active,
so English text = a localizability bug, not a locale problem.

## The translation payload — by surface, hardest last

| Surface | Volume | Notes |
|---|---|---|
| View-layer UI strings | ~267 `Text("…")` + ~386 distinct labels/buttons | Standard; String Catalog handles these |
| Interpolated view strings | ~93 `Text` with `\(…)` | Each needs a format string; **German reorders args** (verb-final) — can't just swap words |
| Airport "destination flavor" prose | ~50 evocative one-liners (`Airport.flavorByCode`) | Real prose translation (marketing-quality) |
| Aircraft flavor lines | 35 (`AircraftType.flavor`) | Short prose |
| Airport recruitment pitches | 3 templates × interpolated city names | Prose + interpolation |
| Tutorial steps | 5 coach cards | Prose |
| Session briefing lines | ~8 states | Prose |
| Achievement titles + descriptions | 29 × (title + before + after) = ~87 strings | Also live in ASC (Game Center localizations — SEPARATE from the app binary) |
| **Sim-layer Ops-log / decision copy** | **~124 sentence-like literals in Simulation.swift alone** | **THE HARD ONE — see below** |

## The architectural blocker: Sim-layer strings

**`Sim/` builds user-facing English strings** — e.g. `logOps(.structural, "Hub established at \(code)", "\(clubName) opens at \(code)", …)` (Simulation.swift ~L386/403/414), plus decision-card copy, offer pitches, closure messages. ~124 sentence-like literals in Simulation.swift.

**The problem:** `Sim/` must stay **framework-free** (the headless harnesses compile it with plain
`swiftc`, no SwiftUI/Foundation-localization). SwiftUI's `LocalizedStringKey` and String Catalogs are
UI-framework-bound. So these strings **cannot be localized the standard way without breaking the
harness.** Three options, cheapest-risk first:
1. **Framework-free localization shim in Sim/** — a tiny `L(_ key:)` func + a plain `[String:String]`
   table per language, no Foundation-localization dependency. The harness compiles it fine (it's just
   a dictionary lookup). Most contained; keeps Sim/ pure.
2. **Move string-building to the view layer** — Sim/ returns structured data (enum + params), the view
   formats + localizes. Cleanest long-term (Sim/ becomes truly string-free) but touches every
   `logOps`/decision-card call site — large refactor.
3. **Localize only the view layer, leave Sim/ English** — cheap but the Ops feed / decision cards stay
   English for a German player. Half-localized reads worse than not localized. Not recommended.

Recommendation for scoping: **option 1** (the shim) for a first pass — it localizes the Sim strings
without the big refactor and keeps the harness working.

## Effort estimate (rough)

- **View-layer String Catalog migration:** ~1–2 days (wrap literals, extract, the 93 interpolated
  ones need care for German word order).
- **Sim-layer shim + table:** ~1 day (the shim is small; extracting the ~124 strings is the work).
- **Prose translation** (flavor, tutorial, briefing, pitches, achievements — several hundred lines of
  real sentences): the **actual bottleneck.** Machine translation is NOT acceptable for a marketing-
  facing game — German is a first-language market that will notice MT. Budget for a **native German
  translator/reviewer** pass. This is a cost/time item, not a code item.
- **ASC-side:** German App Store listing (name/subtitle/description/keywords/screenshots) + German
  Game Center achievement localizations — separate from the binary, done in ASC.
- **Layout risk:** German words run ~30% longer than English. The tab bar, control-bar buttons
  (already `minimumScaleFactor(0.7)`), and stat chips need a German-length pass on device — some will
  overflow. Real QA time.

**Total, honestly:** a **multi-day engineering effort + a paid human-translation pass + a device QA
pass**, not a quick win. But framed as market entry (above), the ROI question is "does DACH premium
conversion justify a few days of eng + one paid translation pass" — for a market that size, plausibly
yes, largely independent of the current user count.

## Recommended sequence

The acquisition framing changes what's a BLOCKER vs a GATE:
1. **INFRA CAN START ANY TIME** — the String Catalog migration + the framework-free Sim shim are NOT
   a shippable localization diff on their own (they add the plumbing, strings stay English until a
   `de` column is filled). So this is pure de-risking work with no 4.3(a) exposure; do it whenever.
   It's reusable for es/fr later (FC already localizes), so it compounds across the series.
2. **Commission the NATIVE German translation** when you commit to the market-entry bet — this is the
   real spend and the real timeline driver. Never MT (a first-language market notices; bad German
   converts WORSE than clean English).
3. **SHIP GATE (timing, not merit):** do NOT release the German-enabled build STANDALONE during the
   4.3(a) cascade — FC's localization-only 1.3 was rejected for exactly that. Bundle the `de` turn-on
   WITH a content/gameplay update, or ship after the account-wide cascade clears. This gate is about
   Apple's current reflex, not about whether localization is worth doing.
4. Device QA for German string lengths (~30% longer).
5. German ASC listing + Game Center achievement localizations.

Sample-size note (for PRIORITIZATION only, not veto): still worth pulling the absolute German user
count from TD to sequence this against other work — but per the acquisition framing above, a low
count is expected pre-localization and does not kill the bet.

## Family note (VERIFIED 2026-08-28)

FC Architect already shipped fr/it/es localization (its 1.3 — the one 4.3(a)-rejected, now appealed),
and its infra is the template to copy:
- **FC uses a String Catalog:** `FC Architect/FCArchitect/FCArchitect/Resources/Localizable.xcstrings`
  — the exact `.xcstrings` approach recommended above. Copy FC's structure; don't invent AA's.
- **FC does NOT have German yet** (its catalog has fr/it/es, no `de`). So **AA localizing German would
  LEAD the family on that language** — and the infra + any German translator AA sources is then
  reusable by FC and the other siblings. Coordinate: German is a family-wide win, not AA-only.
- **AA's unique wrinkle is confirmed:** FC's engine strings live in `Services/` (MatchEngine,
  MatchSimulator) — NOT a framework-free `Sim/` dir compiled by a plain-`swiftc` harness the way AA's
  is. So FC likely did NOT face AA's Sim-layer-string problem, and AA can't just copy FC's engine
  approach for that part — the framework-free shim (option 1 above) is AA-specific. Everything ELSE
  (view-layer catalog, ASC listing, translation workflow) copies from FC directly.

**Bottom line:** the view-layer + ASC work is a well-trodden family path (copy FC). The Sim-layer
strings are AA's one novel problem, solvable with a small framework-free shim. The real cost remains
the human German translation pass + device QA — and the timing constraint (not standalone during the
4.3(a) cascade).
