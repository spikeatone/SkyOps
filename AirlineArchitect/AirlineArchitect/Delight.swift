//
//  Delight.swift
//  Airline Architect
//
//  Shared micro-interaction primitives — the little bits of motion and surprise
//  that make the app feel alive: a springy "pressable" button feel, standard
//  animation curves so everything glides consistently, and the celebratory
//  milestone toast (net-worth thresholds, first flight, a route going profitable).
//

import SwiftUI

/// Standard motion curves — used everywhere so panels, cards, and toasts share a
/// consistent, lively personality instead of each rolling its own timing.
enum Motion {
    /// Panels / sheets gliding in and out.
    static let glide = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Snappy little pops (selection rings, chips, taps).
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.62)
    /// Celebratory toast entrance — a touch bouncier.
    static let toast = Animation.spring(response: 0.5, dampingFraction: 0.68)
}

/// A tactile button feel: scale + fade on press, spring back. Preserves the
/// label's own styling (drop-in for `.plain`), just adds the physical response.
struct Pressable: ButtonStyle {
    var scale: CGFloat = 0.93
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Motion.pop, value: configuration.isPressed)
    }
}

extension View {
    /// Sugar for the pressable feel.
    func pressable(_ scale: CGFloat = 0.93) -> some View { self.buttonStyle(Pressable(scale: scale)) }
}

// MARK: - Easter egg: tap-the-title fly-by

/// A little plane that zips across in a gentle arc when triggered — a hidden
/// bit of joy for tapping the NETWORK title. Recreate it with `.id(counter)` so
/// each tap replays the flight.
struct PlaneFlyBy: View {
    @State private var progress: CGFloat = 0
    var body: some View {
        Text("✈️")
            .font(.system(size: 22))
            .rotationEffect(.degrees(-6))
            .offset(x: -44 + progress * 470, y: -sin(progress * .pi) * 16)
            .opacity(progress > 0.03 && progress < 0.97 ? 1 : 0)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeInOut(duration: 1.4)) { progress = 1 } }
    }
}

// MARK: - Milestone celebration toast

/// The celebratory banner that glides down from the top when the player hits a
/// milestone. A small "surprise and delight" reward — fires once per milestone.
struct MilestoneToast: View {
    let celebration: Simulation.Celebration
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @State private var wiggle = false

    private let gold = Color(skyHex: 0xFFC73B)
    private var primary: Color { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    var body: some View {
        HStack(spacing: 12) {
            // On-brand milestone icon (gold), rendered from the Figma set via SVGPath;
            // falls back to the SF Symbol for any name not in the art set.
            Group {
                if MilestoneIconArt.has(celebration.symbol) {
                    MilestoneIconArtView(name: celebration.symbol, color: gold).frame(width: 26, height: 26)
                } else {
                    Image(systemName: celebration.symbol)
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(gold)
                }
            }
            .frame(width: 28)
            .rotationEffect(.degrees(wiggle ? 6 : -6))
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: wiggle)
            VStack(alignment: .leading, spacing: 2) {
                // Route milestone: show the city pair with the ⇄ route icon between
                // the codes (matches the Ops boxes / Figma "RT Route Arrows").
                if let o = celebration.originCode, let d = celebration.destCode {
                    HStack(spacing: 6) {
                        Text(o).font(.karla(15, .bold)).foregroundStyle(primary)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(secondary)
                        Text(d).font(.karla(15, .bold)).foregroundStyle(primary)
                    }
                } else {
                    Text(celebration.title).font(.karla(15, .bold)).foregroundStyle(primary)
                }
                Text(celebration.subtitle)
                    .font(.karla(12))
                    .foregroundStyle(secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(
            ZStack {
                (isDark ? Sky.navBarDark : .white)
                // A soft golden sheen so a milestone reads as a reward.
                LinearGradient(colors: [Color(skyHex: 0xFFC73B).opacity(isDark ? 0.16 : 0.20), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(skyHex: 0xFFC73B).opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.18), radius: 10, y: 4)
        .onAppear { wiggle = true }
    }
}

/// The "slow-down gauge" icon (Figma Airline-Architect-Production 149:861) — a stroked
/// speedometer, rendered natively via SVGPath like the tab icons (viewBox 34, tintable),
/// used on the auto-slow alert. No bundled raster.
struct GaugeSlowIcon: View {
    let color: Color
    private static let paths: [String] = [
        "M5.48003 28.5199C2.42475 25.4646 0.708313 21.3208 0.708313 17C0.708313 12.6792 2.42475 8.53531 5.48003 5.48003C8.53531 2.42475 12.6792 0.708313 17 0.708313C21.3208 0.708313 25.4646 2.42475 28.5199 5.48003C31.5752 8.53531 33.2916 12.6792 33.2916 17C33.2916 21.3208 31.5752 25.4646 28.5199 28.5199C25.4646 31.5752 21.3208 33.2916 17 33.2916C12.6792 33.2916 8.53531 31.5752 5.48003 28.5199Z",
        "M19.0032 19.0032C18.4688 19.5193 17.7531 19.8049 17.0102 19.7984C16.2673 19.792 15.5567 19.494 15.0313 18.9687C14.506 18.4434 14.208 17.7327 14.2016 16.9898C14.1951 16.2469 14.4807 15.5312 14.9968 14.9969C16.1032 13.8904 26.5172 7.48853 26.5172 7.48853C26.5172 7.48853 20.1167 17.8968 19.0032 19.0032Z",
        "M4.95831 17H7.08331",
        "M8.48584 8.48584L9.98751 9.98751",
        "M17 4.95831V7.08331",
        "M29.0417 17H26.9167",
        "M29.2301 27.7667C25.6395 25.2889 21.3617 24.0005 17 24.0833C12.6382 24.0005 8.36047 25.2889 4.7699 27.7667",
    ]
    var body: some View {
        Canvas { ctx, size in
            let scale = size.width / 34
            let t = CGAffineTransform(scaleX: scale, y: scale)
            for d in Self.paths {
                let p = SVGPath.parse(d).applying(t)
                ctx.stroke(p, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// Brief banner when a new event AUTO-SLOWED the sim from a high speed to 1×, so the
/// player knows what happened (at ≥5× a new card is easy to miss). Amber theme, tap to
/// open Alerts. Stays until tapped (ContentView).
struct AutoSlowAlertBanner: View {
    let kind: Simulation.Decision.Kind
    let tail: String?
    let fromSpeed: Double
    var onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private let amber = Color(skyHex: 0xFFAB44)
    private var primary: Color { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    private var speedText: String {
        fromSpeed == fromSpeed.rounded() ? "\(Int(fromSpeed))×" : String(format: "%g×", fromSpeed)
    }
    private var detail: String {
        // e.g. "N4ZQ: an aircraft is grounded (AOG)" — lead with the tail when there is one.
        if let t = tail { return "\(t): \(kind.alertLabel)" }
        return kind.alertLabel.prefix(1).uppercased() + kind.alertLabel.dropFirst()
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                GaugeSlowIcon(color: amber).frame(width: 24, height: 24).padding(2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slowed \(speedText) → 1×").font(.karla(15, .bold)).foregroundStyle(primary)
                    Text(detail).font(.karla(12)).foregroundStyle(secondary).lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(
                ZStack {
                    (isDark ? Sky.navBarDark : .white)
                    LinearGradient(colors: [amber.opacity(isDark ? 0.16 : 0.20), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(amber.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(isDark ? 0.4 : 0.18), radius: 10, y: 4)
            .frame(maxWidth: 380)
            .padding(.horizontal, 16)
        }.buttonStyle(.plain)
    }
}
