//
//  Simulation.swift
//  Airline Architect — Phase 1–2
//
//  Owns the world (airports + aircraft) and the tick clock. The tick loop is a
//  Swift-Concurrency async task, decoupled from the render frame rate exactly
//  like the prototype's requestAnimationFrame accumulator: 1 tick = BASE_TICK_MS
//  of real time at 1× speed, divided by the speed multiplier, capped at 50
//  catch-up ticks per wake so a stall can't spiral. The view re-renders on each
//  tick (MapView takes `tick` as a value input) and reads current positions.
//

import Foundation
import Observation
import CoreGraphics

@MainActor
@Observable
final class Simulation {

    /// Real-time milliseconds per tick at 1× speed (prototype BASE_TICK_MS).
    static let baseTickMs: Double = 250

    private(set) var tick: Int = 0
    private(set) var airports: [Airport] = []
    private(set) var aircraft: [Aircraft] = []

    /// Prototype: passenger-demand model (load factor = route demand vs. aircraft
    /// capacity). ON by default; a DEV toggle can flip it OFF to A/B against the
    /// old flat-load-factor economy. See `Demand` in Economics.swift.
    var useDemandModel = true

    /// Convenience for the UI: this route's estimated daily one-way demand, and
    /// the load factor a given aircraft would fly it at (for the route-open panel).
    func routeDailyDemand(_ a: Airport, _ b: Airport) -> Int { Int(Demand.dailyOneWay(a, b).rounded()) }
    func projectedLoadFactor(seats: Int, from a: Airport, to b: Airport) -> Double {
        Demand.loadFactor(seats: seats, dailyOneWay: Demand.dailyOneWay(a, b))
    }

    /// Speed multiplier. Prototype default is 5× (feels smooth; at 1× the
    /// aircraft visibly steps every 250 ms, which is expected, not a bug).
    private(set) var speed: Double = 5

    /// Selectable speeds (¼×/½× are the slow-mo tiers; ¼× is rate-limited).
    static let speedOptions: [Double] = [0.25, 0.5, 1, 5, 10, 25]

    // ¼× is rate-limited: 3 uses per FIXED sim-calendar-day (resets when the
    // day-of-sim number changes, NOT a rolling 24h window). Exhausting it snaps
    // speed to 1× (not back to the previous speed). Ported from the prototype.
    static let quarterSpeedDailyLimit = 3
    private(set) var quarterSpeedUsesToday = 0
    private var quarterSpeedDay = 0

    /// Uses of ¼× left today (the UI shows/greys the ¼× control by this).
    var quarterSpeedUsesRemaining: Int {
        let day = tick / 1440
        return day == quarterSpeedDay ? max(0, Simulation.quarterSpeedDailyLimit - quarterSpeedUsesToday)
                                      : Simulation.quarterSpeedDailyLimit
    }

    /// Set the speed, enforcing the ¼× daily rate limit. Requesting ¼× when
    /// it's exhausted snaps to 1× instead. Non-¼× speeds set directly.
    func requestSpeed(_ s: Double) {
        if s == 0.25 {
            let day = tick / 1440
            if day != quarterSpeedDay { quarterSpeedDay = day; quarterSpeedUsesToday = 0 }
            guard quarterSpeedUsesToday < Simulation.quarterSpeedDailyLimit else { speed = 1; return }
            quarterSpeedUsesToday += 1
        }
        speed = s
    }

    private var nextTailNum = 1

    // MARK: - Camera (pan / zoom), ported from the prototype's camera model.
    // Everything on the map lives in resolution-independent "unit" space; the
    // camera maps unit→screen each frame. Default view frames the continental
    // US (resetCameraToConus); zoom clamps to [0.4×, 28×].

    static let cameraMinZoom: CGFloat = 0.4    // out enough to see AK+HI+CONUS
    static let cameraMaxZoom: CGFloat = 28     // in close enough to inspect a single airport (was 14)
    private static let elementZoomGrowthMax: CGFloat = 0.15  // icon growth cap

    /// Horizontal wrap period in unit space = one full 360° of longitude. The map
    /// wraps around the world: panning east past the last airport rolls seamlessly
    /// back into the Americas (and vice versa). The rendered content actually spans
    /// ~390° (Alaska → Tahiti, because Tahiti is stored across the antimeridian), so
    /// there's a ~30° overlap of (near-empty) mid-Pacific at the seam — Anchorage
    /// and Tahiti are at the same real longitude and coincide there, which is why
    /// this tiling is correct rather than an error.
    static let wrapWidthUnits: CGFloat = 360 * GeoProjection.lonCorrection

    /// Zoom multiplier (× the whole-world fit). Observable → drives redraw.
    var cameraZoom: CGFloat = 1
    /// Unit-space point shown at screen centre. Observable → drives redraw.
    var cameraCenter: CGPoint = .zero

    private var viewport: CGSize = .zero
    private var worldScale: CGFloat = 1     // px per unit at zoom = 1 (whole world fits)
    private(set) var defaultZoom: CGFloat = 1
    /// Set once the user pans/zooms. Until then the view auto-frames CONUS on
    /// every size change, so a transient launch/rotation size can't lock the
    /// camera to the wrong framing.
    private var userAdjustedCamera = false

    // World and CONUS-frame extents in unit space (computed once).
    private static let worldUnitSize: CGSize = {
        let br = GeoProjection.unit(lat: GeoProjection.latMin, lon: GeoProjection.lonMax)
        return CGSize(width: br.x, height: br.y)   // top-left projects to (0,0)
    }()
    private static let conusFrame: (origin: CGPoint, size: CGSize, center: CGPoint) = {
        let tl = GeoProjection.unit(lat: 49.5, lon: -125)
        let br = GeoProjection.unit(lat: 24.5, lon: -66.5)
        let size = CGSize(width: br.x - tl.x, height: br.y - tl.y)
        return (tl, size, CGPoint(x: (tl.x + br.x) / 2, y: (tl.y + br.y) / 2))
    }()

    /// Ensure the camera is configured for the current viewport. Recomputes the
    /// whole-world scale and the CONUS-fit default zoom on size change; frames
    /// CONUS on first configure. Ported from resetCameraToConus() semantics.
    func configure(viewport size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if size != viewport {
            viewport = size
            let w = Simulation.worldUnitSize
            worldScale = min(size.width / w.width, size.height / w.height)
            let conus = Simulation.conusFrame
            let fit = min(size.width / (conus.size.width * worldScale),
                          size.height / (conus.size.height * worldScale)) * 0.92
            defaultZoom = min(Simulation.cameraMaxZoom, max(Simulation.cameraMinZoom, fit))
            // Auto-frame CONUS until the user takes manual control.
            if !userAdjustedCamera {
                cameraZoom = defaultZoom
                cameraCenter = conus.center
            }
        }
    }

    private var pixelsPerUnit: CGFloat { worldScale * cameraZoom }
    private var viewportCentre: CGPoint { CGPoint(x: viewport.width / 2, y: viewport.height / 2) }

    /// One wrap period in screen pixels at the current zoom.
    var wrapWidthPx: CGFloat { Simulation.wrapWidthUnits * pixelsPerUnit }

    /// Pixel x-offsets at which the whole world should be redrawn so it tiles
    /// across the viewport for the wrap-around effect. Always includes 0; adds
    /// the ±copies whose content actually intersects the viewport. Falls back to
    /// [0] if anything's degenerate.
    func wrapDrawOffsetsPx() -> [CGFloat] {
        let wpx = wrapWidthPx
        guard wpx > 1, viewport.width > 0 else { return [0] }
        let minX = project(.zero).x                                        // world left edge
        let maxX = project(CGPoint(x: Simulation.worldUnitSize.width, y: 0)).x  // world right edge
        let kMin = Int((-maxX / wpx).rounded(.up))
        let kMax = Int(((viewport.width - minX) / wpx).rounded(.down))
        guard kMin <= kMax, (kMax - kMin) <= 12 else { return [0] }        // sanity cap
        return (kMin...kMax).map { CGFloat($0) * wpx }
    }

    /// Minimal horizontal screen delta between two x's, accounting for the wrap
    /// (so a tap on any tiled copy of an airport still registers as that airport).
    private func wrappedDX(_ ax: CGFloat, _ px: CGFloat) -> CGFloat {
        let w = wrapWidthPx
        guard w > 1 else { return ax - px }
        var d = (ax - px).truncatingRemainder(dividingBy: w)
        if d > w / 2 { d -= w } else if d < -w / 2 { d += w }
        return d
    }

    /// Keep cameraCenter.x in [0, wrapWidthUnits) so it never drifts unbounded
    /// over a long session. A shift of exactly one period is visually invisible
    /// (the scene is periodic — the tiled copies fill in), so this can't jump.
    private func wrapCameraX() {
        let w = Simulation.wrapWidthUnits
        guard w > 0 else { return }
        cameraCenter.x = cameraCenter.x.truncatingRemainder(dividingBy: w)
        if cameraCenter.x < 0 { cameraCenter.x += w }
    }

    /// Unit → screen for the current camera. Airports and basemap both use this.
    func project(_ u: CGPoint) -> CGPoint {
        let ppu = pixelsPerUnit
        return CGPoint(x: (u.x - cameraCenter.x) * ppu + viewportCentre.x,
                       y: (u.y - cameraCenter.y) * ppu + viewportCentre.y)
    }

    /// Screen → unit (inverse), for gesture anchoring.
    func unit(fromScreen s: CGPoint) -> CGPoint {
        let ppu = pixelsPerUnit
        return CGPoint(x: (s.x - viewportCentre.x) / ppu + cameraCenter.x,
                       y: (s.y - viewportCentre.y) / ppu + cameraCenter.y)
    }

    /// Damped element-scale curve: airports/aircraft stay constant size up to
    /// the default zoom, then grow modestly to +15% and hold there. The growth
    /// range is anchored to a FIXED zoom span (not cameraMaxZoom) so raising
    /// the max zoom doesn't change how icons feel at the zoom levels the
    /// designer already tuned — extra zoom just keeps icons at the +15% cap.
    private var elementGrowthEnd: CGFloat { defaultZoom * 2.5 }

    var elementScale: CGFloat {
        guard cameraZoom > defaultZoom else { return 1 }
        let t = min(1, (cameraZoom - defaultZoom) / (elementGrowthEnd - defaultZoom))
        return 1 + Simulation.elementZoomGrowthMax * t
    }

    /// Airport labels grow like other elements, PLUS an extra +15% that ramps
    /// in between the element cap and the max zoom — so labels read 15% larger
    /// than everything else at the highest zoom (designer request), where
    /// there's room for it and legibility matters most.
    var labelScale: CGFloat {
        let extra = min(1, max(0, (cameraZoom - elementGrowthEnd) / (Simulation.cameraMaxZoom - elementGrowthEnd)))
        return elementScale * (1 + Simulation.elementZoomGrowthMax * extra)
    }

    /// Recompute every airport's screen position (call each frame after
    /// configure, since the camera can change between frames).
    func projectAirports() {
        for ap in airports { ap.screen = project(ap.unit) }
    }

    /// Nearest aircraft within `tolerance` screen points of a tap, or nil.
    /// Lives in the sim layer (not the view) so the headless harness can
    /// verify hit-testing without driving real touches.
    /// Nearest airport within `tolerance` of a tap (for the route picker).
    /// 44pt ≈ a fingertip; nearest-wins keeps dense clusters unambiguous.
    func airport(atScreenPoint p: CGPoint, tolerance: CGFloat = 44) -> Airport? {
        var best: (ap: Airport, d: CGFloat)?
        for ap in airports {
            let d = hypot(wrappedDX(ap.screen.x, p.x), ap.screen.y - p.y)
            if d <= tolerance && d < (best?.d ?? .infinity) { best = (ap, d) }
        }
        return best?.ap
    }

    func aircraft(atScreenPoint p: CGPoint, tolerance: CGFloat = 24) -> Aircraft? {
        var best: (ac: Aircraft, d: CGFloat)?
        for ac in aircraft {
            let pos = ac.position(tick: tick).point
            let d = hypot(wrappedDX(pos.x, p.x), pos.y - p.y)
            if d <= tolerance && d < (best?.d ?? .infinity) { best = (ac, d) }
        }
        return best?.ac
    }

    // MARK: - Camera controls (driven by gestures / buttons)

    func pan(by delta: CGSize) {
        userAdjustedCamera = true
        let ppu = pixelsPerUnit
        cameraCenter.x -= delta.width / ppu
        cameraCenter.y -= delta.height / ppu
        wrapCameraX()   // keep x bounded; the map wraps around the world
    }

    /// Multiply zoom by `factor`, keeping the unit point under `anchor` fixed.
    func zoom(by factor: CGFloat, anchor: CGPoint) {
        userAdjustedCamera = true
        let anchorUnit = unit(fromScreen: anchor)
        cameraZoom = min(Simulation.cameraMaxZoom, max(Simulation.cameraMinZoom, cameraZoom * factor))
        // keep anchorUnit projecting back to `anchor`
        let ppu = pixelsPerUnit
        cameraCenter = CGPoint(x: anchorUnit.x - (anchor.x - viewportCentre.x) / ppu,
                               y: anchorUnit.y - (anchor.y - viewportCentre.y) / ppu)
    }

    func resetCamera() {
        userAdjustedCamera = false
        cameraZoom = defaultZoom
        cameraCenter = Simulation.conusFrame.center
    }

    init() {
        // Phase 2: the full 48-airport network and a stress-test fleet flying
        // real routes between them. These are stress-test aircraft (no
        // ownership/economy yet — that's Phase 5); each gets a weighted-random
        // type, a random city pair it flies back and forth, and a staggered
        // start so the fleet isn't synchronized.
        airports = Airport.all
        provisionSlots()
        // Crew pools start EMPTY — the player-driven model fills them as aircraft
        // are bought/leased (grantBundledCrew), not by any startup ratio.
        initializeUsedInventory()   // 1–2 pre-owned listings per type at start
        // Full-shift start: $20M, zero aircraft, zero routes. The FLEET buttons
        // are a DEV stress-test control (spawn background/non-owned traffic).
        financeSnapshots = [financeSnapshotNow()]   // launch baseline (tick 0, $20M)
    }

    // MARK: - Ownership economy (Phase 5)

    static let startingCapital = 30_000_000

    /// A held aircraft (AOG/crew) still costs money at the gate, but a PARKED
    /// aircraft doesn't burn full in-flight block-hour cost — only idle cost
    /// (crew standby, gate, opportunity). So hold burn is a FRACTION of the flight
    /// operating rate. Early-game tuning: at the full rate, an under-crewed
    /// starter regional lost ~$5k/held-leg (ruinous, ~3 profitable legs); at 0.4
    /// it's a recoverable setback that still signals "hire crew" (you also lose
    /// the flights themselves while held). The AOG expedite-vs-standard tradeoff
    /// still holds — the standard repair's timed burn is smaller now, so expedite
    /// stays a premium reserved for expensive aircraft / lost high-value revenue.
    static let holdBurnRate = 0.4

    /// The player's airline name. nil until the first-launch naming screen is
    /// completed (which blocks the game until then). Defaults to "New Airline".
    private(set) var playerAirlineName: String?
    /// The 2-letter code stamped into every owned aircraft's tail (e.g. "ZQ" →
    /// "N1ZQ"). Chosen on the naming screen; can't match a real airline code
    /// (validated there). Defaults to a safe fictional code if left blank.
    private(set) var playerTailCode = "ZQ"
    func nameAirline(_ name: String, tailCode: String = "") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        playerAirlineName = trimmed.isEmpty ? "New Airline" : trimmed
        let code = tailCode.uppercased().filter { $0.isLetter }
        // Ignore an invalid/blank/colliding code and keep the safe default.
        if code.count == 2 && Airline.realCodes[code] == nil { playerTailCode = code }
    }

    private(set) var playerBalance = startingCapital
    private(set) var playerRoutes: [Route] = []
    /// Routes archived (not deleted) when their aircraft was sold — full
    /// history preserved so a closed route stays reviewable.
    private(set) var closedPlayerRoutes: [Route] = []
    private var nextRouteId = 1

    /// Open + closed routes, newest first (for the ROUTES panel).
    var allRoutes: [Route] { (playerRoutes + closedPlayerRoutes).sorted { $0.openedTick > $1.openedTick } }

    /// "Day N · HH:MM" from a tick (1 tick = 1 sim-minute).
    static func simDate(fromTick t: Int) -> String {
        let day = t / 1440 + 1
        let mins = t % 1440
        return String(format: "Day %d · %02d:%02d", day, mins / 60, mins % 60)
    }

    var ownedCount: Int { aircraft.lazy.filter { $0.purchased }.count }
    /// Aircraft owned OUTRIGHT (bought, not leased) — the ones that are real,
    /// sellable assets. A leased aircraft isn't yours to sell, so it isn't a
    /// balance-sheet asset (its lease is an ongoing expense, not equity).
    var ownedOutrightCount: Int { aircraft.lazy.filter { $0.purchased && !$0.isLeased }.count }
    var leasedCount: Int { aircraft.lazy.filter { $0.purchased && $0.isLeased }.count }
    /// Current resale value of owned-outright aircraft (each at its depreciated
    /// sell value) — the "assets" side of the Finance net-worth view. Leased
    /// aircraft are deliberately excluded (see ownedOutrightCount).
    var fleetMarketValue: Int { aircraft.lazy.filter { $0.purchased && !$0.isLeased }.reduce(0) { $0 + sellValue(of: $1) } }
    var stressTestCount: Int { aircraft.lazy.filter { !$0.purchased }.count }
    /// Purchased aircraft with no route yet — available to assign to a new one.
    var idleSpares: [Aircraft] { aircraft.filter { $0.isIdleSpare } }

    /// Slot scarcity: busier/more-expensive airports get fewer slots (3–13),
    /// starting 30–70% available. Ported from the setup pass around AIRPORTS.
    private func provisionSlots() {
        let sorted = airports.sorted { $0.landingFeePerKlb < $1.landingFeePerKlb }
        let n = max(1, sorted.count - 1)
        for (i, ap) in sorted.enumerated() {
            // cheapest (i=0) → ~13 slots, most expensive → floor of 3
            ap.slotsTotal = max(3, 13 - Int((Double(i) / Double(n) * 10).rounded()))
            ap.slotsAvailable = max(1, Int((Double(ap.slotsTotal) * (0.3 + Double.random(in: 0..<0.4))).rounded()))
        }
    }

    /// Slots slowly free up (abstract background churn). ~5%/day per airport
    /// under capacity. Ported from tickSlotAvailability().
    private func tickSlotAvailability() {
        guard tick % 1440 == 0 else { return }   // once per sim-day
        for ap in airports where ap.slotsAvailable < ap.slotsTotal {
            if Double.random(in: 0..<1) < 0.05 { ap.slotsAvailable += 1 }
        }
    }

    // MARK: Buying

    // CONUS bounds (matches the default camera frame). A fresh spare spawns at
    // a CONUS airport so it's VISIBLE in the default view — spawning at an
    // off-screen AK/HI base (ANC lat 61 / HNL lat 21) made a new spare
    // invisible and untappable until it was routed. The base is cosmetic
    // (openRoute reassigns origin), so restricting it purely improves
    // visibility; background traffic is unaffected (it can fly AK/HI freely).
    private static let conusLatRange = 24.5...49.5
    private static let conusLonRange = (-125.0)...(-66.5)
    /// Airports inside the CONUS frame (falls back to all if somehow empty).
    private var conusAirports: [Airport] {
        let inside = airports.filter {
            Simulation.conusLatRange.contains($0.lat) && Simulation.conusLonRange.contains($0.lon)
        }
        return inside.isEmpty ? airports : inside
    }

    /// A genuinely fresh purchase — 0 cycles, PARKED at a random CONUS base, no
    /// route (a spare). Separate from makeAircraft (stress-test) by design.
    private func makePurchasedAircraft(_ type: AircraftType, startingCycles: Int = 0) -> Aircraft {
        let base = conusAirports.randomElement()!
        let tail = "N\(nextTailNum)\(playerTailCode)"
        nextTailNum += 1
        let ac = Aircraft(tail: tail, type: type, origin: base, dest: base,
                          stateIndex: FlightState.parked.rawValue,
                          cyclesAccrued: startingCycles, purchased: true)
        rollRevenue(for: ac)
        return ac
    }

    /// Buy an aircraft if affordable. Returns the new spare (to auto-assign to a
    /// pending route) or nil.
    @discardableResult
    func buyAircraft(_ type: AircraftType) -> Aircraft? {
        guard playerBalance >= type.purchasePrice else { return nil }
        playerBalance -= type.purchasePrice
        totalAcquisitionSpend += type.purchasePrice
        let ac = makePurchasedAircraft(type)
        aircraft.append(ac)
        grantBundledCrew(type.family)   // 1 crew bundled; the player hires more
        return ac
    }

    // MARK: Leasing

    /// Upfront cost to lease instead of buy: 15% of purchase price
    /// (LEASE_UPFRONT_RATE). Lower capital now, but the fixed monthly bill
    /// (type.monthlyLeaseCost, tickLeaseBilling) makes a leased aircraft cost
    /// more over time — a genuine tradeoff, not a strictly-better option.
    static let leaseUpfrontRate = 0.15

    func leaseUpfront(_ type: AircraftType) -> Int {
        Int((Double(type.purchasePrice) * Simulation.leaseUpfrontRate).rounded())
    }

    /// Running total of all fixed lease bills paid (a separate line from
    /// operating cost at the data layer, per the prototype's design).
    private(set) var totalLeaseCost = 0

    /// Lease an aircraft if the upfront cost is affordable. Returns the new
    /// spare (to auto-assign to a pending route) or nil. Ported from
    /// leaseAircraft().
    @discardableResult
    func leaseAircraft(_ type: AircraftType) -> Aircraft? {
        let upfront = leaseUpfront(type)
        guard playerBalance >= upfront else { return nil }
        playerBalance -= upfront
        totalAcquisitionSpend += upfront
        let ac = makePurchasedAircraft(type)
        ac.isLeased = true
        aircraft.append(ac)
        grantBundledCrew(type.family)   // 1 crew bundled; the player hires more
        return ac
    }

    /// Charge every leased aircraft its fixed monthly obligation, ACCRUED
    /// CONTINUOUSLY per tick (monthlyLeaseCost / ticksPerMonth) rather than as a
    /// monthly lump. This means a leased aircraft's cost shows up immediately in
    /// its route P&L and the running lease total (a lump-sum model left a leased
    /// route reading $0 lease for its whole first sim-month, then a big jump).
    /// The charge lands regardless of whether the aircraft is flying, held, or
    /// an idle spare, so leasing stays a real fixed obligation (NOT the earlier
    /// per-leg proration bug, which made idle leases free). Sub-dollar remainders
    /// carry in ac.leaseAccrued so nothing is lost to rounding. playerBalance is
    /// allowed to go negative (no bankruptcy mechanic yet).
    private func tickLeaseBilling() {
        let perTick: (AircraftType) -> Double = { Double($0.monthlyLeaseCost) / Double(Simulation.ticksPerMonth) }
        for ac in aircraft where ac.isLeased {
            ac.leaseAccrued += perTick(ac.type)
            let bill = Int(ac.leaseAccrued)   // whole dollars due this tick
            guard bill > 0 else { continue }
            ac.leaseAccrued -= Double(bill)
            playerBalance -= bill
            totalLeaseCost += bill
            if let id = ac.assignedRouteId, let r = playerRoutes.first(where: { $0.id == id }) {
                r.totalLeaseCost += bill
                r.cumulativeNet -= bill   // a real cost against this route's P&L
            }
        }
    }

    // MARK: Routes

    static let routeBaseCost = 50_000
    static let routeCostPerGateFeeUnit = 50
    static let routeSlotPurchasePremium = 75_000

    func route(between a: String, _ b: String) -> Route? {
        playerRoutes.first { ($0.originCode == a && $0.destCode == b) || ($0.originCode == b && $0.destCode == a) }
    }

    /// Real opening cost: base + both endpoints' gate fees, plus a premium per
    /// endpoint with no free slot. Ported from computeRouteOpeningCost().
    func routeOpeningCost(_ origin: Airport, _ dest: Airport) -> Int {
        var cost = Double(Simulation.routeBaseCost)
                 + Double(origin.gateFeeNarrowbody + dest.gateFeeNarrowbody) * Double(Simulation.routeCostPerGateFeeUnit)
        if origin.slotsAvailable <= 0 { cost += Double(Simulation.routeSlotPurchasePremium) }
        if dest.slotsAvailable <= 0 { cost += Double(Simulation.routeSlotPurchasePremium) }
        return Int(cost.rounded())
    }

    enum OpenRouteResult { case success, sameAirport, alreadyOpen, noSpare, insufficientFunds(Int) }

    /// Open a route and assign a spare to fly it. Ported from openRoute().
    @discardableResult
    func openRoute(from origin: Airport, to dest: Airport, using ac: Aircraft) -> OpenRouteResult {
        if origin === dest { return .sameAirport }
        if route(between: origin.code, dest.code) != nil { return .alreadyOpen }
        guard ac.purchased, ac.assignedRouteId == nil else { return .noSpare }
        let cost = routeOpeningCost(origin, dest)
        guard playerBalance >= cost else { return .insufficientFunds(cost) }

        playerBalance -= cost
        totalRouteSpend += cost
        if origin.slotsAvailable > 0 { origin.slotsAvailable -= 1 }
        if dest.slotsAvailable > 0 { dest.slotsAvailable -= 1 }

        let r = Route(id: nextRouteId, originCode: origin.code, destCode: dest.code,
                      openedTick: tick, openingCost: cost)
        r.assignmentHistory.append(RouteAssignment(id: 0, tail: ac.tail,
                                                   typeName: ac.type.name, assignedTick: tick))
        nextRouteId += 1
        playerRoutes.append(r)
        logOps(.structural, "Route opened", "\(origin.code) ↔︎ \(dest.code)")

        ac.assignedRouteId = r.id
        ac.origin = origin
        ac.dest = dest
        ac.stateIndex = FlightState.parked.rawValue
        ac.stateTick = 0
        rollRevenue(for: ac)
        return .success
    }

    // MARK: Selling

    /// Linear depreciation from purchase price, floored at 5%. Ported from
    /// computeSellValue().
    func sellValue(of ac: Aircraft) -> Int {
        let used = Double(ac.cyclesAccrued) / Double(max(1, ac.type.expectedLifespanCycles))
        let remaining = max(0.05, 1 - used)
        return Int((Double(ac.type.purchasePrice) * remaining).rounded())
    }

    // MARK: - Used-aircraft market (buy-only, persistent inventory)

    /// One pre-owned listing: a specific airframe at a real cycle count and its
    /// depreciated price. Persists in `usedInventory` until bought or replaced.
    struct UsedListing: Identifiable {
        let id: Int
        let typeId: String
        let cyclesAccrued: Int
        let price: Int
    }

    /// Listings per type id. Generated at game start, removed on purchase,
    /// slowly replenished (so a long session doesn't permanently deplete it).
    private(set) var usedInventory: [String: [UsedListing]] = [:]
    private var nextUsedListingId = 1

    /// Pricing reuses the EXACT SAME linear depreciation as sellValue() — a
    /// deliberate consistency with the sell mechanic, not a new formula.
    private func usedPrice(_ type: AircraftType, cyclesAccrued: Int) -> Int {
        let usedFraction = Double(cyclesAccrued) / Double(max(1, type.expectedLifespanCycles))
        return Int((Double(type.purchasePrice) * max(0.05, 1 - usedFraction)).rounded())
    }

    /// A listing at 15–75% of expected life — meaningfully used, not
    /// near-new or near-scrap, so the market has real variety.
    private func generateUsedListing(_ type: AircraftType) -> UsedListing {
        let cycles = Int((Double(type.expectedLifespanCycles) * (0.15 + Double.random(in: 0..<0.6))).rounded())
        defer { nextUsedListingId += 1 }
        return UsedListing(id: nextUsedListingId, typeId: type.id,
                           cyclesAccrued: cycles, price: usedPrice(type, cyclesAccrued: cycles))
    }

    /// 1–2 listings per type at game start (called once from init).
    private func initializeUsedInventory() {
        for type in AircraftType.all {
            let count = 1 + Int.random(in: 0...1)
            usedInventory[type.id] = (0..<count).map { _ in generateUsedListing(type) }
        }
    }

    /// Slowly refill toward 2 listings/type (another airline selling, a lessor's
    /// aircraft coming off lease). Once per sim-day, 10% chance per under-stocked
    /// type. Ported from tickUsedMarketReplenishment().
    private func tickUsedMarketReplenishment() {
        guard tick % 1440 == 0 else { return }
        for type in AircraftType.all {
            let listings = usedInventory[type.id] ?? []
            if listings.count < 2, Double.random(in: 0..<1) < 0.1 {
                usedInventory[type.id, default: []].append(generateUsedListing(type))
            }
        }
    }

    /// All current listings flattened, cheapest first (for the USED panel).
    var usedListings: [UsedListing] {
        usedInventory.values.flatMap { $0 }.sorted { $0.price < $1.price }
    }

    /// Buy a specific used listing. A purchased used aircraft inherits the
    /// listing's real cycle count (NOT 0). Returns the new spare or nil.
    @discardableResult
    func buyUsedAircraft(_ listing: UsedListing) -> Aircraft? {
        guard let type = AircraftType.all.first(where: { $0.id == listing.typeId }),
              var listings = usedInventory[listing.typeId],
              let idx = listings.firstIndex(where: { $0.id == listing.id }),
              playerBalance >= listing.price else { return nil }
        playerBalance -= listing.price
        totalAcquisitionSpend += listing.price
        let ac = makePurchasedAircraft(type, startingCycles: listing.cyclesAccrued)
        aircraft.append(ac)
        grantBundledCrew(type.family)   // 1 crew bundled; the player hires more
        listings.remove(at: idx)          // sold — gone until replenishment
        usedInventory[listing.typeId] = listings
        return ac
    }

    // MARK: - Fleet

    /// Spawn one stress-test aircraft — weighted type, random route, staggered
    /// start. Ported from makeAircraft().
    // MARK: Background-traffic geography (airline-first, region-constrained)

    /// Airports grouped by carrier region (computed once from Airport.all).
    @ObservationIgnored private lazy var airportsByRegion: [Airline.Region: [Airport]] = {
        var m: [Airline.Region: [Airport]] = [:]
        for ap in airports { m[Airline.region(ap.code), default: []].append(ap) }
        return m
    }()

    /// Per-region international GATEWAYS = the busiest ~35% of that region's
    /// airports (min 2) by annual passengers. Only a gateway can be the endpoint
    /// of a cross-region international leg, so a small airport (Oklahoma City,
    /// Bozeman) stays domestic-only and never gets a foreign carrier flying in.
    @ObservationIgnored private lazy var gatewaysByRegion: [Airline.Region: Set<String>] = {
        var m: [Airline.Region: Set<String>] = [:]
        for (region, aps) in airportsByRegion {
            let sorted = aps.sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
            let n = max(2, Int((Double(sorted.count) * 0.35).rounded()))
            m[region] = Set(sorted.prefix(n).map { $0.code })
        }
        return m
    }()

    /// Region spawn weights ∝ each region's airport count (a simple, self-adjusting
    /// proxy for its share of air traffic — the US, with the most airports, spawns
    /// the most traffic).
    @ObservationIgnored private lazy var backgroundRegionPool: [(Airline.Region, Int)] = {
        Airline.allRegions.compactMap { r in
            let c = airportsByRegion[r]?.count ?? 0
            return c > 0 ? (r, c) : nil
        }
    }()

    private func pickBackgroundRegion() -> Airline.Region {
        let total = backgroundRegionPool.reduce(0) { $0 + $1.1 }
        var r = Int.random(in: 0..<max(1, total))
        for (region, w) in backgroundRegionPool { r -= w; if r < 0 { return region } }
        return .us
    }

    /// A plausible leg for a carrier whose home region is `region`: mostly a
    /// domestic leg within the region; occasionally (from a gateway only) an
    /// international leg to a plausible neighbour region's gateway. This is what
    /// keeps a carrier inside its real sphere — no more "EgyptAir to OKC".
    func backgroundLeg(for region: Airline.Region) -> (Airport, Airport) {
        let pool = airportsByRegion[region] ?? airports
        guard let origin = pool.randomElement() else { return Airport.randomPair() }
        // International: from a gateway only, ~25% of the time, to a neighbour gateway.
        if (gatewaysByRegion[region]?.contains(origin.code) ?? false), Int.random(in: 0..<100) < 25,
           let neighbours = Airline.corridors[region] {
            let viable = neighbours.filter { !(gatewaysByRegion[$0]?.isEmpty ?? true) }
            if let nr = viable.randomElement(), let gws = gatewaysByRegion[nr],
               let dest = (airportsByRegion[nr] ?? []).filter({ gws.contains($0.code) }).randomElement() {
                return (origin, dest)
            }
        }
        // Domestic: another airport in the same region.
        guard pool.count > 1 else { return (origin, origin) }
        var dest = pool.randomElement()!
        while dest === origin { dest = pool.randomElement()! }
        return (origin, dest)
    }

    /// A type the carrier actually flies, weighted by that type's global commonness.
    private func pickBackgroundType(for airline: Airline) -> AircraftType {
        let types = airline.types.compactMap { AircraftType.byId[$0] }
        guard !types.isEmpty else { return AircraftType.pickWeighted() }
        let total = types.reduce(0) { $0 + $1.weight }
        var r = Int.random(in: 0..<max(1, total))
        for t in types { r -= t.weight; if r < 0 { return t } }
        return types.last!
    }

    private func makeAircraft() -> Aircraft {
        // Airline-FIRST: pick a region (weighted by traffic) → a carrier in it →
        // a type it flies → a route in its geographic sphere. Each background
        // aircraft is thus ONE coherent airline that never flies outside its real
        // reach. (The old model picked a random GLOBAL airport pair every leg while
        // keeping the spawn carrier — that's how "EgyptAir to Oklahoma City" happened.)
        let region = pickBackgroundRegion()
        let airline = Airline.weighted(Airline.roster(for: region))
        let type = pickBackgroundType(for: airline)
        let (origin, dest) = backgroundLeg(for: region)
        // Tail carries the carrier's real IATA code (Delta → "N123DL"); the
        // generic fallback gets a random non-real code so they aren't uniform.
        let code = airline.code.isEmpty ? Airline.randomTailCode() : airline.code
        let tail = "N\(nextTailNum)\(code)"
        nextTailNum += 1
        let ac = Aircraft(tail: tail,
                          type: type,
                          origin: origin,
                          dest: dest,
                          stateIndex: Int.random(in: 0..<FlightState.allCases.count),
                          cyclesAccrued: Int.random(in: 0..<Int(Double(type.expectedLifespanCycles) * 0.9)))
        ac.airlineName = airline.name
        ac.homeRegion = region
        rollRevenue(for: ac)   // seed this leg's revenue before its first arrival
        return ac
    }

    /// Grow or shrink the fleet to `n` (stress-test control; all aircraft are
    /// non-owned so a plain trim is fine — the purchased-vs-spawn distinction
    /// arrives with the Phase 5 economy).
    /// DEV stress-test control — sets the count of NON-OWNED background
    /// aircraft, never touching the player's purchased fleet.
    func setFleetSize(_ n: Int) {
        let target = max(0, n)
        let current = stressTestCount
        if target < current {
            var toRemove = current - target
            let removed = aircraft.filter { !$0.purchased }.suffix(toRemove)
            aircraft.removeAll { ac in
                if !ac.purchased && toRemove > 0 { toRemove -= 1; return true }
                return false
            }
            decisionQueue.removeAll { d in removed.contains(where: { $0 === d.aircraft }) }
        } else {
            while stressTestCount < target { aircraft.append(makeAircraft()) }
        }
        resizeCrewPools()   // cleanup only (background traffic uses no crew)
    }

    var fleetCount: Int { aircraft.count }

    // MARK: - Tick

    /// Ticks in a 30-day sim-month (1 tick = 1 sim-minute). Used for
    /// converting real per-month event rates into per-tick probabilities.
    static let ticksPerMonth = 30 * 24 * 60   // 43,200

    // MARK: - AOG (unscheduled maintenance), ported from tickAOGOnset()

    /// Real anchor: ~2 incidents/month for a 100-aircraft airline, as a
    /// continuous per-aircraft per-tick probability (NOT bracketed tiers).
    static let aogRatePerAircraftPerMonth = 2.0 / 100.0
    static let aogProbPerTick = aogRatePerAircraftPerMonth / Double(ticksPerMonth)
    /// One incident temporarily triples AOG risk for the SAME family only
    /// (real-world analog: type-wide ADs / bad parts batches), decaying
    /// linearly over 3 sim-days. Families never cross-contaminate.
    static let aogClusterMultiplier = 3.0
    static let aogClusterDecayTicks = 4320   // 3 sim-days

    private var familyPressureTicksLeft: [String: Int] = [:]

    /// NOTE (ownership scoping): the prototype gates AOG on `ac.purchased` —
    /// background traffic never experiences it. Ownership doesn't exist until
    /// Phase 5, so for now the whole stress-test fleet is eligible. Re-scope
    /// this when `purchased` lands (see TASKS.md / CLAUDE.md — the prototype
    /// had a real reported bug from missing exactly this retrofit).
    private func tickAOGOnset() {
        for (f, left) in familyPressureTicksLeft where left > 0 {
            familyPressureTicksLeft[f] = left - 1
        }
        for ac in aircraft where ac.purchased && !ac.maint {
            let pressure = Double(familyPressureTicksLeft[ac.type.family] ?? 0)
                         / Double(Simulation.aogClusterDecayTicks)
            let multiplier = 1 + (Simulation.aogClusterMultiplier - 1) * pressure
            if Double.random(in: 0..<1) < Simulation.aogProbPerTick * multiplier {
                ac.maint = true
                // this incident (re)opens the elevated window for the family
                familyPressureTicksLeft[ac.type.family] = Simulation.aogClusterDecayTicks
            }
        }
    }

    // MARK: - Crew (per-family pools, FAA Part 117 duty/rest)

    // PLAYER-DRIVEN crew model (ported from the prototype, replacing the native
    // app's auto-ratio stand-in). Buying/leasing an aircraft bundles exactly 1
    // crew — deliberately NOT enough for continuous operation once duty/rest
    // limits kick in (a crew flies ~55% of the time), which is the real pressure
    // toward hiring more via the ADD CREW panel. A family's FIRST aircraft also
    // seeds 1 reserve (1 bundled + 1 reserve = 2 crew total on the first tail —
    // the corrected count, was 2 reserves). `crewsPerTail` (6 short / 11 long
    // haul) is now purely a REFERENCE figure the player reasons about — no code
    // consumes it, so the old cascade-prone auto-ratio is gone entirely.
    private static let reservesPerFamily = 1
    /// Crew hire cost = 0.2% of a representative aircraft's price (scales with
    /// complexity: ~$28K regional-jet crew … ~$578K widebody crew). A DESIGNED
    /// estimate, not deeply sourced.
    private static let crewHireCostRate = 0.002

    private(set) var crewPoolsByFamily: [String: [Crew]] = [:]
    private(set) var reserveCrewsByFamily: [String: Int] = [:]

    /// Families the player currently owns aircraft in (for the ADD CREW panel —
    /// never the full 15). Insertion-ordered by first-owned.
    var ownedFamilies: [String] {
        var seen = Set<String>(), out = [String]()
        for ac in aircraft where ac.purchased && !seen.contains(ac.type.family) {
            seen.insert(ac.type.family); out.append(ac.type.family)
        }
        return out
    }
    func crewCount(family: String) -> Int { crewPoolsByFamily[family]?.count ?? 0 }
    func ownedCount(family: String) -> Int { aircraft.lazy.filter { $0.purchased && $0.type.family == family }.count }

    /// Bundle exactly 1 crew with a bought/leased aircraft; seed 1 reserve if
    /// this is the family's first aircraft. Ported from grantBundledCrew().
    private func grantBundledCrew(_ family: String) {
        if crewPoolsByFamily[family]?.isEmpty ?? true {
            reserveCrewsByFamily[family] = Simulation.reservesPerFamily
        }
        let id = crewPoolsByFamily[family]?.count ?? 0
        crewPoolsByFamily[family, default: []].append(Crew(id: id))
    }

    /// Cleanup pass ONLY — clears a family's pool/reserves to 0 once its owned
    /// count hits zero (last one sold). Never grows or shrinks by any ratio
    /// (that's the player's job now). Ported from the rewritten resizeCrewPools().
    private func resizeCrewPools() {
        for family in Array(crewPoolsByFamily.keys) where ownedCount(family: family) == 0 {
            crewPoolsByFamily[family] = nil
            reserveCrewsByFamily[family] = nil
        }
    }

    /// Cost to hire one crew in a family (0.2% of a representative aircraft's
    /// price). Same function the ADD CREW panel and the CREW card's hire option
    /// both use.
    func crewHireCost(family: String) -> Int {
        let price = AircraftType.all.first { $0.family == family }?.purchasePrice ?? 0
        return Int((Double(price) * Simulation.crewHireCostRate).rounded())
    }

    /// Hire one crew into a family if affordable (real playerBalance cost).
    /// Returns the new crew's id, or nil if unaffordable.
    @discardableResult
    func hireCrew(family: String) -> Int? {
        let cost = crewHireCost(family: family)
        guard playerBalance >= cost else { return nil }
        playerBalance -= cost
        maintenanceSpend += cost
        let id = crewPoolsByFamily[family]?.count ?? 0
        crewPoolsByFamily[family, default: []].append(Crew(id: id))
        return id
    }

    /// Duty/rest clock. Ported from tickCrewPool(): on-duty accrues duty time;
    /// a completed rest period is the ONLY place dutyTicks resets (Part 117).
    private func tickCrewPool() {
        for pool in crewPoolsByFamily.values {
            for c in pool {
                switch c.status {
                case .onDuty:
                    c.dutyTicks += 1
                case .resting:
                    c.restTicksLeft -= 1
                    if c.restTicksLeft <= 0 { c.status = .available; c.dutyTicks = 0 }
                case .available, .sidelined:
                    break   // sidelined crew return via the labor-action expiry
                }
            }
        }
    }

    /// Injected into Aircraft.advance — take an available crew (keeping its
    /// duty clock), or fail.
    private func assignCrew(_ ac: Aircraft) -> Bool {
        guard let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.status == .available }) else { return false }
        crew.status = .onDuty
        ac.crewId = crew.id   // dutyTicks NOT reset — the Part 117 fix
        return true
    }

    /// Injected into Aircraft.advance — release the crew to rest (if it hit the
    /// duty limit) or back to the pool, and clear the assignment.
    private func releaseCrew(_ ac: Aircraft) {
        if let id = ac.crewId, let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == id }) {
            if crew.dutyTicks >= Crew.maxDutyTicks {
                crew.status = .resting
                crew.restTicksLeft = Crew.restTicks
            } else {
                crew.status = .available
            }
        }
        ac.crewId = nil
    }

    /// Assigned crew's duty hours for the tooltip, or nil if none / held.
    func crewDuty(for ac: Aircraft) -> (used: Double, max: Double)? {
        guard let id = ac.crewId,
              let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == id }) else { return nil }
        return (Double(crew.dutyTicks) / 60.0, Double(Crew.maxDutyTicks) / 60.0)
    }

    // MARK: - Decisions (AOG + CREW cards; SELL arrives with the economy)

    struct Decision: Identifiable {
        enum Kind { case aog, crew, sell, offer }
        let id: String
        let kind: Kind
        /// The subject aircraft (aog / crew / sell). nil for an `.offer`.
        let aircraft: Aircraft?
        /// The slot-buyback details (`.offer` only).
        var offer: SlotOffer? = nil
    }

    /// A slot-value buyback: an airport (the destination) offers to buy back a
    /// route's slot. Accepting closes the route for cash; declining keeps it.
    struct SlotOffer {
        let routeId: Int
        let originCode: String
        let destCode: String
        let amount: Int
    }

    private(set) var decisionQueue: [Decision] = []
    /// Running maintenance spend (expedite/standard repair costs). The full
    /// fee/economy system is Phase 5; this keeps the costs real until then.
    private(set) var maintenanceSpend: Int = 0

    private func pushDecision(_ kind: Decision.Kind, for ac: Aircraft) {
        guard !decisionQueue.contains(where: { $0.aircraft === ac && $0.kind == kind }) else { return }
        decisionQueue.append(Decision(id: "\(kind)_\(ac.tail)_\(tick)", kind: kind, aircraft: ac))
    }

    /// Remove a card whose condition resolved through a path OTHER than its
    /// own buttons (e.g. the timed standard repair completing). Ported from
    /// clearDecisionForAircraft() — a real reported prototype bug.
    private func clearDecision(_ kind: Decision.Kind, for ac: Aircraft) {
        decisionQueue.removeAll { $0.aircraft === ac && $0.kind == kind }
    }

    /// Charge a real decision cost against the balance (and track the running
    /// maintenance stat). Previously `maintenanceSpend` accumulated but never
    /// touched `playerBalance` — decisions were silently free; now they cost.
    private func chargeDecisionCost(_ amount: Int) {
        playerBalance -= amount
        maintenanceSpend += amount
    }

    /// AOG card option 1: pay to have the aircraft ready now. Cost is scaled by
    /// any active #12 maintenance-cost inflation (repair costs only).
    func resolveAOGExpedite(_ decision: Decision) {
        chargeDecisionCost(Int((15_000 * maintCostMultiplier).rounded()))
        decision.aircraft?.maint = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// AOG card option 2: cheaper repair on a ~3 sim-hour timer; the aircraft
    /// stays held until it completes. Cost scaled by #12 maintenance inflation.
    func resolveAOGStandard(_ decision: Decision) {
        chargeDecisionCost(Int((3_000 * maintCostMultiplier).rounded()))
        decision.aircraft?.aogAutoClearTick = tick + 180
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// True if a family still has a reserve crew to call in.
    func hasReserve(for ac: Aircraft) -> Bool { (reserveCrewsByFamily[ac.type.family] ?? 0) > 0 }

    /// CREW card option 1: call in a reserve crew ($5,000), assigned now so the
    /// aircraft boards this cycle. Disabled when the family is out of reserves.
    func resolveCrewReserve(_ decision: Decision) {
        guard let ac = decision.aircraft else { return }
        let family = ac.type.family
        guard (reserveCrewsByFamily[family] ?? 0) > 0 else { return }
        reserveCrewsByFamily[family]! -= 1
        chargeDecisionCost(5_000)
        let crew = Crew(id: crewPoolsByFamily[family]?.count ?? 0)
        crew.status = .onDuty
        crewPoolsByFamily[family, default: []].append(crew)
        ac.crewId = crew.id
        ac.holdReason = nil
        ac.holdLogged = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// True if the player can afford to hire a crew for this aircraft's family.
    func canAffordCrewHire(for ac: Aircraft) -> Bool {
        playerBalance >= crewHireCost(family: ac.type.family)
    }

    /// CREW card option 2: hire a NEW crew (real cost) and assign it to this
    /// held aircraft immediately, resolving the hold this cycle. Reuses
    /// hireCrew() — same cost/pool logic as the ADD CREW panel.
    func resolveCrewHire(_ decision: Decision) {
        guard let ac = decision.aircraft else { return }
        guard let id = hireCrew(family: ac.type.family) else { return }
        // Put the freshly-hired crew straight on this aircraft.
        crewPoolsByFamily[ac.type.family]?.first { $0.id == id }?.status = .onDuty
        ac.crewId = id
        ac.holdReason = nil
        ac.holdLogged = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// CREW card option 3: dismiss and let the aircraft keep waiting on the
    /// pool — the boarding gate assigns a crew the moment one frees up.
    func resolveCrewWait(_ decision: Decision) {
        decisionQueue.removeAll { $0.id == decision.id }
    }

    // MARK: - Economics (per-flight revenue / cost / fees)

    /// Active economic condition and how many ticks it has left.
    private(set) var currentEvent = EconomicEvent.normal
    private(set) var economicEventTicksLeft = 0

    // MARK: - Ops event log (the Ops tab's Events feed)
    private(set) var opsEventLog: [OpsEvent] = []
    private var nextOpsEventId = 1

    /// Highest ops-event id the player has already seen (Ops tab viewed). Drives
    /// the Ops tab-bar activity badge.
    private(set) var lastSeenOpsEventId = 0
    /// New ops events since the player last looked at the Ops feed.
    var unseenOpsEventCount: Int {
        opsEventLog.reduce(0) { $0 + ($1.id > lastSeenOpsEventId ? 1 : 0) }
    }
    /// Mark the Ops feed as seen — called when the Ops tab is on screen. The
    /// newest event is always at index 0 (highest id), so that's the high-water mark.
    func markOpsEventsSeen() {
        lastSeenOpsEventId = max(lastSeenOpsEventId, opsEventLog.first?.id ?? lastSeenOpsEventId)
    }

    /// Record an event to the (capped, newest-first) Ops feed.
    private func logOps(_ category: OpsEvent.Category, _ title: String, _ subtitle: String) {
        opsEventLog.insert(OpsEvent(id: nextOpsEventId, category: category,
                                    title: title, subtitle: subtitle, tick: tick), at: 0)
        nextOpsEventId += 1
        if opsEventLog.count > 40 { opsEventLog.removeLast(opsEventLog.count - 40) }
    }

    /// Airport codes on the player's open routes (weather there is worth logging).
    private var playerRouteCodes: Set<String> {
        Set(playerRoutes.flatMap { [$0.originCode, $0.destCode] })
    }

    private func opsEventSubtitle(_ e: EconomicEvent) -> String {
        switch e.id {
        case "OIL_SPIKE": return "Fuel costs surge \(Int(((e.costMultiplier - 1) * 100).rounded()))%"
        case "FUEL_GLUT": return "Fuel costs drop \(Int(((1 - e.costMultiplier) * 100).rounded()))%"
        case "ECON_BOOM": return "Demand up — fares +\(Int(((e.fareMultiplier - 1) * 100).rounded()))%"
        case "RECESSION": return "Fares down \(Int(((1 - e.fareMultiplier) * 100).rounded()))%"
        case "FFR_SURGE": return "Seats fill (+\(Int(((e.loadMultiplier - 1) * 100).rounded()))%), less cash per seat"
        default:          return e.label
        }
    }

    // MARK: - World disruption / structural events (Phase 1 of the event system)
    // Regional ATC shortages and single-airport security incidents both reuse
    // the SAME ground-stop mechanism as weather (distinguished only by cause /
    // scope / duration). Airport expansion is the one DURABLE event (a permanent
    // slot increase). Daily probabilities are designed pacing, not sourced.
    private static let atcDailyProbability = 0.04
    private static let securityDailyProbability = 0.03
    private static let expansionDailyProbability = 0.025
    private static let slotOfferDailyProbability = 0.06
    private static let laborActionDailyProbability = 0.02
    private static let recallDailyProbability = 0.015

    /// Tick a family's labor action ends (its sidelined crew return). Days
    /// boundaries only, so it's safe to expire inside the daily tickWorldEvents.
    private(set) var laborActionExpiryByFamily: [String: Int] = [:]

    // MARK: Phase-4 cost/revenue events (all passive multipliers/bills).
    // #11 Insurance — a recurring MONTHLY bill vs current fleet value, with an
    // occasional "hard market" period that raises the premium.
    static let insuranceRateMonthly = 0.0008    // 0.08%/mo of fleet value (designed)
    static let insuranceHardMarketMultiplier = 1.8
    private var nextInsuranceBillTick = Simulation.ticksPerMonth
    private var insuranceHardMarketExpiryTick = 0
    private(set) var totalInsuranceSpent = 0
    var insuranceHardMarketActive: Bool { tick < insuranceHardMarketExpiryTick }
    // #12 Maintenance cost inflation — spikes AOG REPAIR cost only (not fuel).
    static let maintInflationMultiplier = 1.6
    private var maintInflationExpiryTick = 0
    var maintCostMultiplier: Double { tick < maintInflationExpiryTick ? Simulation.maintInflationMultiplier : 1 }
    // #13 FX shock — widebody fare only (honest adaptation: no real intl routes).
    static let fxFareMultiplier = 0.85
    private var fxShockExpiryTick = 0
    var fxShockActive: Bool { tick < fxShockExpiryTick }
    // #14 Competitor fare war — depresses ONE existing player route's fare.
    static let fareWarMultiplier = 0.75
    private(set) var fareWarRouteId: Int?
    private var fareWarExpiryTick = 0
    private static let insuranceHardMarketDailyProbability = 0.02
    private static let maintInflationDailyProbability = 0.025
    private static let fxShockDailyProbability = 0.02
    private static let fareWarDailyProbability = 0.03

    private func tickWorldEvents() {
        guard tick % 1440 == 0 else { return }   // once per sim-day

        // Clear an expired fare war so a new one can start.
        if fareWarRouteId != nil, tick >= fareWarExpiryTick { fareWarRouteId = nil }

        // Expire any finished labor action FIRST (return the sidelined crew).
        for (fam, expiry) in laborActionExpiryByFamily where tick >= expiry {
            for c in crewPoolsByFamily[fam] ?? [] where c.status == .sidelined { c.status = .available }
            laborActionExpiryByFamily[fam] = nil
            logOps(.disruption, "Labor action resolved", CREW_FAMILY_INFO[fam]?.name ?? fam)
        }

        // #9 Labor Action — sideline a real fraction (~40%) of ONE crew family's
        // pool (from the ready/resting crew, not mid-flight), for 3–8 sim-days.
        if Double.random(in: 0..<1) < Simulation.laborActionDailyProbability,
           let fam = ownedFamilies.filter({ (laborActionExpiryByFamily[$0] ?? 0) <= tick }).randomElement() {
            let pool = crewPoolsByFamily[fam] ?? []
            let candidates = pool.filter { $0.status == .available || $0.status == .resting }
            let n = min(candidates.count, max(1, Int((Double(pool.count) * 0.4).rounded())))
            let sidelined = Array(candidates.shuffled().prefix(n))
            for c in sidelined { c.status = .sidelined }
            if !sidelined.isEmpty {
                laborActionExpiryByFamily[fam] = tick + (3 + Int.random(in: 0...5)) * 1440
                logOps(.disruption, "Labor action", "\(CREW_FAMILY_INFO[fam]?.name ?? fam): \(sidelined.count) crew sidelined")
            }
        }

        // #10 Aircraft Recall / Airworthiness Directive — ground EVERY owned
        // aircraft of one type at once (reuses the AOG mechanism: maint = true →
        // each aircraft AOGs at its next gate, pushing an AOG card per tail).
        if Double.random(in: 0..<1) < Simulation.recallDailyProbability {
            let ownedTypes = Set(aircraft.filter { $0.purchased && !$0.maint }.map { $0.type.id })
            if let typeId = ownedTypes.randomElement() {
                let affected = aircraft.filter { $0.purchased && $0.type.id == typeId && !$0.maint }
                for ac in affected { ac.maint = true }
                if let name = affected.first?.type.name {
                    logOps(.disruption, "Airworthiness Directive", "\(name): \(affected.count) grounded")
                }
            }
        }
        // ATC staffing shortage — regional, 2–4 airports grounded at once,
        // moderate duration (2.5–5 sim-hours).
        if Double.random(in: 0..<1) < Simulation.atcDailyProbability {
            let hit = Array(airports.shuffled().prefix(Int.random(in: 2...4)))
            for ap in hit { ap.groundStop = true; ap.groundStopTicksLeft = 150 + Int.random(in: 0...150) }
            logOps(.disruption, "ATC staffing shortage", "Ground stops: \(hit.map { $0.code }.joined(separator: ", "))")
        }
        // Security incident — single airport, sharper & SHORTER than weather
        // (0.75–2 sim-hours vs weather's 1.5–5.5).
        if Double.random(in: 0..<1) < Simulation.securityDailyProbability, let ap = airports.randomElement() {
            ap.groundStop = true; ap.groundStopTicksLeft = 45 + Int.random(in: 0...75)
            logOps(.disruption, "Security incident", "Ground stop at \(ap.code)")
        }
        // Airport expansion — PERMANENT slot capacity increase (durable).
        if Double.random(in: 0..<1) < Simulation.expansionDailyProbability, let ap = airports.randomElement() {
            let added = Int.random(in: 2...3)
            ap.slotsTotal += added; ap.slotsAvailable += added
            logOps(.structural, "\(ap.code) capacity expansion", "\(added) new slots available")
        }
        // Slot-value buyback — an airport offers to buy back one route's slot.
        // The one event that's a real player CHOICE (Accept/Decline card), not a
        // passive effect. Only one open at a time; only when the player has a route.
        if !decisionQueue.contains(where: { $0.kind == .offer }),
           Double.random(in: 0..<1) < Simulation.slotOfferDailyProbability,
           let r = playerRoutes.randomElement() {
            let amount = Int((Double(r.openingCost) * Double.random(in: 2.0...4.0)).rounded())
            decisionQueue.append(Decision(id: "offer_\(r.id)_\(tick)", kind: .offer, aircraft: nil,
                offer: SlotOffer(routeId: r.id, originCode: r.originCode, destCode: r.destCode, amount: amount)))
        }

        // #11 Insurance hard market — a temporary spike in the recurring premium.
        if !insuranceHardMarketActive, Double.random(in: 0..<1) < Simulation.insuranceHardMarketDailyProbability {
            insuranceHardMarketExpiryTick = tick + (15 + Int.random(in: 0...20)) * 1440
            logOps(.market, "Insurance hard market", "Premiums up \(Int((Simulation.insuranceHardMarketMultiplier - 1) * 100))%")
        }
        // #12 Maintenance cost inflation — parts/MRO spike (AOG repair cost only).
        if tick >= maintInflationExpiryTick, Double.random(in: 0..<1) < Simulation.maintInflationDailyProbability {
            maintInflationExpiryTick = tick + (5 + Int.random(in: 0...8)) * 1440
            logOps(.market, "Maintenance cost inflation", "Repair costs +\(Int((Simulation.maintInflationMultiplier - 1) * 100))%")
        }
        // #13 FX shock — widebody fares only (needs at least one owned widebody).
        if !fxShockActive, Double.random(in: 0..<1) < Simulation.fxShockDailyProbability,
           aircraft.contains(where: { $0.purchased && $0.type.bodyType.usesWidebodyGateFee }) {
            fxShockExpiryTick = tick + (5 + Int.random(in: 0...10)) * 1440
            logOps(.market, "FX shock", "Widebody fares −\(Int((1 - Simulation.fxFareMultiplier) * 100))%")
        }
        // #14 Competitor fare war — depresses ONE existing player route's fare.
        if fareWarRouteId == nil, Double.random(in: 0..<1) < Simulation.fareWarDailyProbability,
           let r = playerRoutes.randomElement() {
            fareWarRouteId = r.id
            fareWarExpiryTick = tick + (4 + Int.random(in: 0...8)) * 1440
            let comp = ["American Airlines", "Delta Air Lines", "Southwest Airlines", "United Airlines"].randomElement()!
            logOps(.market, "Fare war", "\(comp) dumps capacity \(r.originCode)-\(r.destCode)")
        }
    }

    /// #11 Insurance — bill the recurring MONTHLY premium (current fleet value ×
    /// rate, × the hard-market multiplier when active). Silent routine cost
    /// (tracked in totalInsuranceSpent for the Finance tab); the hard-market
    /// ONSET is what surfaces in the Ops feed.
    private func tickInsuranceBilling() {
        guard tick >= nextInsuranceBillTick else { return }
        nextInsuranceBillTick += Simulation.ticksPerMonth
        let owned = aircraft.filter { $0.purchased }
        guard !owned.isEmpty else { return }
        let fleetValue = owned.reduce(0) { $0 + sellValue(of: $1) }
        let mult = insuranceHardMarketActive ? Simulation.insuranceHardMarketMultiplier : 1
        let bill = Int((Double(fleetValue) * Simulation.insuranceRateMonthly * mult).rounded())
        playerBalance -= bill
        totalInsuranceSpent += bill
    }

    /// OFFER card: accept the slot buyback — credit the cash and close the route
    /// (its aircraft becomes an idle spare, crew released; the SLOT is sold, not
    /// the plane). The route is archived, keeping its P&L history reviewable.
    func resolveOfferAccept(_ decision: Decision) {
        defer { decisionQueue.removeAll { $0.id == decision.id } }
        guard let offer = decision.offer,
              let idx = playerRoutes.firstIndex(where: { $0.id == offer.routeId }) else { return }
        playerBalance += offer.amount
        totalOfferIncome += offer.amount
        let r = playerRoutes.remove(at: idx)
        r.closedTick = tick
        closedPlayerRoutes.append(r)
        for ac in aircraft where ac.assignedRouteId == offer.routeId {
            ac.assignedRouteId = nil
            if let cid = ac.crewId, let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == cid }) {
                crew.status = .available
            }
            ac.crewId = nil
            ac.holdReason = nil
        }
        logOps(.structural, "Slot sold", "\(offer.originCode) ↔\u{FE0E} \(offer.destCode): $\(offer.amount.formatted())")
    }

    /// OFFER card: decline — keep the route.
    func resolveOfferDecline(_ decision: Decision) {
        decisionQueue.removeAll { $0.id == decision.id }
    }

    private static let economicEventCheckInterval = 1440   // once per sim-day
    private static let economicEventDailyProbability = 0.15
    private static let economicEventMinDurationDays = 3
    private static let economicEventMaxDurationDays = 10

    /// Sim-days remaining on the active event (for the HUD banner).
    var eventDaysLeft: Int { max(0, Int((Double(economicEventTicksLeft) / (24 * 60)).rounded(.up))) }

    /// Randomly start / end economic events. Ported from tickEconomicEvents():
    /// checked once per sim-day, 15% chance to start when normal, 3–10 days.
    private func tickEconomicEvents() {
        if !currentEvent.isNormal {
            economicEventTicksLeft -= 1
            if economicEventTicksLeft <= 0 { currentEvent = .normal }
            return
        }
        guard tick % Simulation.economicEventCheckInterval == 0 else { return }
        if Double.random(in: 0..<1) < Simulation.economicEventDailyProbability {
            currentEvent = EconomicEvent.all.randomElement()!
            let days = Double(Simulation.economicEventMinDurationDays)
                     + Double.random(in: 0..<1) * Double(Simulation.economicEventMaxDurationDays - Simulation.economicEventMinDurationDays)
            economicEventTicksLeft = Int((days * 24 * 60).rounded())
            logOps(.market, currentEvent.label, opsEventSubtitle(currentEvent))
        }
    }

    // MARK: - Fuel hedging (a real call option on fuel cost)

    // A fuel hedge is a CALL OPTION: pay a premium now for the right to buy at
    // a locked price if the market spikes. The ASYMMETRY is the whole point —
    // it caps the player's cost multiplier at the ceiling ONLY when a spike
    // would push above it, and does NOT force costs up during a genuine price
    // drop (a real call option doesn't erase the benefit of prices falling).
    // If no spike ever happens, the premium is a genuine sunk cost — the same
    // "real downside risk" as leasing's fixed obligation, not free insurance.
    static let fuelHedgePremiumRate = 0.10     // real: Carter/Rogers/Simkins 2006 (≤10%)
    static let fuelHedgeCeiling = 1.0          // caps a spike's cost multiplier here
    static let fuelHedgeUtilization = 0.35     // designed: share of ticks an owned aircraft accrues op cost
    static let fuelHedgeDurations = [30, 60, 90]

    /// Tick the active hedge expires (nil = no hedge).
    private(set) var fuelHedgeExpiryTick: Int?
    var fuelHedgeActive: Bool { if let e = fuelHedgeExpiryTick { return tick < e } else { return false } }
    var fuelHedgeDaysRemaining: Int {
        guard let e = fuelHedgeExpiryTick, tick < e else { return 0 }
        return Int((Double(e - tick) / 1440).rounded(.up))
    }

    /// The asymmetric call-option cap, as a pure function (so it's testable
    /// without forcing an economic event): a spike is capped at the ceiling
    /// ONLY when hedged; a price drop (raw ≤ ceiling) always passes through.
    static func effectiveMultiplier(raw: Double, hedged: Bool) -> Double {
        (hedged && raw > fuelHedgeCeiling) ? fuelHedgeCeiling : raw
    }

    /// The multiplier the PLAYER actually pays. With an active hedge a spike is
    /// capped at the ceiling; a price drop passes through unchanged. The global
    /// economic banner deliberately shows the RAW `currentEvent.costMultiplier`
    /// (the market's true state), NOT this hedged view.
    var effectiveCostMultiplier: Double {
        Simulation.effectiveMultiplier(raw: currentEvent.costMultiplier, hedged: fuelHedgeActive)
    }

    /// Premium for a `days`-length hedge, priced against the player's ACTUAL
    /// owned fleet's expected operating cost over that window (not a flat fee) —
    /// real hedges are priced against expected consumption the same way. Scales
    /// linearly with duration. Empty fleet → $0 (there's nothing to hedge).
    func fuelHedgePremium(days: Int) -> Int {
        let durationTicks = Double(days * 1440)
        let expectedOpCost = aircraft.lazy.filter { $0.purchased }.reduce(0.0) {
            $0 + Double($1.type.holdCostPerTick) * durationTicks * Simulation.fuelHedgeUtilization
        }
        return Int((expectedOpCost * Simulation.fuelHedgePremiumRate).rounded())
    }

    enum FuelHedgeResult { case success, noFleet, alreadyActive, insufficientFunds(Int) }

    /// Buy a hedge (only when none is active and the player owns aircraft).
    @discardableResult
    func buyFuelHedge(days: Int) -> FuelHedgeResult {
        guard ownedCount > 0 else { return .noFleet }
        guard !fuelHedgeActive else { return .alreadyActive }
        let premium = fuelHedgePremium(days: days)
        guard playerBalance >= premium else { return .insufficientFunds(premium) }
        playerBalance -= premium
        totalHedgeSpend += premium
        fuelHedgeExpiryTick = tick + days * 1440
        return .success
    }

    // Running financial totals (a fresh session's ledger). playerBalance and
    // the ownership economy arrive in a later slice; for now this is the sim's
    // net result.
    private(set) var totalRevenue = 0
    private(set) var totalFees = 0
    private(set) var totalOperatingCost = 0
    var netRevenue: Int { totalRevenue - totalFees - totalOperatingCost }

    // Capital-account totals (for the Finance tab). Together with the operating
    // totals above, the recurring totals (lease/insurance/maintenance), and
    // startingCapital, these RECONCILE exactly to playerBalance — every place
    // that moves cash also books into one of these. Keep that invariant if you
    // add a new cash flow.
    private(set) var totalAcquisitionSpend = 0   // buy + used-buy + lease upfront
    private(set) var totalRouteSpend = 0         // route opening costs
    private(set) var totalHedgeSpend = 0         // fuel-hedge premiums
    private(set) var totalSaleProceeds = 0       // aircraft sales
    private(set) var totalOfferIncome = 0        // slot-buyback offers accepted
    private(set) var totalFlightsFlown = 0       // owned-aircraft legs settled

    // MARK: Per-period finance history (for the Finance tab's period views)

    /// A frozen copy of every cumulative total (plus cash / net worth) at one
    /// instant. One is captured at launch (tick 0) and at each sim-month
    /// boundary; a period's activity is the difference between two snapshots,
    /// which reconciles the same way the cumulative ledger does.
    struct FinanceSnapshot {
        let tick, revenue, fees, operatingCost: Int
        let leaseCost, insurance, maintenance: Int
        let acquisition, routeSpend, hedgeSpend: Int
        let saleProceeds, offerIncome, flights: Int
        let cash, netWorth: Int
    }
    private(set) var financeSnapshots: [FinanceSnapshot] = []
    private func financeSnapshotNow() -> FinanceSnapshot {
        FinanceSnapshot(tick: tick, revenue: totalRevenue, fees: totalFees,
                        operatingCost: totalOperatingCost, leaseCost: totalLeaseCost,
                        insurance: totalInsuranceSpent, maintenance: maintenanceSpend,
                        acquisition: totalAcquisitionSpend, routeSpend: totalRouteSpend,
                        hedgeSpend: totalHedgeSpend, saleProceeds: totalSaleProceeds,
                        offerIncome: totalOfferIncome, flights: totalFlightsFlown,
                        cash: playerBalance, netWorth: playerBalance + fleetMarketValue)
    }

    /// Roll a leg's revenue at scheduling time — pax-first so displayed pax and
    /// revenue always agree. Ported from rollRevenue(). Stored on the aircraft.
    private func rollRevenue(for ac: Aircraft) {
        let avgFare = ac.type.bodyType.avgFarePerSeat
        // Event fare modifiers: #13 FX shock (widebody only) and #14 fare war
        // (this specific route only) stack on top of the economic condition.
        var fareMult = currentEvent.fareMultiplier
        if fxShockActive, ac.type.bodyType.usesWidebodyGateFee { fareMult *= Simulation.fxFareMultiplier }
        if let fw = fareWarRouteId, ac.assignedRouteId == fw, tick < fareWarExpiryTick { fareMult *= Simulation.fareWarMultiplier }
        let farePerSeat = avgFare * fareMult * (0.9 + Double.random(in: 0..<0.2))  // ±10%
        // Load factor: with the demand model ON (prototype), it's an OUTCOME of
        // this route's passenger demand vs. this aircraft's seats — so a widebody
        // on a thin route flies half-empty. With it OFF (dev A/B toggle), the old
        // flat industry baseline. Event/random modifiers apply on top of both.
        let load: Double
        if useDemandModel {
            let base = Demand.loadFactor(seats: ac.type.seats,
                                         dailyOneWay: Demand.dailyOneWay(ac.origin, ac.dest))
            load = min(Demand.maxLoadFactor, base * currentEvent.loadMultiplier * (0.9 + Double.random(in: 0..<0.2)))
        } else {
            load = min(1, baseLoadFactor * currentEvent.loadMultiplier * (0.95 + Double.random(in: 0..<0.1)))  // ±5%, capped
        }
        let pax = Int((Double(ac.type.seats) * load).rounded())
        ac.currentLoadFactor = load
        ac.currentPax = pax
        ac.projectedRevenue = Int((Double(pax) * farePerSeat).rounded())
        ac.holdBurn = 0   // fresh leg — no hold cost accrued yet
    }

    /// Real economics for a leg (projected while flying, settled at arrival).
    /// Ported from computeLegEconomics(): weight-based landing fee, body-type
    /// gate fee, per-bodyType stage-length operating cost × event multiplier.
    func legEconomics(for ac: Aircraft) -> LegEconomics {
        let landingFee = Int((ac.dest.landingFeePerKlb * (Double(ac.type.mlwLbs) / 1000)).rounded())
        let gateFee = Int(ac.type.bodyType.usesWidebodyGateFee ? ac.dest.gateFeeWidebody : ac.dest.gateFeeNarrowbody)
        // Base stage-length operating cost + any accrued hold burn (a held
        // flight keeps burning money at the gate — booked as cost, so revenue
        // stays = pax × fare and never goes negative). Net is identical to the
        // old "erode revenue" model, just correctly attributed.
        let opCost = Int((Double(ac.type.bodyType.operatingCostBlockMinutes)
                          * Double(ac.type.holdCostPerTick) * effectiveCostMultiplier).rounded())
                     + ac.holdBurn
        // DISPLAY-ONLY: a smoothed lease-per-leg figure for the tooltip. Does
        // not affect net/settlement — real lease is billed monthly. Ported
        // from computeLegEconomics: blockMinutes × (monthlyLeaseCost / month).
        let leaseEst = ac.isLeased
            ? Int((Double(ac.type.bodyType.operatingCostBlockMinutes)
                   * Double(ac.type.monthlyLeaseCost) / Double(Simulation.ticksPerMonth)).rounded())
            : 0
        return LegEconomics(revenue: ac.projectedRevenue, landingFee: landingFee,
                            gateFee: gateFee, operatingCost: opCost, leaseCostEstimate: leaseEst)
    }

    /// Settle a completed leg. Only OWNED aircraft move the player's money /
    /// route P&L; stress-test traffic is pure flavor.
    private func settleLeg(_ ac: Aircraft) {
        let econ = legEconomics(for: ac)
        guard ac.purchased else { return }
        totalFlightsFlown += 1
        totalRevenue += econ.revenue
        totalFees += econ.fees
        totalOperatingCost += econ.operatingCost
        playerBalance += econ.net
        if let id = ac.assignedRouteId, let r = playerRoutes.first(where: { $0.id == id }) {
            r.cumulativeNet += econ.net
            r.flights += 1
            r.history.append(FlightRecord(
                id: r.history.count, tick: tick, tail: ac.tail,
                revenue: econ.revenue, fees: econ.fees, operatingCost: econ.operatingCost,
                leaseCostEstimate: econ.leaseCostEstimate, net: econ.net,
                pax: ac.currentPax, seats: ac.type.seats, loadFactor: ac.currentLoadFactor,
                cumulativeNet: r.cumulativeNet))
        }
        // At 80% of expected lifespan, offer a one-time sell decision.
        if !ac.sellOfferDismissed && ac.cyclesAccrued >= Int(Double(ac.type.expectedLifespanCycles) * 0.8) {
            pushDecision(.sell, for: ac)
        }
    }

    /// SELL card option: sell at linear-depreciated value, close its route.
    func resolveSell(_ decision: Decision) { if let ac = decision.aircraft { sellAircraft(ac) } }

    /// Sell an aircraft (from the SELL card OR the Fleet detail screen): credit
    /// its depreciated value, release its crew, archive its route, remove it,
    /// and clear any pending decision cards for it.
    func sellAircraft(_ ac: Aircraft) {
        let proceeds = sellValue(of: ac)
        playerBalance += proceeds
        totalSaleProceeds += proceeds
        // Release the sold aircraft's crew back to the pool (it isn't sold with
        // the aircraft) before the cleanup pass.
        if let cid = ac.crewId, let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == cid }) {
            crew.status = .available
        }
        ac.crewId = nil
        if let id = ac.assignedRouteId, let idx = playerRoutes.firstIndex(where: { $0.id == id }) {
            // Archive, don't discard — the route's full P&L history stays
            // reviewable (including one that never recouped its cost).
            let r = playerRoutes.remove(at: idx)
            r.closedTick = tick
            closedPlayerRoutes.append(r)
            logOps(.structural, "Route closed", "\(r.originCode) ↔︎ \(r.destCode)")
            decisionQueue.removeAll { $0.kind == .offer && $0.offer?.routeId == id }
            airports.first { $0.code == r.originCode }?.slotsAvailable += 1
            airports.first { $0.code == r.destCode }?.slotsAvailable += 1
        }
        aircraft.removeAll { $0 === ac }
        decisionQueue.removeAll { $0.aircraft === ac }
        resizeCrewPools()   // clears the family's pool only if this was its last aircraft
    }

    /// SELL card option: keep flying (don't re-prompt this aircraft).
    func resolveSellKeep(_ decision: Decision) {
        decision.aircraft?.sellOfferDismissed = true
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// One sim-minute for the whole world.
    func advanceTick() {
        tick += 1
        // Capture a finance snapshot at each sim-month boundary (the launch
        // baseline is seeded in init) for the Finance tab's period views.
        if tick % Simulation.ticksPerMonth == 0 { financeSnapshots.append(financeSnapshotNow()) }
        tickWeather()
        tickCrewPool()
        tickAOGOnset()
        tickEconomicEvents()
        tickWorldEvents()
        tickSlotAvailability()
        tickLeaseBilling()
        tickInsuranceBilling()
        tickUsedMarketReplenishment()
        for ac in aircraft {
            switch ac.advance(tick: tick, assignCrew: assignCrew, releaseCrew: releaseCrew) {
            case .aogHoldStarted:      pushDecision(.aog, for: ac)
            case .aogRepairCompleted:  clearDecision(.aog, for: ac)   // defensive — card normally already resolved
            case .crewHoldStarted:     pushDecision(.crew, for: ac)
            case .crewHoldResolved:    clearDecision(.crew, for: ac)  // crew freed up outside the card's own buttons
            case .legScheduled:
                // Background traffic picks a NEW route each cycle, but within its
                // carrier's own geographic sphere (home region ± plausible
                // international corridors) — NOT a random global pair, which used to
                // let a carrier wander anywhere. Owned aircraft keep their assigned
                // route (advance already swapped origin/dest).
                if !ac.purchased { (ac.origin, ac.dest) = backgroundLeg(for: ac.homeRegion ?? .us) }
                rollRevenue(for: ac)
            case .legCompleted:        settleLeg(ac)
            case nil:                  break
            }
            // A booked aircraft still burns money while stuck at the gate
            // (AOG/crew) — accrue that burn as OPERATING COST (not negative
            // revenue), scaled by the effective (hedge-aware) cost multiplier.
            // Charged at a FRACTION of the flight rate (holdBurnRate) — a parked
            // aircraft isn't burning full block-hour cost. Net still slides toward
            // loss the longer it's held (plus the lost flights), so the pressure
            // to resolve a hold / hire crew remains.
            if ac.holdReason == .aog || ac.holdReason == .crew {
                ac.holdBurn += Int((Double(ac.type.holdCostPerTick) * Simulation.holdBurnRate * effectiveCostMultiplier).rounded())
            }
        }
    }

    /// Per-airport weather ground stops. Onset uses each airport's real
    /// groundStopsPerMonth rate; duration 90–330 ticks (1.5–5.5 sim-hours).
    /// Ported from tickWeather(). Universal — applies to all traffic.
    private func tickWeather() {
        let relevant = playerRouteCodes   // only log weather where the player flies
        for ap in airports {
            if ap.groundStop {
                ap.groundStopTicksLeft -= 1
                if ap.groundStopTicksLeft <= 0 {
                    ap.groundStop = false
                    if relevant.contains(ap.code) { logOps(.disruption, "Ground stop lifted", ap.code) }
                }
            } else if Double.random(in: 0..<1) < ap.groundStopsPerMonth / Double(Simulation.ticksPerMonth) {
                ap.groundStop = true
                ap.groundStopTicksLeft = 90 + Int.random(in: 0...240)
                if relevant.contains(ap.code) { logOps(.disruption, "Ground stop", "Weather hold at \(ap.code)") }
            }
        }
    }

    /// The async tick loop. Start once from the view's `.task`; it advances the
    /// world in real time based on `speed`, independent of how often the view
    /// draws. Cancelling the surrounding Task (view disappears) ends it.
    func run() async {
        var last = ContinuousClock.now
        var accumulatorMs: Double = 0

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(8))
            let now = ContinuousClock.now
            let deltaMs = Double((now - last).components.attoseconds) / 1e15
                        + Double((now - last).components.seconds) * 1000
            last = now

            guard speed > 0 else { continue }

            accumulatorMs += deltaMs
            let intervalMs = Simulation.baseTickMs / speed
            var ticksThisWake = 0
            while accumulatorMs >= intervalMs && ticksThisWake < 50 {
                advanceTick()
                accumulatorMs -= intervalMs
                ticksThisWake += 1
            }
        }
    }
}
