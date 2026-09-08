//
//  FlightPath.swift
//  Airline Architect — Phase 1
//
//  Position interpolation along a quadratic bezier arc between two airports,
//  ported VERBATIM from the prototype's getPathPoints / getAircraftPosition /
//  headingAt / bezier. The per-state `t` ranges are chained (takeoff 0→0.12,
//  cruise 0.12→0.82, approach 0.82→0.92, landing 0.92→1.0) so motion stays
//  continuous across phase boundaries — that continuity, plus the eased
//  takeoff/landing curves, is exactly what fixed the takeoff-jolt and
//  landing-teleport bugs. Do not "clean up" the magic numbers.
//
//  Phase 1 deliberately omits the WEATHER holding-pattern and REJOIN easing
//  branches — those belong to the Phase 3 weather system.
//

import Foundation
import CoreGraphics

/// A sampled aircraft position: screen point, altitude 0…1 (visual only for
/// now), and heading in radians (atan2 convention, +x = 0, clockwise).
struct AircraftPosition {
    var point: CGPoint
    var alt: Double
    var heading: Double
}

enum FlightPath {

    /// Quadratic bezier scalar. Ported verbatim.
    static func bezier(_ a: Double, _ b: Double, _ c: Double, _ t: Double) -> Double {
        (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c
    }

    /// Control points for the arc between two airports (screen pixels).
    /// Arc height scales with real distance — 12% of the straight-line
    /// distance, floored at 15px and capped at 120px — so short hops don't
    /// bulge like coast-to-coast routes (a real prototype bug fix).
    struct PathPoints {
        var start: CGPoint
        var mid: CGPoint
        var end: CGPoint
    }

    /// Horizontal wrap period of the map in screen pixels — the distance between
    /// tiled copies of the world. `Simulation.projectAirports()` refreshes it
    /// every frame from the live camera; 0 = no wrap (the headless harnesses
    /// never project, so they keep the flat prototype geometry unchanged).
    /// Every path runs to the copy of its destination NEAREST the origin, so a
    /// transpacific leg crosses the Pacific seam instead of drawing the long way
    /// round the world across the Atlantic (a real player-reported bug). This is
    /// the screen-space twin of the ±180° longitude normalization in
    /// `Airport.greatCircleNM` — the sim's distances were already right; only
    /// the drawn arc and the aircraft riding it went the wrong way.
    nonisolated(unsafe) static var wrapWidth: CGFloat = 0

    /// `dest` shifted by whole wrap periods to the tiled copy nearest `origin`.
    /// Identity when there's no wrap.
    static func nearestCopy(of dest: CGPoint, to origin: CGPoint,
                            wrapWidth: CGFloat = FlightPath.wrapWidth) -> CGPoint {
        guard wrapWidth > 1 else { return dest }
        var dx = (dest.x - origin.x).truncatingRemainder(dividingBy: wrapWidth)
        if dx > wrapWidth / 2 { dx -= wrapWidth } else if dx < -wrapWidth / 2 { dx += wrapWidth }
        return CGPoint(x: origin.x + dx, y: dest.y)
    }

    static func pathPoints(origin: CGPoint, dest rawDest: CGPoint,
                           wrapWidth: CGFloat = FlightPath.wrapWidth) -> PathPoints {
        let dest = nearestCopy(of: rawDest, to: origin, wrapWidth: wrapWidth)
        let midX = (origin.x + dest.x) / 2
        let dist = hypot(dest.x - origin.x, dest.y - origin.y)
        let arcHeight = min(120, max(15, dist * 0.12))
        let midY = min(origin.y, dest.y) - arcHeight
        return PathPoints(start: origin,
                          mid: CGPoint(x: midX, y: midY),
                          end: dest)
    }

    /// Heading (radians) of the path tangent at parameter `t`.
    static func heading(_ path: PathPoints, _ t: Double) -> Double {
        let dt = 0.01
        let t2 = min(t + dt, 1)
        let x1 = bezier(path.start.x, path.mid.x, path.end.x, t)
        let y1 = bezier(path.start.y, path.mid.y, path.end.y, t)
        let x2 = bezier(path.start.x, path.mid.x, path.end.x, t2)
        let y2 = bezier(path.start.y, path.mid.y, path.end.y, t2)
        return atan2(y2 - y1, x2 - x1)
    }

    static func point(_ path: PathPoints, at t: Double) -> CGPoint {
        CGPoint(x: bezier(path.start.x, path.mid.x, path.end.x, t),
                y: bezier(path.start.y, path.mid.y, path.end.y, t))
    }

    private static func pointOnPath(_ path: PathPoints, _ t: Double) -> CGPoint {
        point(path, at: t)
    }

    /// Shortest-arc angular interpolation (radians). Ported from lerpAngle().
    static func lerpAngle(_ a: Double, _ b: Double, _ t: Double) -> Double {
        var diff = ((b - a + .pi).truncatingRemainder(dividingBy: 2 * .pi)) - .pi
        if diff < -.pi { diff += 2 * .pi }
        return a + diff * t
    }

    /// Interpolated position for an aircraft, given its current phase and the
    /// fractional progress `p` (= stateTick / durationTicks) through it.
    /// Ported verbatim from getAircraftPosition (non-hold cases only).
    static func position(state: FlightState,
                         progress p: Double,
                         origin: CGPoint,
                         dest: CGPoint) -> AircraftPosition {
        let path = pathPoints(origin: origin, dest: dest)

        switch state {
        case .parked, .boarding:
            return AircraftPosition(point: origin, alt: 0, heading: heading(path, 0.001))

        case .taxiOut:
            // ease heading toward the flight direction during taxi instead of
            // snapping to it the instant takeoff starts
            let target = heading(path, 0.001)
            return AircraftPosition(point: origin, alt: 0, heading: target * p)

        case .takeoff:
            // quadratic ease-in: the roll accelerates rather than covering
            // ground in coarse equal steps
            let eased = p * p
            let t = eased * 0.12
            return AircraftPosition(point: pointOnPath(path, t),
                                    alt: eased * 0.2,
                                    heading: heading(path, max(t, 0.001)))

        case .cruise:
            let t = 0.12 + p * 0.7
            return AircraftPosition(point: pointOnPath(path, t), alt: 1, heading: heading(path, t))

        case .approach:
            let t = 0.82 + p * 0.10
            return AircraftPosition(point: pointOnPath(path, t),
                                    alt: 1 - p * 0.7,
                                    heading: heading(path, t))

        case .landing:
            // ease-out deceleration through flare + rollout, continuing the
            // same path instead of snapping to the destination coordinates
            let eased = 1 - (1 - p) * (1 - p)
            let t = 0.92 + eased * 0.08
            return AircraftPosition(point: pointOnPath(path, t),
                                    alt: (1 - eased) * 0.3,
                                    heading: heading(path, min(t, 0.999)))

        case .taxiIn, .turnaround:
            // path.end, not the raw dest: keeps the aircraft in the same tiled
            // copy it just flew into (the raw point is one wrap period away).
            return AircraftPosition(point: path.end, alt: 0, heading: heading(path, 0.999))
        }
    }
}
