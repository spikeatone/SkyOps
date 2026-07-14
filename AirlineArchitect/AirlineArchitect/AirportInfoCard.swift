//
//  AirportInfoCard.swift
//  Airline Architect — the card shown when the player taps an airport on the
//  map. Surfaces the airport's value to their network: full name/location,
//  annual operations, runways + longest runway, ground stops/month, metro-area
//  population, and annual passengers. Same theme-aware chrome as AircraftTooltip
//  (Figma 3:1542/3:1662). Dismissed by tapping the map (no close button).
//

import SwiftUI

struct AirportInfoCard: View {
    let airport: Airport
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark.opacity(0.9) : Color.white.opacity(0.96) }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var titleColor: Color { isDark ? .white : .black }
    private var labelColor: Color { isDark ? .white : Color(skyHex: 0x64748B) }
    private var valueColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x0EA5E9) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: full name + location (falls back to the code when a name
            // isn't sourced yet).
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(airport.code).font(.karla(18, .heavy)).foregroundStyle(valueColor)
                    Text(airport.info?.name ?? "Airport").font(.karla(14, .bold)).foregroundStyle(titleColor)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                if let city = airport.info?.city {
                    Text(city).font(.karla(13)).foregroundStyle(labelColor)
                }
            }
            Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 2)

            if let i = airport.info {
                // Daily flights = annual operations (arrivals + departures) / 365
                // — a more intuitive, human-scale number than annual movements.
                row("Daily flights", (i.operationsPerYear / 365).formatted(.number.grouping(.automatic)))
                row("Runways", "\(i.runways)")
                row("Longest runway", "\(i.longestRunwayFt.formatted(.number.grouping(.automatic))) ft")
                row("Ground stops/mo", String(format: "%.1f", airport.groundStopsPerMonth))
                row("Metro population", compact(i.metroPopulation))
                row("Annual passengers", compact(i.annualPassengers))
            } else {
                // International airports aren't sourced yet — show what we have.
                row("Ground stops/mo", String(format: "%.1f", airport.groundStopsPerMonth))
                Text("Detailed stats coming soon.")
                    .font(.karla(12)).foregroundStyle(labelColor).padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.karla(14, .bold)).foregroundStyle(labelColor)
            Spacer(minLength: 8)
            Text(value).font(.karla(14)).foregroundStyle(valueColor)
        }
    }

    /// "6.3M" / "830K" compact population/passenger counts.
    private func compact(_ v: Int) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 1_000     { return String(format: "%.0fK", Double(v) / 1_000) }
        return "\(v)"
    }
}
