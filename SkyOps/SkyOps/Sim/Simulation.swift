//
//  Simulation.swift
//  SkyOps — Phase 1
//
//  Owns the world (airports + aircraft) and the tick clock. The tick loop is a
//  Swift-Concurrency async task, decoupled from the render frame rate exactly
//  like the prototype's requestAnimationFrame accumulator: 1 tick = BASE_TICK_MS
//  of real time at 1× speed, divided by the speed multiplier, capped at 50
//  catch-up ticks per wake so a stall can't spiral. The view renders every
//  frame (TimelineView) and just reads whatever position the sim is currently at.
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

    init() {
        // Phase 1: two real airports and one aircraft flying the route between.
        let sfo = Airport(code: "SFO", lat: 37.6213, lon: -122.3790)
        let jfk = Airport(code: "JFK", lat: 40.6413, lon: -73.7781)
        airports = [sfo, jfk]
        aircraft = [Aircraft(tail: "SKY001", origin: sfo, dest: jfk)]
    }

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

        let xs = airports.map { $0.unit.x }
        let ys = airports.map { $0.unit.y }
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
