# AIRPORT PHOTOS — spec (1.2 feature)

Give each airport card a **hero image** (Vineyard-Architect style) so tapping an
airport surfaces a sense of place. See VA's site card for the target look: photo
band on top, location line + stats below.

## Approach — archetypes, not 380 unique photos

380+ airports × a unique licensed photo = a licensing headache **and** a ~95 MB
bundle. Instead, each airport maps to one of a **curated set of region/terrain
archetypes**. Art is **Midjourney-generated in the VA style** (series
consistency), bundled, offline. A curated set (~8 now → target ~50) is ~10–15 MB.

## Archetype set (v1 = 8; expand toward ~50)

`metro · tropicalIsland · snowyNorth · desert · alpine · coastal · tropical ·
plains`. Expand later (split island into Caribbean/Pacific, add jungle, savanna,
fjord, and a handful of distinct **marquee-city skylines**).

## Mapping — self-contained, no sim (`AirportPhoto.archetype(for:)`)

First-pass heuristic from data the app already has: leisure flag → island; big
hub (`annualPassengers ≥ 30M`) → metro; `|lat| ≥ 54` → snowyNorth; else carrier
`region` + latitude. Refine per-airport freely — it's a pure function of `Airport`.

## Midjourney generation

- **Lock a style** — reuse VA's `--sref` (or a fixed prompt suffix) so all AA
  images share that warm, painterly-photo look.
- **`--ar 16:9`** (or up to ~2:1). The hero band runs ~2.5:1 (iPhone / iPad-landscape)
  → ~3.6:1 (iPad portrait), so a 16:9 source crops top/bottom; 2:1 wastes a little
  less. **Keep the subject in the center ~50% vertically** — the tightest crop is
  iPad-portrait at ~3.6:1.
- **Downscale each export to ~1500 px wide** before bundling — the hero never
  displays wider than ~1200 px, so a full MJ export is mostly wasted bytes. THIS,
  not the aspect ratio, is the real file-size lever.
- **No baked-in text** — the card overlays the city/country itself, so the art stays
  reusable.
- One image per archetype → drop into `Resources/AirportPhotos/airport_<archetype>.jpg`
  (files under `Resources/` flatten to the bundle root, like the fonts/illustrations).
- **Marquee overrides** (`airport_<CODE>.jpg`, checked before the archetype fallback)
  depict the **city / skyline, NOT the airport itself** — MJ can't render famous
  airfields convincingly and viewers who know them notice (a gorgeous city reads as
  "evocative"; a wrong airport reads as "wrong"). Same principle as the archetypes: a
  sense of place, never a building.
- **Marquee overrides ONLY for GLOBALLY-ultra-iconic landmarks MJ renders faithfully**
  (Eiffel Tower, Sydney Opera House, Big Ben / Tower Bridge, the Hollywood Sign, Statue
  of Liberty, Golden Gate…). **REGIONALLY-iconic landmarks come out WRONG** — MJ invents
  a plausible-but-inaccurate version and locals/visitors catch it instantly (Red Rocks
  for Denver was flat-out wrong per a Colorado native — the real tilted monoliths and
  steep straight seating are nothing like MJ's guess). Rule of thumb: the more
  recognizable a place is to your players, the more a wrong render hurts — so **if MJ
  won't nail it, DON'T override; fall back to the generic archetype** (generic on
  purpose, so it can't be "wrong"). For a place with a strong regional identity but no
  MJ-faithful landmark (e.g. Denver), an evocative *landscape* works instead — the
  snow-capped Front Range behind the distant city — accurate in feel, with no fragile
  specific structure to get wrong.
- **Chosen marquee landmarks** (all globally-iconic, MJ-faithful, no fragile text):
  LHR → Big Ben / Tower Bridge · CDG → Eiffel Tower · SYD → Opera House · SFO →
  Golden Gate Bridge · SEA → Space Needle · **JFK / LGA / EWR → Statue of Liberty**
  (one shared `airport_NYC.jpg` via `AirportPhoto.sharedOverride`) · LAX → Griffith
  Observatory. **Dropped:** the Hollywood Sign for LAX — MJ misspells "HOLLYWOOD" and
  misplaces the sign-to-city geography. **DEN** has no MJ-faithful landmark → use the
  archetype, or the Front-Range-behind-the-city landscape.

## Card layout

Hero band at the **top** of `AirportInfoCard` (`AirportHero`, `scaledToFill` +
`clipped`); header/stats below. **Height is RESPONSIVE to card width**
(`width / 2.5`, clamped 132–220 pt) so the band holds ~2.5:1 on iPhone /
iPad-landscape and grows to a proper ~3.6:1 banner on the wide iPad-portrait card —
a fixed height read as a thin ~8:1 strip there. Top corners come from the card's own
`clipShape` (radius is a tweakable — VA's is rounder).

## Placeholder (ships now, for design approval)

`AirportPhoto.image(for:)` returns `nil` when no bundled art exists → a **styled
placeholder** renders (archetype-tinted sky gradient + sun + horizon/skyline
silhouette + a `Placeholder · <archetype>` label). This lets the LAYOUT be
approved before any art exists. **Drop the MJ jpgs into `Resources/AirportPhotos/`
and they replace the placeholders automatically** — no code change.

The `Placeholder · <archetype>` label is **`#if DEBUG` only** (a dev aid, never
ships). The gradient itself remains as a graceful fallback for any archetype that
lacks art — so a release build is safe even mid-way through generating the set.

## Files

- `AirportPhoto.swift` — archetype enum + mapping + image loader + `AirportHero`
  view + the placeholder.
- `AirportInfoCard.swift` — `AirportHero` added at the top of the card.
