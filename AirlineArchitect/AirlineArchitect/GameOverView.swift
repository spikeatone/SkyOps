//
//  GameOverView.swift
//  Airline Architect
//
//  The failure state. When sustained negative cash liquidates the whole fleet
//  and the airline is still insolvent, the game is over — a modal recap with a
//  fresh-start button. Presented by ContentView while `sim.isBankrupt`.
//

import SwiftUI

struct GameOverView: View {
    /// The two failure paths — cash bankruptcy, or removal by the board of a
    /// public company. Same recap layout; different headline + explanation.
    enum Cause { case bankruptcy, boardOuster }

    let sim: Simulation
    var cause: Cause = .bankruptcy
    let onRestart: () -> Void
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    private var cardBG: Color { isDark ? Sky.navBarDark : .white }
    private var border: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var primary: Color { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private let red = Color(skyHex: 0xFF5C5C)

    private var headline: String { cause == .bankruptcy ? "BANKRUPT" : "OUSTED" }
    private var icon: String { cause == .bankruptcy ? "airplane.circle" : "person.crop.circle.badge.xmark" }
    private var message: String {
        let name = sim.playerAirlineName ?? "The airline"
        switch cause {
        case .bankruptcy:
            return "\(name) ran out of cash and its fleet was liquidated."
        case .boardOuster:
            return "\(name)'s board voted to remove you. Losing majority control while the share price languished cost you the airline."
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light)).foregroundStyle(red)
                Text(headline).font(.karla(28, .heavy)).foregroundStyle(red)
                Text(message)
                    .font(.karla(15)).foregroundStyle(secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    statRow("Days operated", "\(sim.tick / 1440)")
                    statRow("Routes flown", "\(sim.allRoutes.count)")
                    statRow("Flights completed", sim.totalFlightsFlown.formatted())
                }
                .padding(14)
                .background(isDark ? .white.opacity(0.04) : Color(skyHex: 0xF1F1F1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button(action: onRestart) {
                    Text("Start a New Airline")
                        .font(.karla(16, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Sky.brightBlue).clipShape(RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1))
            .padding(24)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.karla(14)).foregroundStyle(secondary)
            Spacer()
            Text(value).font(.karla(14, .bold)).foregroundStyle(primary)
        }
    }
}
