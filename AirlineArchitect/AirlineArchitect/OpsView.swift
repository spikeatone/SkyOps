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
    /// Jump to an airport on the Network map (tap a mappable Ops event).
    var onShowAirport: (String) -> Void = { _ in }
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
                        if !sim.incentedRoutes.isEmpty { incentivesGroup }
                        if !sim.hubs.isEmpty || !sim.rivalHubs.isEmpty { hubsGroup }
                        reputationGroup
                        competitionGroup
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

    // MARK: Airport Incentives (from accepted route offers)
    /// Hubs & Clubs status box — each hub's health, monthly bills, and any
    /// airports lost to a rival (the purple monuments).
    private var hubsGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hubs & Clubs").font(.karla(20, .heavy)).foregroundStyle(primary)
            ForEach(sim.hubs.keys.sorted(), id: \.self) { code in
                let operating = sim.hubOperating(code)
                let hasClub = sim.hubs[code]?.hasClub == true
                let labor = sim.hubMonthlyLabor(code)
                let rent = hasClub ? (sim.airport(code).map { sim.clubMonthlyRent($0) } ?? 0) : 0
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(operating ? Color(skyHex: 0xFFC73B) : Color(skyHex: 0xFFB700).opacity(0.6))
                            Text(code).font(.karla(16, .heavy)).foregroundStyle(primary)
                            if hasClub {
                                Image(systemName: "cup.and.saucer.fill").font(.system(size: 11))
                                    .foregroundStyle(Color(skyHex: 0x6E43A6))
                            }
                        }
                        Text(operating ? (hasClub ? "Operating · \(sim.clubName)" : "Operating")
                                       : "UNDERSTAFFED — \(sim.routesAt(code))/\(Simulation.hubMinRoutes) routes (benefits suspended, bills continue)")
                            .font(.karla(12))
                            .foregroundStyle(operating ? Sky.coreGreen : Color(skyHex: 0xFFB700))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("−\(compact(labor))/mo labor").font(.karla(13, .bold)).foregroundStyle(secondary)
                        if hasClub { Text("−\(compact(rent))/mo rent").font(.karla(12)).foregroundStyle(secondary) }
                    }
                }
                .padding(.vertical, 4)
            }
            ForEach(sim.rivalHubs.keys.sorted(), id: \.self) { code in
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill").font(.system(size: 12)).foregroundStyle(Color(skyHex: 0xD767FF))
                    Text(code).font(.karla(16, .heavy)).foregroundStyle(primary)
                    Text("sold to \(sim.rivalHubs[code] ?? "a rival") — their fortress now")
                        .font(.karla(12)).foregroundStyle(Color(skyHex: 0xD767FF))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private var incentivesGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Airport Incentives").font(.karla(20, .heavy)).foregroundStyle(primary)
            Text("Deals you accepted — waived opening fees and marketing bonuses.")
                .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(sim.incentedRoutes) { r in
                let pending = !sim.routeStaffed(r)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(r.originCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(secondary)
                            Text(r.destCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                        }
                        Text(pendingStatus(r, pending: pending))
                            .font(.karla(12)).foregroundStyle(pending ? Color(skyHex: 0xFFB700) : Sky.coreGreen)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(compact(r.incentiveBonus)) bonus").font(.karla(14, .bold)).foregroundStyle(Sky.coreGreen)
                        Text("opening waived (\(compact(r.incentiveWaived)))").font(.karla(12)).foregroundStyle(secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }
    /// Pending routes show the fulfillment countdown; staffed ones "In service".
    private func pendingStatus(_ r: Route, pending: Bool) -> String {
        guard pending else { return "In service" }
        if let dl = r.fulfillByTick {
            let daysLeft = max(0, (dl - sim.tick) / 1440)
            return "Awaiting aircraft · \(daysLeft)d left to staff"
        }
        return "Awaiting aircraft — acquire one in range"
    }
    private func compact(_ v: Int) -> String {
        let a = abs(v), s = v < 0 ? "−" : ""
        if a >= 1_000_000 { return s + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000 { return s + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return s + "$\(a)"
    }

    // MARK: Reputation
    private func repColor(_ r: Double) -> Color {
        switch r {
        case ..<40: return Sky.red
        case ..<60: return Color(skyHex: 0xFFB700)
        case ..<80: return Sky.brightBlue
        default:    return Sky.coreGreen
        }
    }
    private var reputationGroup: some View {
        let rep = sim.reputation
        let dp = sim.reputationDemandPercent
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reputation").font(.karla(20, .heavy)).foregroundStyle(primary)
                Spacer()
                Text(sim.reputationTier).font(.karla(14, .bold)).foregroundStyle(repColor(rep))
                Text("· \(Int(rep.rounded()))/100").font(.karla(14, .bold)).foregroundStyle(primary)
            }
            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(isDark ? Color.white.opacity(0.12) : Color(skyHex: 0xE6E6E6))
                    Capsule().fill(repColor(rep)).frame(width: max(4, geo.size.width * rep / 100))
                }
            }
            .frame(height: 8)
            HStack {
                Text("Passenger demand").font(.karla(13)).foregroundStyle(secondary)
                Spacer()
                Text("\(dp >= 0 ? "+" : "")\(dp)%")
                    .font(.karla(14, .bold)).foregroundStyle(dp >= 0 ? Sky.coreGreen : Sky.red)
            }
            Text("Built by on-time flights; hurt by groundings and crew holds.")
                .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Competition (rival carriers on the player's routes)
    private var competitionGroup: some View {
        let contested = sim.contestedRoutes
        return VStack(alignment: .leading, spacing: 10) {
            Text("Competition").font(.karla(20, .heavy)).foregroundStyle(primary)
            if contested.isEmpty {
                Text("No rival carriers on your routes. Profitable routes attract competitors — your reputation helps keep them out.")
                    .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(contested) { r in
                    let pct = r.competitionPercent(reputation: sim.reputation)
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(r.originCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                                Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(secondary)
                                Text(r.destCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                            }
                            Text("vs \(r.competitors.joined(separator: ", "))")
                                .font(.karla(12)).foregroundStyle(secondary).lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(pct)% demand").font(.karla(15, .bold)).foregroundStyle(Sky.red)
                            Text("\(r.competitionLevel) rival\(r.competitionLevel == 1 ? "" : "s")")
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
        let mappable = e.airportCode != nil
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.karla(16, .semibold)).foregroundStyle(eventOrange)
                Text(e.subtitle).font(.karla(14)).foregroundStyle(secondary)
                if mappable {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 10))
                        Text("Show on map").font(.karla(12, .semibold))
                    }
                    .foregroundStyle(Sky.brightBlue).padding(.top, 3)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(relativeTime(e.tick)).font(.karla(14)).foregroundStyle(secondary)
                if mappable {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Sky.brightBlue)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(eventSubBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { if let c = e.airportCode { onShowAirport(c) } }
    }

    // MARK: Helpers
    private func relativeTime(_ eventTick: Int) -> String {
        let mins = max(0, sim.tick - eventTick)   // 1 tick = 1 sim-minute
        if mins < 60 { return "\(mins)m ago" }
        if mins < 1440 { return "\(mins / 60)h ago" }
        return "\(mins / 1440)d ago"
    }

    private var cashString: String { cashLabel(sim.playerBalance) }
}
