//
//  SessionBriefingView.swift
//  Airline Architect — the "welcome back" ops briefing.
//
//  Shown once when a saved game loads (not on a new airline): the most
//  actionable state of the operation, prioritized by Simulation.briefingItems().
//  No sim time passes while the app is closed, so this is a re-orientation
//  ("where you left off"), not a replay of missed events — it gives every
//  session a first 30 seconds of reading your airline's story before the map
//  starts moving. Dismiss by tapping Continue or the dimmed backdrop.
//

import SwiftUI

struct SessionBriefingView: View {
    let airlineName: String
    let dateLine: String                       // "Day 214 · Mar 4, 2027"
    let items: [Simulation.BriefingItem]
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color    { isDark ? Sky.navBarDark : .white }
    private var border: Color    { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var primary: Color   { isDark ? .white : .black }
    private var secondary: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private var urgentC: Color   { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OPS BRIEFING").font(.karla(11, .bold)).foregroundStyle(secondary)
                        .kerning(1.2)
                    Text("Welcome back to \(airlineName)")
                        .font(.karla(20, .bold)).foregroundStyle(primary)
                    Text(dateLine).font(.karla(13)).foregroundStyle(secondary)
                }
                Rectangle().fill(border).frame(height: 1)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(item.urgent ? urgentC : Sky.brightBlue)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.karla(15, .semibold))
                                    .foregroundStyle(item.urgent ? urgentC : primary)
                                Text(item.detail).font(.karla(13)).foregroundStyle(secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                Button(action: onDismiss) {
                    Text("Take the controls")
                        .font(.karla(16, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Sky.brightBlue).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .pressable()
            }
            .padding(18)
            .frame(maxWidth: 420)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
            .shadow(color: .black.opacity(isDark ? 0.5 : 0.2), radius: 14, y: 6)
            .padding(20)
        }
    }
}
