//
//  Tutorial.swift
//  Airline Architect
//
//  A short first-play walkthrough — a handful of cards the player reads and
//  acknowledges. Each step switches the app to the tab it describes, so the
//  player builds a mental model of where things live. Shown once (a UserDefaults
//  flag), after naming the airline on a fresh game.
//

import SwiftUI

struct TutorialStep {
    let tab: Int          // which tab to show behind the card (0 Network … 4 Finance)
    let title: String
    let body: String
}

let tutorialSteps: [TutorialStep] = [
    .init(tab: 0, title: "Welcome aboard ✈️",
          body: "Your goal is to build a profitable global airline. You'll start small — one aircraft, one route — and grow it flight by flight."),
    .init(tab: 0, title: "Open your first route",
          body: "Tap Open Route, pick two cities on the map, then buy or lease an aircraft to fly it. Match the plane to the route — a small regional jet for short hops, bigger jets for busy, long ones."),
    .init(tab: 1, title: "Mind your fleet",
          body: "The Fleet tab tracks every aircraft — its status, age, and resale value. Older airframes cost more to run and break down more often, so plan when to sell."),
    .init(tab: 2, title: "Staff your crews",
          body: "Aircraft need pilots. Crews shows how many you have for each type — hire more as you grow, or flights get held waiting for a rested crew."),
    .init(tab: 3, title: "Watch the numbers",
          body: "Ops logs events — weather, fuel spikes, strikes — and Finance shows your bottom line. Keep cash positive, or the airline goes bankrupt. Now go build it — good luck, boss!"),
]

/// Whether the walkthrough has been shown (app-level, not per-save).
enum TutorialState {
    private static let key = "hasSeenTutorial_v1"
    static var seen: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// The bottom-docked coach card. Deliberately does NOT dim the whole screen —
/// the section behind stays visible so the player sees what's being described.
struct TutorialCard: View {
    let step: TutorialStep
    let index: Int
    let total: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color { isDark ? Sky.navBarDark : .white }
    private var border: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var primary: Color { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private var dot: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xD9D9D9) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule().fill(i == index ? Sky.brightBlue : dot)
                            .frame(width: i == index ? 16 : 6, height: 6)
                    }
                }
                Spacer()
                if index < total - 1 {
                    Button("Skip", action: onSkip)
                        .font(.karla(13, .semibold)).foregroundStyle(secondary).pressable()
                }
            }
            Text(step.title).font(.karla(19, .bold)).foregroundStyle(primary)
            Text(step.body).font(.karla(14)).foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onNext) {
                Text(index == total - 1 ? "Start playing" : "Next")
                    .font(.karla(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(Sky.brightBlue).clipShape(RoundedRectangle(cornerRadius: 6))
            }.pressable()
        }
        .padding(16)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        .shadow(color: .black.opacity(isDark ? 0.5 : 0.2), radius: 14, y: 6)
        .padding(16)
    }
}
