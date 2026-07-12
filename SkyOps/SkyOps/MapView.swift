//
//  MapView.swift
//  SkyOps — Phase 1
//
//  Renders the world with a SwiftUI Canvas driven by TimelineView(.animation),
//  so the map redraws every frame regardless of the (separately clocked) tick
//  loop. Aircraft colour is tied to the real flight PHASE, not an altitude
//  threshold (the prototype's validated fix): green climb, blue cruise, amber
//  descent, amber on the ground.
//

import SwiftUI

struct MapView: View {
    let sim: Simulation

    /// The current tick, passed in as a VALUE (not read off `sim`). MapView's
    /// only other stored property is the `sim` reference, which never changes —
    /// so without a changing value input, SwiftUI diffs MapView as identical
    /// every tick and skips re-invoking its body, freezing the Canvas at the
    /// first frame. Passing tick as a value makes the input genuinely change
    /// each tick, guaranteeing the redraw. Aircraft position is a step-function
    /// of the tick, so this is exact, not just a hack.
    let tick: Int

    // Player per-phase colours, ported from the prototype.
    private let climbColor   = Color(red: 0x37/255, green: 0xFF/255, blue: 0xB0/255) // #37FFB0
    private let cruiseColor  = Color(red: 0x83/255, green: 0xC9/255, blue: 0xFF/255) // #83C9FF
    private let descentColor = Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255) // #FFB300
    private let groundColor  = Color(red: 0xE8/255, green: 0xA1/255, blue: 0x3C/255) // ground amber

    var body: some View {
        // `tick` (a changing value input) is what forces this body to re-run
        // each tick; the aircraft position is a step-function of it, so a
        // tick-driven redraw is both sufficient and exact. The tick loop stays
        // decoupled — it runs on its own async clock and this view just
        // re-renders in response to the state it produces.
        Canvas { ctx, size in
            sim.layout(in: size)
            drawGrid(ctx, size)
            drawRoutes(ctx)
            drawAirports(ctx)
            drawAircraft(ctx)
        }
        .background(Color(red: 0.03, green: 0.05, blue: 0.06))
        .ignoresSafeArea()
    }

    // MARK: - Layers

    private func drawGrid(_ ctx: GraphicsContext, _ size: CGSize) {
        let spacing: CGFloat = 40
        var path = Path()
        var x: CGFloat = 0
        while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
        var y: CGFloat = 0
        while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
        ctx.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 1)
    }

    private func drawRoutes(_ ctx: GraphicsContext) {
        for ac in sim.aircraft {
            let pp = FlightPath.pathPoints(origin: ac.origin.screen, dest: ac.dest.screen)
            var arc = Path()
            arc.move(to: pp.start)
            arc.addQuadCurve(to: pp.end, control: pp.mid)
            ctx.stroke(arc, with: .color(cruiseColor.opacity(0.18)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
    }

    private func drawAirports(_ ctx: GraphicsContext) {
        for ap in sim.airports {
            let r: CGFloat = 5
            let rect = CGRect(x: ap.screen.x - r, y: ap.screen.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(climbColor))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                       with: .color(climbColor.opacity(0.4)), lineWidth: 1)
            let text = Text(ap.code).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
            ctx.draw(text, at: CGPoint(x: ap.screen.x, y: ap.screen.y - 16), anchor: .center)
        }
    }

    private func drawAircraft(_ ctx: GraphicsContext) {
        for ac in sim.aircraft {
            let pos = ac.position
            let color = color(for: ac.state)

            // triangle pointing along +x, then rotated to heading
            let s: CGFloat = 9
            var tri = Path()
            tri.move(to: CGPoint(x: s, y: 0))
            tri.addLine(to: CGPoint(x: -s * 0.7, y: s * 0.6))
            tri.addLine(to: CGPoint(x: -s * 0.7, y: -s * 0.6))
            tri.closeSubpath()

            var transform = ctx
            transform.translateBy(x: pos.point.x, y: pos.point.y)
            transform.rotate(by: .radians(pos.heading))
            transform.fill(tri, with: .color(color))
        }
    }

    private func color(for state: FlightState) -> Color {
        switch state {
        case .takeoff:            return climbColor
        case .cruise:             return cruiseColor
        case .approach, .landing: return descentColor
        default:                  return groundColor  // all ground phases
        }
    }
}
