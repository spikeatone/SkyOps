//
//  MapView.swift
//  SkyOps — Phase 1–4 (map)
//
//  Renders the world with a SwiftUI Canvas. Everything projects through the
//  Simulation camera (pan/zoom); airports and aircraft use the camera's damped
//  element-scale so they stay legible instead of ballooning when zoomed in.
//  Aircraft colour is tied to the real flight PHASE (green climb / blue cruise
//  / amber descent / amber ground / red held).
//

import SwiftUI

struct MapView: View {
    let sim: Simulation

    // Changing VALUE inputs that force this view's body to re-run (SwiftUI
    // diffs MapView as identical otherwise, since `sim` is a stable reference —
    // see the Phase 1 freeze bug). tick drives sim motion; the camera fields
    // drive pan/zoom redraws.
    let tick: Int
    let cameraZoom: CGFloat
    let cameraCenter: CGPoint

    // Per-phase colours, ported from the prototype.
    private let climbColor   = Color(red: 0x37/255, green: 0xFF/255, blue: 0xB0/255) // #37FFB0
    private let cruiseColor  = Color(red: 0x83/255, green: 0xC9/255, blue: 0xFF/255) // #83C9FF
    private let descentColor = Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255) // #FFB300
    private let groundColor  = Color(red: 0xE8/255, green: 0xA1/255, blue: 0x3C/255) // ground amber
    private let heldColor    = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255) // #ff5c5c — held
    private let borderColor  = Color(red: 108/255, green: 127/255, blue: 143/255)    // basemap gray

    var body: some View {
        Canvas { ctx, size in
            sim.configure(viewport: size)
            sim.projectAirports()
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

    /// Real geography beneath the network: Canada (muted) → US outline (faint
    /// green fill + stroke) → state borders (fainter). Projects through the
    /// same camera as the airports, so it can't drift.
    private func drawBasemap(_ ctx: GraphicsContext) {
        let map = Basemap.shared

        func ringPath(_ rings: [[CGPoint]]) -> Path {
            var path = Path()
            for ring in rings where ring.count >= 2 {
                path.move(to: sim.project(ring[0]))
                for i in 1..<ring.count { path.addLine(to: sim.project(ring[i])) }
                path.closeSubpath()
            }
            return path
        }

        ctx.stroke(ringPath(map.canada), with: .color(borderColor.opacity(0.20)), lineWidth: 1)
        let nation = ringPath(map.nation)
        ctx.fill(nation, with: .color(climbColor.opacity(0.025)))
        ctx.stroke(nation, with: .color(climbColor.opacity(0.35)), lineWidth: 1.25)
        ctx.stroke(ringPath(map.states.flatMap { $0 }), with: .color(borderColor.opacity(0.25)), lineWidth: 0.75)
    }

    private func drawRoutes(_ ctx: GraphicsContext) {
        var arcs = Path()
        for ac in sim.aircraft {
            let pp = FlightPath.pathPoints(origin: ac.origin.screen, dest: ac.dest.screen)
            arcs.move(to: pp.start)
            arcs.addQuadCurve(to: pp.end, control: pp.mid)
        }
        ctx.stroke(arcs, with: .color(cruiseColor.opacity(0.07)), lineWidth: 1)
    }

    private func drawAirports(_ ctx: GraphicsContext) {
        let es = sim.elementScale
        let r: CGFloat = 3.2 * es
        var dots = Path()
        var stopped = Path()
        for ap in sim.airports {
            let p = ap.screen
            dots.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            if ap.groundStop {
                let rr = r + 4.5
                stopped.addEllipse(in: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2))
            }
        }
        ctx.fill(dots, with: .color(climbColor.opacity(0.85)))
        ctx.stroke(stopped, with: .color(heldColor.opacity(0.9)), lineWidth: 1.5)

        // Labels — grow with zoom, reaching +15% over other elements at max
        // zoom (their own labelScale) where legibility matters most.
        let fontSize = min(13, 8.5 * sim.labelScale)
        for ap in sim.airports {
            let text = Text(ap.code)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            ctx.draw(text, at: CGPoint(x: ap.screen.x, y: ap.screen.y - (r + fontSize * 0.9)), anchor: .center)
        }
    }

    private func drawAircraft(_ ctx: GraphicsContext) {
        let es = sim.elementScale
        for ac in sim.aircraft {
            let pos = ac.position(tick: tick)
            let color = ac.isHeld ? heldColor : color(for: ac.state)

            var g = ctx
            g.translateBy(x: pos.point.x, y: pos.point.y)
            g.rotate(by: .radians(pos.heading))

            if let icon = AircraftIcon.byBodyType[ac.type.bodyType] {
                g.scaleBy(x: icon.scale * es, y: icon.scale * es)
                g.translateBy(x: -icon.center.x, y: -icon.center.y)
                g.fill(icon.path, with: .color(color))
            } else {
                let len = ac.type.bodyType.iconLength * es
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
        default:                  return groundColor
        }
    }
}
