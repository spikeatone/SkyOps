# Personalized Livery — Phase 1 (prototype spec)

> **▶ NEXT SESSION STARTS HERE (designer, this branch `livery-prototype`):**
> **(1) Normalize the tail emblem images** — trim each of the 5 rasterised PNGs to its
> own artwork bounds + centre, so all emblems drop in centred at one placement (ends
> the per-emblem nudging; see "To finish Phase 1" §2). **(2) Then build the livery
> creation flow in the app** — the 2-colour + emblem picker on the naming screen,
> persistence, and wiring `AircraftLiveryImage` into the real Fleet/Acquire views.
> Work on THIS branch; keep `main` clean until 1.2 is live.


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
