# AIRPORT PHOTOS — spec (1.2 feature) — **BUILT, 54 images shipped**

> **STATUS (2026-08-30): 54 images in the app** — 9 archetypes + **45** per-airport
> overrides. Every airport in the game resolves to real art (per-code →
> shared-city → archetype), so the styled placeholder is only a safety net,
> never seen in normal play.
>
> - **Archetypes (9):** metro · tropicalIsland · snowyNorth · desert · **savanna**
>   · alpine · coastal · tropical · plains.
> - **Marquee cities — original 25 (2026-08-03):** LHR CDG SYD SFO SEA LAX DEN +
>   TYO(HND,NRT) CHI(ORD,MDW) PEK DXB SIN HKG IST FCO BCN AMS PVG BKK YYZ LAS DOH
>   MIA NYC(JFK,LGA,EWR) + **BZN** (Bozeman — designer's hometown).
> - **Marquee cities — +20 added 2026-08-30 (this batch):** OAK MEX GIG CPT KEF
>   (first pass — OAK was the "beach town for Oakland" miss), then the 15 busiest
>   airports that were all sharing the generic `metro` skyline: ATL DFW DEL CAN
>   MAD FRA MCO ICN CGK CLT BOM SZX PHX KUL IAH. **ATL (world's busiest, 105M
>   pax) was the biggest miss.** All MJ `--v 8`, 1456×816 JPG. Prompts + the
>   audit that ranked them are in this session's scratchpad sheets.
> - **Shared-city aliases** (`AirportPhoto.sharedOverride`): NYC→JFK/LGA/EWR,
>   TYO→HND/NRT, CHI→ORD/MDW. None of the +20 are shared — each is a standalone
>   `airport_<CODE>.jpg`.
> - **HERO FRAMING FIX (2026-08-30, `AirportHero`):** `scaledToFill` was
>   CENTER-cropping the 16:9 source into the shorter 2.5:1 band, lopping the SKY
>   (and tower-tops) off skyline heroes — worst on the wide iPad card, where
>   `width/2.5` clamped the band even shorter. Fixed by (a) cropping toward the
>   TOP (`biasFromTop = 0.38`, the visible window lands on the upper ~⅜ so sky +
>   subject stay, excess taken from the foreground) and (b) raising `maxHeight`
>   220→300 so the iPad band isn't clamped so short. ONE change, fixes all 54
>   heroes, no regen. Verified on device across a skyline (ATL) and two landscapes
>   (MEX volcano, KEF town+mountains) — no regressions. When re-prompting future
>   heroes, still keep the subject in the center-to-upper band (the crop favors
>   the top now, not dead center).
> - **Next if extended:** the audit (`aa-1.1.x/archetype-audit`, or the fresh
>   pax-ranked variant in scratchpad) lists the remaining high-traffic airports
>   on generic art, busiest first — the priority list for the next batch. All
>   drop-in (add the JPG; only a new shared alias needs code).
> - **⚠️ WORKING FOLDER GOTCHA:** the designer's source library is
>   `~/Architect Universe/Airline Architect/Resources/Airport Photos` (WITH a
>   space, human-named `San Francisco.jpg` + both .jpg/.png). That is NOT the
>   bundle — the app only loads from
>   `SkyOps/AirlineArchitect/AirlineArchitect/Resources/AirportPhotos/` (no space,
>   code-named `airport_SFO.jpg`). New heroes must be COPIED into the app folder
>   (renamed to `airport_<CODE>.jpg`) or they never load. Dropping them only in
>   the working folder does nothing.

Give each airport card a **hero image** (Vineyard-Architect style) so tapping an
airport surfaces a sense of place. See VA's site card for the target look: photo
band on top, location line + stats below.

## Approach — archetypes, not 380 unique photos

380+ airports × a unique licensed photo = a licensing headache **and** a ~95 MB
bundle. Instead, each airport maps to one of a **curated set of region/terrain
archetypes**. Art is **Midjourney-generated in the VA style** (series
consistency), bundled, offline. A curated set (~8 now → target ~50) is ~10–15 MB.

## Archetype set (v1 = 9; expand toward ~50)

`metro · tropicalIsland · snowyNorth · desert · savanna · alpine · coastal ·
tropical · plains`. `savanna` split off equatorial-Africa/Sahel (abs lat ≤ 15° in
the africa/middleEast region) so the golden-grassland belt no longer gets a Sahara
scene. Expand later (split island into Caribbean/Pacific, add jungle, fjord, and a
handful of distinct **marquee-city skylines**).

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
