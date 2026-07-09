# TASKS

Manually maintained. Update this when you start/finish something so the next
session (you tomorrow, or a different agent) doesn't have to guess what's
actually in flight vs merely planned in ROADMAP.md.

Format: `- [ ] Task — owner/session note — status`

This file went badly stale between updates — it described "repo just
scaffolded" for an extended stretch while the browser prototype grew from
a 6-type/7-airport smoke test into a 31-type/48-airport sim with a real
economy, pan/zoom map, and Figma-sourced icons. See `CLAUDE.md` for the
actual technical detail on all of it; this file is just the task-tracking
layer. Don't let it drift this far again — update it in the same session
as the work, not "later."

## In progress

- [ ] Full 31-type / 48-airport / economic-event system has NOT been
      playtested as one continuous session — every individual piece has
      been spot-checked (icon rendering, weight math, fee calculations,
      zoom-scale curves) but nobody has watched it all run together for
      an extended real session. This is the single most valuable next
      step before adding more scope — see `CLAUDE.md`'s Open section for
      why this matters more than it might sound.

## Up next (Phase 0 — still not started, unchanged since original scaffold)

- [ ] Create real Xcode project shell on a Mac
- [ ] Decide SwiftData vs Core Data — leaning SwiftData, not final
- [ ] Get Figma file link from designer, pull first screen via
      `Figma:get_design_context` (note: the Figma MCP tool returns
      flattened raster exports for at least some node types regardless of
      query params — confirmed during icon work, see `CLAUDE.md` Icons
      section — verify early whether this affects full-screen mockups too)
- [ ] Confirm min iOS version

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

## Not yet started — economy layer beyond current scope

- [ ] Player-facing purchase economy (buying aircraft, paying to open
      routes) -- design intent captured in `ROADMAP.md` Phase 5, nothing
      built. Real constraint flagged there: real aircraft prices run
      hundreds of millions, this sim's revenue is tens of thousands per
      flight -- needs deliberate game-balance work, not a real-price import.
