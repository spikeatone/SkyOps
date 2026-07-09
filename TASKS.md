# TASKS

Manually maintained. Update this when you start/finish something so the next
session (you tomorrow, or a different agent) doesn't have to guess what's
actually in flight vs merely planned in ROADMAP.md.

Format: `- [ ] Task — owner/session note — status`

## In progress

- [ ] Nothing in progress right now — v12 fee/map work (below) just landed.

## Up next (Phase 0)

- [ ] Create real Xcode project shell on a Mac
- [ ] Decide SwiftData vs Core Data — leaning SwiftData, not final
- [ ] Get Figma file link from designer, pull first screen via
      `Figma:get_design_context`
- [ ] Confirm min iOS version

## Blocked

- [ ] Nothing currently blocked.

## Done

- [x] Browser JS prototype validated: tick engine, multi-aircraft scaling,
      crew rest, weather, AOG (calibrated + clustered), fees, revenue erosion,
      hover tooltips, speed controls. See `prototype-reference/`.
- [x] Fleet composition + aircraft type costs researched and sourced
      (real 2025-26 public data, not invented numbers)
- [x] Crew type-locking + per-family pools designed and validated
- [x] Repo scaffolded: README, CLAUDE.md, ROADMAP.md, this file
- [x] swiftui-pro / swift-concurrency-pro / swiftdata-pro skills reviewed
      (MIT-licensed, real content, not stubs) and installed for chat-session use
- [x] v12: real landing fee model — signatory rate ($/1,000 lbs) × aircraft
      max landing weight, replacing flat per-airport fee. `mlwLbs` added to
      `AIRCRAFT_TYPES`.
- [x] v12: real gate fee model — narrowbody/widebody tiers via new explicit
      `bodyType` field (also now drives the on-scope rendering scale, one
      definition instead of two).
- [x] v12: airport network expanded from 7 placeholders to the real top-25
      U.S. airports (designer-sourced landing/gate fees + real per-airport
      ground-stop frequency, replacing one flat rate applied to everyone).
- [x] v12: airport positions now computed from real lat/lon via a map
      projection instead of hand-placed x/y; NYC-area and South Florida
      label crowding fixed with leader-line decluttering (stopgap pending
      real pinch-zoom — see CLAUDE.md "Open").
- [x] v12: real continental-U.S. outline + state borders rendered under the
      airports (Natural Earth data via `us-atlas`, not hand-drawn), sharing
      the same projection as airports so nothing can drift out of alignment.
      Reverses an earlier "projected positions only" call — see CLAUDE.md.
- [x] CLAUDE.md updated to reflect all of the above in "Decided" / "Open".

## Needs playtesting (not yet done — flagged, not verified)

- [ ] Crew/AOG/weather behavior against the new 25-airport network and real
      per-airport ground-stop rates hasn't actually been played yet. Airport
      count and route-assignment distribution changed materially from the
      original 7; a given aircraft's odds of repeatedly cycling through a
      high-ground-stop airport (EWR, 14.2/mo) vs. a near-zero one (LAX,
      0.1/mo) are now real and untested, not just theoretically calibrated.
