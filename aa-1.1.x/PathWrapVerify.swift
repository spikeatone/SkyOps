//
//  PathWrapVerify.swift — regression guard for the transpacific "routes across
//  the Atlantic" bug (player-reported, 8 Sep 2026).
//
//  FlightPath.pathPoints used to interpolate between two RAW screen points, so a
//  leg whose endpoints straddle the antimeridian seam (LAX↔HND) drew the LONG way
//  round the wrap-around map. Now every path runs to the copy of its destination
//  nearest the origin (FlightPath.nearestCopy), driven by FlightPath.wrapWidth —
//  the wrap period in screen px that Simulation.projectAirports() refreshes each
//  frame (0 in headless harnesses = the old flat geometry, unchanged).
//
//  Pure geometry — compiles with just two Sim files, no harness stubs needed:
//
//    cd AirlineArchitect/AirlineArchitect
//    cp ../../aa-1.1.x/PathWrapVerify.swift /tmp/main.swift
//    swiftc -O Sim/FlightPath.swift Sim/FlightState.swift /tmp/main.swift -o /tmp/pathwrap
//    /tmp/pathwrap            # expect 16/16
//
import Foundation
import CoreGraphics

var pass = 0, fail = 0
func check(_ name: String, _ ok: Bool) {
    if ok { pass += 1; print("✓ \(name)") } else { fail += 1; print("✗ \(name)") }
}

let o = CGPoint(x: 100, y: 200)      // e.g. LAX
let d = CGPoint(x: 1500, y: 220)     // e.g. HND, far to the "east" on a 1700px-period map

// 1. No wrap (the harness default) == the old flat prototype geometry, untouched.
check("static wrapWidth defaults to 0", FlightPath.wrapWidth == 0)
let flat = FlightPath.pathPoints(origin: o, dest: d, wrapWidth: 0)
check("no-wrap: end == raw dest", flat.end == d)
check("no-wrap: mid.x is the flat midpoint", abs(flat.mid.x - 800) < 1e-9)
let flatArc = min(120.0, max(15.0, hypot(1400.0, 20.0) * 0.12))
check("no-wrap: arc height from the long distance (capped 120)", abs((200 - flat.mid.y) - flatArc) < 1e-9)

// 2. With a 1700px wrap period: 1500-100 = 1400 > 850 → the short way is WEST,
//    to the copy of HND at x = 100 + (1400 - 1700) = -200.
let w = FlightPath.pathPoints(origin: o, dest: d, wrapWidth: 1700)
check("wrap: end.x shifted to the nearest copy (-200)", abs(w.end.x - (-200)) < 1e-9)
check("wrap: end.y unchanged", w.end.y == d.y)
check("wrap: mid.x is the SHORT midpoint (-50)", abs(w.mid.x - (-50)) < 1e-9)
let shortArc = min(120.0, max(15.0, hypot(300.0, 20.0) * 0.12))
check("wrap: arc height from the SHORT distance", abs((200 - w.mid.y) - shortArc) < 1e-9)

// 3. A same-side pair is untouched by the wrap.
let near = FlightPath.pathPoints(origin: o, dest: CGPoint(x: 400, y: 300), wrapWidth: 1700)
check("wrap: same-side pair untouched", near.end == CGPoint(x: 400, y: 300))

// 4. The return leg mirrors it (HND→LAX also goes the short way, eastward off the right edge).
let rev = FlightPath.pathPoints(origin: d, dest: o, wrapWidth: 1700)
check("wrap: reverse leg mirrors (end.x = 1800)", abs(rev.end.x - 1800) < 1e-9)

// 5. nearestCopy is idempotent and never moves y.
let nc = FlightPath.nearestCopy(of: d, to: o, wrapWidth: 1700)
check("nearestCopy idempotent", FlightPath.nearestCopy(of: nc, to: o, wrapWidth: 1700) == nc)

// 6. The aircraft rides the short path: heading points WEST mid-cruise, and the
//    landed aircraft sits at the shifted end (same tiled copy it flew into).
FlightPath.wrapWidth = 1700
let cruise = FlightPath.position(state: .cruise, progress: 0.5, origin: o, dest: d)
check("cruise: heading points west (dx < 0)", cos(cruise.heading) < 0)
check("cruise: x between origin and shifted dest", cruise.point.x < 100 && cruise.point.x > -200)
let landed = FlightPath.position(state: .turnaround, progress: 0, origin: o, dest: d)
check("turnaround: sits at the shifted end, not the raw dest", abs(landed.point.x - (-200)) < 1e-9)
let parked = FlightPath.position(state: .parked, progress: 0, origin: o, dest: d)
check("parked: still at origin", parked.point == o)
FlightPath.wrapWidth = 0

// 7. Restoring wrapWidth = 0 restores the flat geometry exactly.
check("after reset: flat again", FlightPath.pathPoints(origin: o, dest: d).end == d)

print("\n\(pass)/\(pass + fail) passed")
exit(fail == 0 ? 0 : 1)
