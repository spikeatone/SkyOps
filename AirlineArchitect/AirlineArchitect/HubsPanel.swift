//
//  HubsPanel.swift
//  Airline Architect — the NETWORK "Hubs" control-bar panel.
//
//  Appears once the player establishes their first hub (the control bar shows a
//  5th "Hubs" button only when `sim.hubs` is non-empty). Lists each hub with the
//  flights (routes) originating there. A SINGLE hub renders expanded; MULTIPLE
//  hubs are collapsible drawers grouped by hub, so a big network doesn't become
//  one long scroll. Styling mirrors RoutesPanel.
//

import SwiftUI

struct HubsPanel: View {
    let sim: Simulation
    /// Which multi-hub drawers are open (a single hub is always shown expanded).
    @State private var expanded: Set<String> = []
    /// Measured content height so the panel hugs its content, scrolling only past a cap.
    @State private var contentHeight: CGFloat = 0

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color      { isDark ? Sky.navBarDark.opacity(0.92) : Color.white.opacity(0.96) }
    private var innerCardBG: Color { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var labelColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private var primaryC: Color    { isDark ? .white : .black }
    private var green: Color       { isDark ? Color(skyHex: 0x87ED7A) : Color(skyHex: 0x10B981) }
    private let amber = Color(skyHex: 0xFFAB44)
    private let gold  = Color(skyHex: 0xE9B949)

    var body: some View {
        let _ = sim.displayTick   // throttled heartbeat — keeps route counts/status live
        let hubs = sim.hubCodes
        Group {
            if hubs.isEmpty {
                Text("No hubs yet. Establish a hub at an airport with 5+ routes.")
                    .font(.karla(14)).foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24).padding(.horizontal, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(hubs, id: \.self) { hubDrawer($0, single: hubs.count == 1) }
                    }
                    .padding(8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .frame(height: min(max(contentHeight, 1), 376))
            }
        }
        .frame(maxWidth: .infinity)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func isOpen(_ code: String, single: Bool) -> Bool { single || expanded.contains(code) }

    @ViewBuilder private func hubDrawer(_ code: String, single: Bool) -> some View {
        let open = isOpen(code, single: single)
        let routes = sim.hubRoutes(code)
        let operating = sim.hubOperating(code)
        let city = sim.airport(code)?.info?.city ?? code
        VStack(alignment: .leading, spacing: 8) {
            // Hub header — tap to expand/collapse (a lone hub isn't collapsible).
            Button {
                guard !single else { return }
                if expanded.contains(code) { expanded.remove(code) } else { expanded.insert(code) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill").font(.system(size: 13)).foregroundStyle(gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(code).font(.karla(17, .heavy)).foregroundStyle(primaryC)
                        Text(city).font(.karla(11)).foregroundStyle(labelColor).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text(operating ? "OPERATING" : "UNDERSTAFFED")
                        .font(.karla(10, .bold)).foregroundStyle(operating ? green : amber)
                    Text("· \(routes.count) flt\(routes.count == 1 ? "" : "s")")
                        .font(.karla(11)).foregroundStyle(labelColor)
                    if !single {
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(labelColor)
                    }
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)

            if open {
                if routes.isEmpty {
                    Text("No flights yet.").font(.karla(12)).foregroundStyle(labelColor).padding(.leading, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(routes) { flightRow($0, hub: code) }
                    }
                }
                opportunitiesSubsection(code)
            }
        }
        .padding(10)
        .background(innerCardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// Route Opportunities radiating from this hub — mirrors OPS ▸ Route Opps
    /// (same demand model, hub-boosted). Tapping previews it on the map and drops
    /// into the SAME open-route flow (via sim.suggestRoute, which NetworkView adopts).
    @ViewBuilder private func opportunitiesSubsection(_ code: String) -> some View {
        let opps = sim.hubRouteOpportunities(from: code, limit: 4)
        if !opps.isEmpty {
            Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 4)
            Text("ROUTE OPPORTUNITIES").font(.karla(10, .bold)).foregroundStyle(labelColor).tracking(0.5)
            VStack(spacing: 4) {
                ForEach(opps) { opp in
                    Button { sim.suggestRoute(from: opp.originCode, to: opp.destCode) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(labelColor)
                            Text(opp.destCode).font(.karla(14, .bold)).foregroundStyle(primaryC)
                            Text(opp.destCity).font(.karla(10)).foregroundStyle(labelColor).lineLimit(1)
                            Spacer(minLength: 6)
                            Text("~\(opp.demandPerDay)/day").font(.karla(11, .bold)).foregroundStyle(green)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(labelColor.opacity(0.7))
                        }
                        .contentShape(Rectangle()).padding(.vertical, 2).padding(.horizontal, 4)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func flightRow(_ r: Route, hub: String) -> some View {
        let spoke = r.originCode == hub ? r.destCode : r.originCode
        let tail = sim.aircraft.first { $0.assignedRouteId == r.id }?.tail
        return HStack(spacing: 8) {
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(labelColor)
            Text(spoke).font(.karla(14, .bold)).foregroundStyle(primaryC)
            if let tail { Text(tail).font(.karla(11)).foregroundStyle(labelColor) }
            Spacer(minLength: 6)
            Text(r.isProfitable ? "profitable" : "building")
                .font(.karla(10, .semibold)).foregroundStyle(r.isProfitable ? green : amber)
        }
        .padding(.vertical, 3).padding(.horizontal, 4)
    }
}
