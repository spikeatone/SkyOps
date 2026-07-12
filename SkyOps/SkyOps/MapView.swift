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
        // One faint arc per aircraft's current leg — conveys the network
        // without dominating the map at high fleet counts.
        var arcs = Path()
        for ac in sim.aircraft {
            let pp = FlightPath.pathPoints(origin: ac.origin.screen, dest: ac.dest.screen)
            arcs.move(to: pp.start)
            arcs.addQuadCurve(to: pp.end, control: pp.mid)
        }
        ctx.stroke(arcs, with: .color(cruiseColor.opacity(0.07)), lineWidth: 1)
    }

    private func drawAirports(_ ctx: GraphicsContext) {
        // All 48 airports as small dots. Real label decluttering / leader
        // lines are a Phase 4 (map) concern; here they'd just overlap.
        var dots = Path()
        let r: CGFloat = 3.5
        for ap in sim.airports {
            dots.addEllipse(in: CGRect(x: ap.screen.x - r, y: ap.screen.y - r, width: r * 2, height: r * 2))
        }
        ctx.fill(dots, with: .color(climbColor.opacity(0.85)))
    }

    private func drawAircraft(_ ctx: GraphicsContext) {
        for ac in sim.aircraft {
            let pos = ac.position
            let color = color(for: ac.state)

            // Triangle sized by body-type tier (RJ < narrowbody < 2-engine
            // widebody < 4-engine), pointing along +x then rotated to heading.
            // Slice 2 replaces these with the real Figma vector icons.
            let len = ac.type.bodyType.iconLength
            var tri = Path()
            tri.move(to: CGPoint(x: len * 0.55, y: 0))
            tri.addLine(to: CGPoint(x: -len * 0.45, y: len * 0.32))
            tri.addLine(to: CGPoint(x: -len * 0.45, y: -len * 0.32))
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
