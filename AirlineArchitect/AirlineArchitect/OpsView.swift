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
    /// Ops' Maintenance summary row → Fleet ▸ Maintenance, where the MX section lives.
    var onOpenMaintenance: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    /// Cached so the finder isn't recomputed on every tick — it only changes when
    /// the player's route network changes (demand is otherwise static).
    @State private var opportunities: [Simulation.RouteOpportunity] = []
    /// Which per-hub opportunity drawers are expanded (only shown once a hub exists).
    @State private var expandedOppHubs: Set<String> = []
    /// The MX row currently expanded to its Details view (tail), or nil. Tapping a
    // (The MX row/expansion/cover-banner state moved to `MaintenanceSection` with the
    //  flow itself — see MaintenanceView.swift.)

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
                        fuelHedgeGroup
                        if sim.integrationInProgress { integrationGroup }
                        if !opsDecisions.isEmpty { needsAttentionGroup }
                        if sim.ownedCount > 0 { maintenanceSummary }
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
        }
        .onChange(of: sim.opsEventLog.first?.id) { _, _ in sim.markOpsEventsSeen() }
        // Recompute the finder only when the route network changes (not per tick).
        .onChange(of: sim.playerRoutes.count) { _, _ in opportunities = sim.topRouteOpportunities() }
    }

    // MARK: Airport Incentives (from accepted route offers)
    /// Hubs & Clubs status box — each hub's health, monthly bills, and any
    /// airports lost to a rival (the purple monuments).
    private var hubsGroup: some View {
        drawer(.hubs, "Hubs & Clubs", trailing: {
            let n = sim.hubs.count
            Text(n == 1 ? "1 hub" : "\(n) hubs").font(.karla(13, .semibold)).foregroundStyle(secondary)
        }) {
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
    }

    private var incentivesGroup: some View {
        drawer(.incentives, "Airport Incentives", trailing: {
            let n = sim.incentedRoutes.count
            Text(n == 1 ? "1 route" : "\(n) routes").font(.karla(13, .semibold)).foregroundStyle(secondary)
        }) {
            Text("Deals you accepted — waived opening fees and marketing bonuses.")
                .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(sim.incentedRoutes) { r in
                let pending = !sim.routeStaffed(r)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        routeTitle(r)
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
    }
    /// A route's title: a 2-stop route shows ORIG ⇄ DEST with the route icon; a
    /// multi-city rotation shows the whole loop (DEN → ORD → MSP → ↺).
    @ViewBuilder private func routeTitle(_ r: Route) -> some View {
        if r.isMultiStop {
            Text(r.stops.joined(separator: " → ") + " → ↺")
                .font(.karla(15, .heavy)).foregroundStyle(primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 6) {
                Text(r.originCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(secondary)
                Text(r.destCode).font(.karla(16, .heavy)).foregroundStyle(primary)
            }
        }
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
        return drawer(.reputation, "Reputation", trailing: {
            Text(LocalizedStringKey(sim.reputationTier)).font(.karla(14, .bold)).foregroundStyle(repColor(rep))
            Text("· \(Int(rep.rounded()))/100").font(.karla(14, .bold)).foregroundStyle(primary)
        }) {
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
    }

    // MARK: Maintenance summary (the MX section itself now lives on FLEET ▸ Maintenance)
    /// ⚠️ MOVED 9 Sep 2026. The full due-list / Details / coverage flow is
    /// `MaintenanceSection` (MaintenanceView.swift), reached from Fleet. Ops keeps
    /// ONLY what is genuinely an alert — the C/D and overdue `.mxCheck` cards, which
    /// are already rendered in Needs Attention — plus this one-line summary so a
    /// player scanning Ops still sees the state and knows where to act.
    /// Rationale in MX_BASES_SCOPE.md §3.4: a 200-plane fleet turned a per-aircraft
    /// due list into most of the alerts screen; maintenance is fleet ADMIN, not a
    /// disruption.
    private var maintenanceSummary: some View {
        let _ = sim.displayTick
        let due = sim.mxDueAircraft.count
        let inShop = sim.mxInShopCount
        return Button {
            Feedback.impact(.light)
            onOpenMaintenance()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Maintenance").font(.karla(20, .heavy)).foregroundStyle(primary)
                Spacer(minLength: 6)
                if due > 0 { alertChip("\(due) due") }
                Text(due > 0 ? "· \(inShop) in shop" : "\(due) due · \(inShop) in shop")
                    .font(.karla(13, .semibold)).foregroundStyle(secondary)
                Text("Fleet").font(.karla(13, .semibold)).foregroundStyle(Sky.brightBlue)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Sky.brightBlue)
            }
            .contentShape(Rectangle())
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }



    // MARK: Integration (a merger in progress)
    /// ⚠️ THE SURFACE THAT DIDN'T EXIST. `activeIntegration` was read by NO view, so
    /// a player mid-merger could not see how long was left, and the acquisition
    /// block said only "One at a time." A paying customer emailed asking how to
    /// "fully integrate" their first subsidiary — the answer is that you wait, and
    /// nothing on screen said so. This box says it, counts down, and finally holds
    /// the one real lever (`settleSeniority`) that shipped with no button anywhere.
    ///
    /// Placed directly after the two actionable boxes and ABOVE the long status
    /// groups: it only exists while a merger runs, and it carries a decision that
    /// EXPIRES (the dispute lapses on its own at 9 months, taking the settle option
    /// with it), so it should not be buried under Needs Attention on a big fleet.
    private var integrationGroup: some View {
        let _ = sim.displayTick
        let monthsLeft = sim.integrationMonthsRemaining
        let name = sim.activeIntegration?.subsidiaryName ?? ""
        let bill = sim.activeIntegration?.monthlyBill ?? 0
        let progress = sim.integrationProgress
        let sidelined = sim.senioritySidelinedCount
        let disputeDays = sim.seniorityDaysRemaining
        let settlement = sim.pendingSenioritySettlement
        return drawer(.integration, "Integration", trailing: {
            Text(monthsLeft == 1 ? "1 mo left" : "\(monthsLeft) mo left")
                .font(.karla(13, .semibold)).foregroundStyle(secondary)
        }) {
            Text(name).font(.karla(16, .heavy)).foregroundStyle(primary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(isDark ? Color.white.opacity(0.12) : Color(skyHex: 0xE6E6E6))
                    Capsule().fill(Sky.brightBlue).frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            // THE line the support email was missing. Say plainly that waiting is
            // the mechanic, so "how do I finish this?" stops being a question.
            Text("Completes on its own in about \(monthsLeft) months — there's nothing to finish early. Raise the sim speed to get there sooner.")
                .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Integration bill").font(.karla(13)).foregroundStyle(secondary)
                Spacer()
                Text("−\(compact(bill))/mo").font(.karla(13, .bold)).foregroundStyle(secondary)
            }

            if let days = disputeDays, let cost = settlement {
                Divider().overlay(cardBorder.opacity(0.4))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Seniority dispute").font(.karla(14, .bold)).foregroundStyle(Sky.red)
                    Spacer(minLength: 6)
                    Text(days == 1 ? "1 day left" : "\(days) days left")
                        .font(.karla(13, .semibold)).foregroundStyle(secondary)
                }
                Text(sidelined == 1
                     ? "1 crew is sidelined while the two seniority lists are merged."
                     : "\(sidelined) crews are sidelined while the two seniority lists are merged.")
                    .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                Button {
                    Feedback.impact(.light)
                    if sim.settleSeniority() { Feedback.success() }
                } label: {
                    Text(sim.canSettleSeniority
                         ? "Settle now · \(compact(cost))"
                         : "Settle now · need \(compact(cost))")
                        .font(.karla(13, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(sim.canSettleSeniority ? Sky.coreGreen : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(!sim.canSettleSeniority)
                Text("Ends the dispute today and puts every sidelined crew back on the line.")
                    .font(.karla(11)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Seniority settled — all crews are back on the line.")
                    .font(.karla(12)).foregroundStyle(Sky.coreGreen)
            }

            Text("Where both airlines fly the same city pair those routes split passengers between them. Closing or reassigning one of each duplicate is the main way a merger pays off.")
                .font(.karla(11)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Competition (rival carriers on the player's routes)
    private var competitionGroup: some View {
        let contested = sim.contestedRoutes
        return drawer(.competition, "Competition", trailing: {
            if !contested.isEmpty { alertChip("\(contested.count) contested") }
        }) {
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
                                routeTitle(r)
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
        drawer(.opportunities, "Route Opportunities") {
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

    /// A filled red chip for a drawer's attention-needing count. Plain red TEXT got
    /// lost against a column of collapsed grey summaries (designer, 8 Sep 2026) —
    /// a solid badge reads as "act on me" at a glance, especially when the drawer
    /// is closed and the chip is the only thing showing.
    private func alertChip(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.karla(12, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Sky.red)
            .clipShape(Capsule())
    }

    // MARK: Drawers (collapsible section boxes)
    /// A collapsible section box (designer request: with a big airline, Ops is a long
    /// scroll). The header — title, optional trailing summary, chevron — always shows;
    /// the body only while the section isn't in the player's collapsed set, which lives
    /// on the SIM (so it survives the tab switch that recreates this view) and is
    /// PERSISTED (a save doesn't reset the layout). An alert about a box re-opens it
    /// (`Simulation.opsAutoOpen`), so the player never has to hunt.
    private func drawer<Content: View>(_ section: OpsSection, _ title: LocalizedStringKey,
                                       @ViewBuilder content: () -> Content) -> some View {
        drawer(section, title, trailing: { EmptyView() }, content: content)
    }
    private func drawer<Trailing: View, Content: View>(_ section: OpsSection, _ title: LocalizedStringKey,
                                                       @ViewBuilder trailing: () -> Trailing,
                                                       @ViewBuilder content: () -> Content) -> some View {
        let open = !sim.opsCollapsedSections.contains(section)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                Feedback.impact(.light)
                withAnimation(.easeInOut(duration: 0.2)) { sim.toggleOpsSection(section) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.karla(20, .heavy)).foregroundStyle(primary)
                    Spacer(minLength: 6)
                    trailing()
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open { content() }
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
    /// Crew-training cards live on the Crews tab + the bell, not here (designer,
    /// 8 Sep 2026) — Ops shows the operational decisions only.
    private var opsDecisions: [Simulation.Decision] { sim.decisionQueue.filter { $0.kind != .training } }

    private var needsAttentionGroup: some View {
        drawer(.needsAttention, "Needs Attention", trailing: {
            alertChip("\(opsDecisions.count)")
        }) {
            ForEach(opsDecisions) { NeedsAttentionCard(sim: sim, decision: $0) }
        }
    }

    /// Fuel Hedge lives on Ops now (moved off the Network tab); the panel supplies
    /// the rows, the drawer supplies the header + card.
    private var fuelHedgeGroup: some View {
        drawer(.fuelHedge, "Fuel Hedge") { FuelHedgePanel(sim: sim, embedded: true) }
    }

    // MARK: Events group
    private var eventsGroup: some View {
        drawer(.events, "Events") {
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
