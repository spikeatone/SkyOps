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
        setFleetSize(60)
    }

    // MARK: - Fleet

    /// Spawn one stress-test aircraft — weighted type, random route, staggered
    /// start. Ported from makeAircraft().
    private func makeAircraft() -> Aircraft {
        let type = AircraftType.pickWeighted()
        let (origin, dest) = Airport.randomPair()
        let tail = "N\(nextTailNum)SK"
        nextTailNum += 1
        return Aircraft(tail: tail,
                        type: type,
                        origin: origin,
                        dest: dest,
                        stateIndex: Int.random(in: 0..<FlightState.allCases.count),
                        cyclesAccrued: Int.random(in: 0..<Int(Double(type.expectedLifespanCycles) * 0.9)))
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

    // MARK: - Decisions (AOG cards; CREW/SELL arrive with their systems)

    struct Decision: Identifiable {
        enum Kind { case aog }
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

    /// One sim-minute for the whole world.
    func advanceTick() {
        tick += 1
        tickWeather()
        tickAOGOnset()
        for ac in aircraft {
            switch ac.advance(tick: tick) {
            case .aogHoldStarted:      pushDecision(.aog, for: ac)
            case .aogRepairCompleted:  clearDecision(.aog, for: ac)   // defensive — card normally already resolved
            case nil:                  break
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
