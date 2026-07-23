//
//  ArchitectBackdropTestView.swift
//  Airline Architect — DESIGN EXPERIMENT harness for the shared
//  "architect's tools" brand motif (Figma 90:4819).
//
//  Not part of the shipping app: reached only via the DEBUG launch argument
//  `-backdropTest`. It exists so the treatment can be judged ON DEVICE at real
//  size and real opacity, and so the designer can dial the numbers in live
//  rather than round-tripping through Figma.
//
//  Three modes:
//    • MOTIF    — the backdrop bare, so you can see exactly what the texture
//                 is doing at a given opacity/angle/scale.
//    • NAMING   — the real `AirlineNamingView` over it (the Figma frame).
//    • SEQUENCE — the designer's sequencing idea: the motif loads FIRST, the
//                 cold-launch intro animation plays OVER it, then hands off to
//                 the naming screen — all sharing ONE persistent backdrop, so
//                 the tools never move across the transition.
//
//  Whatever numbers look right here are the numbers to bake into
//  `ArchitectBackdrop`'s defaults.
//

import SwiftUI

#if DEBUG

struct ArchitectBackdropTestView: View {

    private enum Mode: String, CaseIterable, Identifiable {
        case motif = "Motif"
        case naming = "Naming"
        case sequence = "Sequence"
        var id: String { rawValue }
    }

    private enum Phase { case splash, naming }

    /// Launch-arg seeding — the Simulator's input channel is unreliable on this
    /// machine (documented in CLAUDE.md), so every knob is reachable without a
    /// tap: `-backdropMode <motif|naming|sequence>`, `-backdropOpacity <n>`,
    /// `-hideControls`.
    private static func arg(_ key: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: key), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    @State private var mode: Mode = Mode(rawValue: (arg("-backdropMode") ?? "").capitalized) ?? .motif
    @State private var opacity: Double = Double(arg("-backdropOpacity") ?? "") ?? 0.10   // Figma
    @State private var angle: Double = 30              // Figma
    @State private var widthScale: Double = 603.274 / 440   // Figma
    @State private var showControls = !ProcessInfo.processInfo.arguments.contains("-hideControls")
    @State private var phase: Phase = .splash
    @State private var runID = 0

    var body: some View {
        ZStack {
            // ONE persistent backdrop for every mode — this is the whole point
            // of the sequencing test: the motif is a base layer the other
            // screens composite onto, so it never re-renders or jumps.
            Sky.darkBG.ignoresSafeArea()
            ArchitectBackdrop(opacity: opacity,
                              angle: angle,
                              widthScale: CGFloat(widthScale))

            content

            if showControls { controls }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button(showControls ? "Hide" : "Tune") { withAnimation { showControls.toggle() } }
                .font(.karla(13, .semibold))
                .foregroundStyle(Sky.lightBlue)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.trailing, 14)
                .padding(.top, 58)
        }
    }

    // MARK: - Modes

    @ViewBuilder private var content: some View {
        switch mode {
        case .motif:
            VStack(spacing: 6) {
                Spacer()
                Text("ARCHITECT'S TOOLS")
                    .font(.karla(12, .semibold))
                    .foregroundStyle(Sky.lightBlue.opacity(0.8))
                Text("shared brand motif")
                    .font(.karla(18))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }

        case .naming:
            // The real shipping screen, with the motif switched on behind it.
            AirlineNamingView(backdropOpacity: opacity) { _, _, _ in }

        case .sequence:
            // Exactly the shipping arrangement: each screen draws its OWN
            // motif at the same geometry, so it holds still on handoff.
            ZStack {
                if phase == .splash {
                    SplashView(backdropOpacity: opacity) {
                        withAnimation(.easeInOut(duration: 0.6)) { phase = .naming }
                    }
                    .id(runID)
                    .transition(.opacity)
                } else {
                    AirlineNamingView(backdropOpacity: opacity) { _, _, _ in }
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Tuning panel

    private var controls: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 12) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                slider("Opacity", value: $opacity, range: 0...0.30, format: "%.3f")
                slider("Angle",   value: $angle,   range: 0...90,   format: "%.0f°")
                slider("Scale",   value: $widthScale, range: 0.7...2.4, format: "%.3f×")

                HStack(spacing: 10) {
                    Button("Reset to Figma") {
                        withAnimation {
                            opacity = 0.10; angle = 30; widthScale = 603.274 / 440
                        }
                    }
                    if mode == .sequence {
                        Button("Replay") {
                            phase = .splash
                            runID += 1
                        }
                    }
                }
                .font(.karla(13, .semibold))
                .foregroundStyle(Sky.brightBlue)

                Text("opacity \(opacity, specifier: "%.3f") · angle \(angle, specifier: "%.0f")° · scale \(widthScale, specifier: "%.3f")×")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(14)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 22)
        }
    }

    private func slider(_ label: String, value: Binding<Double>,
                        range: ClosedRange<Double>, format: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.karla(12, .semibold))
                .foregroundStyle(Sky.lightBlue)
                .frame(width: 58, alignment: .leading)
            Slider(value: value, in: range)
                .tint(Sky.brightBlue)
            Text(String(format: format, value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 52, alignment: .trailing)
        }
    }
}

#endif
