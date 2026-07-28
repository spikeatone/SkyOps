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
- **Fixed `--ar 16:9`**, and **no baked-in text** — the card overlays the
  city/country itself, so the art stays reusable.
- One image per archetype → drop into `Resources/AirportPhotos/airport_<archetype>.jpg`
  (files under `Resources/` flatten to the bundle root, like the fonts/illustrations).
- **Optional later:** per-airport marquee overrides (`airport_<CODE>.jpg`) for
  famous skylines, checked before the archetype fallback.

## Card layout

Hero band (~138 pt, full-bleed, `scaledToFill` + `clipped`) at the **top** of
`AirportInfoCard`; the existing header/stats sit below. Top corners come from the
card's own `clipShape` (corner radius is a tweakable — VA's is rounder).

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
