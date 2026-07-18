//
//  SplashView.swift
//  Airline Architect — cold-launch splash (surprise & delight)
//
//  The "route-network reveal": great-circle arcs draw themselves across a
//  brand-navy sky in the game's flight-phase colours, each led by the game's
//  own aircraft icon flying the route, then the logo badge settles in over the
//  network. It teaches the game's visual language before the first screen
//  appears — same trick as the region carousel's map hues. ~3.3s, tap to skip,
//  and Reduce Motion collapses it to a simple logo fade.
//
//  The arc layer is a TimelineView + Canvas driven by ELAPSED TIME (rather than
//  withAnimation on a trim), because the jet has to sit exactly at the drawing
//  tip each frame — which means we need the in-between progress value, not just
//  the animated end state.
//

import SwiftUI

struct SplashView: View {
    /// Called when the splash finishes (or is tapped through).
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var start = Date()
    @State private var logoIn = false
    @State private var wordmarkIn = false
    @State private var finished = false

    /// Global tempo — 1.25 = 20% slower than the first cut (designer request).
    private let tempo = 1.25

    /// The arcs, in unit space (x/y fractions of the screen) — chosen to
    /// crisscross like a small route network. Colours are the game's own:
    /// climb green, cruise blue, descent amber, competitor purple.
    private static let arcs: [(from: CGPoint, to: CGPoint, tint: Color)] = [
        (CGPoint(x: 0.08, y: 0.78), CGPoint(x: 0.88, y: 0.30), Color(skyHex: 0x37FFB0)),
        (CGPoint(x: 0.12, y: 0.26), CGPoint(x: 0.92, y: 0.62), Color(skyHex: 0x83C9FF)),
        (CGPoint(x: 0.22, y: 0.90), CGPoint(x: 0.72, y: 0.12), Color(skyHex: 0xFFB300)),
        (CGPoint(x: 0.85, y: 0.85), CGPoint(x: 0.18, y: 0.48), Color(skyHex: 0xD767FF)),
    ]

    private func startTime(_ i: Int) -> Double { (0.15 + Double(i) * 0.22) * tempo }
    private var drawTime: Double { 0.85 * tempo }

    var body: some View {
        ZStack {
            // Brand-navy sky (the badge gradient's dark end), both themes.
            LinearGradient(colors: [Color(skyHex: 0x2B303D), Color(skyHex: 0x101937)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // The route network + the jets flying it.
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                Canvas { ctx, size in
                    drawGrid(ctx, size)
                    let elapsed = reduceMotion ? 99 : timeline.date.timeIntervalSince(start)
                    for (i, arc) in Self.arcs.enumerated() {
                        draw(arc: arc, index: i, elapsed: elapsed, ctx: ctx, size: size)
                    }
                }
            }

            // Logo badge + wordmark settle in over the network — laid out to
            // match the naming screen's badge position for a soft handoff.
            VStack(spacing: 14) {
                Spacer().frame(height: 0)
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(skyHex: 0x4E67A1), Color(skyHex: 0x0C1A42)],
                                                 startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
                    VStack(spacing: 6) {
                        AppLogo().frame(width: 88, height: 71)
                        VStack(spacing: -7) {
                            Text("Airline")
                            Text("Architect")
                        }
                        .font(.karla(19, .light))
                        .foregroundStyle(.white)
                    }
                    .padding(.top, 6)
                }
                .frame(width: 150, height: 150)
                .scaleEffect(logoIn ? 1 : 1.25)
                .opacity(logoIn ? 1 : 0)

                Text("Build the sky.")
                    .font(.karla(18))
                    .foregroundStyle(Color(skyHex: 0xBDE0FF))
                    .opacity(wordmarkIn ? 1 : 0)
                Spacer()
            }
            .padding(.top, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }   // impatient hands welcome
        .onAppear(perform: run)
    }

    // MARK: - Drawing

    /// One route: the dashed trail drawn so far, the game's aircraft icon at the
    /// leading tip (rotated along the path), and a pulse once it lands.
    private func draw(arc: (from: CGPoint, to: CGPoint, tint: Color),
                      index i: Int, elapsed: Double, ctx: GraphicsContext, size: CGSize) {
        let raw = (elapsed - startTime(i)) / drawTime
        let p = CGFloat(easeInOut(min(1, max(0, raw))))
        guard p > 0 else { return }

        let p0 = place(arc.from, size), p1 = place(arc.to, size)
        let c = control(p0, p1)

        // Trail drawn so far (sampled — the dash pattern reads identically).
        var trail = Path()
        trail.move(to: p0)
        let steps = 64
        for s in 1...steps {
            trail.addLine(to: bezier(p0, c, p1, p * CGFloat(s) / CGFloat(steps)))
        }
        ctx.stroke(trail, with: .color(arc.tint.opacity(0.75)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5]))

        // Origin dot.
        dot(ctx, at: p0, r: 2.5, color: arc.tint.opacity(0.9))

        if p < 1 {
            // The jet, at the tip, banked along the flight path.
            let tip = bezier(p0, c, p1, p)
            let heading = tangent(p0, c, p1, p)
            if let icon = AircraftIcon.byBodyType[.narrowbody] {
                var g = ctx
                g.translateBy(x: tip.x, y: tip.y)
                g.rotate(by: .radians(heading))
                let s = icon.scale * 2.1          // bigger than map size — this is the hero
                g.scaleBy(x: s, y: s)
                g.translateBy(x: -icon.center.x, y: -icon.center.y)
                g.fill(icon.path, with: .color(arc.tint))
            }
        } else {
            // Landed: destination dot + a ripple, like the in-game route-open pulse.
            dot(ctx, at: p1, r: 2.5, color: arc.tint.opacity(0.9))
            let since = elapsed - (startTime(i) + drawTime)
            let t = CGFloat(min(1, max(0, since / (0.7 * tempo))))
            if t > 0, t < 1 {
                let r = 4 + t * 22
                ctx.stroke(Path(ellipseIn: CGRect(x: p1.x - r, y: p1.y - r, width: r * 2, height: r * 2)),
                           with: .color(arc.tint.opacity(Double(1 - t) * 0.85)), lineWidth: 2)
            }
        }
    }

    private func dot(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                 with: .color(color))
    }

    private func drawGrid(_ ctx: GraphicsContext, _ size: CGSize) {
        var p = Path()
        let step: CGFloat = 72
        var x: CGFloat = 0
        while x < size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += step }
        var y: CGFloat = 0
        while y < size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += step }
        ctx.stroke(p, with: .color(.white.opacity(0.04)), lineWidth: 1)
    }

    // MARK: - Geometry (the map's flight-path curve: a 12%-of-distance bulge)

    private func place(_ unit: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }
    private func control(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dx = b.x - a.x, dy = b.y - a.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return mid }
        let n = CGPoint(x: -dy / dist, y: dx / dist)
        let bulge = 0.12 * dist
        return CGPoint(x: mid.x + n.x * bulge, y: mid.y + n.y * bulge)
    }
    /// Quadratic bezier point at t.
    private func bezier(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
        let m = 1 - t
        return CGPoint(x: m * m * p0.x + 2 * m * t * c.x + t * t * p1.x,
                       y: m * m * p0.y + 2 * m * t * c.y + t * t * p1.y)
    }
    /// Heading (radians) along the curve at t — the icon's nose is authored +x.
    private func tangent(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> Double {
        let m = 1 - t
        let dx = 2 * m * (c.x - p0.x) + 2 * t * (p1.x - c.x)
        let dy = 2 * m * (c.y - p0.y) + 2 * t * (p1.y - c.y)
        return atan2(dy, dx)
    }
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    // MARK: - Choreography

    private func run() {
        start = Date()
        guard !reduceMotion else {
            // Reduce Motion: no jets racing around — a calm fade over a static network.
            withAnimation(.easeOut(duration: 0.6)) { logoIn = true; wordmarkIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { finish() }
            return
        }
        withAnimation(.spring(response: 0.7 * tempo, dampingFraction: 0.8).delay(1.1 * tempo)) { logoIn = true }
        withAnimation(.easeOut(duration: 0.5 * tempo).delay(1.6 * tempo)) { wordmarkIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6 * tempo) { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}
