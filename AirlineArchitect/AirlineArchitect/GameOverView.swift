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
    let sim: Simulation
    let onRestart: () -> Void
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    private var cardBG: Color { isDark ? Sky.navBarDark : .white }
    private var border: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var primary: Color { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private let red = Color(skyHex: 0xFF5C5C)

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 44, weight: .light)).foregroundStyle(red)
                Text("BANKRUPT").font(.karla(28, .heavy)).foregroundStyle(red)
                Text("\(sim.playerAirlineName ?? "The airline") ran out of cash and its fleet was liquidated.")
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
