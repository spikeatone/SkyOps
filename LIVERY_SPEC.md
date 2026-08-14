# Personalized Livery — Phase 1 (prototype spec)

> **▶ STATUS (this branch `livery-prototype`, 14 Aug 2026): THE CREATION FLOW IS
> BUILT.** Naming → **livery design screen** → Launch. Both prior "next session"
> items are done: emblems normalised (see below) AND the full picker + persistence +
> Fleet-detail wiring shipped. Debug + Release both build clean; driven live on the
> iPhone 17 Pro sim (both themes, owned-aircraft livery confirmed). What's built:
>
> - **`LiveryDesignView.swift`** — the one-screen creator (designer's spec): a live
>   **737 MAX 9** preview + four inputs: **fuselage text** (separate from the airline
>   name — capped at `Livery.maxTextLength` = 16, seeded from the name), **title font**
>   (5 bundled OFL faces), **color palette** (the 10 designer packs), **tail emblem**
>   (10 normalised emblems). "Launch Airline" commits + starts the game. Reached in the
>   cold-launch flow via `ContentView.firstLaunchFlow` (naming sets the name → livery
>   step → launch). DEBUG harness: `-liveryPreview` opens it directly.
> - **`Livery.swift`** — the model + three catalogs: `LiveryFont.all` (5 faces,
>   PostScript names + per-face `sizeAdjust`), `LiveryPalette.all` (the 10 packs —
>   Atlantic/Cardinal/Pacific/Meridian/Evergreen/Copper/Azure/Tropic/Burgundy/Velocity;
>   colour 1 = titles, colour 2 = tail), `TailArt` (10 tintable emblems). To retune
>   palettes edit the hex literals here — nothing else references the colours.
> - **Fonts** — 5 static OFL TTFs in `Resources/Fonts/` (ArchivoBlack, BebasNeue,
>   Poppins-SemiBold, Righteous, DMSerifDisplay) + `OFL-LiveryFonts.txt`, registered in
>   Info.plist `UIAppFonts`. Static instances on purpose (variable-font weight is fragile).
> - **Emblems** — the designer's 10 SVGs (`art-source/tail-logos/`) rasterised, **trimmed
>   to artwork bounds + centred in a square** (the normalisation the old spec asked for),
>   bundled as `Resources/TailArt/tailart1…10.png`. One fin placement now centres any of
>   them.
> - **Persistence** — `liveryFontIndex` / `liveryPaletteIndex` / `liveryTailArtIndex` /
>   `liveryText` on `Simulation` + `GameSnapshot` (each `decodeSafe`, nil/legacy-safe,
>   like `playerTailCode`). `sim.liveryTitle` = the text if set, else the airline name.
> - **Painted where** — owned-aircraft illustration in **Fleet detail** (`sim.liveryTitle`
>   + `sim.livery`). The Marketplace/Acquire CATALOG stays plain white (a livery on a
>   plane you don't own yet reads wrong) — deliberate; revisit if the designer wants a
>   "preview in your colours" there.
> - **MAX 9 name placement** — `titleCY = 0.665` is the MEASURED window-row centre of
>   `MAX9.png` (the multiply blend punches the windows through the letters — the United
>   look), `titleCX = 0.33` pushed forward toward the nose (designer call — reads better,
>   leaves long names room). Don't nudge titleCY off the window row.
>
> **PER-TYPE PLACEMENT — DONE (all 35 illustrated types).** `LiveryPlacement.forType`
> now has a case per type, MEASURED from each illustration (a Python pass detects the
> dashed cabin-window row → `titleCY`, the forward cabin → `titleCX`, the fin body →
> the emblem). The turboprops + small commuters (AT46 / B1900 / D328 / DH8B / ERJ135 /
> ERJ140) and MAX9 are HAND-TUNED (marked `// tuned`) — their titles push forward toward
> the nose so they clear the wing/prop, and sit on the real (higher) window row. New
> types fall through to a narrowbody default. **Verified in the REAL SwiftUI renderer**
> via the `-liveryGallery` DEBUG harness (a keeper, like `-liveryPreview`): every type
> walked through on the iPhone 17 Pro sim, all clean. To re-tune after an art/type
> change: run the measure script (in git history of this session) or launch
> `-liveryGallery` and adjust the one case.
>
> **Still Phase-2 / open (designer calls):** whether the Marketplace should preview the
> livery (today only owned aircraft in Fleet detail wear it); a livery-edit screen
> post-launch (today it's set once at creation). See "To finish" below.
>
> ---
> _Original prototype spec preserved below for reference._


Surprise-&-delight: the player's **airline name is painted on the fuselage** and a
**tail emblem** sits on the fin, both driven by a **2-colour palette** they pick.
Prototyped and designer-approved on the A320 (the reference) + the Dash-8. This
branch (`livery-prototype`) is the proof of concept — NOT shipped. Build it out as
its own version AFTER 1.2 is live so `main` stays clean.

## What's built (this branch)
- **`AircraftLivery.swift`** — `AircraftLiveryImage(typeID:name:colors:tailArt:)`
  overlays on the side-view illustration (`AircraftArt.uiImage`). One reusable view;
  every Fleet/Acquire surface already routes through `AircraftArt`, so wiring it in
  is one swap.
- **`AircraftArt.uiImage(for:)`** — added so the overlay can read the image aspect.
- **Tail emblems** — the 5 designer SVGs (`Resources/Tail logos/SVG`) rasterised to
  bundled template PNGs (`Resources/TailArt/tailart1–5.png`) via `rsvg-convert -w 512
  -h 512`. Rendered `.renderingMode(.template).foregroundStyle(tint)` → recolourable.
- **Preview harness** — `LiveryPrototypeView`, reached via the `-liveryPreview`
  launch arg (`ContentView`, `#if DEBUG`). **Strip this + the `showLiveryPreview`
  wiring when productionising.**

## The two techniques that make it look real
1. **Titles on the WINDOW LINE with `.blendMode(.multiply)`** — placed at the
   fuselage vertical centre (not above the windows), the multiply blend makes the
   illustration's own dark windows punch through the letters as cutouts (the United
   look). **No per-window masking needed** — this was the key insight; don't go back
   to placing titles above the windows (they read as floating).
2. **Tail emblem tinted + placed on the fin** — one solid colour tint; positioned
   per type.

## Placement — `LiveryPlacement.forType(id)`
Fractional coords (0…1) of the fitted image rect: title `cx/cy/w/scale`, tail
`cx/cy/scale`. **A320 family is the LOCKED reference**; Dash-8 tuned too; everything
else uses a heuristic default. Reference values live in the switch. Notes from the
tuning: jet titles run forward over the doors; the Dash-8 title is smaller, lower,
and forward over its door; tail emblems sit centred on the fin body (down + forward
of the tip, following the swept leading edge).

## To finish Phase 1
1. **Per-type placement for the other ~33 types** — replicate + sim-tune the A320
   template (the mechanical bulk).
2. **NORMALISE THE EMBLEM ART FIRST** — trim each rasterised PNG to its own artwork
   bounds (+ centre) so all 5 emblems drop in centred at one placement. Without this,
   a shared placement can't perfectly centre differently-shaped emblems and you end up
   nudging in circles (learned the hard way). This is the real fix; do it before the
   per-type pass.
3. **Picker on the naming screen** — 2 palette colours (complementary pairs) + choose
   an emblem. `AirlineNamingView` already collects name + tail code + region.
4. **Persistence** — add `liveryPrimary` / `liverySecondary` (hex) + `tailEmblem` (Int)
   to `GameSnapshot` (each one `decodeSafe`, nil-safe), like `playerTailCode`.
5. **Wire `AircraftLiveryImage` into Fleet + Acquire**; strip the `-liveryPreview` harness.
6. **Bundle the tail PNGs as real assets** (they already bundle by flattened name).

## Open product decisions (designer)
- Which emblems are keepers (1–5).
- Tail tint: primary or the accent/secondary colour (prototype uses primary).
- Map icons stay phase-coloured (livery is side-view illustrations only — don't tint
  the top-down map icons or it breaks the flight-phase colour coding).
