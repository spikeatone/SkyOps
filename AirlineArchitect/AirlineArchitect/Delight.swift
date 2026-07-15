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
            // App-aesthetic SF Symbol (gold, matching the reward theme) — not emoji.
            Image(systemName: celebration.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(gold)
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
