//
//  MaintenanceView.swift
//  Airline Architect
//
//  FLEET ▸ MAINTENANCE — the MX program's home (moved out of Ops, 9 Sep 2026,
//  per the confirmed placement in `aa-1.1.x/MX_BASES_SCOPE.md` §3.4).
//
//  WHY IT MOVED. MX started life as an Ops drawer, but Ops is the ALERTS screen and
//  a 200-plane fleet turns a per-aircraft due list into most of that page — the
//  designer's report was that maintenance ate a third of their time at 5× and
//  nearly all of it faster. Maintenance is fleet ADMINISTRATION, not a disruption:
//  it belongs beside My Fleet and Marketplace, where you already go to think about
//  aircraft. Ops keeps only what is genuinely an alert — the C/D and overdue
//  `.mxCheck` cards in Needs Attention — plus a one-line summary drawer pointing
//  here, so a player scanning Ops still sees the state.
//
//  This file owns the whole due-list / Details / coverage flow verbatim from the
//  Ops implementation; only the CHROME changed (a section card instead of a
//  collapsible drawer) and `onAcquire` now switches the Fleet segment rather than
//  the tab, since the Marketplace is a sibling segment now.
//
//  NOT here yet (later phases of `MX_BASES_SCOPE.md`, deliberately): the auto-A-check
//  policy toggle, maintenance BASES, and the contract-MRO provider line.
//

import SwiftUI

struct MaintenanceSection: View {
    var sim: Simulation
    /// Shop for a like-size cover — the Fleet Marketplace, which is a sibling
    /// segment now rather than another tab.
    var onAcquire: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var eventSubBG: Color  { isDark ? Sky.darkBG : Color(skyHex: 0xF9F9F9) }

    @State private var expandedMXTail: String? = nil
    /// Reveals the full MX list past `mxRowCap`.
    @State private var mxShowAll = false
    @State private var coverBanner: (sub: String, covered: String, route: String, days: Int)? = nil

    var body: some View {
        let _ = sim.displayTick   // keep ETAs/shop countdowns live
        let fleet = sim.mxFleet
        let due = sim.mxDueAircraft.count
        let inShop = sim.mxInShopCount
        return VStack(alignment: .leading, spacing: 12) {
            if let c = coverBanner { coverConfirmBanner(c) }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Maintenance").font(.karla(20, .heavy)).foregroundStyle(primary)
                    Spacer(minLength: 6)
                    // Only the DUE count is an alert; "in shop" is just status.
                    if due > 0 {
                        alertChip("\(due) due")
                        Text("· \(inShop) in shop").font(.karla(13, .semibold)).foregroundStyle(secondary)
                    } else {
                        Text("\(due) due · \(inShop) in shop").font(.karla(13, .semibold)).foregroundStyle(secondary)
                    }
                }
                Text("Scheduled A/C/D checks. Service due aircraft to stay airworthy — flying past a check raises breakdown risk. Emergencies (AOG) appear in Ops.")
                    .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)

                if fleet.isEmpty {
                    Text("No aircraft yet. Checks appear here once you own a fleet.")
                        .font(.karla(12)).foregroundStyle(secondary)
                } else {
                    // ⚠️ BOUNDED (8 Sep 2026). This list is NOT lazy, and the section
                    // rebuilds at the 5Hz displayTick heartbeat — at 200 aircraft that
                    // is 200 rows of layout plus per-row sim helpers, five times a
                    // second, on a screen players sit on.
                    // Safe ONLY because `mxFleet` sorts nearest-date-first (due/overdue
                    // → soonest upcoming → in shop last), so the actionable aircraft are
                    // at the head. Never truncate a differently-sorted list here.
                    // The alert chip above deliberately still counts the FULL fleet.
                    let shown = mxVisible(fleet)
                    ForEach(Array(shown.enumerated()), id: \.element.id) { idx, ac in
                        if idx > 0 { Divider().overlay(cardBorder.opacity(0.4)) }
                        mxRow(ac)
                    }
                    if fleet.count > shown.count {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { mxShowAll = true } } label: {
                            Text("Show all \(fleet.count)")
                                .font(.karla(13, .semibold)).foregroundStyle(Sky.brightBlue)
                        }
                        .padding(.top, 4)
                    } else if mxShowAll && fleet.count > Self.mxRowCap {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { mxShowAll = false } } label: {
                            Text("Show fewer")
                                .font(.karla(13, .semibold)).foregroundStyle(Sky.brightBlue)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }
        // The tab bar / segment switch recreates this view, so an intent set BEFORE
        // the switch must be adopted in .onAppear, not only .onChange — the standing
        // rule in CLAUDE.md.
        .onAppear { adoptCoverConfirmIfAny() }
        .onChange(of: sim.mxCoverConfirm?.sub) { _, _ in adoptCoverConfirmIfAny() }
    }

    /// How many MX rows render before the "Show all" toggle.
    private static let mxRowCap = 12

    /// The head of the (nearest-date-first) MX list, ALWAYS including the row the
    /// player currently has expanded — otherwise an aircraft whose Details are open
    /// would vanish mid-interaction if it sorted past the cap.
    private func mxVisible(_ fleet: [Aircraft]) -> [Aircraft] {
        guard !mxShowAll, fleet.count > Self.mxRowCap else { return fleet }
        var shown = Array(fleet.prefix(Self.mxRowCap))
        if let tail = expandedMXTail, !shown.contains(where: { $0.tail == tail }),
           let open = fleet.first(where: { $0.tail == tail }) {
            shown.append(open)
        }
        return shown
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
                            value: r.label, tint: primary)
            }

            Divider().overlay(cardBorder.opacity(0.4)).padding(.vertical, 2)

            if coverReq {
                // C/D on a routed aircraft — a LONG check. Either cover the route with a
                // like-size aircraft, or suspend the route while it's in the shop.
                Text(String(localized: "This is a long check. Cover \(route?.label ?? "") with a comparable idle aircraft (it flies the route until \(ac.tail) returns, then goes back to your spares), or suspend the route while \(ac.tail) is in the shop."))
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
                Text(String(localized: "Suspending pauses \(route?.label ?? String(localized: "the route")) for ~\(days) days (no flights, no revenue), then \(ac.tail) resumes it. Covering keeps the route earning."))
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
    /// the player sees the new tail covering it, and auto-dismiss the banner.
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
    /// assigned to a new route."
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

    private func alertChip(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.karla(12, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Sky.red)
            .clipShape(Capsule())
    }

    /// "2.5" from the 2.5× overdue surcharge constant, trimmed of a trailing ".0".
    private var surchargeText: String {
        let s = Simulation.mxOverdueCostSurcharge
        return s == s.rounded() ? String(Int(s)) : String(format: "%.1f", s)
    }
}
