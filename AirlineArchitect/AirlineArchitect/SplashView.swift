//
//  SplashView.swift
//  Airline Architect — cold-launch splash (surprise & delight)
//
//  The "route-network reveal": great-circle arcs draw themselves across a
//  brand-navy sky in the game's flight-phase colours, their endpoints pulsing
//  like the route-open ripple, then the logo badge settles in over the network.
//  It teaches the game's visual language before the first screen appears —
//  same trick as the region carousel's map hues. ~2.6s, tap to skip, and
//  Reduce Motion collapses it to a simple logo fade.
//

import SwiftUI

struct SplashView: View {
    /// Called when the splash finishes (or is tapped through).
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Draw progress per arc (0…1), staggered.
    @State private var arcProgress: [CGFloat] = [0, 0, 0, 0]
    /// Endpoint pulse scale/opacity per arc.
    @State private var pulse: [Bool] = [false, false, false, false]
    @State private var logoIn = false
    @State private var wordmarkIn = false
    @State private var finished = false

    /// The arcs, in unit space (x/y fractions of the screen) — chosen to
    /// crisscross like a small route network. Colours are the game's own:
    /// climb green, cruise blue, descent amber, competitor purple.
    private static let arcs: [(from: CGPoint, to: CGPoint, tint: Color)] = [
        (CGPoint(x: 0.08, y: 0.78), CGPoint(x: 0.88, y: 0.30), Color(skyHex: 0x37FFB0)),
        (CGPoint(x: 0.12, y: 0.26), CGPoint(x: 0.92, y: 0.62), Color(skyHex: 0x83C9FF)),
        (CGPoint(x: 0.22, y: 0.90), CGPoint(x: 0.72, y: 0.12), Color(skyHex: 0xFFB300)),
        (CGPoint(x: 0.85, y: 0.85), CGPoint(x: 0.18, y: 0.48), Color(skyHex: 0xD767FF)),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Brand-navy sky (the badge gradient's dark end), both themes.
                LinearGradient(colors: [Color(skyHex: 0x2B303D), Color(skyHex: 0x101937)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Faint grid, like the map at night.
                gridLines(size: geo.size)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)

                // The route network.
                ForEach(0..<Self.arcs.count, id: \.self) { i in
                    let a = Self.arcs[i]
                    let p0 = place(a.from, in: geo.size)
                    let p1 = place(a.to, in: geo.size)
                    ArcShape(from: p0, to: p1)
                        .trim(from: 0, to: arcProgress[i])
                        .stroke(a.tint.opacity(0.75),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5]))
                        .shadow(color: a.tint.opacity(0.5), radius: 4)
                    // Origin dot appears with the arc; destination pulses on arrival.
                    Circle().fill(a.tint)
                        .frame(width: 5, height: 5).position(p0)
                        .opacity(arcProgress[i] > 0 ? 0.9 : 0)
                    Circle().stroke(a.tint.opacity(pulse[i] ? 0 : 0.9), lineWidth: 2)
                        .frame(width: pulse[i] ? 44 : 6, height: pulse[i] ? 44 : 6)
                        .position(p1)
                        .opacity(arcProgress[i] >= 1 ? 1 : 0)
                    Circle().fill(a.tint)
                        .frame(width: 5, height: 5).position(p1)
                        .opacity(arcProgress[i] >= 1 ? 0.9 : 0)
                }

                // Logo badge + wordmark settle in over the network — laid out to
                // match the naming screen's badge position for a soft handoff.
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)
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
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }   // impatient hands welcome
        .onAppear(perform: run)
    }

    private func place(_ unit: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func gridLines(size: CGSize) -> Path {
        var p = Path()
        let step: CGFloat = 72
        var x: CGFloat = 0
        while x < size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += step }
        var y: CGFloat = 0
        while y < size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += step }
        return p
    }

    /// Global tempo — 1.25 = 20% slower than the first cut (designer request).
    private let tempo = 1.25

    /// The choreography. Arcs stagger in over ~1.9s, the logo lands at ~1.4s,
    /// and the whole thing hands off at ~3.3s.
    private func run() {
        guard !reduceMotion else {
            // Reduce Motion: no flight paths racing around — just a calm fade.
            arcProgress = [1, 1, 1, 1]
            withAnimation(.easeOut(duration: 0.6)) { logoIn = true; wordmarkIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { finish() }
            return
        }
        for i in 0..<Self.arcs.count {
            let start = (0.15 + Double(i) * 0.22) * tempo
            let draw = 0.85 * tempo
            withAnimation(.easeInOut(duration: draw).delay(start)) { arcProgress[i] = 1 }
            // Destination pulse fires as the arc completes.
            withAnimation(.easeOut(duration: 0.7 * tempo).delay(start + draw)) { pulse[i] = true }
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

/// The map's flight-path curve, reused: a quadratic arc whose bulge scales
/// with the leg's length (12% of distance) — same shape language as in-game.
private struct ArcShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let dx = to.x - from.x, dy = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        // Perpendicular offset, 12% of distance — the in-game proportion.
        let n = dist > 0 ? CGPoint(x: -dy / dist, y: dx / dist) : .zero
        let bulge = 0.12 * dist
        let control = CGPoint(x: mid.x + n.x * bulge, y: mid.y + n.y * bulge)
        p.move(to: from)
        p.addQuadCurve(to: to, control: control)
        return p
    }
}
