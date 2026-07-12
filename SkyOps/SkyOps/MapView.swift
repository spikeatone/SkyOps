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
    private let heldColor     = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255) // #ff5c5c — held (weather)

    var body: some View {
        // `tick` (a changing value input) is what forces this body to re-run
        // each tick; the aircraft position is a step-function of it, so a
        // tick-driven redraw is both sufficient and exact. The tick loop stays
        // decoupled — it runs on its own async clock and this view just
        // re-renders in response to the state it produces.
        Canvas { ctx, size in
            sim.layout(in: size)
            drawGrid(ctx, size)
            drawBasemap(ctx)
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

    /// Real geography beneath the network: Canada (muted context) first, then
    /// the U.S. nation outline (faint green fill + brighter stroke), then state
    /// borders (fainter). Colours/order ported from drawGeographyLayers().
    /// Every point projects through the same transform as the airports.
    private func drawBasemap(_ ctx: GraphicsContext) {
        let t = sim.transform
        let map = Basemap.shared

        func ringPath(_ rings: [[CGPoint]]) -> Path {
            var path = Path()
            for ring in rings where ring.count >= 2 {
                path.move(to: t(ring[0]))
                for i in 1..<ring.count { path.addLine(to: t(ring[i])) }
                path.closeSubpath()
            }
            return path
        }

        // Canada — neutral gray context, behind everything.
        ctx.stroke(ringPath(map.canada),
                   with: .color(Color(red: 108/255, green: 127/255, blue: 143/255).opacity(0.20)),
                   lineWidth: 1)

        // U.S. nation outline — faint green fill + brighter stroke.
        let nation = ringPath(map.nation)
        ctx.fill(nation, with: .color(climbColor.opacity(0.025)))
        ctx.stroke(nation, with: .color(climbColor.opacity(0.35)), lineWidth: 1.25)

        // State borders — fainter still (context, not focal).
        ctx.stroke(ringPath(map.states.flatMap { $0 }),
                   with: .color(Color(red: 108/255, green: 127/255, blue: 143/255).opacity(0.25)),
                   lineWidth: 0.75)
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
        // Ground-stopped airports (weather) get a red ring.
        var dots = Path()
        var stopped = Path()
        let r: CGFloat = 3.5
        for ap in sim.airports {
            dots.addEllipse(in: CGRect(x: ap.screen.x - r, y: ap.screen.y - r, width: r * 2, height: r * 2))
            if ap.groundStop {
                let rr: CGFloat = 8
                stopped.addEllipse(in: CGRect(x: ap.screen.x - rr, y: ap.screen.y - rr, width: rr * 2, height: rr * 2))
            }
        }
        ctx.fill(dots, with: .color(climbColor.opacity(0.85)))
        ctx.stroke(stopped, with: .color(heldColor.opacity(0.9)), lineWidth: 1.5)
    }

    private func drawAircraft(_ ctx: GraphicsContext) {
        for ac in sim.aircraft {
            let pos = ac.position(tick: tick)
            let color = ac.isHeld ? heldColor : color(for: ac.state)

            // Base transform: pivot on the aircraft position, rotate to heading
            // (icons are authored nose-toward +x). Same order as the prototype.
            var g = ctx
            g.translateBy(x: pos.point.x, y: pos.point.y)
            g.rotate(by: .radians(pos.heading))

            if let icon = AircraftIcon.byBodyType[ac.type.bodyType] {
                // Real Figma vector icon: scale into map space, recentre on its
                // viewBox, fill with the phase colour.
                g.scaleBy(x: icon.scale, y: icon.scale)
                g.translateBy(x: -icon.center.x, y: -icon.center.y)
                g.fill(icon.path, with: .color(color))
            } else {
                // Fallback triangle, sized by body-type tier.
                let len = ac.type.bodyType.iconLength
                var tri = Path()
                tri.move(to: CGPoint(x: len * 0.55, y: 0))
                tri.addLine(to: CGPoint(x: -len * 0.45, y: len * 0.32))
                tri.addLine(to: CGPoint(x: -len * 0.45, y: -len * 0.32))
                tri.closeSubpath()
                g.fill(tri, with: .color(color))
            }
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
