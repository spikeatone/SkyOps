# Personalized Livery — Phase 1 (prototype spec)

> ## ▶▶ NEXT SESSION STARTS HERE — TAIL EMBLEM PLACEMENT (14 Aug 2026, `livery-prototype`)
>
> **The tail-emblem-on-fin placement is AUTO-COMPUTED and CLOSE but not perfect.**
> The designer wants it finished. It is NOT hand-tuned per plane anymore — do NOT go
> back to that. It's a repeatable script:
>
> **`aa-livery/fin_place.py`** — for every `Resources/Illustrations/<TYPE>.png` it
> detects the FIN silhouette, finds the **largest square that fits fully INSIDE the fin
> outline** (so the emblem can NEVER exceed the fin edge — the designer's explicit
> requirement: "outline the edge of each tail, the logo never exceeds it, sits
> comfortably within it"), detects **T-tails** (biases the emblem LOWER, off the
> horizontal stab), and gives big tall fins a height-based minimum size. It writes
> `tailCX/tailCY/tailScale` into `AircraftLivery.swift` (TITLE values are separately
> hand-tuned — leave them). Tunables + full notes are in the script's docstring.
>
> **WORKFLOW to iterate:**
> 1. Edit a tunable (or add a per-type override) in `aa-livery/fin_place.py`.
> 2. `python3 aa-livery/fin_place.py` (rewrites the Swift values) — or `--report` to
>    just print detected values + which types classified as `[T-TAIL]`.
> 3. **CLEAN build** (`xcodebuild … clean build` — plain build caches stale art/values;
>    this bit us repeatedly) → **uninstall + install** → launch `-liveryGallery`
>    (shows ALL 10 emblems on one aircraft; `-galleryType <ID>` to switch; there's also
>    a Python compositor pattern in this session's git history that matches the SwiftUI
>    render for fast off-sim previews).
>
> **KNOWN REMAINING IMPERFECTIONS (what "not quite perfect" means):**
> - **T-tail detector misses some.** The width-ratio heuristic correctly caught
>   CRJ900/ERJ145/DH8B but MISSED **CRJ1000, ERJ135, ERJ140** (they came out with a
>   high `cy` = placed too high, not lowered). Run `--report` and check the `[T-TAIL]`
>   flags — fix the heuristic or add those ids to a T-tail set.
> - **AT46 (ATR 42)** — stubby T-tail; round emblems (globe) kiss the horizontal stab.
>   Wants a smaller emblem and/or lower centre for this one type.
> - **A couple of big jets** were reading small — the height-based min size helped
>   (A380/777/747 now bigger); eyeball whether they're now right.
> - Likely cleanest endgame: keep the auto pass for the ~30 that are good, add a small
>   **per-type override table** (layered on top) for the 3-4 stubborn T-tails/turboprops.
>   Don't chase global constants into breaking the good ones.
>
> **Everything else about the livery feature is DONE** (creation flow, fonts, palettes,
> emblem normalisation, persistence, Fleet-detail painting, screen layout). Both Debug
> + Release build clean. `main` untouched; all work on `livery-prototype`.
>
> ---

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
> - **Emblems** — the designer's 10 SVGs (`art-source/tail-logos/`) rasterised + **normalised
>   to a CONSISTENT ON-FIN HEIGHT** (~62% of the square), bundled as
>   `Resources/TailArt/tailart1…10.png`. This is the KEY fix: the emblems have wildly
>   different aspects (a wing 1.34 vs a thin swoosh 3.55 vs a tall globe ~0.8), so merely
>   centring them in equal squares made tall ones render huge and wide ones tiny/overhanging
>   at one `tailScale`. Now each PNG's ARTWORK fills the same height fraction (width clamped
>   to ≤90% so the thin ribbons don't overflow sideways), so a SINGLE `tailScale` gives every
>   emblem the same visual footprint on the fin — the per-aircraft tail placements (all tuned
>   against the wing) apply to all 10 with no per-emblem fiddling. To re-normalise after new
>   emblem art: re-run the height-normalise pass (this session's git history) targeting ~0.62
>   artwork-height, then verify on the `-liveryGallery` fleet.
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
> **PER-TYPE PLACEMENT — DONE + DESIGNER-DIALED (all 35 illustrated types).**
> `LiveryPlacement.forType` has a case per type. First cut was MEASURED from each
> illustration (a Python pass detects the dashed cabin-window row → `titleCY`, the
> forward cabin → `titleCX`, the fin body → the emblem). Then the DESIGNER hand-dialed
> EVERY type on the iPhone-sim gallery, screenshot by screenshot (title size/position +
> emblem size/position, per airframe) — almost all cases are now `// tuned`. Key
> patterns that emerged: titles sit on the window line so the multiply blend punches the
> windows through the letters; emblems are sized to the fin and seated on the fin BODY
> (the auto-measure put them too small + too high/aft on many types — especially the
> widebodies, CRJ T-tails, ERJ T-tails, and turboprops, which all got much larger
> emblems pulled down/forward). New types fall through to a narrowbody default. **Verified
> in the REAL SwiftUI renderer** via the `-liveryGallery` DEBUG harness (a keeper, like
> `-liveryPreview`). To re-tune after an art/type change: launch `-liveryGallery` and
> adjust the one case (or re-run the measure script in this session's git history for a
> new type's starting values).
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
