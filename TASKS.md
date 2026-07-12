# TASKS

Manually maintained. Update this when you start/finish something so the next
session (you tomorrow, or a different agent) doesn't have to guess what's
actually in flight vs merely planned in ROADMAP.md.

Format: `- [ ] Task — owner/session note — status`

This file went badly stale between updates — it described "repo just
scaffolded" for an extended stretch while the browser prototype grew from
a 6-type/7-airport smoke test into a 30-type/48-airport sim with a real
economy (sell, buy, lease, a used-aircraft market, a genuine player route
network, and a twice-rebuilt crew system), real player/competitor airline
identity, pan/zoom map, and Figma-sourced icons. See `CLAUDE.md` for the
actual technical detail on all of it; this file is just the task-tracking
layer. Don't let it drift this far again — update it in the same session
as the work, not "later."

## In progress

- [ ] The full system — fleet, airports, economy, route network, leasing,
      the used-aircraft market, crew, airline identity — has NOT been
      playtested as one continuous session. Every individual piece has
      been spot-checked or numerically verified, but that verification
      has a long, real, DEMONSTRATED catch rate at this point, not a
      theoretical one: the `operatingCost` ReferenceError, three separate
      instances of the same panel-flicker bug, a lease-proration bug that
      made leasing nearly dominant, a phantom-crew-family bug, background
      traffic generating real player decisions, crew duty time never
      actually accumulating across flights, decision cards going stale
      when resolved outside their own buttons, and aircraft color/flight-
      path rendering bugs that only became visible through actual play —
      all shipped once, all only caught after the fact (through a bug
      report or a direct question), none caught by the verification that
      shipped them. This is still the single most valuable next step
      before adding more scope — see `CLAUDE.md`'s Open section for the
      full reasoning.

## Phase 0 — DONE (native project foundation)

- [x] Create real Xcode project shell on a Mac — SwiftUI + SwiftData
      template, `SkyOps/SkyOps.xcodeproj`. Builds clean on the iPhone 17
      Pro simulator (`** BUILD SUCCEEDED **`), launches to the template's
      placeholder to-do UI. Verified via `xcodebuild` + simulator launch.
- [x] Decide SwiftData vs Core Data — SwiftData (kept the template's
      choice; matches the CLAUDE.md "leaning SwiftData" call).
- [x] Confirm min iOS version — set to iOS 18.0 across all three targets
      (was 26.5 from the template default). Nothing in the port needs
      26-only APIs, so 18 maximizes reach at no technical cost.
- [ ] Get Figma file link from designer, pull first screen via
      `Figma:get_design_context` — DEFERRED to Phase 4 (this is UI-layer
      work; Figma MCP also needs authorizing in an interactive session
      first). Note: the Figma MCP tool returns flattened raster exports
      for at least some node types regardless of query params — confirmed
      during icon work, see `CLAUDE.md` Icons section — verify early
      whether this affects full-screen mockups too.

## In progress (Phase 1 — port the validated tick engine)

- [ ] One aircraft flies one route in SwiftUI on the SAME state machine /
      tick durations as the JS prototype (ported verbatim, not re-derived
      — takeoff/landing must NOT visually jolt).

## Blocked

- [ ] Nothing currently blocked.

## Done — original scaffold

- [x] Fleet composition + aircraft type costs researched and sourced
      (real 2025-26 public data, not invented numbers)
- [x] Crew type-locking + per-family pools designed and validated
- [x] Repo scaffolded: README, CLAUDE.md, ROADMAP.md, this file
- [x] swiftui-pro / swift-concurrency-pro / swiftdata-pro skills reviewed
      (MIT-licensed, real content, not stubs) and installed for chat-session use

## Done — fleet expansion

- [x] Browser JS prototype validated: tick engine, multi-aircraft scaling,
      crew rest, weather, AOG (calibrated + clustered), hover tooltips,
      speed controls. See `prototype-reference/`.
- [x] Fleet expanded from 6 types / 4 crew families to 31 types / 13 crew
      families — every real named variant (A319/A320/A321 ceo+neo,
      737 NG+MAX, E-Jets, CRJ, ERJ, A220, 4-engine widebodies, ARJ21) as
      its own entry, crew pools following real type-rating groupings
      (coarser than the type list — E-Jets notably split into TWO crew
      families despite one marketing name). Fleet spawn weights are
      real-world-proportional (sourced global in-service fleet counts).
      Sukhoi Superjet 100 was later removed (reasoning not documented,
      see `CLAUDE.md` Open section).
- [x] 4 real Figma-sourced vector icon tiers (regionalJet, narrowbody,
      widebody2Engine, widebody4Engine), replacing the generic fallback
      triangle. Sized +15% from original ship values per designer
      feedback; relative hierarchy verified by script after the change.

## Done — map + geography

- [x] Real lat/lon-based airport positions (equirectangular projection),
      replacing hand-placed x/y coordinates.
- [x] Airport network expanded from 7 placeholder airports to 48 real
      U.S. airports (top-50 by fee, minus 2 cross-batch duplicates),
      each with real landing/gate fees and ground-stop rates.
- [x] Real U.S. nation outline + state borders (Natural Earth data via
      `us-atlas`), including Alaska and Hawaii (added after an initial
      gap where those two states had no landmass shape).
- [x] Canada added as a muted background-context layer (`world-atlas`
      npm package — new dependency) so Alaska doesn't read as a
      disconnected blob in empty ocean space.
- [x] Pan (drag) + zoom (scroll wheel, cursor-anchored) camera system —
      the desktop-appropriate equivalent of pinch-zoom, built as real
      reusable infrastructure (not a continental-only patch) since the
      designer's stated direction is an eventual global map.
- [x] Airport dot / label sizing and aircraft icon sizing both tuned
      through real designer feedback iteration: v1 (airports fully
      zoom-invariant, aircraft fully zoom-proportional) -> v2 (both share
      one damped curve -- flat until default zoom, then capped at +15%
      growth at max zoom).
- [x] Label decluttering for close-together airport clusters (leader
      lines + fan-out), generic over whatever's in the airport list --
      automatically picked up new clusters as the network grew to 48.

## Done — economy

- [x] Real per-flight revenue formula (seats x load factor x average
      fare per seat, real 2025-26 sourced baselines), replacing an
      arbitrary random-range placeholder.
- [x] Real per-flight operating cost, charged on every flight (not just
      held ones) -- required fixing a real design bug where cost spikes
      had paradoxically been making the airline MORE profitable net-net.
- [x] Randomized economic events (Oil Price Spike, Fuel Price Drop,
      Economic Boom, Recession) with real-anchored magnitude, modulating
      cost/fare/load together.
- [x] Real weight-based landing fees and body-type-tiered gate fees,
      replacing flat per-airport placeholders.
- [x] Financials UI rebuilt as a stacked ledger (Revenue / -Operating
      Costs / -Fees / =Net Revenue) instead of a single formula string;
      same breakdown surfaced in the aircraft hover tooltip.
- [x] A real ship-blocking bug (`ReferenceError: operatingCost is not
      defined`, firing on most flights) was caught and fixed after a
      refactor left one reference unmigrated -- this changed the
      project's verification practice going forward (see `CLAUDE.md`
      Economy section): `node --check` alone doesn't catch undefined-
      variable references, only actual parse errors. An ESLint
      `no-undef` pass now runs alongside it before anything ships.

## Not yet started — beyond current scope

- [ ] Player-funded route marketing (view loads by route/origin, spend to
      boost them) — genuinely separate from the airport-incentive
      mechanic below, needs its own load-visibility UI.
- [ ] Airport-incentive-offer mechanic — bottom-15 airports offering
      waived fees + marketing support, with a real clawback penalty for
      abandoning the route early. Explicitly sequenced as Phase C/D,
      held until the route-opening foundation (Phase A/B, now done and
      shipped) could be felt in actual play first.
- [ ] Route profitability chart visualization — the data model
      (`route.history`) is real and verified sufficient to build this;
      the actual chart doesn't exist yet.
- [ ] Bankruptcy / negative-balance consequences — `playerBalance` can go
      negative (confirmed via lease billing) with no consequence beyond
      red text and being blocked from further purchases.

## Done — fleet lifecycle & ownership economy

- [x] Bombardier CRJ700 removed from the fleet (aging out of most real
      fleets, nearing retirement, per designer direction) — 30 types now.
      Designer has stated an ongoing intent to keep the fleet current
      with real deliveries/retirements; expect more changes like this.
- [x] Real `purchasePrice` added to every type — median of designer-
      sourced published list price and estimated market value, or a
      documented discount-ratio extrapolation where only one figure
      existed (regional-jet vs. narrowbody discount ratios differ
      meaningfully, ~0.66 vs ~0.46 — handled per-category, not blended).
- [x] Real `expectedLifespanCycles` added to every type — real FAA/
      manufacturer Design Service Goal data for well-established
      families, extrapolated from a confirmed real figure for regional
      jets lacking published data.
- [x] Cycle-based lifespan mechanic: 1 cycle = 1 completed flight,
      tracked per aircraft, 80% threshold triggers a real sell decision
      through the same AOG/CREW decision-card system.
- [x] Real sell mechanic: linear depreciation from purchase price,
      floored at 5%, verified against a designer-specified example
      before shipping.
- [x] Real buy mechanic: a minimal stand-in `playerBalance` (accumulates
      net flight revenue + sell proceeds — explicitly NOT the full Phase
      5 economy), a Buy Aircraft panel listing all types with live
      affordability, purchased aircraft starting genuinely fresh (0
      cycles, PARKED).
- [x] A real bug caught before it could destroy a player's purchase: the
      stress-test fleet slider's old truncation logic would have
      silently deleted purchased aircraft. Fixed by protecting purchased
      aircraft from slider shrinkage; verified numerically including the
      extreme case.
- [x] A real bug fixed after being reported: the decision panel (AOG/
      CREW/SELL) flickered and unreliably registered clicks, caused by a
      per-tick full DOM rebuild. Fixed by removing the redundant per-tick
      render call — the two structural triggers (decision added/
      resolved) were already correct and sufficient on their own.

## Done — real starting capital

- [x] Starting capital: $20M, calibrated to cover the cheapest aircraft
      plus a typical route-opening cost with buffer. A fresh session now
      starts with real capital, no planes, no routes, and zero background
      traffic — an actual new-game experience, not a stress-test default.

## Done — leasing

- [x] Real leasing mechanic alongside buying: 15% of purchase price
      upfront (designer-specified), real sourced monthly rate (0.8% of
      aircraft value — industry lease-rate-factor data, cross-validated
      against real quoted dollar figures). ACQUIRE AIRCRAFT panel (renamed
      from BUY AIRCRAFT) shows Buy and Lease as two independent options
      per type.
- [x] A real bug caught mid-build: the first version prorated lease cost
      per-flight (same as operating cost), which made leasing nearly
      strictly dominant — an idle leased aircraft cost nothing, so the
      real downside risk of a fixed obligation was missing. Fixed with a
      genuine recurring-billing mechanism (`tickLeaseBilling()`) charging
      every leased aircraft monthly regardless of flying/idle/held status.
      Verified numerically: an idle leased aircraft now genuinely loses
      money over time with zero revenue.
- [x] Lease cost is a real separate line item in report views (financials
      ledger, route detail panel) but folds into the tooltip's displayed
      "Operating cost" as a smoothed estimate, per designer direction —
      too much detail for the in-flight view.

## Done — real player route network

- [x] The foundational shift: purchased aircraft no longer fly random
      destinations. They fly only between airports the player has
      explicitly opened a route between, swapping direction each cycle.
      An unassigned purchased aircraft is a real idle spare, not wandering
      traffic. Background stress-test traffic is unaffected — still fully
      random by design.
- [x] Abstract airport slot scarcity (no real competitor-airline modeling
      — deliberately deferred, matching `ROADMAP.md`'s existing scope
      decision), scaled to real landing-fee data already in the game.
- [x] Real route-opening cost, built from real data already in the game
      (base fee + both endpoints' gate fees), landing in a real
      $68K-$275K range.
- [x] Route-opening UI rebuilt from dropdowns (which hit the same
      flicker bug as the decision panel) to real click-to-select-on-map:
      click OPEN ROUTE, click origin, click destination, confirm panel
      with live cost/slot data. Basic mobile tap support included.
- [x] Buying/leasing an aircraft while mid-route-selection auto-assigns
      it to the pending route — the whole "realize you need a plane,
      buy one, route opens" flow now completes in one pass. A second
      ACQUIRE AIRCRAFT button lives inside the route-confirm panel itself.
- [x] Deterministic route-economics preview in the route-confirm panel —
      real distance (haversine), revenue/fees/operating cost/net for a
      round trip, using a real spare's actual type if one exists.
- [x] Real per-flight simulated load tracking: the aircraft tooltip shows
      actual pax/seats/load% for the current flight — previously
      computed internally and immediately discarded, now captured and
      displayed.
- [x] Real route-level profitability, weighed against actual
      establishment cost — a route isn't "profitable" until cumulative
      net revenue recoups what it cost to open, not just whenever one
      flight nets positive. Reduced by real lease bills too, not just
      flight economics.
- [x] Full per-flight route history (revenue, fees, costs, load, net,
      cumulative net per flight) — real data, verified sufficient to
      support a future profitability-over-time chart (not built yet).
- [x] Routes are archived, not deleted, when closed — selling a
      route-assigned aircraft used to destroy the route's history
      entirely; now moves to a real archive with a close date stamped on.
- [x] A dedicated ROUTES panel: list view of every route (open and
      closed), tap for full detail (dates, flights flown, financials,
      assigned-aircraft history, recent-flights log).

## Done — crew system rebuilt (twice)

- [x] Crew provisioning changed from automatic ratio-based sizing to
      player-driven hiring. Buying/leasing an aircraft bundles exactly 1
      crew (deliberately not enough for continuous operation); growing
      the pool further requires the new ADD CREW panel with a real
      designed hire cost, scaled by aircraft complexity.
- [x] A real reported bug fixed: crew pools showed a phantom minimum
      ("1/0/0 · 2 res") for every family regardless of ownership. Fixed
      at the root — `resizeCrewPools()` no longer auto-sizes by ratio at
      all, it's a pure cleanup pass now.
- [x] A second real reported bug fixed: AOG, crew-shortage, and
      sell-eligibility decisions were firing for background traffic the
      player doesn't own. Fixed across five functions — background
      traffic now has zero economic/decision stakes, confirmed via
      individually checking every other fleet-wide loop in the codebase
      to make sure this wasn't a sixth instance hiding somewhere.
- [x] Reserve crew count corrected: 1 per family (not 2) — a family's
      first aircraft should grant 2 crew total (1 bundled + 1 reserve),
      not 3.
- [x] Background traffic given a distinct color scheme, reduced hover
      tooltip (Route/Tail/Type/Status only — no performance data). NOTE:
      the color scheme changed twice after this — first blue/orange
      (flying/ground) vs. the player's green/amber, later simplified to
      one constant color (`#B25BFF`) regardless of state. See the
      rendering-fixes batch below for the current, correct version —
      this entry is kept for history, don't treat "blue/orange" as
      current.
- [x] A real, substantive bug fixed after direct questioning, not a bug
      report: crew duty time never actually accumulated across flights.
      `dutyTicks` was reset to 0 on every new assignment, meaning a lone
      crew member could fly indefinitely without ever hitting real rest
      (a single flight cycle is well under the duty ceiling). Fixed to
      match real FAA Part 117 mechanics — duty time now carries across
      consecutive assignments, only clearing after an actual completed
      rest period. Also caught and corrected in the same pass:
      `REST_TICKS` was wrong (480/8hr), not just simplified — real Part
      117 minimum rest is 10 consecutive hours. Verified via simulation:
      a lone crew member now flies exactly 2 consecutive cycles before
      mandatory rest blocks a third.

## Done — decision panel fixes

- [x] A real reported bug: decision cards went stale when resolved
      through a path OTHER than that card's own buttons (hiring crew via
      ADD CREW while a CREW hold was showing). Root cause affected AOG's
      timed auto-repair too, caught by checking rather than assuming the
      fix was narrowly scoped. Fixed with a real cleanup function called
      from both actual resolution points.
- [x] CREW decision now has a real third option, "Hire new crew" —
      reuses the same `hireCrew()` function as the standalone panel, not
      a duplicate implementation.

## Done — used aircraft market

- [x] Real used-aircraft market: buy-only, persistent inventory (1-2
      listings per type, generated once, slowly replenished over time).
      Pricing reuses the exact same linear depreciation formula as the
      sell mechanic, per designer direction for consistency. Real market
      research behind it: a genuine $1.96B+ industry segment, real
      depreciation curve cross-checked against an actual Boeing 737-800
      example. Verified end-to-end with the real extracted functions —
      listing generated, purchased, balance deducted exactly, the
      resulting aircraft correctly inheriting the used cycle count
      instead of starting fresh.

## Done — rendering fixes

- [x] A real reported bug: flight-path arcs looked disproportionately
      curved on short routes. Root cause was a fixed 90px arc height
      regardless of actual distance between airports. Fixed to scale
      with real distance (12% of straight-line distance, floored at
      15px, capped at 120px) — verified numerically.
- [x] A real reported bug: aircraft color stayed in the wrong flight-
      phase color too long, both at takeoff and landing. Root cause:
      color was picked from an altitude THRESHOLD that never actually
      lined up with the real state machine (TAKEOFF's altitude curve
      never even crosses the old threshold; APPROACH stayed above it for
      ~71% of its duration). Fixed to key color directly off the real
      state instead — three real colors for the player's own aircraft
      (takeoff/climb, cruise, descent/landing), applied the same
      state-based fix to background traffic too for the same accuracy
      reason.
- [x] Background traffic's color simplified to one constant color,
      replacing an earlier two-tier scheme from the same session — makes
      it instantly recognizable as "not mine" regardless of flight
      phase. NOTE: this value was tweaked again later in the same
      session (`#B25BFF` -> `#D767FF`, "wasn't popping enough") — see the
      color-tweaks batch below, don't treat `#B25BFF` as current.

## Done — airline identity & competitor traffic

- [x] Player airline naming: a styled modal blocks the game on load,
      asking the player to name their airline. Shown as the first line
      in the player's own aircraft tooltip.
- [x] Real-world-weighted competitor airlines assigned to background
      traffic — actual 2025-26 US domestic market share (BTS/OAG/
      Statista, cross-checked across five sources). Original version
      restricted eligibility by aircraft BODY TYPE (narrowbody/widebody/
      etc) — see the REBUILD below, this is superseded, not current.
- [x] Alaska Airlines roster entry updated mid-session for a real,
      independently-verified 2026 news development (absorbed Hawaiian's
      787 fleet, launched real widebody international routes from
      Seattle) — confirmed via search before changing anything, not
      taken on request alone, though it matched.

## Done — fleet-accuracy rebuild, certification gating, A330/A350

- [x] Airline eligibility REBUILT from body-type-category restriction to
      real SPECIFIC-aircraft-type restriction — prompted by a real
      concern ("a player will notice if Airline X doesn't fly type Y").
      Every airline's eligible-types list is now individually researched,
      not a category. Real findings, several of which corrected
      assumptions rather than confirmed them: Delta's widebody fleet was
      100% Airbus (none modeled in this game at the time — see A330/A350
      below); Delta flies no 737 MAX at all; United flies A321neo but no
      A321ceo; JetBlue retired its last E190 in Sept 2025; Emirates flies
      no 787 at all; Lufthansa flies no Boeing 777 passenger service at
      all — but IS confirmed the world's largest A340 operator in 2026
      (14 -300s + 5 -600s, kept flying due to 777X delivery delays), the
      opposite of the "probably retired" assumption made before checking.
      Types with no real match anywhere in the roster (A319neo, E190,
      E195, ERJ135/140, ARJ21) fall to a generic "Independent Operator"
      fallback rather than a forced fake match. Verified via script that
      every type in the fleet resolves to at least one eligible airline
      (no crash risk), and via real 10,000-20,000-sample distribution
      checks that the weighted outcomes match the real sourced
      percentages.
- [x] A new, real design principle: aircraft must be actually FAA/ICAO
      certified AND in real service to stay in this fleet — an order or
      certification-pending status isn't enough. Established by removing
      Boeing 737 MAX 7 and MAX 10 entirely (verified via search: neither
      was certified as of this game's real current timeframe, first
      deliveries not until 2027 even after certification). Same bar then
      applied to Delta's real Jan 2026 787-10 order — confirmed real, but
      deliberately NOT added to Delta's fleet yet since an order isn't a
      delivery.
- [x] Airbus A330-900 and A350-900 added — specifically to give Delta a
      real widebody fleet in this game (their actual widebody fleet is
      100% Airbus). Real sourced specs (MLW, seats matching Delta's own
      cabin config, market-value-based purchase price, not Airbus sticker
      list price). Also added to Air France (both), Lufthansa/British
      Airways/Japan Airlines (A350 only), Air Canada (A330 only) — each
      individually confirmed, not assumed uniform. A real correction
      surfaced while researching this, unrelated to the reason for the
      search: Air France's A380 fleet was fully retired by 2022 and had
      never been re-verified since the original roster build — fixed in
      the same pass.

## Done — color tweaks

- [x] Background traffic color: `#B25BFF` -> `#D767FF` ("wasn't popping
      enough"). Player aircraft cruise color: `#6CD3FF` -> `#83C9FF`
      (better contrast).
