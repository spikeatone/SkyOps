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

    private var lastLayoutSize: CGSize = .zero
    private var nextTailNum = 1

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
            aircraft.removeLast(aircraft.count - target)
        } else {
            while aircraft.count < target { aircraft.append(makeAircraft()) }
        }
    }

    var fleetCount: Int { aircraft.count }

    // MARK: - Layout

    /// Fit every airport's projected world-unit position into `size` (pixels)
    /// with padding, preserving aspect ratio. Mirrors the prototype projecting
    /// into canvas pixels; the flight-path math then works in this pixel space.
    func layout(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if size == lastLayoutSize { return }
        lastLayoutSize = size

        let padding: CGFloat = 80
        let usableW = max(1, size.width - padding * 2)
        let usableH = max(1, size.height - padding * 2)

        // Frame continental US by default (like the prototype's
        // resetCameraToConus). ANC/HNL are geographic outliers that would
        // squish CONUS into a tiny cluster if included in the bounds; they
        // still render, just off the framed area until the Phase 4 pan/zoom
        // camera lands. All airports are positioned with the SAME scale/offset.
        let framed = airports.filter { $0.code != "ANC" && $0.code != "HNL" }
        let xs = framed.map { $0.unit.x }
        let ys = framed.map { $0.unit.y }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        let spanX = max(0.0001, maxX - minX)
        let spanY = max(0.0001, maxY - minY)

        let scale = min(usableW / spanX, usableH / spanY)
        // centre the fitted content
        let contentW = spanX * scale
        let contentH = spanY * scale
        let offsetX = padding + (usableW - contentW) / 2
        let offsetY = padding + (usableH - contentH) / 2

        for ap in airports {
            ap.screen = CGPoint(x: offsetX + (ap.unit.x - minX) * scale,
                                y: offsetY + (ap.unit.y - minY) * scale)
        }
    }

    // MARK: - Tick

    /// One sim-minute for the whole world.
    func advanceTick() {
        tick += 1
        for ac in aircraft { ac.advance() }
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
