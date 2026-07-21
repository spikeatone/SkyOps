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
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

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
    // Climb-phase green — also the flight-path arcs and airport dots. The bright
    // mint #37FFB0 pops on the dark map but is too pale on white, so light mode
    // uses the app's core green #10B981.
    private var climbColor: Color { isDark ? Color(red: 0x37/255, green: 0xFF/255, blue: 0xB0/255)
                                           : Color(red: 0x10/255, green: 0xB9/255, blue: 0x81/255) }
    // Cruise-phase blue for the player's own aircraft. Light-blue #83C9FF reads
    // fine on the dark map but washes out on white, so light mode uses the
    // darker #4E67A0 (the app's section-header blue).
    private var cruiseColor: Color { isDark ? Color(red: 0x83/255, green: 0xC9/255, blue: 0xFF/255)
                                            : Color(red: 0x4E/255, green: 0x67/255, blue: 0xA0/255) }
    private let descentColor = Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255) // #FFB300
    // On-ground amber. The dark-map amber #E8A13C is muddy on white, so light
    // mode uses #FFB700.
    private var groundColor: Color { isDark ? Color(red: 0xE8/255, green: 0xA1/255, blue: 0x3C/255)
                                            : Color(red: 0xFF/255, green: 0xB7/255, blue: 0x00/255) }
    private let heldColor    = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255) // #ff5c5c — held
    private let othersColor  = Color(red: 0xD7/255, green: 0x67/255, blue: 0xFF/255) // #D767FF — competitor traffic
    private let borderColor  = Color(red: 108/255, green: 127/255, blue: 143/255)    // basemap gray

    // Per-region geography hues (same brightness as the old US outline, one
    // colour each): US blue · Mexico green · Canada red · Central America orange
    // · South America yellow.
    private let usColor      = Color(red: 0x4A/255, green: 0x9E/255, blue: 0xFF/255) // blue
    private let mexicoColor  = Color(red: 0x35/255, green: 0xC7/255, blue: 0x5A/255) // green
    private let canadaColor  = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255) // red
    private let centralColor = Color(red: 0xFF/255, green: 0x9A/255, blue: 0x3C/255) // orange
    private let southColor   = Color(red: 0xED/255, green: 0xB9/255, blue: 0x3C/255) // yellow
    private let europeColor    = Color(red: 0xA5/255, green: 0x61/255, blue: 0xFF/255) // #A561FF purple
    private let asiaColor      = Color(red: 0x89/255, green: 0x85/255, blue: 0x76/255) // #898576 taupe
    private let africaColor    = Color(red: 0xFF/255, green: 0xB7/255, blue: 0x00/255) // #FFB700 amber
    private let australiaColor = Color(red: 0x43/255, green: 0xCC/255, blue: 0xBA/255) // #43CCBA teal

    // Theme-aware chrome. The geography (green outlines/fill) and airports keep
    // the SAME green hue in both themes; only the canvas background, grid,
    // labels, and rings flip so they stay legible on white. Green/gray strokes
    // get a small opacity boost in light mode (a light colour at low opacity
    // vanishes on white).
    private var mapBackground: Color { isDark ? Color(red: 0.03, green: 0.05, blue: 0.06) : .white }
    private var gridColor: Color     { isDark ? .white.opacity(0.03) : .black.opacity(0.045) }
    private var labelColor: Color    { isDark ? .white.opacity(0.6) : Color(red: 0x33/255, green: 0x41/255, blue: 0x55/255).opacity(0.85) }
    private var selectionRing: Color { isDark ? .white.opacity(0.85) : .black.opacity(0.5) }
    /// Opacity multiplier for green/gray strokes so they read on white.
    private var strokeBoost: Double  { isDark ? 1.0 : 1.7 }

    var body: some View {
        Canvas { ctx, size in
            sim.configure(viewport: size)
            sim.projectAirports()
            drawGrid(ctx, size)   // screen-space — drawn once, not tiled
            // Wrap-around: redraw the whole world at each visible horizontal
            // tile offset so panning east/west circles the globe seamlessly.
            // (project() gives base positions; a translated context copy shifts
            // each tile — same trick drawAircraft already uses per-icon.)
            for dx in sim.wrapDrawOffsetsPx() {
                var w = ctx
                w.translateBy(x: dx, y: 0)
                drawBasemap(w)
                drawNightShade(w)   // day/night terminator — dims the geography, under the live network
                drawRoutes(w)
                drawAirports(w)
                drawAircraft(w)
                drawRoutePulse(w)
                drawSuggestion(w)
            }
        }
        .background(mapBackground)
    }

    // MARK: - Layers

    /// Day/night terminator — a soft night band on the half of the globe where the
    /// sun is below the horizon, sweeping west as sim-time advances (subsolar
    /// longitude = longitude of local noon). Longitude-based (no seasonal polar
    /// tilt — a future refinement); drawn under the live network so it dims the
    /// geography but the aircraft/routes still glow over it. Tiles with the map.
    private func drawNightShade(_ ctx: GraphicsContext) {
        let maxDark = isDark ? 0.42 : 0.12
        let nightColor = isDark ? Color(red: 0x0C/255, green: 0x16/255, blue: 0x3A/255)   // deep twilight blue
                                : Color(red: 0x1E/255, green: 0x29/255, blue: 0x3B/255)
        let subLon = 180.0 - Double(tick % 1440) / 1440.0 * 360.0   // subsolar longitude, deg
        let topY = sim.project(GeoProjection.unit(lat: GeoProjection.latMax, lon: 0)).y
        let botY = sim.project(GeoProjection.unit(lat: GeoProjection.latMin, lon: 0)).y
        let strips = 60
        let step = (GeoProjection.lonMax - GeoProjection.lonMin) / Double(strips)
        for i in 0..<strips {
            let lonA = GeoProjection.lonMin + step * Double(i)
            let h = (lonA + step / 2 - subLon) * .pi / 180
            let nightness = max(0, -cos(h))     // 0 at the terminator/day side, 1 at anti-solar
            if nightness <= 0.02 { continue }
            let xA = sim.project(GeoProjection.unit(lat: 0, lon: lonA)).x
            let xB = sim.project(GeoProjection.unit(lat: 0, lon: lonA + step)).x
            let rect = CGRect(x: min(xA, xB), y: topY, width: abs(xB - xA) + 1, height: botY - topY)
            ctx.fill(Path(rect), with: .color(nightColor.opacity(maxDark * nightness)))
        }
    }

    private func drawGrid(_ ctx: GraphicsContext, _ size: CGSize) {
        let spacing: CGFloat = 40
        var path = Path()
        var x: CGFloat = 0
        while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
        var y: CGFloat = 0
        while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
        ctx.stroke(path, with: .color(gridColor), lineWidth: 1)
    }

    /// Real geography beneath the network, one hue per region (US blue · Mexico
    /// green · Canada red · Central America orange · South America yellow), each
    /// a faint fill + coloured outline at a shared brightness, plus faint US
    /// state borders. Projects through the same camera as the airports.
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

        // Each region: a very faint fill + a coloured outline, all at the same
        // brightness (the old US-outline treatment), one hue per region.
        func region(_ rings: [[CGPoint]], _ color: Color) {
            let p = ringPath(rings)
            ctx.fill(p, with: .color(color.opacity(isDark ? 0.028 : 0.06)))
            ctx.stroke(p, with: .color(color.opacity(0.35 * strokeBoost)), lineWidth: 1.2)
        }
        region(map.africa, africaColor)
        region(map.asia, asiaColor)
        region(map.europe, europeColor)
        region(map.australia, australiaColor)
        region(map.canada, canadaColor)
        region(map.southAmerica, southColor)
        region(map.centralAmerica, centralColor)
        region(map.mexico, mexicoColor)
        region(map.nation, usColor)                       // drawn last (on top at shared borders)
        // US internal state borders — a faint version of the US blue.
        ctx.stroke(ringPath(map.states.flatMap { $0 }), with: .color(usColor.opacity(0.22 * strokeBoost)), lineWidth: 0.75)
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

        // Weather glyph on a ground-stopped airport — named by the seasonal reason
        // (#2): a cyclone in hurricane season, a snowflake for a winter storm, rain
        // for the monsoon, else a generic cloud. A curfewed airport in its local
        // night (#4) gets a moon instead. Reads the disruption type at a glance.
        for ap in sim.airports {
            let sym: String, tint: Color
            if ap.groundStop {
                switch ap.groundStopReason {
                case "Hurricane":    sym = "hurricane"
                case "Winter storm": sym = "snowflake"
                case "Monsoon":      sym = "cloud.heavyrain.fill"
                default:             sym = "cloud.fill"
                }
                tint = heldColor
            } else if ap.curfew {
                sym = "moon.stars.fill"; tint = Color(red: 0x9A/255, green: 0xA8/255, blue: 0xE0/255)
            } else { continue }
            ctx.draw(Text(Image(systemName: sym)).font(.system(size: 13.5 * es)).foregroundColor(tint),   // 50% larger (designer, next build)
                     at: CGPoint(x: ap.screen.x, y: ap.screen.y - (r + 8 * es)))
        }

        // Hub badges — the identity-on-the-map payoff. Player hubs: a gold
        // double ring (dimmed amber when UNDERSTAFFED). Sold hubs: the rival's
        // purple ring, a permanent monument to that decision.
        if !sim.hubs.isEmpty || !sim.rivalHubs.isEmpty {
            let gold = Color(skyHex: 0xFFC73B)
            var hubInner = Path(), hubOuter = Path(), understaffed = Path(), rival = Path()
            for ap in sim.airports {
                let p = ap.screen
                if sim.hubs[ap.code] != nil {
                    let r1 = r + 3.5, r2 = r + 6.5
                    if sim.hubOperating(ap.code) {
                        hubInner.addEllipse(in: CGRect(x: p.x - r1, y: p.y - r1, width: r1 * 2, height: r1 * 2))
                        hubOuter.addEllipse(in: CGRect(x: p.x - r2, y: p.y - r2, width: r2 * 2, height: r2 * 2))
                    } else {
                        understaffed.addEllipse(in: CGRect(x: p.x - r1, y: p.y - r1, width: r1 * 2, height: r1 * 2))
                    }
                } else if sim.rivalHubs[ap.code] != nil {
                    let r1 = r + 4.5
                    rival.addEllipse(in: CGRect(x: p.x - r1, y: p.y - r1, width: r1 * 2, height: r1 * 2))
                }
            }
            ctx.stroke(hubInner, with: .color(gold), lineWidth: 1.8)
            ctx.stroke(hubOuter, with: .color(gold.opacity(0.55)), lineWidth: 1.2)
            ctx.stroke(understaffed, with: .color(gold.opacity(0.45)), lineWidth: 1.8)
            ctx.stroke(rival, with: .color(Color(skyHex: 0xD767FF).opacity(0.9)), lineWidth: 1.8)
        }

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
                .foregroundColor(ap.groundStop ? heldColor : labelColor)
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
                    with: .color(selectionRing), lineWidth: 1.5)
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

    /// A brief celebratory expanding ring at both endpoints of a just-opened
    /// route — two concentric ripples that grow and fade. Tick-driven (no SwiftUI
    /// animation needed): the Canvas already redraws every tick.
    private func drawRoutePulse(_ ctx: GraphicsContext) {
        guard let p = sim.routeOpenPulse else { return }
        let elapsed = tick - p.tick
        let duration = 48
        guard elapsed >= 0, elapsed < duration else { return }
        let prog = Double(elapsed) / Double(duration)      // 0 → 1
        let es = sim.elementScale
        for code in [p.a, p.b] {
            guard let ap = sim.airports.first(where: { $0.code == code }) else { continue }
            // Two staggered rings for a richer ripple.
            for delay in [0.0, 0.28] {
                let t = prog - delay
                guard t > 0, t < 1 else { continue }
                let r = (5 + t * 34) * es
                ctx.stroke(Path(ellipseIn: CGRect(x: ap.screen.x - r, y: ap.screen.y - r, width: r * 2, height: r * 2)),
                           with: .color(climbColor.opacity((1 - t) * 0.8)), lineWidth: 2)
            }
        }
    }

    /// The Ops "Route Opportunities" preview: a bright dashed arc between the
    /// tapped city pair with continuously pulsing endpoints, so the player sees
    /// exactly which route the panel's Open This Route / Don't Open buttons act
    /// on. Tick-driven (the Canvas already redraws each tick), so the pulse
    /// loops for as long as the suggestion is up.
    private func drawSuggestion(_ ctx: GraphicsContext) {
        guard let sug = sim.pendingSuggestion,
              let a = sim.airports.first(where: { $0.code == sug.origin }),
              let b = sim.airports.first(where: { $0.code == sug.dest }) else { return }
        let accent = groundColor          // amber — the route-picker's accent
        let es = sim.elementScale

        // Dashed great-circle arc between the pair (same curve as real routes),
        // marching so it reads as "proposed, not yet flown".
        let pp = FlightPath.pathPoints(origin: a.screen, dest: b.screen)
        var arc = Path()
        arc.move(to: pp.start); arc.addQuadCurve(to: pp.end, control: pp.mid)
        let phase = CGFloat(sim.tick % 12)   // marching-ants offset
        ctx.stroke(arc, with: .color(accent),
                   style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [7, 5], dashPhase: phase))

        // Pulsing endpoints — a looping ripple at both airports.
        let period = 44
        let prog = Double(sim.tick % period) / Double(period)   // 0 → 1, loops
        for ap in [a, b] {
            for delay in [0.0, 0.3] {
                let t = prog - delay
                guard t > 0, t < 1 else { continue }
                let r = (5 + t * 26) * es
                ctx.stroke(Path(ellipseIn: CGRect(x: ap.screen.x - r, y: ap.screen.y - r, width: r * 2, height: r * 2)),
                           with: .color(accent.opacity((1 - t) * 0.85)), lineWidth: 2)
            }
            // Solid ring so the endpoint stays anchored between ripples.
            let rr = 3.2 * es + 5
            ctx.stroke(Path(ellipseIn: CGRect(x: ap.screen.x - rr, y: ap.screen.y - rr, width: rr * 2, height: rr * 2)),
                       with: .color(accent), lineWidth: 2.5)
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
