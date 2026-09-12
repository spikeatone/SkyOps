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

> ~29 bullets that had been RESOLVED / BUILT / SHIPPED (or gone stale and been corrected) were
> moved out of this list on 2026-09-12 to keep it to genuinely-open questions. Their full text is in
> **`CLAUDE_HISTORY.md` § "Resolved items (moved from CLAUDE.md 'Open' list, 2026-09-12)"** —
> persistence, route competition, player competition actions, reputation, hub effect, delight pass,
> the cold-launch splash + backdrop lineage, haptics/SFX, pinch-zoom, label declutter, bankruptcy,
> the profitability chart, the route-marketing/incentive layer, and the Xcode-shell / README stale
> claims. A few carried an active rule; the tight version of each is kept just below.

**Active rules kept from resolved bullets:**

- **Persistence is a plain Codable JSON snapshot — NOT SwiftData.** `Persistence.swift`
  (`GameSnapshot` + `GameStore`, `Documents/savegame.json`); `Simulation.snapshot()`/`restore(from:)`
  live IN Simulation.swift to set the `private(set)` state. **Persisted:** identity, balance, tick, all
  economy accumulators, PURCHASED aircraft, open+closed routes (with history), crew pools/reserves,
  finance snapshots, camera, firedMilestones, traffic count. **NOT persisted (regenerated on load):**
  background/competitor traffic (`setFleetSize(savedCount)`), live event effects (→ Normal), used
  market, airport ground-stops (cleared), slots (re-provisioned then decremented per open route).
  SwiftData model classes are present but UNUSED — don't "restore" them. (history: § Resolved items.)
- **Region rosters are hand-curated literals with NO self-updating mechanism.** 8 region rosters in
  `Airline.swift` (+ US default), classified by `region()`/`roster(for:)`/`pick(...)`. Corrections get
  applied only because someone reported and independently verified them — treat every roster entry as
  due for eventual re-verification. (history: see CLAUDE_HISTORY.md § Resolved items.)

**Genuinely open:**

- Figma → SwiftUI pipeline: designer has real mockups in Figma; pull via
  Figma MCP `get_design_context` against actual file/node URLs, don't
  guess at layouts from descriptions. Note the raster-export limitation
  documented above under Icons — full-screen mockups may hit the same
  wall the icon nodes did; verify early rather than assuming it'll work.
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
