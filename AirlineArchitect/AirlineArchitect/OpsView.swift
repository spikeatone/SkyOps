//
//  OpsView.swift
//  Airline Architect — the OPS tab
//
//  Built to the Figma (ops home 5:3458 light / 5:3707 dark). Two groups:
//  a "Needs Attention" group (the sim's pending decisions — AOG / crew /
//  end-of-service — rendered with the shared NeedsAttentionCard, same as the
//  Alerts modal), and an "Events" feed (the real Ops event log grouped into
//  DISRUPTIONS / MARKET / STRUCTURAL, each with a relative timestamp).
//  Theme-aware via the Sky tokens + light Figma colours.
//

import SwiftUI

struct OpsView: View {
    let sim: Simulation
    var onBell: () -> Void = {}
    var onSave: () -> Void = {}
    var onQuit: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    /// Cached so the finder isn't recomputed on every tick — it only changes when
    /// the player's route network changes (demand is otherwise static).
    @State private var opportunities: [Simulation.RouteOpportunity] = []

    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var eventSubBG: Color   { isDark ? Sky.darkBG : Color(skyHex: 0xF9F9F9) }
    private var sectionLabel: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private let eventOrange = Color(skyHex: 0xFF8C00)

    var body: some View {
        let _ = sim.tick
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        if !sim.decisionQueue.isEmpty { needsAttentionGroup }
                        opportunitiesGroup
                        // Fuel Hedge lives on Ops now (moved off the Network tab).
                        FuelHedgePanel(sim: sim)
                        eventsGroup
                        if sim.decisionQueue.isEmpty && sim.opsEventLog.isEmpty {
                            Text("Nothing to report yet — a quiet day on the network.")
                                .font(.karla(14)).foregroundStyle(secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity).padding(.top, 24)
                        }
                    }
                    .padding(.bottom, 8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        // While the Ops tab is on screen, everything here is "seen" — clear the
        // tab badge on entry and as new events arrive live.
        .onAppear { sim.markOpsEventsSeen(); opportunities = sim.topRouteOpportunities() }
        .onChange(of: sim.opsEventLog.first?.id) { _, _ in sim.markOpsEventsSeen() }
        // Recompute the finder only when the route network changes (not per tick).
        .onChange(of: sim.playerRoutes.count) { _, _ in opportunities = sim.topRouteOpportunities() }
    }

    // MARK: Route Opportunities (underserved-markets finder)
    private var opportunitiesGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Opportunities").font(.karla(20, .heavy)).foregroundStyle(primary)
            Text("Underserved markets you don't fly yet — ranked by estimated daily demand.")
                .font(.karla(12)).foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            if opportunities.isEmpty {
                Text("No opportunities to show yet.").font(.karla(14)).foregroundStyle(secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(opportunities) { opp in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(opp.originCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                                Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(secondary)
                                Text(opp.destCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                            }
                            Text("\(opp.originCity) – \(opp.destCity)")
                                .font(.karla(12)).foregroundStyle(secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("~\(opp.demandPerDay.formatted())/day")
                                .font(.karla(15, .bold)).foregroundStyle(Sky.coreGreen)
                            Text("\(opp.distanceNM.formatted()) nm · \(opp.suggested)")
                                .font(.karla(12)).foregroundStyle(secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(cashString).font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                Spacer(minLength: 8)
                SaveQuitBar(onSave: onSave, onQuit: onQuit)
            }
            Divider().overlay(cardBorder)
            HStack {
                Text("OPS HOME").font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    // MARK: Needs Attention group
    private var needsAttentionGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Needs Attention").font(.karla(20, .heavy)).foregroundStyle(primary)
            ForEach(sim.decisionQueue) { NeedsAttentionCard(sim: sim, decision: $0) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Events group
    private var eventsGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events").font(.karla(20, .heavy)).foregroundStyle(primary)
            if sim.opsEventLog.isEmpty {
                Text("No recent events.").font(.karla(14)).foregroundStyle(secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(OpsEvent.Category.allCases, id: \.self) { cat in
                    let events = sim.opsEventLog.filter { $0.category == cat }
                    if !events.isEmpty {
                        HStack(spacing: 8) {
                            Text(cat.rawValue).font(.karla(14)).foregroundStyle(sectionLabel)
                            Rectangle().fill(cardBorder).frame(height: 1)
                        }
                        ForEach(events.prefix(6).map { $0 }) { eventCard($0) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private func eventCard(_ e: OpsEvent) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.karla(16, .semibold)).foregroundStyle(eventOrange)
                Text(e.subtitle).font(.karla(14)).foregroundStyle(secondary)
            }
            Spacer(minLength: 8)
            Text(relativeTime(e.tick)).font(.karla(14)).foregroundStyle(secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(eventSubBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Helpers
    private func relativeTime(_ eventTick: Int) -> String {
        let mins = max(0, sim.tick - eventTick)   // 1 tick = 1 sim-minute
        if mins < 60 { return "\(mins)m ago" }
        if mins < 1440 { return "\(mins / 60)h ago" }
        return "\(mins / 1440)d ago"
    }

    private var cashString: String {
        let v = sim.playerBalance, a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }
}
