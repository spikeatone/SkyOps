# German Localization — Scoping Assessment (2026-08-28)

## ⏳ PROGRESS (branch `de-translation`, NOT merged, NOT ship-ready) — read this first

**~141 of ~370 strings translated + 7 category-2 code gaps fixed, all verified live on device in
German.** Register: **du**. AI-drafted (no native review — designer accepted that risk). Everything is
on the `de-translation` branch, three commits, pushed. English is unchanged throughout (the catalog
only adds a `de` column; harness stays 13/13). NOT ship-ready — partial German is worse than none, so
it stays on the branch until it's finished + timing clears the 4.3(a) cascade.

**Assets created:**
- `Resources/Localizable.xcstrings` — the view-layer String Catalog (141 keys, all with a `de` value).
- `Sim/Localization.swift` — the framework-free `L()` shim (its `de` table is still EMPTY — Sim strings
  are NOT translated yet).
- `aa-1.1.x/de-glossary.md` — the terminology glossary (du; Route/Slot/Gate/Crew kept as German
  loanwords; Drehkreuz = hub; Lounge = club; etc.). **Use this for every remaining string — consistency
  is the whole game.**

**DONE (verified in German on the sim):** tab bar (Netzwerk/Flotte/Crews/Betrieb/Finanzen) · Network
control bar (Erwerben/Route eröffnen/Routen/Crew einstellen) · Finance tab (FINANZEN, NETTOVERMÖGEN,
GRATIS-VERSION, all ledger/card labels, REPORTS/FUNDING + period selectors) · Fleet/Marketplace (FLOTTE,
Meine Flotte, Marktplatz, status boxes, aircraft labels, OWNED/LEASED) · Save/Quit (shared, all 5 tabs)
· core Naming + Paywall strings.

**Category-2 code gaps FIXED so far** (the pattern — see the CRITICAL FINDING section below): tab bar
(`SkyTabIcons`/`SkySidebar`), `NetworkView.barButton`, `FinanceView` sectionTitle/ledgerLine/ledgerRow/
miniStat/leverSection + the section/period `Text(rawValue)` selectors, `FleetView` segButton/statusBox,
`SaveQuitBar.pill`. **Every custom label helper with a `String` title/label param is a suspect** — audit
each and change the DISPLAY param to `LocalizedStringKey` (keep VALUE params `String` — they carry data).

**REMAINING (~230 strings) — the mechanical long tail for the next pass:**
1. **Whole screens not touched:** Crews, Ops, Network panels (Acquire/Routes/Hire/FuelHedge/Hubs),
   aircraft detail (`FleetDetailView`), airport card, alerts/decision cards, session briefing, tutorial.
2. **Interpolated strings** (deliberately deferred — need `%@`/`%lld` format-string care + German word
   order): "N cycles / X%", "$X since launch", "N/6 aircraft · M/5 routes", demand/event lines, offer
   pitches, milestone/celebration copy. ~75 in the view layer.
3. **Category-2 tail:** Fleet category filters (Turbo/RJ/Narrow/Wide — likely `BodyType`-derived),
   status chips (FLYING/IDLE/GROUNDED), Show/Sort dropdown labels, and any other data-driven labels.
4. **Flavor text:** ~50 `Airport.destinationFlavor` + 35 `AircraftType.flavor` (marketing prose).
5. **The Sim `L()` German table:** ~124 Sim-layer strings (Ops log, decision copy) — convert each
   `logOps(...)`/decision string to `L("… %@", args)` (ONE reference example done in `establishHub`)
   AND fill `simLocalizationTables["de"]`.
6. **ASC-side (separate from the binary):** German App Store listing (name/subtitle/description/
   keywords/screenshots) + German Game Center achievement localizations.

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
