# Personalized Livery — Phase 1 (prototype spec)

> ## ▶▶ CURRENT STATE (15 Aug 2026, `livery-prototype`) — PAINTED TAIL, FEATURE COMPLETE
>
> The livery feature is **built and looks like a real airline**. All pushed to
> `origin/livery-prototype`. Debug + Release both build clean.
>
> **▶ SHIPS AS 1.3, AFTER 1.2.1.** Release order (designer, 17 Aug): 1.2 (the monetization
> pivot, WAITING_FOR_REVIEW) → 1.2.1 (the airport-offer fix, on `main` build 42, awaiting
> 1.2's approval) → **1.3 = this branch**. `main` is deliberately clean of livery code;
> `main` has been MERGED INTO this branch (17 Aug) so it carries 1.2.1 and current docs,
> and the merge back is verified conflict-free.
>
> **ONE GATE LEFT before cutting 1.3: walk the full first-run flow (naming → livery →
> launch) on a REAL DEVICE.** It has never been done end-to-end — sim text entry keeps
> backgrounding the app. Everything else is verified: fins on all 35 types, the
> Fleet-detail render, repaint (47/47 headless + driven), the existing-player
> free-first-choice path + one-time prompt (4/4 + driven), both themes.
>
> ### The livery model (as shipped on this branch)
> A player picks a **font**, a **2-colour palette**, a **tail emblem**, and the
> **fuselage text**. On every side-view illustration:
> - **PAINTED TAIL** — the whole fin is filled with the palette's **secondary** colour
>   and the emblem is drawn **WHITE**, both **CLIPPED to the fin silhouette** (United /
>   Delta / Lufthansa look). *This replaced the old "small emblem on a white metal fin"
>   and SOLVED the emblem-fit problem for good:* an oversized emblem simply clips at the
>   fin edge, which reads as intentional. **Overflow is impossible by construction — do
>   NOT reintroduce per-plane emblem-size/position nudging to "make it fit".**
> - **TITLE** — the fuselage name in the palette's **primary** colour, on the window
>   line, `.blendMode(.multiply)` so the illustration's own windows punch through the
>   letters (the painted-on look). Two-tone livery: both palette colours used.
>
> ### How the painted tail is implemented (don't relearn this the hard way)
> - **Fin masks**: `Resources/FinMasks/<TYPE>_fin.png`, one per illustration, **RGBA
>   with alpha = the fin shape** (white RGB). Generated from each illustration by the
>   fin-detection pass. ⚠️ **They MUST be RGBA** — SwiftUI `.mask` clips by ALPHA; an
>   `L`-mode (grayscale, no-alpha) mask loads fully opaque and fills the whole card
>   (this bug cost real time). `FinMask.uiImage(for:)` in Livery.swift loads them.
> - **Render** (`AircraftLiveryImage`): `ZStack { secondaryFill; whiteEmblem }.mask(finImage)`
>   over the illustration; title drawn separately. Mask + illustration are the same
>   pixel size and both `scaledToFit` in the same frame, so they align.
> - **Emblem placement** (`LiveryPlacement.forType`): `tailCX/tailCY/tailScale` are
>   LARGE and fin-bbox-centred (fills the tail; clipping at the edge is the point).
>   TITLE values in the same table are separately hand-tuned — leave them.
> - **Per-emblem re-centre**: `TailArt.nudge(_ n:)` in Livery.swift — a few emblems
>   (3 eagle / 4 shield / 5 swoosh / 7 heart) carry their mass forward, so a small +dx
>   pushes them back to sit centred. Add cases here if a new emblem reads off-centre.
> - **`aa-livery/fin_place.py`** — the reusable script that detects each fin and emits
>   the placement (and documents regenerating the masks). Header note explains the
>   painted-tail model + tunables. Re-run after new/changed aircraft art.
>
> ### Re-customise (existing players can restyle their fleet)
> A **"Livery" button in the FLEET HOME header** opens `LiveryDesignView` in **EDIT
> mode**: pre-filled from the current livery (`initialLivery`/`initialText`), header
> reads "Customise your livery", commit button says **"Save Livery"**, a back chevron
> (`onCancel`) returns without saving. Save applies `sim.setLivery(...)` live to the
> whole fleet and persists immediately. **A pre-livery save opens on the defaults**
> (font0 / palette0 / wing) — so every player, new or existing, can style their fleet.
> The first-launch flow (naming → livery → launch) is unchanged.
>
> ### DEBUG harnesses (all `#if DEBUG`, in ContentView / LiveryDesignView)
> - **`-freshFlow`** — jump straight into the first-launch flow (naming → livery →
>   tutorial → game) on a clean sim, **bypassing the splash AND the load menu**,
>   regardless of saved games. The way to walk the whole first-run flow.
> - **`-liveryPreview`** — open the livery design screen directly (fresh-create).
> - **`-liveryGallery`** — EMBLEM FIT TEST: all 10 emblems on one aircraft, then a
>   fin-shape spread. Args: `-galleryType <ID>`, `-galleryName "AIR TINA"`,
>   `-galleryPalette <0-9>`. (Its background is fixed light-grey, so it does NOT show
>   the app's dark theme — use `-liveryPreview` for a true dark-theme check.)
>
> ### ⚠️ The designer's insets are DYNAMIC now (fixed 15 Aug 2026)
> `LiveryDesignView` had a hardcoded `safeAreaPadding(.top, 58)` — tuned on one iPhone,
> and wrong anywhere the metrics differ. It now reads the device's real top inset:
> `max(24, topSafeInset + 4)`, which yields **58 on the iPhone it was dialled on** (54+4,
> so the tuned look is preserved pixel-for-pixel — verified) and adapts elsewhere
> (no-notch 24, older notch 51, iPad 28). The floor keeps a sane gap if a platform
> reports 0. `topSafeInset` reads the active `UIWindowScene`'s `safeAreaInsets` rather
> than a GeometryReader, so it can't fight the ScrollView's own layout.
>
> ### ⚠️ EDIT MODE pads for the tab bar (fixed 15 Aug 2026)
> `LiveryDesignView` is used in TWO contexts and they need different bottom padding:
> first-launch is FULL-SCREEN (no tab bar, 8pt is right), but EDIT mode is presented
> **over the Fleet tab**, where the custom `SkyTabBar` sits on top of the scroll content
> and was CLIPPING the last emblem row and the commit button. The tab bar is a
> `safeAreaInset` on the ROOT view and this screen is layered above it, so the safe area
> doesn't account for it — hence the explicit `.padding(.bottom, initialLivery == nil ? 8
> : 104)`. If this screen ever gains a third presentation context, check the bottom edge.
>
> ### ⚠️ Build gotcha (bit us repeatedly)
> After changing **bundled art** (fin masks, emblem PNGs, fonts) OR the placement
> values, do a **`xcodebuild … clean build` + `simctl uninstall` + `install`**. A
> plain incremental build/install caches the old art and you'll be looking at a STALE
> binary. You CANNOT judge staleness by file hash — Xcode re-encodes PNGs to Apple's
> CgBI format at build time, so the hash always differs; judge by the build timestamp
> or just clean-build when in doubt.
>
> ### ✅ FULL-FLEET CONTACT SHEET — DONE (15 Aug 2026), and it CHANGED THE PRIORITY
> The compositor is now a committed, reusable script: **`aa-livery/contact_sheet.py`**
> (no longer a throwaway in the transcript). It parses the REAL values straight out of
> the Swift source — the per-type placement table in `AircraftLivery.swift`, the
> palettes and `TailArt.nudge()` in `Livery.swift` — so the sheet can't drift from the
> app; change the app and re-run. Flags: `--emblem/--palette/--font/--name/--types/
> --parts/--width/--rowheight/--out`.
> ```
> python3 aa-livery/contact_sheet.py --parts 2 --width 1400 --rowheight 140
> ```
> **FIDELITY VERIFIED against the real renderer, not assumed** — the same CRJ900 was
> rendered in `-liveryGallery` on the iPhone 17 Pro sim and matches the compositor's row
> (identical fin fill, emblem shape/size, and the same stabilizer bleed). Only known gap:
> title glyph widths differ slightly (CoreText vs Pillow rasterisation); tail geometry is
> exact. So the sheet is a valid stand-in for judging fins without 35 build/launch cycles.
>
> **WHAT THE SHEET SHOWED (and it's worse in scope than the old note assumed):** the ~26
> conventional-tail JETS are clean and consistent — Airbus, 737/MAX, 747/777/787, A380,
> E-Jets all read like a real airline. **The bad masks are NOT just the 4 turboprops:**
> - **T-TAILS BLEED ONTO THE HORIZONTAL STABILIZER** — CRJ900, CRJ1000, ERJ135, ERJ140,
>   ERJ145 paint the cross-arm teal, so the tail reads as a solid teal T instead of a
>   painted fin. Confirmed in the live gallery across ALL 10 emblems (it's the mask, not
>   the emblem). This was only a "eyeball them too" aside before; it's a real defect.
> - **TURBOPROPS ARE A HARD RECTANGULAR BLOCK** — DH8B/D328 (and AT46/B1900 worst of all)
>   show a box with a flat bottom edge slicing across the fin, lower fin left unpainted,
>   paint spilling past the trailing edge. AT46's lands on the stabilizer; B1900's is a
>   detached floating wedge.
>
> So the fix list below is **9 types, not 4**, and the T-tail jets should arguably come
> FIRST — a player is far more likely to fly a CRJ/ERJ than a Dornier.
>
> ### ✅ FLEET REPAINT — BUILT (15 Aug 2026, designer request)
> Changing the livery once you own aircraft is a **repaint**, not a free restyle: the
> Livery button's commit routes through an **itemized quote**. With no aircraft owned
> there's nothing to repaint, so the choice stays free.
> - **Costs are the designer's real-world bands** (`Simulation.repaintCost`): narrowbody
>   **$130k** (a real 737-900ER refresh is ~$131k), widebody **$225k**, jumbo **$400k**;
>   turboprop $35k / RJ $60k sit below the narrowbody floor.
> - **SCHEDULED THROUGH A SHOP QUEUE, not all at once** (`repaintShopSlots` = 2). A real
>   airline cycles its fleet through in ones and twos, so **calendar time scales with
>   FLEET SIZE**: 20 aircraft ≈ **103 days**, not the 18 days of the longest single job.
>   Booked aircraft keep flying and earning until their slot opens (`repaintQueued`);
>   `fillPaintShop()` pulls the LONGEST jobs in first, which is both what minimises the
>   program and what makes `repaintProgramDays` match what the player is shown.
> - **Durations are total HANGAR OCCUPANCY** (`repaintDays`: 7 / 10 / 14 / 18d by size) —
>   occupancy is what costs revenue. Real: narrowbody 3–7d active but 5–10d occupancy;
>   widebody 7–14d / 10–21d. The four real stages (strip 1–3d · prep+prime 1–3d ·
>   paint 1–7d · clear coat+cure 1–3d = 4–16d) corroborate those totals and drive the
>   fleet-card DISPLAY, but are deliberately **not four tracked phases** — the player
>   never schedules around a stage, so splitting it would be detail with no decision.
> - **LOST REVENUE (opportunity cost) is shown per line and totalled.** Each type's line
>   carries, in amber, the revenue those airframes won't earn while grounded; the footer
>   sums **Paint cost + Revenue lost while grounded = True cost**. On a 20-aircraft fleet
>   that's $2.7M paint vs **$9.2M forgone** — the downtime is ~3.4× the bill, which is the
>   whole point. ⚠️ **It is an ESTIMATE, never a charge** — income that never arrives, so
>   it is NOT a cash-invariant term and the button bills only the paint cost. Idle spares
>   and loss-making legs contribute zero (grounding them costs no revenue).
>   - `dailyNet` reads the route's REALISED average (`cumulativeNet / flights`), not the
>     leg in the air: a single leg carries a random fare/load spread, which made the same
>     fleet quote a ~4% different total every time the card opened. The average holds ~1%.
> - **Fleet cards explain themselves**: an aircraft in the shop shows a purple
>   **LIVERY UPDATE** chip with its current stage and days left; a queued one shows
>   "Scheduled for repaint" and keeps flying.
> - **`totalRepaintSpend` is a capital-out term in the cash invariant**; it and each
>   aircraft's `repaintUntilTick` / `repaintStartTick` / `repaintQueued` PERSIST — a paid
>   repaint vanishing on reload is exactly the fuel-hedge bug class. A failed repaint
>   (unaffordable, or one already running) is **INERT**.
> - Card uses **4px corners** (family spec) and names the amber figure three ways — intro
>   sentence, a "REVENUE LOST WHILE GROUNDED" column header, and "Not billed — it's income
>   the fleet won't earn, not a charge."
> - Verified **47/47 headless** (`aa-1.1.x/RepaintVerify.swift` + its stub file — note
>   `Livery.swift` imports SwiftUI, so a headless harness needs the catalog stubs) and
>   driven live on the 20-aircraft fleet.
> - **`-devScenario fleet` / `-devScenario bigfleet`** (new, `#if DEBUG`) seed a livery +
>   a fleet (1 per class / 20 mixed) **with routes opened** — without routes every aircraft
>   is an idle spare and the lost-revenue estimate is correctly zero, with nothing to see.
>
> ### ✅ EXISTING PLAYERS (pre-livery saves) — the first choice is FREE
> A save from before this feature decodes to the DEFAULT indices, so an existing player's
> fleet is already wearing a livery **they never picked** (Atlantic + wing emblem). Left
> alone, the first time they opened the design screen they'd be billed a full repaint for
> the initial choice every new player gets free at naming. Fixed with
> **`Simulation.liveryChosen`** (persisted, `decodeSafe` default **false**):
> - `needsFirstLivery` → the Fleet header button reads **"Add Livery"** with a green dot
>   (an existing player otherwise has no idea the feature exists), the commit button says
>   **"Save Livery"** rather than promising a paid repaint, and the apply is **free**.
> - `setLivery` sets the flag, so every change after that is a normal billed repaint.
>   The flag persists, so the free choice can't be farmed by reloading.
> - **ONE-TIME UPDATE PROMPT** (`NewLiveryPromptView`, `LiveryPromptState.seen`): the
>   first time an existing player CONTINUES a pre-livery save, a card appears over the
>   resumed game — "PAINT YOUR FLEET", naming their airline, stating that the first
>   livery is free and that later changes cost money and ground aircraft. **Later** and
>   **Design it** both dismiss it permanently; Design it jumps to Fleet and opens the
>   editor. Deliberately NOT a gate in front of the load menu — interrupting someone's
>   saved game on update is the thing to avoid. Fired from `loadSlot`, so it can't hit a
>   new airline (which chooses a livery during creation).
>   - The cross-tab intent uses `openLivery: Binding<Bool>` adopted in FleetView's
>     **`.onAppear` AND `.onChange`** — the standing rule, since the tab bar recreates
>     the tab's content view and `.onChange` never fires for a value set beforehand.
>   - ⚠️ **ContentView.body is at the Swift type-checker's budget.** Adding one more
>     `.overlay` + `.animation` pair to it failed with "unable to type-check this
>     expression in reasonable time". The prompt is therefore rendered INSIDE the
>     existing `firstLaunchFlow` overlay, and the cold-launch `.onAppear` body was
>     extracted to `coldLaunch()`. If a future screen needs another root overlay,
>     extract rather than chain.
> - **`-devScenario legacyPlayer`** seeds exactly this state (real fleet on real routes,
>   `liveryChosen` false) and shows the prompt — that state only exists on a save made
>   before the feature, so it isn't otherwise reachable by hand.
>
> ### ✅ FLEET-DETAIL LIVERY CHECK — DONE (one of the two 1.3 gates)
> The livery was verified on the REAL Fleet detail screen (not just the `-liveryGallery`
> harness), on both a **turboprop (B1900)** and a **widebody (787-9)**: painted tail,
> emblem, and fuselage title all render correctly against the real screen chrome.
> **Remaining 1.3 gate: the first-run flow on a REAL DEVICE** (sim text entry keeps
> backgrounding the app).
>
> ### Cash display — `cashLabel` now switches to BILLIONS past $1B
> "$1136.0M" stopped reading as money; it's `$1.136B` now (3 decimals ≈ $1M precision,
> still finer than the aircraft prices it gets compared against). The Finance ledger
> already used compact B — this aligns the always-visible header with it, which the
> spec previously flagged as a known divergence to fix "if it ever bugs someone."
>
> ### Open / possible next
> - **✅ T-TAIL STABILIZER BLEED — FIXED (15 Aug 2026). CRJ900 · CRJ1000 · ERJ135 ·
>   ERJ140 · ERJ145 now paint the FIN ONLY**; the horizontal stabilizer stays white, so
>   the tail reads as a painted fin with the stab crossing it instead of a solid teal T.
>   Driven live in `-liveryGallery` on CRJ900 + ERJ145 across ALL 10 emblems.
>   - **HOW — `aa-livery/trim_stab.py`, a SUBTRACT-ONLY edit of the COMMITTED mask, NOT
>     a regeneration.** A T-tail's stab reads column-by-column as a THIN top-run
>     continuing aft of the fin's trailing edge while the fin blade is DEEP; walking aft
>     from the deepest column, the first column thinner than `STAB_RATIO` (0.45) of that
>     depth starts the stab — cut there. Measured profiles: fin peaks ~0.34h, stab tapers
>     0.24 → 0.03, so 0.45 sits mid-gap. A `MAX_TRIM` 45% guard means a mis-detect
>     degrades to "unchanged", never to a destroyed fin. Removed 8–12% per type.
>   - **⚠️ WHY NOT `make_fin_masks.py`: its auto path NO LONGER REPRODUCES THE COMMITTED
>     MASKS — measured, all 35 differ, jets included** (A320 ~8.8k px). The committed
>     masks came from a better pass. Regenerating any existing type DOWNGRADES it. That's
>     the "improved auto pass broke the jets" trap, now confirmed with numbers and
>     documented at the top of that script. **Verified this fix touched exactly 5 masks;
>     the other 30 are byte-identical.**
>   - **`tailCX` moved for these 5** (0.904→0.872, 0.900→0.870, 0.813→0.794, 0.840→0.821,
>     0.862→0.843). The old values were the fin bbox centre INCLUDING the stab, so once
>     the stab was removed every emblem sat too far aft. New values are the new bbox
>     centre. `tailCY`/`tailScale` unchanged (fin height didn't move); titles untouched.
>     **Any future mask change that alters a fin's bbox must re-check `tailCX` the same
>     way** — `contact_sheet.py` makes the error obvious immediately.
>   - **`aa-livery/fin_probe.py`** (new) is the tracing aid: zooms a tail with a
>     fractional coordinate grid + the current mask in red, which is how the geometry
>     above was read off. Use it for the turboprops.
> - **✅ THE 4 TURBOPROPS — FIXED (15 Aug 2026). AT46 · B1900 · D328 · DH8B** now paint a
>   real fin: filled top-to-bottom down to the fuselage, stabilizer left white, emblem
>   centred on the blade. Was a rectangular block with a flat cut across the fin (lower
>   fin unpainted, paint past the trailing edge; B1900 read as a detached wedge).
>   - **TRACED FROM THE ARTWORK (`aa-livery/trace_fin.py`) — NOT a polygon.** A first cut
>     used hand-traced `FIN_POLYGONS`, and the designer rejected it on sight: **a polygon
>     has STRAIGHT edges, a real fin has a CURVED leading edge and a ROUNDED tip**, so the
>     paint left an unpainted sliver of fin along the curve and read as the wrong fin
>     shape. Lesson worth keeping — approximating a shape the artwork already contains is
>     always worse than reading it. `trace_fin.py` takes each column's own top opaque pixel
>     (the true outline) down to the fitted fuselage crown, so curves and tips are exact
>     and stay exact if the art changes.
>   - **Two cuts make it a fin and not a whole tail:** an **x-range** [x0,x1] (leading to
>     trailing edge — x1 excludes a stabilizer continuing aft, and on the B1900 also its
>     separate endplate), and a **`--stab-top` floor** that clamps the traced top DOWN
>     under the stabilizer where the stab sits ON the fin. The exact per-type invocations
>     are recorded at the top of `make_fin_masks.py`; `FIN_POLYGONS` is kept only as a
>     record of the x-ranges and is SUPERSEDED for these four.
>   - **`tailCX/CY/Scale` re-derived from the new fin bbox** (the old values pointed at the
>     wrong blocks, so emblems sat high/aft and clipped). **Titles also moved** — these are
>     HIGH-WING props, so the old mid-body titles collided with the wing root and the
>     propeller; they now sit on the upper cabin band forward of the wing. AT46/D328 still
>     graze the prop blade slightly (it's mid-cabin on those airframes — unavoidable
>     without shrinking the title further).
> - **✅ RJ TAILS NOW PAINT ALL THE WAY DOWN (designer request, 15 Aug 2026).** The CRJ/ERJ
>   fin fairing sweeps down and blends into the fuselage; the masks stopped at a straight
>   cut partway down, so the paint ended in mid-air. **`aa-livery/extend_fin_base.py`**
>   extends a mask down to the body, following that curve.
>   - **HOW:** below the fin the airframe is CONTINUOUS (fairing and body are one
>     silhouette), so there's no gap to detect — measured that first. Instead it fits the
>     FUSELAGE CROWN line from the columns AHEAD of the tail (least-squares; the rear body
>     tapers, so a line tracks it far better than a constant) and extrapolates aft, then
>     paints each column down to it. The fairing curve comes out exact because it's the
>     artwork's own silhouette between the mask's top edge and the crown — no polygon can
>     match that, and it stays right if the art changes. ADD-ONLY, so a correct blade
>     stays correct. Grew the masks 9–18%.
>   - Same treatment would suit any future type whose tail stops short — run it, don't
>     hand-trace.
> - **⭐ NEXT ITEM: none of the fin masks are known-bad.** All 35 types now read as real
>   painted tails (26 conventional jets untouched + 5 T-tails + 4 turboprops). Re-run
>   `contact_sheet.py` after any art change to spot a regression. If a NEW type is added,
>   the mechanism below is how to give it a fin:
>   `aa-livery/make_fin_masks.py` has a `FIN_POLYGONS` dict — add a hand-traced fin
>   outline (fractional (x,y) corners: tip → trailing edge → base → leading edge) per
>   exception type, run the script (it intersects the polygon with the airframe
>   silhouette so paint can't spill), CLEAN build, check in `-liveryGallery
>   -galleryType DH8B`. ⚠️ **Do NOT regenerate ANY already-good mask** — the auto path
>   downgrades every one of them (measured; see the T-tail note above). Only add polygons
>   for these 4 remaining types; run the script with an explicit type
>   list (`make_fin_masks.py DH8B AT46 …`) so it can't touch the rest. **Re-run
>   `contact_sheet.py` after each pass** — it's the fastest way to see all 35 at once.
> - **Walk the full first-run flow end-to-end** on a real device (sim text-typing was
>   flaky — `-freshFlow` reaches the naming screen reliably, but typing into the field
>   via the automation `text` action can background the app; a real device or the sim
>   SOFTWARE keyboard avoids it). The transitions/pieces are all individually verified;
>   the designer walked most of it live (Spikeair/Pacific/shield).
> - **SHIPS AS 1.3 (designer, 15 Aug 2026).** Merge `livery-prototype` → main only AFTER
>   1.2 is LIVE in the App Store, then cut 1.3. Merging earlier is the thing to avoid:
>   1.2.0 (build 41) is the one-time-unlock pivot and is waiting on RevenueCat offering
>   config, so if the paywall needs a hotfix build, `main` must be able to produce one
>   WITHOUT dragging the livery feature into review with it. Verified 15 Aug: the branch
>   merges into main with ZERO conflicts (main is 1 doc commit ahead), so waiting costs
>   nothing — it stays a trivial merge.
> - **Two gates before the 1.3 cut** (neither blocks the merge, both block shipping):
>   walk the FULL first-run flow (naming → livery → launch) on a REAL DEVICE — sim text
>   entry keeps backgrounding the app, so it has never been done end-to-end — and check
>   the livery on the **Fleet detail** screen, which is where players actually meet it
>   (all the fin verification so far was done in the `-liveryGallery` harness).
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
