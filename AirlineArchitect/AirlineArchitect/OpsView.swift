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
    /// Tap a Route Opportunity → preview it on the map (dashed line + pulse)
    /// with Open This Route / Don't Open.
    var onPreviewRoute: (Simulation.RouteOpportunity) -> Void = { _ in }
    /// Free tier: the Events card carries a one-line depth hint (the rival
    /// flavor events SHOW the endgame systems; this line names the door).
    var isPro: Bool = true
    var onUpgrade: () -> Void = {}
    /// Jump to the Network tab's Acquire panel (used by the MX Details view when a
    /// heavy check has no suitable in-fleet cover — buy/lease a like-size aircraft).
    var onAcquire: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    /// Cached so the finder isn't recomputed on every tick — it only changes when
    /// the player's route network changes (demand is otherwise static).
    @State private var opportunities: [Simulation.RouteOpportunity] = []
    /// Which per-hub opportunity drawers are expanded (only shown once a hub exists).
    @State private var expandedOppHubs: Set<String> = []
    /// The MX row currently expanded to its Details view (tail), or nil. Tapping a
    /// due row opens the cost/downtime/grounding breakdown + the Service action; a
    /// C/D check on a routed aircraft shows the spare-coverage picker inside it.
    @State private var expandedMXTail: String? = nil
    /// A just-completed auto-cover (from acquiring a replacement) — shown as a banner
    /// at the top of Ops, then auto-dismissed. Copied from sim.mxCoverConfirm on entry.
    @State private var coverBanner: (sub: String, covered: String, route: String, days: Int)? = nil

    // Loyalty-push purple — bright #C79CFF pops on the dark map; a darker
    // #6E43A6 keeps contrast on the light (white) background.
    private var loyaltyColor: Color { isDark ? Color(skyHex: 0xC79CFF) : Color(skyHex: 0x6E43A6) }
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
        let _ = sim.displayTick   // throttled UI heartbeat (not raw tick) — keeps scrolling smooth
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        // Confirmation banner after auto-covering a route with a newly
                        // acquired aircraft (from the MX "Acquire a replacement" flow).
                        if let c = coverBanner { coverConfirmBanner(c) }
                        // Reputation sits at the very TOP (designer request) — it's
                        // the health signal the player wants at a glance whenever they
                        // open Ops.
                        reputationGroup
                        // The two actionable boxes come next (designer request): with a
                        // large fleet, Needs Attention + the status/event groups below
                        // push these far down, and a player reaches for them often.
                        // Urgent decisions are also surfaced by the bell/Alerts modal,
                        // so Needs Attention moving down doesn't hide anything.
                        opportunitiesGroup
                        // Fuel Hedge lives on Ops now (moved off the Network tab).
                        FuelHedgePanel(sim: sim)
                        if !sim.decisionQueue.isEmpty { needsAttentionGroup }
                        if sim.ownedCount > 0 { maintenanceGroup }
                        if !sim.incentedRoutes.isEmpty { incentivesGroup }
                        if !sim.hubs.isEmpty || !sim.rivalHubs.isEmpty { hubsGroup }
                        competitionGroup
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
        .onAppear {
            sim.markOpsEventsSeen(); opportunities = sim.topRouteOpportunities()
            adoptCoverConfirmIfAny()
        }
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
                            MilestoneIconArtView(name: "building.2.crop.circle",
                                                 color: operating ? Color(skyHex: 0xFFC73B) : Color(skyHex: 0xFFB700).opacity(0.6))
                                .frame(width: 15, height: 15)
                            Text(code).font(.karla(16, .heavy)).foregroundStyle(primary)
                            if hasClub {
                                MilestoneIconArtView(name: "cup.and.saucer.fill", color: Color(skyHex: 0x6E43A6)).frame(width: 14, height: 14)
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
                    MilestoneIconArtView(name: "building.2.crop.circle", color: Color(skyHex: 0xD767FF)).frame(width: 15, height: 15)
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
                        // Explain WHY a pending route hasn't been staffed (e.g.
                        // no spare has the range) so it isn't a silent mystery.
                        if pending, let reason = sim.pendingStaffingReason(r) {
                            Text(reason).font(.karla(11)).foregroundStyle(secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
    private func pendingStatus(_ r: Route, pending: Bool) -> LocalizedStringKey {
        guard pending else { return "In service" }
        if let dl = r.fulfillByTick {
            let daysLeft = max(0, (dl - sim.displayTick) / 1440)
            return "Awaiting aircraft · \(daysLeft)d left to staff"
        }
        return "Awaiting aircraft — acquire one in range"
    }
    private func compact(_ v: Int) -> String {
        let a = abs(v), s = v < 0 ? "−" : ""
        if a >= 1_000_000 { return s + Currency.symbol + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000 { return s + Currency.symbol + String(format: "%.0fk", Double(a) / 1_000) }
        return s + "\(Currency.symbol)\(a)"
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
                Text(LocalizedStringKey(sim.reputationTier)).font(.karla(14, .bold)).foregroundStyle(repColor(rep))
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

    // MARK: Maintenance (MX program — scheduled A/C/D checks; AOG stays in Needs Attention)
    private var maintenanceGroup: some View {
        let _ = sim.displayTick   // keep ETAs/shop countdowns live
        let fleet = sim.mxFleet
        let due = sim.mxDueAircraft.count
        let inShop = sim.mxInShopCount
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Maintenance").font(.karla(20, .heavy)).foregroundStyle(primary)
                Spacer()
                Text("\(due) due · \(inShop) in shop").font(.karla(13, .semibold))
                    .foregroundStyle(due > 0 ? Sky.red : secondary)
            }
            Text("Scheduled A/C/D checks. Service due aircraft to stay airworthy — flying past a check raises breakdown risk. Emergencies (AOG) appear in Needs Attention.")
                .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(fleet.enumerated()), id: \.element.id) { idx, ac in
                if idx > 0 { Divider().overlay(cardBorder.opacity(0.4)) }
                mxRow(ac)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    @ViewBuilder private func mxRow(_ ac: Aircraft) -> some View {
        let dueNow = sim.mxShopDaysLeft(ac) == nil && sim.mxIsDue(ac)
        VStack(alignment: .leading, spacing: 0) {
            // The summary line (tail · type · status · Details/in-shop).
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ac.tail).font(.karla(14, .bold)).foregroundStyle(primary)
                    Text(ac.type.name).font(.karla(11)).foregroundStyle(secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                if let daysLeft = sim.mxShopDaysLeft(ac), let kind = ac.mxCheckKind {
                    // In the shop (with a coverage tag when a sub is flying its route).
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(LocalizedStringKey(kind.label)).font(.karla(12, .bold)).foregroundStyle(Sky.brightBlue)
                        Text(coverTag(for: ac) ?? String(localized: "in shop · ~\(daysLeft)d"))
                            .font(.karla(11)).foregroundStyle(secondary)
                    }
                } else if let eta = sim.mxNextCheckETA(ac) {
                    let overdue = sim.mxIsOverdue(ac)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(LocalizedStringKey(eta.kind.label)).font(.karla(12, .bold))
                            .foregroundStyle(overdue ? Sky.red : (dueNow ? Color(skyHex: 0xFFAB44) : primary))
                        Text(eta.text).font(.karla(11)).foregroundStyle(overdue ? Sky.red : secondary)
                    }
                    if dueNow {
                        // Tap → expand the Details view (cost/downtime/grounding + Service).
                        Button {
                            Feedback.impact(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedMXTail = (expandedMXTail == ac.tail) ? nil : ac.tail
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("Details").font(.karla(12, .bold)).foregroundStyle(.white)
                                Image(systemName: expandedMXTail == ac.tail ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Sky.brightBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }.buttonStyle(.plain)
                    }
                }
            }
            if dueNow, expandedMXTail == ac.tail {
                mxDetails(ac).padding(.top, 12)
            }
        }
    }

    /// Coverage tag for an in-shop aircraft, e.g. "N7ZQ covering · ~7d" (a sub is
    /// flying its route) vs the plain "in shop · ~7d". nil → no coverage, use default.
    private func coverTag(for ac: Aircraft) -> String? {
        guard ac.mxReclaimRouteId != nil,
              let sub = sim.aircraft.first(where: { $0.coveringForTail == ac.tail }),
              let daysLeft = sim.mxShopDaysLeft(ac) else { return nil }
        return String(localized: "\(sub.tail) covering · ~\(daysLeft)d")
    }

    /// The expanded MX Details view: days out of service + monetary cost (with the
    /// overdue surcharge broken out), days until forced grounding, and the route
    /// impact. For a C/D check on a routed aircraft, coverage is REQUIRED — the
    /// player picks an in-range spare (or is told to free/buy one) before Service.
    @ViewBuilder private func mxDetails(_ ac: Aircraft) -> some View {
        let kind = sim.mxNextCheckETA(ac)?.kind ?? .a
        let overdue = sim.mxIsOverdue(ac)
        let cost = sim.mxCheckCost(kind, ac)
        let base = sim.mxCheckBaseCost(kind, ac)
        let days = sim.mxDowntimeDays(kind)
        let ground = sim.mxDaysUntilForcedGrounding(ac)
        let onRoute = ac.assignedRouteId != nil
        let coverReq = sim.mxCoverageRequired(ac)
        let route = sim.currentRoute(of: ac)
        // COVERAGE candidates are like-capacity/range, not just any jet that fits the
        // route (a 787 D-check can't be covered by an A320 — designer's call).
        let covers = sim.mxCoverageCandidates(for: ac)
        VStack(alignment: .leading, spacing: 8) {
            // Downtime.
            mxDetailRow(label: String(localized: "Downtime"),
                        value: String(localized: "~\(days) days in the shop"), tint: primary)
            // Cost — break out the overdue surcharge so "service early = cheaper" is visible.
            if overdue {
                mxDetailRow(label: String(localized: "Base cost"),
                            value: compactMoney(base), tint: secondary)
                mxDetailRow(label: String(localized: "Overdue surcharge"),
                            value: "×\(surchargeText) → \(compactMoney(cost))", tint: Sky.red)
            } else {
                mxDetailRow(label: String(localized: "Cost"), value: compactMoney(cost), tint: primary)
            }
            // Days until forced grounding — the deferral clock.
            if let g = ground {
                mxDetailRow(label: String(localized: "Forced grounding"),
                            value: g <= 0 ? String(localized: "now — un-airworthy")
                                          : String(localized: "in ~\(g) days if deferred"),
                            tint: g <= 3 ? Sky.red : (overdue ? Sky.red : secondary))
            }
            // Current route (informational). A short A-check is a quick in-and-out —
            // no coverage, no revenue-impact line (a ~1-day pause is negligible); the
            // route impact matters (and is covered) only for the long C/D checks below.
            if onRoute, let r = route {
                mxDetailRow(label: String(localized: "Current route"),
                            value: "\(r.originCode) ↔\u{FE0E} \(r.destCode)", tint: primary)
            }

            Divider().overlay(cardBorder.opacity(0.4)).padding(.vertical, 2)

            if coverReq {
                // C/D on a routed aircraft — a LONG check. Either cover the route with a
                // like-size aircraft, or suspend the route while it's in the shop.
                Text(String(localized: "This is a long check. Cover \(route?.originCode ?? "") ↔\u{FE0E} \(route?.destCode ?? "") with a comparable idle aircraft (it flies the route until \(ac.tail) returns, then goes back to your spares), or suspend the route while \(ac.tail) is in the shop."))
                    .font(.karla(11)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                if !covers.isEmpty {
                    // A tappable row per SUITABLE (like-capacity/range) idle spare.
                    Text(String(localized: "Cover with:")).font(.karla(11, .bold)).foregroundStyle(primary)
                    ForEach(covers, id: \.id) { sub in
                        Button {
                            Feedback.impact(.light)
                            sim.serviceMXWithCoverage(ac, coverWith: sub)
                            withAnimation(.easeInOut(duration: 0.2)) { expandedMXTail = nil }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "airplane").font(.system(size: 11, weight: .bold))
                                Text(sub.tail).font(.karla(12, .bold))
                                Text(sub.type.name).font(.karla(11)).opacity(0.85).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(String(localized: "Cover")).font(.karla(12, .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(sim.playerBalance >= cost ? Sky.coreGreen : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }.buttonStyle(.plain).disabled(sim.playerBalance < cost)
                    }
                    if sim.playerBalance < cost {
                        Text(String(localized: "Insufficient funds for the \(compactMoney(cost)) check."))
                            .font(.karla(11)).foregroundStyle(Sky.red)
                    }
                } else {
                    // No LIKE-SIZE idle aircraft — say so, and offer to acquire one.
                    Text(String(localized: "No comparable idle aircraft (a substitute needs similar seats and range). Acquire one to cover the route, or suspend the route below."))
                        .font(.karla(11, .semibold)).foregroundStyle(Color(skyHex: 0xFFAB44)).fixedSize(horizontal: false, vertical: true)
                    Button {
                        Feedback.impact(.light)
                        sim.pendingCoverFor = ac.tail   // so the Marketplace buy auto-covers this route
                        withAnimation(.easeInOut(duration: 0.2)) { expandedMXTail = nil }
                        onAcquire()
                    } label: {
                        Text(String(localized: "Acquire a replacement"))
                            .font(.karla(13, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(Sky.brightBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                }
                // Suspend the route: service now, route pauses ~N days, then the aircraft
                // returns to it. Always available for a heavy check (the coverage-optional
                // path). Cost breakdown is spelled out below so "$X" is never ambiguous:
                // the MX check cost is paid EITHER WAY (cover or suspend); the LOST REVENUE
                // is the extra cost of suspending vs covering.
                let foregone = sim.mxForegoneRevenue(ac)
                Button {
                    Feedback.impact(.light)
                    sim.sendToMX(ac)
                    withAnimation(.easeInOut(duration: 0.2)) { expandedMXTail = nil }
                } label: {
                    Text(String(localized: "Suspend route"))
                        .font(.karla(13, .bold)).foregroundStyle(sim.playerBalance >= cost ? primary : .gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(eventSubBG)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain).disabled(sim.playerBalance < cost)
                mxDetailRow(label: String(localized: "Check cost (either way)"), value: compactMoney(cost), tint: secondary)
                mxDetailRow(label: String(localized: "Lost revenue (~\(days)d paused)"), value: "~\(compactMoney(foregone))", tint: Sky.red)
                Text(String(localized: "Suspending pauses \(route?.originCode ?? "the route") ↔\u{FE0E} \(route?.destCode ?? "") for ~\(days) days (no flights, no revenue), then \(ac.tail) resumes it. Covering keeps the route earning."))
                    .font(.karla(10)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                // A check (or a spare): service directly.
                Button {
                    Feedback.impact(.light)
                    sim.sendToMX(ac)
                    withAnimation(.easeInOut(duration: 0.2)) { expandedMXTail = nil }
                } label: {
                    Text(String(localized: "Service now · \(compactMoney(cost))"))
                        .font(.karla(13, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(sim.playerBalance >= cost ? Sky.coreGreen : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain).disabled(sim.playerBalance < cost)
            }
        }
        .padding(12)
        .background(eventSubBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// After an auto-cover (acquired a replacement from the MX flow), copy the sim's
    /// one-shot confirmation into local state, EXPAND the covered aircraft's MX card so
    /// the player sees the new tail covering it, and auto-dismiss the banner. Adopted in
    /// .onAppear (the tab bar recreates this view on the tab switch — the standing rule).
    private func adoptCoverConfirmIfAny() {
        guard let c = sim.mxCoverConfirm else { return }
        sim.mxCoverConfirm = nil
        coverBanner = c
        expandedMXTail = c.covered            // open the covered aircraft's MX row
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            withAnimation(.easeInOut) { if coverBanner?.sub == c.sub { coverBanner = nil } }
        }
    }

    /// "N9ZQ now covering DFW↔ATL … when the check finishes, N9ZQ idles and can be
    /// assigned to a new route." Shown at the top of Ops after an auto-cover.
    @ViewBuilder private func coverConfirmBanner(_ c: (sub: String, covered: String, route: String, days: Int)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MilestoneIconArtView(name: "checkmark.circle.fill", color: Sky.coreGreen)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(c.sub) is now covering \(c.route)")
                    .font(.karla(14, .bold)).foregroundStyle(primary)
                Text("It flies the route while \(c.covered) is in the shop (~\(c.days) days). When the check finishes, \(c.sub) becomes an idle spare you can assign to a new route.")
                    .font(.karla(11)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button { withAnimation(.easeInOut) { coverBanner = nil } } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(secondary)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(Sky.coreGreen.opacity(isDark ? 0.12 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Sky.coreGreen.opacity(0.5), lineWidth: 1))
    }

    private func mxDetailRow(label: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.karla(11)).foregroundStyle(secondary)
            Spacer(minLength: 8)
            Text(value).font(.karla(12, .semibold)).foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }

    /// "2.5" from the 2.5× overdue surcharge constant, trimmed of a trailing ".0".
    private var surchargeText: String {
        let s = Simulation.mxOverdueCostSurcharge
        return s == s.rounded() ? String(Int(s)) : String(format: "%.1f", s)
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
                ForEach(Array(contested.enumerated()), id: \.element.id) { idx, r in
                    if idx > 0 { Divider().overlay(cardBorder.opacity(0.4)) }
                    let pct = r.competitionPercent(reputation: sim.reputation)
                    VStack(alignment: .leading, spacing: 8) {
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
                                Text(r.competitionLevel == 1 ? "\(r.competitionLevel) rival" : "\(r.competitionLevel) rivals")
                                    .font(.karla(12)).foregroundStyle(secondary)
                            }
                        }
                        promoActions(r)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Competition actions (per-route marketing levers)
    /// Three route-level levers against rivals: an aggressive fare war (cut fare,
    /// grab share, drive rivals off), a cheaper ad campaign (economy-scaled demand
    /// boost), and a pricier loyalty push (durable share defence). Each is upfront
    /// marketing spend; while active the button shows days remaining.
    private func promoActions(_ r: Route) -> some View {
        HStack(spacing: 6) {
            promoButton(
                idle: "Fare war", active: sim.fareWarActive(r.id), daysLeft: sim.fareWarDaysLeft(r.id),
                cost: sim.fareWarCost(r), color: Sky.red,
                afford: sim.playerBalance >= sim.fareWarCost(r)
            ) { if sim.startFareWar(r.id) { Feedback.success() } }
            promoButton(
                idle: "Ad campaign", active: sim.adCampaignActive(r.id), daysLeft: sim.adCampaignDaysLeft(r.id),
                cost: sim.adCampaignCost(r), color: Sky.brightBlue,
                afford: sim.playerBalance >= sim.adCampaignCost(r)
            ) { if sim.launchAdCampaign(r.id) { Feedback.success() } }
            promoButton(
                idle: "Loyalty", active: sim.loyaltyPushActive(r.id), daysLeft: sim.loyaltyPushDaysLeft(r.id),
                cost: sim.loyaltyPushCost(r), color: loyaltyColor,
                afford: sim.playerBalance >= sim.loyaltyPushCost(r)
            ) { if sim.startLoyaltyPush(r.id) { Feedback.success() } }
        }
    }

    private func promoButton(idle: LocalizedStringKey, active: Bool, daysLeft: Int, cost: Int,
                             color: Color, afford: Bool, action: @escaping () -> Void) -> some View {
        let enabled = !active && afford
        return Button(action: action) {
            VStack(spacing: 1) {
                Text(idle).font(.karla(11, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(active ? "\(daysLeft)d left" : promoCost(cost)).font(.karla(9)).opacity(0.85).lineLimit(1)
            }
            .foregroundStyle(active ? .white : (enabled ? color : secondary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6).padding(.horizontal, 4)
            .background(active ? color : color.opacity(enabled ? 0.14 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(active || enabled ? 0.5 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func promoCost(_ v: Int) -> String {
        v >= 1_000_000 ? (Currency.symbol + String(format: "%.1fM", Double(v) / 1_000_000)) : "\(Currency.symbol)\(v / 1000)k"
    }

    // MARK: Route Opportunities (underserved-markets finder)
    private var opportunitiesGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Opportunities").font(.karla(20, .heavy)).foregroundStyle(primary)
            Text("Underserved markets you don't fly yet — tap one to preview it on the map.")
                .font(.karla(12)).foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            if opportunities.isEmpty {
                Text("No opportunities to show yet.").font(.karla(14)).foregroundStyle(secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(opportunities) { oppRow($0) }
            }
            // Per-hub drawers — appear once a hub is established. The flat list
            // above stays the DEFAULT view; expand a hub to see the strongest
            // markets radiating FROM it (demand already includes the hub bonus).
            if !sim.hubs.isEmpty {
                Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 2)
                Text("BY HUB").font(.karla(11, .bold)).foregroundStyle(secondary).tracking(0.5)
                ForEach(sim.hubCodes, id: \.self) { hubOppDrawer($0) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// One tappable opportunity row (shared by the flat list and the hub drawers).
    private func oppRow(_ opp: Simulation.RouteOpportunity) -> some View {
        Button { onPreviewRoute(opp) } label: {
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
                    (Text("\(opp.distanceNM.formatted()) nm · ") + Text(LocalizedStringKey(opp.suggested)))
                        .font(.karla(12)).foregroundStyle(secondary)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondary.opacity(0.7))
                    .padding(.leading, 2)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .pressable()
    }

    /// A collapsible "opportunities from this hub" drawer. Computed lazily — the
    /// per-hub finder only runs when the drawer is expanded.
    @ViewBuilder private func hubOppDrawer(_ code: String) -> some View {
        let open = expandedOppHubs.contains(code)
        let city = sim.airport(code)?.info?.city ?? code
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if open { expandedOppHubs.remove(code) } else { expandedOppHubs.insert(code) }
            } label: {
                HStack(spacing: 8) {
                    MilestoneIconArtView(name: "building.2.crop.circle", color: Color(skyHex: 0xE9B949)).frame(width: 15, height: 15)
                    Text("From \(code)").font(.karla(14, .bold)).foregroundStyle(primary)
                    Text(city).font(.karla(11)).foregroundStyle(secondary).lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(secondary)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            if open {
                let opps = sim.hubRouteOpportunities(from: code)
                if opps.isEmpty {
                    Text("No new markets from \(code) right now.").font(.karla(12)).foregroundStyle(secondary)
                } else {
                    ForEach(opps) { oppRow($0) }
                }
            }
        }
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
                            Text(LocalizedStringKey(cat.rawValue)).font(.karla(14)).foregroundStyle(sectionLabel)
                            Rectangle().fill(cardBorder).frame(height: 1)
                        }
                        ForEach(events.prefix(6).map { $0 }) { eventCard($0) }
                    }
                }
            }
            if !isPro {
                Button(action: onUpgrade) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open").font(.system(size: 11, weight: .semibold))
                        Text("Your rivals build hubs, go public, and buy airlines. So can you — unlock the full game.")
                            .font(.karla(12, .semibold)).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Sky.brightBlue)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
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
    private func relativeTime(_ eventTick: Int) -> LocalizedStringKey {
        let mins = max(0, sim.tick - eventTick)   // 1 tick = 1 sim-minute
        if mins < 60 { return "\(mins)m ago" }
        if mins < 1440 { return "\(mins / 60)h ago" }
        return "\(mins / 1440)d ago"
    }

    private var cashString: String { cashLabel(sim.playerBalance) }
}
