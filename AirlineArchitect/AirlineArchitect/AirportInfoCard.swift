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
    /// Optional sim: when present, the card gains the Hubs & Clubs section
    /// (status, CREATE A HUB / BUILD CLUB actions, eligibility progress).
    var sim: Simulation? = nil
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
                if let flavor = Airport.destinationFlavor(airport.code) {
                    Text(flavor).font(.karla(12).italic()).foregroundStyle(labelColor.opacity(0.8))
                }
            }
            Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 2)

            // The red ring on the map means an active ground stop — explain it.
            if airport.groundStop {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
                    Text("Ground stop — \(airport.groundStopReason ?? "Weather")")
                        .font(.karla(13, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 6)
                    Text("~\(max(0, airport.groundStopTicksLeft)) min left").font(.karla(12))
                }
                .foregroundStyle(Color(skyHex: 0xFF5C5C))
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color(skyHex: 0xFF5C5C).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Real night curfew (#4) — no departures during the local window.
            if let window = Airport.curfewLabel(airport.code) {
                let indigo = Color(skyHex: 0x9AA8E0)
                HStack(spacing: 6) {
                    Image(systemName: airport.curfew ? "moon.stars.fill" : "moon").font(.system(size: 12))
                    Text(airport.curfew ? "Night curfew — closed now" : "Night curfew \(window) local")
                        .font(.karla(13, airport.curfew ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 6)
                    if !airport.curfew { Text(window).font(.karla(12)).opacity(0) }  // keep layout stable
                }
                .foregroundStyle(indigo)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(indigo.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

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

            if let sim { hubSection(sim) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    // MARK: Hubs & Clubs (see HUBS_AND_CLUBS_SPEC.md)
    @ViewBuilder private func hubSection(_ sim: Simulation) -> some View {
        let code = airport.code
        let gold = Color(skyHex: 0xFFC73B)
        Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 2)
        if let rival = sim.rivalHubs[code] {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill").font(.system(size: 12))
                Text("\(rival) hub — they hold the gates here")
                    .font(.karla(13, .bold)).lineLimit(2).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color(skyHex: 0xD767FF))
        } else if sim.hubs[code] != nil {
            let operating = sim.hubOperating(code)
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill").font(.system(size: 12)).foregroundStyle(gold)
                Text(operating ? "Your hub — operating" : "Your hub — UNDERSTAFFED (\(sim.routesAt(code))/\(Simulation.hubMinRoutes) routes)")
                    .font(.karla(13, .bold))
                    .foregroundStyle(operating ? gold : Color(skyHex: 0xFF9292))
                    .lineLimit(2).minimumScaleFactor(0.7)
            }
            row("Hub labor", "\(money(sim.hubMonthlyLabor(code)))/mo")
            if sim.hubs[code]?.hasClub == true {
                row(sim.clubName, "\(money(sim.clubMonthlyRent(airport)))/mo rent")
            } else if operating {
                actionButton("BUILD \(sim.clubName.uppercased()) — \(money(sim.clubBuildCost(airport)))",
                             enabled: sim.playerBalance >= sim.clubBuildCost(airport)) {
                    Feedback.impact(.medium)
                    sim.buildClub(at: code)
                }
            }
        } else if sim.hubEligible(code) {
            actionButton("CREATE A HUB — \(money(sim.hubEstablishCost(airport)))",
                         enabled: sim.playerBalance >= sim.hubEstablishCost(airport)) {
                Feedback.impact(.medium)
                sim.establishHub(at: code)
            }
            Text("Then \(money(sim.hubMonthlyLabor(code)))/mo ground staff. Benefits suspend below \(Simulation.hubMinRoutes) routes.")
                .font(.karla(11)).foregroundStyle(labelColor)
        } else if sim.routesAt(code) > 0 {
            row("Hub eligibility", "\(sim.routesAt(code))/\(Simulation.hubMinRoutes) routes")
        }
    }

    private func actionButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.karla(13, .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(enabled ? Color(skyHex: 0x497AA5) : Color(skyHex: 0xC9C9C9))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }

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
