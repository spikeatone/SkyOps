//
//  MapView.swift
//  Airline Architect — Phase 1–4 (map)
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
    /// Tap-selected aircraft (tooltip target) — gets a highlight ring.
    let selectedID: UUID?
    /// Airport codes highlighted by the route picker.
    let highlightCodes: Set<String>

    // Per-phase colours, ported from the prototype.
    private let climbColor   = Color(red: 0x37/255, green: 0xFF/255, blue: 0xB0/255) // #37FFB0
    private let cruiseColor  = Color(red: 0x83/255, green: 0xC9/255, blue: 0xFF/255) // #83C9FF
    private let descentColor = Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255) // #FFB300
    private let groundColor  = Color(red: 0xE8/255, green: 0xA1/255, blue: 0x3C/255) // ground amber
    private let heldColor    = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255) // #ff5c5c — held
    private let othersColor  = Color(red: 0xD7/255, green: 0x67/255, blue: 0xFF/255) // #D767FF — competitor traffic
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
        // Latin America — same muted context treatment as Canada, with a very
        // faint fill so large landmasses (Brazil, etc.) read as land.
        let latam = ringPath(map.latam)
        ctx.fill(latam, with: .color(climbColor.opacity(0.02)))
        ctx.stroke(latam, with: .color(borderColor.opacity(0.20)), lineWidth: 1)
        let nation = ringPath(map.nation)
        ctx.fill(nation, with: .color(climbColor.opacity(0.025)))
        ctx.stroke(nation, with: .color(climbColor.opacity(0.35)), lineWidth: 1.25)
        ctx.stroke(ringPath(map.states.flatMap { $0 }), with: .color(borderColor.opacity(0.25)), lineWidth: 0.75)
    }

    private func drawRoutes(_ ctx: GraphicsContext) {
        // Faint arcs for current legs (mostly stress-test background traffic).
        var arcs = Path()
        for ac in sim.aircraft where !ac.isIdleSpare {
            let pp = FlightPath.pathPoints(origin: ac.origin.screen, dest: ac.dest.screen)
            arcs.move(to: pp.start)
            arcs.addQuadCurve(to: pp.end, control: pp.mid)
        }
        ctx.stroke(arcs, with: .color(cruiseColor.opacity(0.07)), lineWidth: 1)

        // The player's opened routes — brighter, so the real network stands out.
        var playerArcs = Path()
        for route in sim.playerRoutes {
            guard let o = sim.airports.first(where: { $0.code == route.originCode }),
                  let d = sim.airports.first(where: { $0.code == route.destCode }) else { continue }
            let pp = FlightPath.pathPoints(origin: o.screen, dest: d.screen)
            playerArcs.move(to: pp.start)
            playerArcs.addQuadCurve(to: pp.end, control: pp.mid)
        }
        ctx.stroke(playerArcs, with: .color(climbColor.opacity(0.55)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }

    private func drawAirports(_ ctx: GraphicsContext) {
        let es = sim.elementScale
        let ls = sim.labelScale
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

        // Route-picker selection rings (amber).
        if !highlightCodes.isEmpty {
            var rings = Path()
            for ap in sim.airports where highlightCodes.contains(ap.code) {
                let rr = r + 6
                rings.addEllipse(in: CGRect(x: ap.screen.x - rr, y: ap.screen.y - rr, width: rr * 2, height: rr * 2))
            }
            ctx.stroke(rings, with: .color(groundColor), lineWidth: 2.5)
        }

        // Label declutter — ported from computeAirportLabelPositions(), with
        // the upgrade CLAUDE.md's Open list asked for: clusters recompute
        // against CURRENT screen distance every frame (the camera exists now),
        // so a fanned cluster naturally un-fans once zooming in gives its
        // labels room. Greedy clustering, fan on a ring around the cluster
        // centroid starting straight up, leader line from each dot.
        let fontSize = min(13, 8.5 * ls)
        let threshold: CGFloat = 13 * ls          // overlap radius grows with label size
        let fanRadius: CGFloat = 24 * ls

        let n = sim.airports.count
        var assigned = [Bool](repeating: false, count: n)
        var labelPos = [CGPoint](repeating: .zero, count: n)
        var hasLeader = [Bool](repeating: false, count: n)

        for i in 0..<n where !assigned[i] {
            var cluster = [i]
            assigned[i] = true
            let pi = sim.airports[i].screen
            for j in (i + 1)..<n where !assigned[j] {
                let pj = sim.airports[j].screen
                if hypot(pi.x - pj.x, pi.y - pj.y) < threshold {
                    cluster.append(j)
                    assigned[j] = true
                }
            }
            if cluster.count == 1 {
                labelPos[i] = CGPoint(x: pi.x, y: pi.y - (r + fontSize * 0.9))
            } else {
                let cx = cluster.reduce(CGFloat(0)) { $0 + sim.airports[$1].screen.x } / CGFloat(cluster.count)
                let cy = cluster.reduce(CGFloat(0)) { $0 + sim.airports[$1].screen.y } / CGFloat(cluster.count)
                for (k, idx) in cluster.enumerated() {
                    // fan starting straight up, evenly spaced
                    let angle = 2 * .pi * CGFloat(k) / CGFloat(cluster.count) - .pi / 2
                    labelPos[idx] = CGPoint(x: cx + cos(angle) * fanRadius,
                                            y: cy + sin(angle) * fanRadius)
                    hasLeader[idx] = true
                }
            }
        }

        // Leader lines under the labels, stopped just short of the text.
        var leaders = Path()
        for i in 0..<n where hasLeader[i] {
            let from = sim.airports[i].screen
            let to = labelPos[i]
            let d = hypot(to.x - from.x, to.y - from.y)
            guard d > 1 else { continue }
            let gap = fontSize * 0.7
            let t = max(0, (d - gap) / d)
            leaders.move(to: from)
            leaders.addLine(to: CGPoint(x: from.x + (to.x - from.x) * t,
                                        y: from.y + (to.y - from.y) * t))
        }
        ctx.stroke(leaders, with: .color(borderColor.opacity(0.5)), lineWidth: 1)

        for (i, ap) in sim.airports.enumerated() {
            let text = Text(ap.code)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(ap.groundStop ? heldColor : .white.opacity(0.6))
            ctx.draw(text, at: labelPos[i], anchor: .center)
        }
    }

    private func drawAircraft(_ ctx: GraphicsContext) {
        let es = sim.elementScale
        for ac in sim.aircraft {
            let pos = ac.position(tick: tick)
            // Competitor traffic is one constant colour (instantly "not mine");
            // the player's own fleet is phase-coloured. Held (red) is shared.
            let color: Color
            if ac.isHeld { color = heldColor }
            else if ac.airlineName != nil { color = othersColor }
            else { color = self.color(for: ac.state) }

            // Selection ring (under the icon) so the tooltip's subject is
            // unambiguous on a busy map.
            if ac.id == selectedID {
                let rr = ac.type.bodyType.iconLength * es * 0.9 + 5
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: pos.point.x - rr, y: pos.point.y - rr,
                                           width: rr * 2, height: rr * 2)),
                    with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            }

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
