# German Localization — Scoping Assessment (2026-08-28)

**Why:** TelemetryDeck "New Users by Preferred Language" shows **German 16%** — the #2 language
after English (76%), and 10× Spanish (1.3%). Region chart barely shows Germany, so these are
German-language-device users spread across DE/AT/CH. A 16% cohort seeing an English-only app is real
friction. ⚠️ **Sample-size caveat:** verify the absolute N behind that 16% before committing — a
0.16% slice = 1 user, so 16% could be a few dozen or a handful. This doc scopes the WORK; it does not
assert the mandate.

**⚠️ TIMING (do NOT ship standalone during the 4.3(a) cascade):** FC Architect 1.3 was rejected 4.3(a)
for a **localization-only** update. Apple's spam reflex flags a pure-localization diff. So German
localization must ride WITH a real gameplay/content change, or wait until the account-wide cascade
cools (see `PostmarkOps/APP_REVIEW_NOTES.md`). This is scoping-ahead, not a ship order.

## Current state

- **No localization infrastructure at all** — English-only, hardcoded string literals. No `.lproj`,
  no `Localizable.strings`, no `.xcstrings` catalog.
- Deployment target iOS 18 → **String Catalogs (`.xcstrings`) are available** and are the right modern
  approach (Xcode extracts, one file, per-language columns, handles plurals/interpolation ordering).

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
pass**, not a quick win. Worth it if the 16% is real N; not worth it on a handful of users.

## Recommended sequence (when the time comes)

1. **Verify the sample** — get absolute German user count from TD, not just the %.
2. **Wait for the 4.3(a) cascade to cool** (or bundle with a content update).
3. Build the infra (String Catalog + Sim shim) — that's reusable for Spanish/French later (the family
   already localizes: FC did fr/it/es), so this investment compounds across the series.
4. Get a **native German** translation pass — don't ship MT.
5. Device QA for German string lengths.
6. German ASC listing + Game Center localizations.

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
