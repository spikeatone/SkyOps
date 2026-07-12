//
//  Simulation.swift
//  SkyOps — Phase 1–2
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

    /// Speed multiplier. Prototype default is 5× (feels smooth; at 1× the
    /// aircraft visibly steps every 250 ms, which is expected, not a bug).
    var speed: Double = 5

    private var nextTailNum = 1

    // MARK: - Camera (pan / zoom), ported from the prototype's camera model.
    // Everything on the map lives in resolution-independent "unit" space; the
    // camera maps unit→screen each frame. Default view frames the continental
    // US (resetCameraToConus); zoom clamps to [0.4×, 4×].

    static let cameraMinZoom: CGFloat = 0.4    // out enough to see AK+HI+CONUS
    static let cameraMaxZoom: CGFloat = 14     // in close enough to inspect a single metro
    private static let elementZoomGrowthMax: CGFloat = 0.15  // icon growth cap

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
    func aircraft(atScreenPoint p: CGPoint, tolerance: CGFloat = 24) -> Aircraft? {
        var best: (ac: Aircraft, d: CGFloat)?
        for ac in aircraft {
            let pos = ac.position(tick: tick).point
            let d = hypot(pos.x - p.x, pos.y - p.y)
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
        setFleetSize(60)   // provisions crew as part of sizing the fleet
    }

    // MARK: - Fleet

    /// Spawn one stress-test aircraft — weighted type, random route, staggered
    /// start. Ported from makeAircraft().
    private func makeAircraft() -> Aircraft {
        let type = AircraftType.pickWeighted()
        let (origin, dest) = Airport.randomPair()
        let tail = "N\(nextTailNum)SK"
        nextTailNum += 1
        let ac = Aircraft(tail: tail,
                          type: type,
                          origin: origin,
                          dest: dest,
                          stateIndex: Int.random(in: 0..<FlightState.allCases.count),
                          cyclesAccrued: Int.random(in: 0..<Int(Double(type.expectedLifespanCycles) * 0.9)))
        rollRevenue(for: ac)   // seed this leg's revenue before its first arrival
        return ac
    }

    /// Grow or shrink the fleet to `n` (stress-test control; all aircraft are
    /// non-owned so a plain trim is fine — the purchased-vs-spawn distinction
    /// arrives with the Phase 5 economy).
    func setFleetSize(_ n: Int) {
        let target = max(0, n)
        if target < aircraft.count {
            let removed = aircraft[target...]
            aircraft.removeLast(aircraft.count - target)
            // don't leave decision cards pointing at aircraft that no longer
            // exist (same stale-card bug family the prototype documented)
            decisionQueue.removeAll { d in removed.contains(where: { $0 === d.aircraft }) }
        } else {
            while aircraft.count < target { aircraft.append(makeAircraft()) }
        }
        // re-size the crew roster to the new fleet (a stress-test control; the
        // player-driven Phase 5 model won't re-provision like this)
        if !crewPoolsByFamily.isEmpty || !aircraft.isEmpty { provisionCrew() }
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
        for ac in aircraft where !ac.maint {
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

    /// Pre-ownership provisioning ratio: crews per aircraft in a family. Sized
    /// so ops mostly flow but a crew resting occasionally leaves an aircraft
    /// briefly short → a real, OCCASIONAL crew hold. When ownership (Phase 5)
    /// lands, this auto-provisioning is REPLACED by the player-driven model
    /// (1 crew bundled per purchase + the ADD CREW hire panel) — same scoping
    /// debt as AOG. Real `crewsPerTail` (6 short / 11 long haul) stays a
    /// reference figure the player reasons about, not consumed here.
    /// Crews per aircraft in a family. TUNED via a headless balance sweep:
    /// ~1.8 is the duty/rest break-even (a crew flies ~55% of the time), so at
    /// or below it a shortage CASCADES into a permanent jam (whole fleet held);
    /// at 1.9–2.4 the system is steady with only occasional 1–2 aircraft holds;
    /// 2.6+ never holds at all. 2.1 gives occasional, recoverable crew holds.
    /// (The real crew-management tension — starting under-crewed and hiring —
    /// arrives with the player-driven Phase 5 model; this is the stand-in.)
    private static let crewsPerAircraft = 2.1
    private static let reservesPerFamily = 2

    private(set) var crewPoolsByFamily: [String: [Crew]] = [:]
    private(set) var reserveCrewsByFamily: [String: Int] = [:]

    /// (Re)build the crew pools sized to the current fleet, then backfill crews
    /// for aircraft that spawned mid-flight with partial duty already elapsed
    /// (staggered starts represent a running operation, not an all-fresh one).
    private func provisionCrew() {
        for ac in aircraft { ac.crewId = nil }
        crewPoolsByFamily = [:]
        reserveCrewsByFamily = [:]
        var counts: [String: Int] = [:]
        for ac in aircraft { counts[ac.type.family, default: 0] += 1 }
        for (family, count) in counts {
            let size = max(1, Int((Double(count) * Simulation.crewsPerAircraft).rounded()))
            crewPoolsByFamily[family] = (0..<size).map { Crew(id: $0) }
            reserveCrewsByFamily[family] = Simulation.reservesPerFamily
        }
        backfillStaggeredCrews()
    }

    private func backfillStaggeredCrews() {
        for ac in aircraft where ac.crewId == nil && ac.state != .parked {
            guard let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.status == .available }) else { continue }
            crew.status = .onDuty
            crew.dutyTicks = Int.random(in: 0..<(Crew.maxDutyTicks / 2))  // partial duty already elapsed
            ac.crewId = crew.id
        }
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
                case .available:
                    break
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
        enum Kind { case aog, crew }
        let id: String
        let kind: Kind
        let aircraft: Aircraft
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

    /// AOG card option 1: pay to have the aircraft ready now.
    func resolveAOGExpedite(_ decision: Decision) {
        maintenanceSpend += 15_000
        decision.aircraft.maint = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// AOG card option 2: cheaper repair on a ~3 sim-hour timer; the aircraft
    /// stays held until it completes.
    func resolveAOGStandard(_ decision: Decision) {
        maintenanceSpend += 3_000
        decision.aircraft.aogAutoClearTick = tick + 180
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// True if a family still has a reserve crew to call in.
    func hasReserve(for ac: Aircraft) -> Bool { (reserveCrewsByFamily[ac.type.family] ?? 0) > 0 }

    /// CREW card option 1: call in a reserve crew ($5,000), assigned now so the
    /// aircraft boards this cycle. Disabled when the family is out of reserves.
    func resolveCrewReserve(_ decision: Decision) {
        let ac = decision.aircraft
        let family = ac.type.family
        guard (reserveCrewsByFamily[family] ?? 0) > 0 else { return }
        reserveCrewsByFamily[family]! -= 1
        maintenanceSpend += 5_000
        let crew = Crew(id: crewPoolsByFamily[family]?.count ?? 0)
        crew.status = .onDuty
        crewPoolsByFamily[family, default: []].append(crew)
        ac.crewId = crew.id
        ac.holdReason = nil
        ac.holdLogged = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// CREW card option 2: dismiss and let the aircraft keep waiting on the
    /// pool — the boarding gate assigns a crew the moment one frees up.
    func resolveCrewWait(_ decision: Decision) {
        decisionQueue.removeAll { $0.id == decision.id }
    }

    // MARK: - Economics (per-flight revenue / cost / fees)

    /// Active economic condition. Only NORMAL until the events slice.
    private(set) var currentEvent = EconomicEvent.normal

    // Running financial totals (a fresh session's ledger). playerBalance and
    // the ownership economy arrive in a later slice; for now this is the sim's
    // net result.
    private(set) var totalRevenue = 0
    private(set) var totalFees = 0
    private(set) var totalOperatingCost = 0
    var netRevenue: Int { totalRevenue - totalFees - totalOperatingCost }

    /// Roll a leg's revenue at scheduling time — pax-first so displayed pax and
    /// revenue always agree. Ported from rollRevenue(). Stored on the aircraft.
    private func rollRevenue(for ac: Aircraft) {
        let avgFare = ac.type.bodyType.avgFarePerSeat
        let farePerSeat = avgFare * currentEvent.fareMultiplier * (0.9 + Double.random(in: 0..<0.2))  // ±10%
        let load = min(1, baseLoadFactor * currentEvent.loadMultiplier * (0.95 + Double.random(in: 0..<0.1)))  // ±5%, capped
        let pax = Int((Double(ac.type.seats) * load).rounded())
        ac.currentLoadFactor = load
        ac.currentPax = pax
        ac.projectedRevenue = Int((Double(pax) * farePerSeat).rounded())
    }

    /// Real economics for a leg (projected while flying, settled at arrival).
    /// Ported from computeLegEconomics(): weight-based landing fee, body-type
    /// gate fee, per-bodyType stage-length operating cost × event multiplier.
    func legEconomics(for ac: Aircraft) -> LegEconomics {
        let landingFee = Int((ac.dest.landingFeePerKlb * (Double(ac.type.mlwLbs) / 1000)).rounded())
        let gateFee = Int(ac.type.bodyType.usesWidebodyGateFee ? ac.dest.gateFeeWidebody : ac.dest.gateFeeNarrowbody)
        let opCost = Int((Double(ac.type.bodyType.operatingCostBlockMinutes)
                          * Double(ac.type.holdCostPerTick) * currentEvent.costMultiplier).rounded())
        return LegEconomics(revenue: ac.projectedRevenue, landingFee: landingFee,
                            gateFee: gateFee, operatingCost: opCost)
    }

    /// Settle a completed leg into the running totals.
    private func settleLeg(_ ac: Aircraft) {
        let econ = legEconomics(for: ac)
        totalRevenue += econ.revenue
        totalFees += econ.fees
        totalOperatingCost += econ.operatingCost
    }

    /// One sim-minute for the whole world.
    func advanceTick() {
        tick += 1
        tickWeather()
        tickCrewPool()
        tickAOGOnset()
        for ac in aircraft {
            switch ac.advance(tick: tick, assignCrew: assignCrew, releaseCrew: releaseCrew) {
            case .aogHoldStarted:      pushDecision(.aog, for: ac)
            case .aogRepairCompleted:  clearDecision(.aog, for: ac)   // defensive — card normally already resolved
            case .crewHoldStarted:     pushDecision(.crew, for: ac)
            case .crewHoldResolved:    clearDecision(.crew, for: ac)  // crew freed up outside the card's own buttons
            case .legScheduled:        rollRevenue(for: ac)
            case .legCompleted:        settleLeg(ac)
            case nil:                  break
            }
            // A booked aircraft still burns money while stuck at the gate
            // (AOG/crew) — erode the leg's revenue at its per-tick cost, scaled
            // by any economic event. One held number crosses profit → loss.
            if ac.holdReason == .aog || ac.holdReason == .crew {
                ac.projectedRevenue -= Int((Double(ac.type.holdCostPerTick) * currentEvent.costMultiplier).rounded())
            }
        }
    }

    /// Per-airport weather ground stops. Onset uses each airport's real
    /// groundStopsPerMonth rate; duration 90–330 ticks (1.5–5.5 sim-hours).
    /// Ported from tickWeather(). Universal — applies to all traffic.
    private func tickWeather() {
        for ap in airports {
            if ap.groundStop {
                ap.groundStopTicksLeft -= 1
                if ap.groundStopTicksLeft <= 0 { ap.groundStop = false }
            } else if Double.random(in: 0..<1) < ap.groundStopsPerMonth / Double(Simulation.ticksPerMonth) {
                ap.groundStop = true
                ap.groundStopTicksLeft = 90 + Int.random(in: 0...240)
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
