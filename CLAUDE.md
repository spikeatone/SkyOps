# CLAUDE.md — Persistent Context for Airline Architect

> **New session? Read `HANDOFF.md` first** — it's the current state and what to do next.
> This file is the active rules, open questions, and key facts (kept lean; it auto-loads every session).
> The *why* behind settled decisions lives in **`CLAUDE_HISTORY.md`** — read it only when you need history.

Read this before doing anything else. It exists so a new session (different
day, different context window, possibly a different agent) doesn't have to
re-derive decisions that were already made and validated. If you're about to
suggest something that contradicts a "Decided" item below, stop and check
whether there's a reason logged here before overriding it.

> ⭐ **THE FAMILY LAYER — `~/Architect Universe/~PostmarkOps`
> ([repo](https://github.com/spikeatone/PostmarkOps), private).** Postmark Digital's shared operating
> layer, kept OUT of the app repos so it can't go stale in six places at once:
> - **`ARCHITECT_FAMILY.md`** — what the family already built (an adoption matrix of which app has
>   which system), the hard engineering rules, shared platform facts, the design language.
> - **`WORKFLOW-ORCHESTRATION.md`** — the PMD Kitchen brigade playbook: stations, the pass, and what
>   "tasted" means (harness + bite-test + cash invariant + *driven-verified*).
> - **`ASCTools/`** — dependency-free App Store Connect client. **Don't rewrite it.**
>
> ⚠️ **Airline is the elder.** Most of what that family brief documents was *derived from this
> codebase* — the tick engine, the cash invariant, tolerant decode, the decision-card queue, the
> persistence model. It is also the ONE project not set up with [mise](https://github.com/emadd/mise-en-claude):
> there is no `.mise/state.json` here and no vendored `/mise-cook` · `/mise-handoff` · `/mise-clean`
> in `.claude/commands/`. Don't assume that scaffolding exists, and **don't run mise over this repo
> without the designer's say-so** — this file is hand-built and load-bearing.
>
> Also shared: **ArchitectKit** (`~/Architect Universe/ArchitectKit`) — the Swift package holding the

> **This file is the ACTIVE working set** — the thesis, the open questions, the current
> release state, and the working agreement. Every settled **"Decided — …"** record now lives in
> **`CLAUDE_HISTORY.md`** (read it when you need the reasoning behind a built feature). Split
> 2026-09-12 to stop this file auto-loading ~120k tokens every session.


## What Airline Architect actually is

NOT a combat RTS. It's an airline operations/logistics tycoon sim — closer to
Airline Tycoon / Transport Fever than Command & Conquer. Player automates the
boring parts (aircraft fly assigned routes automatically, PAX loads simulated,
revenue collected on arrival) and makes strategic decisions: open/close routes,
hire crew, decide maintenance response, manage fleet composition. In the
shipped game, the player will "buy" the aircraft types they want to fly — the
browser prototype's fleet weights are for sim-testing purposes, calibrated to
match real-world deployment ratios rather than the eventual player-driven
economy (see Fleet section below).

Core tension: **the sim never pauses for disruptions.** AOG and crew-shortage
events surface as decisions the player must resolve, but every other aircraft
keeps flying while they think. This is deliberate and load-bearing — do not
add a global pause button back in. (A dev/QA-only pause is fine; a player-facing
one contradicts the design thesis.)

## Open / not yet decided

- ~~Xcode project shell doesn't exist yet~~ **RESOLVED long ago (stale line
  removed as a claim).** The Xcode project exists and the app has SHIPPED through
  1.1 (build 33, public debut) — `AirlineArchitect/AirlineArchitect.xcodeproj`,
  SwiftUI, file-system-synchronized groups. This bullet was a leftover from the
  pre-native planning era; kept only as a marker of how far the project has come.
- **Persistence — BUILT (native app), and NOT via SwiftData.** Went with a
  plain Codable snapshot to disk (JSON), not SwiftData/Core Data — the sim state
  is a self-contained object graph that serializes cleanly, and a single-slot
  save doesn't need a database. `Persistence.swift` has `GameSnapshot` (+ per-
  aircraft/route/crew/finance sub-structs) and `GameStore` (save/load/clear to
  Documents/savegame.json). `Simulation.snapshot()` exports and
  `Simulation.restore(from:)` imports (both live IN Simulation.swift so they can
  set the `private(set)` state). ONLY persisted: identity, balance, tick, all
  economy accumulators, PURCHASED aircraft, open+closed routes (with history),
  crew pools/reserves, finance snapshots, camera, firedMilestones, the traffic
  count. NOT persisted (regenerated on load): background/competitor traffic
  (`setFleetSize(savedCount)`), live event effects (reset to Normal), the used
  market (re-inited), airport ground-stops (cleared), slots (re-provisioned then
  decremented per open route). Aircraft reference type-by-id and airport-by-code;
  crew reconstruct by their per-family id. ContentView autosaves on scenePhase !=
  .active (background/quit) and, on cold launch, shows `ResumePromptView`
  (Continue / Start a New Airline) if a save exists — bankruptcy and "new
  airline" clear the save. Verified: JSON round-trip (7KB) restores every field
  exactly AND the restored sim keeps running/earning (29 new flights, balance
  advancing). SwiftData model classes are still present but unused; this
  supersedes the "SwiftData returns in Phase 5" plan.
- Figma → SwiftUI pipeline: designer has real mockups in Figma; pull via
  Figma MCP `get_design_context` against actual file/node URLs, don't
  guess at layouts from descriptions. Note the raster-export limitation
  documented above under Icons — full-screen mockups may hit the same
  wall the icon nodes did; verify early rather than assuming it'll work.
- **ROUTE COMPETITION — BUILT (native app), a first real version.** Rival
  carriers now REACT to the player: `tickCompetition()` (daily) has rivals ENTER
  the player's PROFITABLE, established (≥8-day-old) routes — up to 3 per route,
  ~6%/day, chasing the traffic — and occasionally EXIT (churn, ~2%/day). Each
  rival SPLITS the route's demand via `Route.competitionShare(reputation:)` =
  `1/(1 + level × (0.6 − 0.3·rep/100))`, floored at 0.2 — so 2 rivals at rep 70 ≈
  −44% demand. A strong REPUTATION both defends share (the factor shrinks with
  rep) AND deters entrants (entry rate halves at rep 100). Applied in `rollRevenue`
  for owned aircraft only. Entries/exits log to the Ops feed (MARKET) naming a
  Big-Four/ULCC rival; a dedicated Ops "Competition" box lists contested routes +
  rivals + the demand hit. Persisted (`competitionLevel`/`competitors` on Route).
  Verified 8/8 headless + live. STILL NOT modeled (deliberate, future): rivals
  competing for SLOTS at open time, or having their own economy/network — this is
  demand-share competition on the player's routes, which is the impactful, visible
  slice. The background-traffic airline NAMES are still separate cosmetic identity.
- **PLAYER COMPETITION ACTIONS — BUILT (native app; designer request). Three
  route-level marketing levers on each Ops "Competition" row, a real
  spend-to-fight-rivals loop.** All three are UPFRONT MARKETING spend and a NEW
  capital-out term in the Finance cash invariant (`totalMarketingSpend`, "Marketing"
  ledger row) — timed per-route effects in a "player promotions" section of
  Simulation.swift:
  - **Ad campaign** ($80k + $150·demand, 14 days): +15% demand, SCALED BY THE
    ECONOMY (`× currentEvent.loadMultiplier` — a recession dampens it, a boom
    amplifies it, so it's not always worth the spend). No fare change.
  - **Fare war** ($150k + $300·demand, 21 days): fare ×0.80 (less per-seat) +
    share ×1.25 AND — designer's call — **drives rivals off faster** (rival exit
    prob ×3 on that route in `tickCompetition`). The aggressive reclaim lever.
  - **Loyalty push** ($250k + $400·demand, 45 days): sticky share ×1.20, no fare
    cut — the priciest/longest DEFENSIVE bookend. Cost ladder ad<fare<loyalty.
  - State: `playerFareWarUntil`/`adCampaignUntil`/`loyaltyPushUntil` ([routeId:
    expiryTick], persisted nil-safe), `tickPromotions()` daily cleanup. Actions
    `startFareWar`/`launchAdCampaign`/`startLoyaltyPush` (afford + not-active gated;
    fare war also requires a rival). Effects live in `rollRevenue`'s fare/demand
    stack. UI: 3 buttons per contested row (`promoActions`); active shows "Nd left".
    Loyalty purple is theme-aware (`#C79CFF` dark / `#6E43A6` light — the light
    lavender washes out on white). Verified **22/22 headless** (cash invariant holds
    after every action + 90 sim-days, marketing spend exact, cost ladder, broke-guard,
    save/load round-trip) via a `cashInvariantResidual()` DEBUG test hook (kept —
    a reusable invariant guard, like `devInjectCash`; absent from Release) + live.
  - The hub drawers (Network ▸ Hubs) ALSO gained a "Route Opportunities" subsection
    (mirrors Ops ▸ Route Opps via `sim.suggestRoute`); Ops ▸ Route Opps gained
    per-hub "BY HUB" drawers (`hubRouteOpportunities(from:)`).
- The airline roster IS region-aware now (this bullet was PARTLY stale — the
  "no region mechanism at all / single fixed US-weighted list" claim is corrected).
  There are 8 region rosters in `Airline.swift` (`canadaRoster`/`mexicoRoster`/
  `centralAmericaRoster`/`caribbeanRoster`/`southAmericaRoster`/`africaRoster`/
  `europeRoster`/`asiaRoster` + the US default) with per-region airport-code Sets
  and `region()`/`roster(for:)`/`pick(...)` classification — so background carriers
  match the leg's region. **What's still true:** each roster is a hand-curated
  literal, and there's no mechanism to detect real-world fleet/route changes on its
  own (roster corrections — e.g. the Alaska Airlines update — get applied because
  someone reported and independently verified them, not because the game noticed).
  Treat every roster entry as due for eventual re-verification.
- **REPUTATION — BUILT (native app).** A service-quality stat (0–100, starts 70)
  that feeds back into demand. FALLS when the operation fails passengers (an
  aircraft grounded −4 at AOG-hold start, a flight held for crew −2) and RECOVERS
  slowly through flights completed cleanly (+0.15 each). `reputationDemandMultiplier`
  = `0.85 + 0.30·rep/100` (0.85 at rep 0 · 1.0 at rep 50 · 1.15 at rep 100), applied
  to owned-aircraft demand in `rollRevenue`. It ALSO defends market share vs
  competitors (see ROUTE COMPETITION above). Dedicated Ops "Reputation" box: score
  bar + tier (Poor/Fair/Good/Excellent) + signed demand %. Persisted. The feedback
  loop: bad service → fewer pax → less revenue → harder to recover. Resolves the
  original-design-brief reputation item (demand curves + hub effect were already
  built).
- **HUB / NETWORK EFFECT — BUILT (native app).** Concentrating routes through
  an airport now pays: `Simulation.hubDemandMultiplier(originCode:destCode:
  excludingRouteId:)` gives a route `+hubBonusRate` (8%) demand per OTHER player
  route touching either endpoint, capped at `hubBonusCap` (+80%). So a coherent
  hub-and-spoke network beats scattered point-to-point (connecting passengers).
  Applied in `rollRevenue` for the player's own aircraft only (background traffic
  isn't part of the player's network); `excludingRouteId` stops a route counting
  itself. Folded into the `routeDailyDemand`/`projectedLoadFactor` UI helpers and
  shown as a "Hub bonus +X%" row in the route-confirm panel. Verified: 2 routes
  out of DEN give each DEN route +16%, an isolated pair stays ×1.00.
- **MICRO-INTERACTIONS / DELIGHT PASS — BUILT (native app; designer request for
  polish + "surprise and delight").** New `Delight.swift` holds the shared
  primitives: a `Motion` enum of standard spring curves (glide / pop / toast) so
  everything animates consistently; a `Pressable` ButtonStyle (`.pressable()`) —
  scale+fade on press — applied to the control-bar / speed-bar / eye buttons; a
  `PlaneFlyBy` easter egg; and the `MilestoneToast`. Wired in: (1) the Cash-on-
  hand value is a rolling counter (`.contentTransition(.numericText())`); (2) the
  Network control-bar panels, route-flow, tooltip and airport card GLIDE in/out
  (move+opacity transitions driven by `.animation(Motion.glide, value:)` on the
  overlay stack); (3) MILESTONE CELEBRATIONS — `Simulation` queues one-time
  `Celebration`s (first flight, fleet 5/10/25, net worth $50M/$100M/$250M/$500M/
  $1B — thresholds ABOVE the $30M start so they're real growth, and a route
  recouping its opening cost from `settleLeg`); ContentView shows the first as a
  gold-rimmed toast that glides down from the top and auto-dismisses (3.6s). Fired
  once each via a `firedMilestones` Set; `checkMilestones()` runs in the tick
  loop. **The badge now uses app-aesthetic SF SYMBOLS (not emoji), tinted gold:**
  `Celebration.symbol` (airplane / airplane.departure / trophy.fill /
  chart.line.uptrend.xyaxis / airplane.circle.fill). For a ROUTE milestone (a
  route recouping), `Celebration.originCode`/`destCode` drive a city-pair line
  rendered with the ⇄ `arrow.left.arrow.right` icon between the codes (matches the
  Figma "RT Route Arrows" 61:4824 + the Ops boxes) instead of a unicode ↔ in the
  title string. **MILESTONE LADDER EXPANDED (1.1.x):** added first_route,
  routes 5/10/25, first_intl (first cross-`Airline.region` route), regions_4/7
  (distinct regions served — a "spread" reward), flights_100 (a beat between
  first_flight and 1,000), first_widebody, iconic SBH/PPT (you EARN St. Barths —
  it's DH8B-only — and Tahiti; both use `beach.umbrella.fill` + the city-pair
  render), first_subsidiary (acquisition) and went_public (IPO). All one-time via
  `firedMilestones`, spread across the whole game arc so they're not spammy.
  Verified 43/43 headless (`aa-1.1.x/RegDelightVerify.swift`) that each fires on
  its trigger. NOTE the 3-slot `celebrations` display cap: a burst that fires >3
  in ONE tick (e.g. a cash-injected test that trips the whole net-worth ladder at
  once) drops the earliest from the toast QUEUE — a display cap, not a
  fire-failure (they're still in `firedMilestones`); real play fires them on
  separate ticks. (4) MAP ROUTE-OPEN RIPPLE — `routeOpenPulse` (set in `openRoute`) drives
  two staggered expanding rings at both endpoints in `MapView.drawRoutePulse`
  (tick-driven over 48 ticks, no SwiftUI animation — the Canvas already redraws
  each tick; speed-dependent, acceptable). (5) EASTER EGG — tapping the "NETWORK"
  title zips a ✈️ across the header in an arc (`PlaneFlyBy`, replayed via `.id`).
  Milestone toast verified visually; the rest are standard SwiftUI transitions.
- **COLD-LAUNCH SPLASH — BUILT (designer request, "route-network reveal"
  chosen over a Star Wars-style logo fly-in).** `SplashView.swift`: ~2.6s on a
  brand-navy sky with a faint night grid — four dashed great-circle arcs draw
  themselves in the game's own colours (climb green / cruise blue / descent
  amber / competitor purple; the ArcShape reuses the in-game 12%-of-distance
  bulge proportion), destination endpoints pulse like the route-open ripple,
  then the logo badge springs in at the naming screen's badge position (soft
  crossfade handoff) with a "Build the sky." tagline — WORDING IS MINE, not
  designer-supplied; swap the string if wanted. Tap anywhere skips; Reduce
  Motion collapses it to a static network + calm logo fade. Shown once per
  process launch (ContentView `showSplash`, zIndex 10 over the load menu /
  naming screen). Verified via timed simulator frame captures.
- **SUPERSEDED AGAIN (2026-08-09) — the cold-launch backdrop is now a full-bleed
  AERIAL RUNWAY scene, and the blend-mode approach below is GONE.** The designer
  supplied FOUR pre-rendered assets — one per (idiom × theme): iPhone dark (a
  charcoal photo of a runway with a queue of airliners taxiing to line up) / iPhone
  light (the same scene as a graphite sketch on off-white) / iPad dark / iPad light
  (the same recomposed for 4:3). Figma `Airline-Architect-Production` nodes 122:4882
  (iPhone dark) / 122:4883 (iPhone light) / 122:4881 (iPad dark) / 122:4887 (iPad
  light). Files: `Resources/Brand/LaunchBackdrop{Dark,Light}.png` (phone) +
  `LaunchBackdropPad{Dark,Light}.png` (iPad); the old single `LaunchBackdrop.png` /
  `LaunchBackdropPad.png` were DELETED.
  - **No more blend mode.** Each asset is already theme-correct, so `ArchitectArt.art(regular:dark:)`
    picks the right one and it's drawn DIRECTLY (the `BackdropBlend` `.multiply`/`.colorInvert().screen`
    modifier is removed). `ArchitectBackdrop`'s public API (`opacity`, `forcedScheme`) is unchanged, so
    callers (SplashView/AirlineNamingView/SaveSlotsView, all via ContentView's `coldLaunchBackdrop`) are
    untouched.
  - **ALWAYS `.fill` (full-bleed), NOT `.fit` — and the 0.98 inset is GONE.** These are opaque full-frame
    photos, so ANY margin (the old iPad `.fit` letterbox in landscape, or the 0.98 inset) exposed the
    image's rectangular EDGE against the page background — a visible seam the designer flagged ("I can see
    the image edges"). `.fill` covers every pixel so there's no edge. iPad PORTRAIT is an exact fit (4:3
    art on 4:3 canvas, no crop); iPad LANDSCAPE center-crops the diagonal runway scene (keeps the focal
    runway + queue) — verified edge-free in both themes.
  - **Opacity: dark 0.25, light 0.42** (`darkOpacity`/`lightOpacity`). Light is HIGHER on purpose — the
    graphite-on-white sketch reads fainter at a given opacity than the dark photo-on-navy, so it needs
    more to land with equal presence (designer: "bump up light, it's too faint"). Both idioms share the
    single `lightOpacity` via `coldLaunchBackdrop = isDark ? darkOpacity : lightOpacity`, so iPad-light ==
    iPhone-light by construction (designer: "white iPad opacity needs to match white iPhone").
  - Verified live on iPhone (dark+light) and iPad Pro 13" (portrait + LANDSCAPE, both themes) — all six
    full-bleed with no visible edges. The `-backdropTest` harness still works (it uses the same
    `ArchitectBackdrop`). Everything below in this bullet describes the OLD pencil-sketch blend approach —
    kept for history but NO LONGER how it works.
- **(HISTORICAL) 2026-08-03 — the cold-launch backdrop was an AVIATION PENCIL
  SKETCH, not the drafting-tools motif.** The designer replaced the tools still
  life with an aviation sketch (airliner + control tower + pilot's cap) on the
  naming/splash/load-menu screens (new Figma `1:2` light / `1:456` dark).
  `Resources/Brand/ArchitectTools.png` → `LaunchBackdrop.png` (a grayscale pencil
  drawing on WHITE), and `ArchitectBackdrop` was rewritten: it's now **FULL-BLEED**
  (the old rotation/scale/`centre`/`tint`/`figmaOpacity` API is GONE) and adapts
  the one grayscale source to each theme with a **BLEND MODE** that preserves the
  pencil shading — `.multiply` on light (drops the white ground → faint gray
  sketch), `.colorInvert()` + `.screen` on dark (→ faint light sketch on navy).
  New API: `ArchitectBackdrop(opacity:forcedScheme:)` — the splash passes
  `forcedScheme: .dark` (always navy); naming/load-menu read the environment
  scheme. **Opacity settled at 0.25 for BOTH themes** (`lightOpacity` =
  `darkOpacity` = 0.25 — device-tuned down from an initial 0.40/0.35, which the
  designer judged as competing with the UI; the designer picked 0.25 as the sweet
  spot for both). Callers dropped the tint arg; `ArchitectBackdropLayer` was
  removed (unused). The **cross-series portability is GONE** — AA's launch art is
  aviation-specific now, so the sibling apps (Golf/Vineyard) keep the tools motif
  independently.
  - **TWO ASSETS, ONE PER IDIOM (the designer rendered a dedicated iPad version).**
    The phone art is a TALL composition; on the wide iPad canvas it cropped the
    airliner's wings, so the designer re-rendered it 4:3 (Figma `116:4932` "on
    white", 1086×1448 — matching the iPad's PORTRAIT aspect) with the full wingspan
    in frame. `LaunchBackdropPad.png` ships alongside `LaunchBackdrop.png` and is
    picked by **horizontal size class** (`ArchitectArt.backdropImage` /
    `.backdropImagePad`). Scaling the phone art was tried first and rejected — a
    purpose-composed asset beats any fit/scale compromise.
  - **Phone = `.fill`, iPad = `.fit` at `regularScale` 0.98.** The pad art shares
    the iPad's PORTRAIT aspect, so at ~0.98 portrait is effectively full-bleed while
    LANDSCAPE stays contained — one constant covers both orientations, no
    orientation branching. **A `.fill` on iPad is WRONG in landscape**: it scales the
    drawing up to cover the width and crops the tower/cap off (the designer flagged
    exactly this). 0.98 = 0.85 +15%, the designer's call after seeing 0.85.
  - **The "on white" source drives BOTH themes** through the blend — the designer's
    separate "on dark" export (`116:4936`) was NOT needed. Ask for on-white renders.
  - **GOTCHA — `⌘⇧A` (Toggle Appearance) does nothing while `-backdropTest` is up.**
    `ArchitectBackdropTestView` PINS the scheme via `.preferredColorScheme(...)` off
    the `-backdropLight` arg, which overrides the system appearance. Relaunch with/
    without `-backdropLight` to switch themes there; the real app screens follow the
    environment normally.
  - Verified live on iPhone (naming light+dark, load menu) and iPad (naming
    light+dark, portrait AND landscape).
  Everything below in this bullet describes the OLD tools motif and its
  geometry/opacity/portability — kept for history but NO LONGER how it works.
- **(HISTORICAL) ARCHITECT'S-TOOLS BRAND MOTIF — BUILT (designer, Figma `90:4819` "home - dark").
  A faint drafting-tools still life behind the cold-launch screens, intended as a
  COMMON VISUAL THEME ACROSS THE WHOLE ARCHITECT SERIES** (Airline Architect, Golf
  Course Architect, Vineyard Architect…). `ArchitectBackdrop.swift` +
  `Resources/Brand/ArchitectTools.png` (T-square, mechanical pencil, compass —
  white line art on alpha, 892×1200).
  - **DELIBERATELY PORTABLE:** the file depends on nothing app-specific, so reusing
    it in a sibling app is "copy 1 Swift file + 1 PNG." The art is drawn as a
    **template** image, so a sibling can `tint:` it to its own brand colour with no
    re-export. `ArchitectBackdrop.figmaOpacity` (0.10) is the single tuning knob.
  - **The Figma-export gotcha applied again** (same as the aircraft illustrations):
    `download_assets`' `export` bakes in an opaque frame background — the **rawImages**
    entry is the transparent source. Node 90:4876 returns TWO raws that are the same
    art at 1× and ¼×; the Figma "mask group" is the image masking its own alpha, so
    only the artwork is needed and the mask is just `.clipped()`.
  - **Geometry is FRACTIONAL, not fixed points** — the Figma frame is 440 wide, real
    devices are 402/430/iPad-wide, so hard-coding would drift off-screen. Art width =
    `1.371 × container width` (603.274/440), centre at `(0.368, 0.578)`, rotation 30°.
    Figma's own numbers were verified before porting: a 603.274×811.579 box rotated
    30° gives a bounding box of 928.23×1004.47, matching the file's stated
    928.24×1004.485.
  - **WIRED INTO ALL THREE COLD-LAUNCH SURFACES** — `SplashView`, `AirlineNamingView`,
    and `SaveSlotsView` each gained an optional `backdropOpacity` (nil = off) and each
    draws its OWN instance. **They are NOT a single shared layer, on purpose:** the
    geometry is a pure function of container size, so all three land pixel-identically
    and the tools hold still across every handoff — while each screen keeps its own
    opaque background. ContentView passes `ArchitectBackdrop.figmaOpacity`. The splash
    draws it over its navy sky and UNDER the route arcs, so the intro animation plays
    on top of the motif (the designer's sequencing idea, and they signed it off live).
  - **BOTH THEMES, ONE PNG — the light treatment is BUILT** (supersedes the earlier
    "dark theme only / light is an open designer call" note). Because the art is drawn
    as a `.template` image it's tinted at draw time, so the same asset serves both:
    **white line-work on the dark page, `Sky.darkBlue` #4E67A0 brand ink on the light
    one** — drafting pencil on vellum rather than a grey smudge. `ContentView`
    supplies `coldLaunchBackdrop` (opacity) + `coldLaunchTint`; `AirlineNamingView`
    and `SaveSlotsView` take a `backdropTint`. The SPLASH always uses white because
    it's always navy regardless of theme. (`Sky.darkBlue` was promoted to a named
    token in the same pass — the hex was already used inline in several places.)
  - **THE TWO OPACITIES ARE DIFFERENT ON PURPOSE — do not "unify" them.** Dark ink on
    white carries further than white line-art on #2B303D, so equal alpha does NOT read
    equal: `figmaOpacity` 0.10 (dark, the Figma value) vs `lightOpacity` **0.08**.
    Tuned by eye on device over the REAL naming screen — 0.06 vanished entirely, 0.12
    began competing with the form fields, 0.08 sits behind the content the way the
    dark 0.10 does. Verified live on the naming screen AND the real no-arg light cold
    launch (load menu).
  - **CROSS-SERIES: AA's light 0.08 is DELIBERATE, not an outlier to "unify" (revisited
    2026-07-24, designer confirmed — KEEP 0.08).** The sibling apps have genuinely
    DIVERGED, on more than one axis, so there is no single series standard to conform to:
    AA = 0.08 light (`Sky.darkBlue` ink) / 0.10 dark; Golf Course Architect = 0.10 BOTH
    themes (`Palette.darkGreen` ink, one `resolvedOpacity` = `figmaOpacity`); Vineyard =
    0.10 light / **0.18** dark. Two reasons matching GCA's number would be WRONG, not
    consistent: (1) the series was already non-uniform BEFORE this (Vineyard's 0.18 dark),
    each app tuned to its own pages; (2) the LIGHT INK COLOURS differ (AA medium blue
    #4E67A0 vs GCA deep green), so identical alpha does NOT read as identical presence — a
    lighter ink reads fainter at the same opacity. AA's 0.08 was device-tuned to AA's own
    light naming screen (above); bumping it to 0.10 would re-enter the range the on-device
    tuning already rejected as competing with the form fields. So this is settled, not a
    pending cosmetic call — do not re-flag it as "the one number that differs across the
    series."
  - **A harness bug worth remembering (it masqueraded as a design finding):** the
    test view's naming/sequence modes called `AirlineNamingView(backdropOpacity:)`
    without passing the tint, so it defaulted to `.white` → white ink on a white page
    → "the light treatment doesn't work." The SHIPPING path was correct the whole
    time. When a preview harness wraps a real view, thread EVERY styling input
    through it, or the harness will lie to you.
  - **NOTE on view API:** `backdropOpacity` is declared BEFORE the trailing closure
    (`onLaunch`/`onDone`) on both views so the trailing-closure call style still
    compiles — reordering the memberwise init is the whole reason.
  - **DEBUG harness:** `ArchitectBackdropTestView.swift`, reached with the
    `-backdropTest` launch arg (`#if DEBUG`, compiled out of Release). Three modes
    (`-backdropMode motif|naming|sequence`) plus live opacity/angle/scale sliders, so
    the treatment can be dialled in on-device instead of round-tripping through Figma;
    `-backdropOpacity <n>` / `-backdropLight` (preview the light ink treatment) /
    `-hideControls` seed it for screenshots. **The Simulator's
    input channel died mid-session (the documented glitch), so modes are reachable by
    launch arg rather than taps** — keep that pattern for any future harness.
  - Verified live on the iPhone 17 Pro sim: motif alone, the naming screen, and the
    REAL no-arg cold launch (splash → load menu) all render it; the designer watched
    the intro animation play over it and approved. Caveat worth knowing: `simctl io
    screenshot` takes ~1s, and the splash is only ~3.3s including cold start, so
    catching a mid-animation frame by polling is unreliable — the live attached panel
    is the honest way to judge the motion.
- **HAPTICS + SUBTLE SFX — BUILT (native app; designer request, extends the
  delight layer).** `Feedback.swift` (UIKit/AVFoundation, VIEW layer only — the
  Sim layer stays framework-free for the headless harness, so every trigger is a
  SwiftUI action or an `.onChange` on observed sim state). Deliberately RESTRAINED
  per designer direction ("don't cartoon it up"): light haptics on the big
  moments, and exactly ONE sound — a short jet whoosh reserved for the flagship
  moment (acquiring an aircraft). Triggers: acquire aircraft (buy/lease/used) →
  success haptic + jet whoosh (`NetworkView.handleBought` + the three `FleetView`
  marketplace buttons); open route → medium impact (`openConfirmedRoute .success`);
  milestone celebration → success haptic + `Resources/Sounds/milestone.wav`
  congrats chime (designer-supplied, `MilestoneSound`, fired from the SAME
  `celebrations.first?.id` change as the badge toast, so chime + badge are synced);
  new decision/alert → warning haptic
  (`onChange decisionQueue.count` increasing); bankruptcy → error haptic; sell →
  light impact (Alerts sell + Fleet-detail sell). `JetSound` PREFERS a real bundled
  recording (`jet`/`jet_takeoff` .caf/.wav/.m4a/.mp3) over the synthesized fallback.
  **REAL RECORDINGS NOW SHIPPED (designer-supplied):** `Resources/Sounds/jet.wav`
  (Jet Overhead, 3.5s) is used on aircraft acquisition; the synthesized whoosh
  (band-passed noise swept 2200→400 Hz) is now the FALLBACK only. Files in
  `Resources/Sounds/` flatten into the app root (like the fonts), so
  `Bundle.main.url(forResource:"jet",withExtension:"wav")` finds them — confirmed
  in the built `.app`. TIMBRE/level are the designer's call on-device; swap the
  file to change the sound (no code change). Four clips now ship in
  `Resources/Sounds/`: `jet.wav` (acquire aircraft), `now_boarding.wav` (open
  route), `milestone.wav` (milestone), `new_crew.wav` (hire crew). Single-clip
  players are a shared `ClipSound(resource:volume:)`; `Feedback.crewHired()`
  (success haptic + `new_crew`) fires at all three hire sites (Crews tab, Network
  ADD CREW panel, CREW alert card's Hire option).
  - **AUDIO SESSION CATEGORY — was `.ambient`, now `.playback` + `.mixWithOthers`
    (real fix).** On-device testing FELT the haptics but heard NOTHING: `.ambient`
    is muted by the hardware ring/silent switch, and the test device was on silent.
    `.playback` makes the cues audible regardless of the ringer (a game the player
    opened should still make its sounds), while `.mixWithOthers` still lets their
    music keep playing. `GameAudio.prepareAmbientSessionOnce()` (shared by JetSound
    + GateAnnouncement) sets it. If a silent-switch-respecting option is ever
    wanted, that's the one line to flip back.
  - **"NOW BOARDING" GATE CALL (native app; designer spitball, shipped).** Opening
    a route plays a gate-style "now boarding" call. **REAL RECORDING NOW SHIPPED:**
    `Resources/Sounds/now_boarding.wav` (1.4s, designer-supplied) is played via
    `AVAudioPlayer` in `GateAnnouncement`. The on-device TTS path (in the player's
    own airline name — "Aster Air, now boarding.") is now the FALLBACK only, used
    if the recording is missing. Reserved for route-open only (a deliberate,
    infrequent action — a nod, not a nag), under the shared `.playback` session.
    Swap the file to change the call (no code change); the recording is generic
    (not airline-specific), which is the designer's choice.
- **Pinch-zoom — BUILT in the native app (this bullet was stale; it described
  the browser prototype).** `NetworkView` drives the camera with a real
  `MagnifyGesture` (anchored at pinch start) + `DragGesture` pan, and the designer
  confirmed it live ("pan feels great, as does pinch"); max zoom is `cameraMaxZoom`
  60. See "Pan/zoom camera + airport labels" in the Native iOS Port section. The
  BROWSER prototype still uses scroll-wheel zoom (no touch gesture) — that's the
  only place this note still applies.
- **Label cluster detection — FIXED in the native app (this bullet described the
  browser prototype, now stale for native).** `MapView` recomputes clusters against
  CURRENT on-screen distance EVERY FRAME (see "Label declutter — DONE, better than
  the prototype" in the Native iOS Port section), so fanned clusters un-fan
  automatically once zoom gives labels room. The static-once-at-startup behavior
  this bullet warned about only remains in the BROWSER prototype.
- **The map is not a true global projection.** WORLD_BOUNDS now spans
  Alaska-to-the-Americas-to-Asia-to-Oceania (every populated continent has
  airports), but it's still one fixed rectangular lon/lat box with a
  cosine-corrected equirectangular projection — that breaks down badly near
  the poles. **UPDATE: the native app DOES wrap horizontally now** (see the
  "Wrap-around map — DONE" note in the Native iOS Port section — tiled
  redraw, `wrapWidthUnits`, wrapped hit-testing), so panning east/west
  circles the globe; the antimeridian is no longer a hard edge. What's still
  NOT a true global projection: the pole distortion, and the ~30° mid-Pacific
  overlap from the 390°-content/360°-period mismatch (documented in that note,
  benign). The browser prototype still has neither wrap nor this.
- **BWI/FLL ground-stop data conflict** — two different source batches
  gave different numbers for the same two airports; kept the
  original/first-sourced values (see Economy section above for the exact
  numbers). Not resolved, just not silently overwritten either.
- **Regional-jet `crewsPerTail`**: defaulted to 6 (same as narrowbody),
  unverified — and its role changed this session. It's no longer consumed
  by any code at all (`resizeCrewPools()` was rewritten to not use it —
  see Fleet Lifecycle section); it's now purely a reference number the
  player might reason about themselves, or that a future UI might show
  as a suggestion. Still unverified either way.
- **Intra-family fleet-weight splits** for A320/737/A220 families, and ALL
  remaining regional-jet family totals: real but lower-confidence data,
  flagged in the Fleet section above. Revisit with dedicated sourcing if
  the designer wants higher precision here.
- **Bankruptcy / failure state — BUILT (native app).** Negative
  `playerBalance` now starts a 14-sim-day grace countdown (`insolventSinceTick`,
  `bankruptcyGraceTicks`, an Ops warning logged; actions are still blocked as
  before). `tickSolvency()` (in the tick loop) runs the countdown; when it
  expires, `forcedLiquidation()` sells owned-outright aircraft most-valuable-first
  until solvent, then hands back leased jets (no proceeds, but stops the bills),
  and if the fleet empties while still negative → `isBankrupt = true` (GAME OVER).
  `sellAircraft` was refactored to share a `liquidate(_,proceeds:)` teardown so a
  leased return is a $0-proceeds liquidation. `GameOverView` is a modal recap
  (days operated / routes flown / flights) with "Start a New Airline", which
  resets by `sim = Simulation()` + bumping `gameID`; ContentView's run loop is now
  `.task(id: gameID)` so the old sim's loop cancels (run() checks
  `Task.isCancelled`) and the new instance starts fresh (naming screen returns).
  Verified headlessly: a healthy 2-aircraft operator never false-bankrupts; a
  player who leases a $200M widebody with no revenue goes negative day 0 and
  bankrupts exactly at day 14 (grace) after the leased jet is returned with
  nothing left to sell. The browser prototype has no failure state.
- **Route-opening cost and starting capital are REAL; the Phase-C/D marketing
  + airport-incentive layers are now BUILT too — this bullet was STALE, corrected.**
  An earlier version said "player-funded route marketing and the airport-incentive-
  offer mechanic ... are still not built (Phase C/D); only the A/B foundation
  shipped." That is no longer true (both shipped; the claim contradicted the
  detailed BUILT notes elsewhere in this file). Player route marketing = the
  per-route ad-campaign / fare-war / loyalty-push levers on each Ops "Competition"
  row (`startFareWar`/`launchAdCampaign`/`startLoyaltyPush` in Simulation.swift,
  `totalMarketingSpend` in the Finance invariant — see "PLAYER COMPETITION ACTIONS
  — BUILT" below). Airport incentives = the `.airportOffer` recruitment-offer card:
  waived opening cost + signing bonus, a 14-day fulfillment deadline, and bonus
  clawback on forfeit (`incentiveWaived`/`incentiveBonus`/`fulfillByTick` in
  Route.swift + Simulation.swift — see "#18 AIRPORT RECRUITMENT OFFER — DONE"). So
  the whole route-opening area (A/B foundation AND the C/D marketing/incentive
  layers) is shipped.
- **Routes profitability chart — RESOLVED (native app).** The designer's goal
  (an app view charting profitability over time, seeing exactly when a route
  became profitable) is built — see `RouteProfitChart` in the Native iOS Port
  section. The browser prototype still lacks it; this is native-app only.
- **Full 30-type fleet, 48 airports, the economic event system, the
  pan/zoom camera, the sell/buy/lease economy, the real player route
  network, AND the rebuilt crew-hiring/duty-rest system have never all
  run together in one real, sustained play session.** Each has been
  individually spot-checked and numerically verified, and SEVERAL of
  them (the `operatingCost` bug, three separate instances of the same
  decision-panel/dropdown/buy-panel flicker bug, the lease-proration bug
  that made leasing nearly dominant, the phantom-crew-family bug, the
  ownership-scoping gap letting background traffic generate real
  decisions, and the crew duty/rest reset bug) had real, user-facing
  issues that only surfaced through actual use or a direct question, not
  through the verification that shipped them. "Spot-checked" has a long,
  real, demonstrated catch rate at this point — not a theoretical safety
  net, a proven one. This is still the single most valuable next step
  before adding more scope, and has been true and repeated at nearly
  every major addition this session.
  - **PARTLY ADDRESSED — a headless SOAK harness now covers the class of this
    concern that a machine CAN reach (`aa-1.1.x/SoakMain.swift`).** It drives ONE
    `Simulation` through a multi-year game with randomised-but-plausible play —
    buy/lease/sell across the whole fleet, open routes, hire crew, take/repay
    loans, weather events, establish hubs, go public + pull levers, drain the
    decision queue — asserting the cross-system invariants on every check: the cash
    residual, crew integrity (crewId resolves in its family pool; no double-booking,
    keyed on (family,id) since ids are per-family), duty/rest bounds + accumulation
    liveness, ownership scoping (every decision names a PURCHASED aircraft), route/
    fleet consistency, and a save/load round-trip of the soaked state. **Result:
    8/8 seeds × 2 sim-years clean (~7.9M ticks), all went public, one went bankrupt
    while public and the cash invariant held through it — NO bugs found.** Of the
    six historical bugs above, five are in this harness's reach (operatingCost /
    lease-proration → cash residual; phantom-crew-family + crew duty/rest reset →
    the crew invariants + `peakDuty✓rest` liveness; ownership-scoping → the decision
    check). **The SIXTH — the decision-panel/dropdown/buy-panel FLICKER — is a pure
    UI re-render and is fundamentally OUT of a headless harness's reach; it still
    needs the Simulator + eyes.** So the concern is NARROWED, not closed: the
    numeric/state-integrity half now has a continuous net (re-run after any economy
    change), and the residual is the UI/"does it feel right" half a real sustained
    session is still owed. **Calibration lesson (kept in the harness README): the
    soak's first two "findings" were BOTH the harness's own bounds being wrong, not
    game bugs — duty legitimately overshoots the cap (cap-and-rest fires at
    release, end-of-flight, realistic Part 117), and crewId is family-scoped. A
    soak finding is a HYPOTHESIS until checked against the real contract.**
- **Why Sukhoi Superjet 100 was removed isn't documented anywhere.** The
  type and its crew family are fully gone from the code (confirmed clean
  — no orphaned references anywhere), but no record of the actual
  decision/reasoning exists in this file or the chat history available at
  time of this update. If that reasoning matters later, it may need to be
  re-asked rather than looked up.
- `README.md` — CHECKED (2026-07-22): there is NO `README.md` at the repo root
  (`ls` confirms). The old `TASKS.md` "Repo scaffolded" reference to one was
  aspirational, never real. Not worth creating one — HANDOFF.md + this file +
  NEXT_SESSION_PROMPT.md already orient a cold session. Resolved; stop re-flagging it.
  (This bullet used to cite RELEASE_STATUS.md, which has since been deleted.)

## Release status — see `HANDOFF.md`

⚠️ **`RELEASE_STATUS.md` NO LONGER EXISTS.** It covered the 1.0 / build 26 launch and
carried its own "delete once 1.0 is live" instruction, which was followed — but three
references to it survived in this file and sent later sessions chasing a missing file.
Corrected 17 Aug 2026. **The current release state lives in `HANDOFF.md`** (which
version is live, what's in review, what the next build number must be), and in-flight
task tracking lives in `TASKS.md`.

As of 31 Aug 2026: **1.2 (41) · 1.2.1 (43) · 1.3 (44, personalized livery) · 1.4 (48, the
GAMEPLAY PACK — fare lever, first quest, session briefing, Game Center, rival flavor, subsidiary
fleet growth) · 1.4.1 (51, Game Center wake fix + Tech Ops modernization) · 1.4.2 (52, ASYNC SAVE
fix for the `hang.under3s` TelemetryDeck signal) · 1.4.3 (53, ASYNC SLOT DECODE — the decode-side
twin, load-menu off main) · 1.5.0 (54, A350-1000 + 747-8i + map-render throttle) are ALL LIVE
(`READY_FOR_SALE`). 1.6.0 (55, German localization + 43 new city hero images/framing fix + GC
per-achievement icons) is now ALSO LIVE (`READY_FOR_SALE`, approved 31 Aug — cleared 4.3(a); the
city artwork made it a content update, not localization-only). Next new build = 56+.**
⚠️⚠️ **1.8.0 (build 57) IS LIVE — APPROVED, `READY_FOR_SALE` / `READY_FOR_DISTRIBUTION`
(confirmed via the ASC API, 10 Sep 2026). NEXT NEW BUILD = 58+.** ASC ids: version `a6e6c4d1-d2bb-41e9-804b-131fcd0730a8`, review
submission `dc118de8-0b52-49a3-8f1e-697fa1ea4587`, delivery `01c7b045-faea-4722-b178-9f5a942c9e44`
(76 MB). The whole chain ran from the CLI (bump 6 configs → archive → export → validate → upload →
attach build → What's New both locales → review notes → Game Center → submit).
**⚠️ 1.8 STARTED AS A 1.7.1 PATCH AND IS NOT ONE — know this before reading its diff.** Build 56 was
cut on 3 Sep, so EVERYTHING merged to `main` after that date shipped in this build: multi-city
rotations (Phases 1–2) · the crew training pipeline + Training Centre + Chief Pilot · MX moved to its
own **Fleet ▸ Maintenance** segment · the four gameplay fixes (real carrier hubs, acquisition MX
seeding, buyback repricing, live subsidiary P&L) · the transpacific routing fix · Ops drawers/red
chips/auto-slow restore · and the eight hang fixes. The designer confirmed shipping it all together
rather than splitting a linear history to isolate the fixes.
Copy kept at `aa-1.1.x/whats-new-1.8.0.md` + `aa-1.1.x/app-review-notes-1.8.0.txt`.
⚠️ **ASC CAPS App Review notes at 4000 CHARACTERS** — the first 1.8 draft was 4571 and would have
silently truncated the 4.3(a) argument mid-sentence. Check the length before pasting; 1.8's final is
3975. **4.3(a) is now easier: Vineyard Architect is APPROVED**, so the verifiable-titles line names
three independently-approved titles (Airline, FC, Vineyard) instead of two.

**1.7.0 (build 56) went LIVE — `READY_FOR_SALE` (confirmed via the ASC API 8 Sep; submitted 3 Sep,
approved since). Next new build = 57+.** Two live consequences: it is the first build whose MetricKit
reports carry **build-at-occurrence tagging** (so the TelemetryDeck Errors dashboard can finally
separate stale hangs from live ones — group by MESSAGE, not by error id, since the tag rides in the
message field), and it put the **100× speed pill** in players' hands on a sim whose tick loop runs on
the MainActor. The whole chain ran from the CLI: bumped 1.6.0→1.7.0 / 55→56
(6 configs), archived→exported→validated (VERIFY SUCCEEDED)→uploaded (UPLOAD SUCCEEDED, Delivery UUID
`40110d3c-3dfa-4587-991f-c6628f26ad98`, 78.5 MB), build 56 attached, review submission
`92dd48c8-b6a5-49fa-8f89-f375d5a29ef3` submitted. **The designer's 40 new city hero images LANDED and
were BUNDLED** (108 city + 9 archetype; `archetype-audit` bundled-set updated to 108, all 40 excluded
from the priority list). ASC v1.7 record `e3ec8afb-6d8d-42fe-ad41-efbf301f2679`: en-US+de-DE What's New
set, App Review notes set (§1 4.3(a) block, `aa-1.1.x/app-review-notes-1.7.0.txt`), GC per-version
checkbox enabled. Commits `901bb53`+`2a5e5d3` pushed. 1.7 = the **MX maintenance program** (Line/A/C/D scheduled
checks, OPS ▸ MX; `MX_PROGRAM_SPEC.md`) + the **MX expanded-Details view & like-size route-coverage
flow** (Details with cost/downtime/surcharge/grounding; C/D covered by a comparable spare that
reclaims on shop-return, or acquire one → Fleet Marketplace auto-covers, or suspend the route; C/D
forced-grounding fixed to a calendar grace; `MXCoverageVerify.swift` 81/81) + the **3 player-feedback
fixes** (crew tuning, 100× speed pill + auto-slow-on-event, route-swap hint) + the **auto-slow alert
banner** (persists until tapped, custom Figma gauge) + **on-brand Figma milestone/banner icons**
(`MilestoneIconArt.swift`, node 150:998, keyed by SF-Symbol name; hub badges use the hub-building art
since `building.2.fill`→a tag=acquisition; Finance Pro seal stays SF) + **real launch-date game start**
(`startOnRealDate`, real date+season+year on the 30-day calendar; `calendarStartYear` persisted) +
**German** for every new string. The SHELVED PM budget stays on `maint-budget-t22` (don't re-attempt
unless AOG frequency is raised). `aa-1.1.x/HERO-PROMPTS-75.md` (next-75 hero list) is on `main` for the
designer to produce/stage 50 — bundle them before the build if they land, else a fast follow-up.
Bump to **1.7.0 / build 56** (6 pbxproj configs each). ⚠️ **App Review
4.3(a) went ACCOUNT-WIDE this week (Vineyard/Foundry/FC-1.3 rejected, appeal filed) — every Airline
submission now leads its App Review notes with the studio-context block; 1.4.3 was the first, approved
same day. Reuse `aa-1.1.x/app-review-notes-1.4.3.txt`; playbook in `PostmarkOps/APP_REVIEW_NOTES.md`.** The 1.4.1 story below is kept for its GC detail. After 1.4 went live the designer checked the App-Store build on-device: the Apple
Games dashboard was STILL EMPTY for AA, so the "the public GC-carrying release heals the stale
server-side record" theory (and its "1.4's release IS the heal mechanism" claim above) is WRONG —
a live + reporting build did NOT wake the record. FC Architect's device A/B found the actual
trigger: a `GKAchievement.report` → `loadAchievements` ROUND-TRIP from a signed-in device (AA
reported but never loaded — the missing half). 1.4.1 adds the load call (`wakeAccountRecord`),
which is device-verified to populate the Apple Games app — but the native `GKAccessPoint` rocket
STILL opens a blank in-app dashboard (a separate GameKit issue, confirmed on FCA too), so **the
rocket stays OFF** (no in-app GC entry point). 1.4.1 ALSO carries the Tech Ops work (RC/Telemetry
externalization + Test Store + MetricKit — see "Decided — Tech Ops modernization"). Build 50 (the
GC-only cut) is superseded by build 51 — attach 51. Next new build after 51 must be **52+**. Query review
state directly rather than trusting any doc's snapshot:
`cd ~/Architect\ Universe/~PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`

## Working agreement for future sessions

1. Read this file. Read `TASKS.md` for what's actually in flight.
2. If you make a decision that should bind future sessions, ADD it to the
   appropriate "Decided" section above, in the same terse style, with the
   real-world reasoning if there is one. Don't just fix code — update this
   file in the same commit/session.
3. If you find a "Decided" item that's wrong, don't silently override it —
   flag it explicitly, explain why, and update this file to reflect the
   correction with a short note on what changed and why (see the map
   basemap reversal above for the pattern: state that an earlier call
   changed, not just what's true now).
4. The prototype-reference numbers (tick durations, AOG rates, crew ratios,
   revenue ranges) came from real back-and-forth tuning or real-world
   sourcing, not arbitrary placeholders — EXCEPT where explicitly flagged
   above as an estimate (regional-jet weights, intra-family splits,
   regional-jet crewsPerTail). Port faithfully; don't casually re-round
   "for cleanliness," and don't upgrade a flagged estimate to treated-as-fact
   without actually sourcing it.
5. This file has drifted badly out of sync with the actual code multiple
   times in a single session before (five distinct gaps accumulated before
   this rewrite: fee model, map position source, label clustering, real
   basemap, and the fleet expansion). If you make a code change that
   contradicts something written here, update this file in the SAME
   response, not "later" — later is how the drift happened the first time.
