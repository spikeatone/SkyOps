//
//  ResumePromptView.swift
//  Airline Architect
//
//  Cold-launch prompt when a saved game exists: continue where you left off, or
//  start a fresh airline. Presented by ContentView before the naming screen.
//

import SwiftUI

struct ResumePromptView: View {
    let snapshot: GameSnapshot
    let onContinue: () -> Void
    let onNew: () -> Void
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    private var cardBG: Color { isDark ? Sky.navBarDark : .white }
    private var border: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var primary: Color { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    private func money(_ v: Int) -> String {
        let a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000 { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("✈️").font(.system(size: 44))
                Text("Welcome back").font(.karla(26, .heavy)).foregroundStyle(primary)
                Text(snapshot.playerAirlineName ?? "Your airline")
                    .font(.karla(16, .bold)).foregroundStyle(Sky.brightBlue)

                VStack(spacing: 10) {
                    row("Day", "\(snapshot.tick / 1440)")
                    row("Cash on hand", money(snapshot.playerBalance))
                    row("Fleet", "\(snapshot.aircraft.count) aircraft")
                    row("Routes", "\(snapshot.routes.count) open")
                }
                .padding(14)
                .background(isDark ? .white.opacity(0.04) : Color(skyHex: 0xF1F1F1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(spacing: 10) {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.karla(16, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Sky.brightBlue).clipShape(RoundedRectangle(cornerRadius: 4))
                    }.pressable()
                    Button(action: onNew) {
                        Text("Start a New Airline")
                            .font(.karla(15, .semibold)).foregroundStyle(secondary)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1))
                    }.pressable()
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1))
            .padding(24)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.karla(14)).foregroundStyle(secondary)
            Spacer()
            Text(value).font(.karla(14, .bold)).foregroundStyle(primary)
        }
    }
}
