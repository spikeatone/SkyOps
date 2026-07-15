//
//  FleetDetailView.swift
//  Airline Architect — FLEET tab, per-aircraft detail
//
//  Built to the Figma (fleet aircraft detail 2:561 light / 2:1273 dark): a
//  back header, the tail/type/ownership + side-view illustration, a Current
//  Status card (phase + ETA + leg progress), a Maintenance & Value card
//  (airframe life + market value + depreciation), a Last Leg Economics card,
//  and Assign-to-new-route / Sell-aircraft actions. Theme-aware via Sky tokens.
//

import SwiftUI

struct FleetDetailView: View {
    let sim: Simulation
    let aircraft: Aircraft
    let onBack: () -> Void
    let onAssignRoute: () -> Void
    let onSold: () -> Void
    var onBell: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @State private var confirmSell = false

    // Theme tokens (light Figma / dark Sky) — matches FleetView.
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var track: Color       { isDark ? Color.white.opacity(0.12) : Color(skyHex: 0xE6E6E6) }
    private let fill = Sky.brightBlue
    private let green = Sky.coreGreen
    // Red reads too dark on the dark theme — use the On-Dark red there.
    private var red: Color { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }

    var body: some View {
        let _ = sim.tick   // keep status/progress live
        ScrollView {
            VStack(spacing: 16) {
                header
                identity
                currentStatusCard
                maintenanceValueCard
                lastLegCard
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .confirmationDialog(aircraft.isLeased ? "Terminate lease on \(aircraft.tail)?" : "Sell \(aircraft.tail)?",
                            isPresented: $confirmSell, titleVisibility: .visible) {
            if aircraft.isLeased {
                Button("Terminate · \(money(sim.leaseTerminationPenalty(aircraft))) fee", role: .destructive) {
                    Feedback.impact(.light); sim.terminateLease(aircraft); onSold()
                }
            } else {
                Button("Sell for \(money(sim.sellValue(of: aircraft)))", role: .destructive) {
                    Feedback.impact(.light); sim.sellAircraft(aircraft); onSold()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(aircraft.isLeased
                 ? "Early termination hands the jet back and costs a \(money(sim.leaseTerminationPenalty(aircraft))) penalty (≈3 months' lease). Closes its route; crew returns to the pool."
                 : "This closes its route and returns its crew to the pool.")
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(cashString).font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                Spacer()
            }
            Divider().overlay(cardBorder)
            HStack(spacing: 6) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(titleColor)
                }.buttonStyle(.plain)
                Text("AIRCRAFT DETAIL").font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    // MARK: Identity (tail + type + ownership + illustration)
    private var identity: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(aircraft.tail).font(.karla(24, .heavy)).foregroundStyle(primary)
                Text(aircraft.type.name).font(.karla(16)).foregroundStyle(secondary)
            }
            ownershipChip(aircraft.isLeased)
            if let img = AircraftArt.image(for: aircraft.type.id) {
                img.resizable().scaledToFit().frame(maxWidth: .infinity)
            } else {
                Image(systemName: "airplane")
                    .font(.system(size: 60)).foregroundStyle(secondary.opacity(0.5))
                    .frame(maxWidth: .infinity).frame(height: 120)
            }
        }
    }

    // MARK: Current Status
    private var currentStatusCard: some View {
        card {
            HStack {
                Text("Current Status").font(.karla(20, .heavy)).foregroundStyle(primary)
                Spacer()
                statusChip
            }
            routeRow
            let eta = ticksToArrival()
            let prog = legProgress()
            HStack(alignment: .top) {
                labeled("Phase", aircraft.isIdleSpare ? "Idle — no route" : phaseLabel(aircraft.state))
                Spacer()
                labeled("ETA", eta.map(etaString) ?? (aircraft.isIdleSpare ? "—" : "At gate"), trailing: true)
            }
            progressBar(prog)
        }
    }

    // MARK: Maintenance & Value
    private var maintenanceValueCard: some View {
        let pct = 100 * aircraft.cyclesAccrued / max(1, aircraft.type.expectedLifespanCycles)
        let value = sim.sellValue(of: aircraft)
        let deprPct = Int((100 * (1 - Double(value) / Double(max(1, aircraft.type.purchasePrice)))).rounded())
        return card {
            Text("Maintenance & Value").font(.karla(20, .heavy)).foregroundStyle(primary)
            HStack {
                Text("Cycle Count (Lifespan)").font(.karla(14)).foregroundStyle(secondary)
                Spacer()
                Text("\(aircraft.cyclesAccrued.formatted()) cycles / \(pct)%")
                    .font(.karla(14, .bold)).foregroundStyle(primary)
            }
            progressBar(Double(min(100, pct)) / 100)
            // Age escalation: an older airframe costs more to run and breaks more.
            let maintPct = Int(((aircraft.maintenanceAgeMultiplier - 1) * 100).rounded())
            HStack {
                Text("Upkeep (age)").font(.karla(14)).foregroundStyle(secondary)
                Spacer()
                Text("+\(maintPct)% cost · \(String(format: "%.1f", aircraft.aogAgeMultiplier))× breakdown risk")
                    .font(.karla(14, .bold)).foregroundStyle(maintPct >= 15 ? red : primary)
            }
            // A leased jet isn't an owned asset, so a "resale value" is misleading
            // — show the real lease figures (monthly cost + early-termination fee).
            if aircraft.isLeased {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Lease").font(.karla(14)).foregroundStyle(secondary)
                        Text(money(aircraft.type.monthlyLeaseCost)).font(.karla(14, .bold)).foregroundStyle(primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Early Termination").font(.karla(14)).foregroundStyle(secondary)
                        Text(money(sim.leaseTerminationPenalty(aircraft))).font(.karla(14, .bold)).foregroundStyle(red)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Market Value").font(.karla(14)).foregroundStyle(secondary)
                        Text(money(value)).font(.karla(14, .bold)).foregroundStyle(primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Depreciation").font(.karla(14)).foregroundStyle(secondary)
                        Text("−\(deprPct)% vs new").font(.karla(14, .bold)).foregroundStyle(red)
                    }
                }
            }
        }
    }

    // MARK: Last Leg Economics
    private var lastLegCard: some View {
        let route = aircraft.assignedRouteId.flatMap { id in sim.playerRoutes.first { $0.id == id } }
        let rec = route?.history.last
        return card {
            Text("Last Leg Economics").font(.karla(20, .heavy)).foregroundStyle(primary)
            if let rec, let route {
                HStack {
                    Text("Last Completed Leg").font(.karla(14)).foregroundStyle(secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text(route.originCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(secondary)
                        Text(route.destCode).font(.karla(16, .heavy)).foregroundStyle(primary)
                    }
                }
                econRow("Revenue (tickets)", rec.revenue, positive: true)
                econRow("Airport Fees", -rec.fees, positive: false)
                econRow("Operating Cost", -rec.operatingCost, positive: false)
                Rectangle().fill(cardBorder).frame(height: 1)
                HStack {
                    Text("Net Income").font(.karla(16, .semibold)).foregroundStyle(secondary)
                    Spacer()
                    Text((rec.net < 0 ? "−" : "") + money(abs(rec.net)))
                        .font(.karla(14, .bold)).foregroundStyle(rec.net < 0 ? red : green)
                }
            } else {
                Text("No completed legs yet.").font(.karla(14)).foregroundStyle(secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private func econRow(_ label: String, _ value: Int, positive: Bool) -> some View {
        HStack {
            Text(label).font(.karla(14)).foregroundStyle(secondary)
            Spacer()
            Text((value < 0 ? "−" : "") + money(abs(value)))
                .font(.karla(14, .bold)).foregroundStyle(positive ? green : red)
        }
    }

    // MARK: Action buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onAssignRoute) {
                Text("ASSIGN TO NEW ROUTE")
                    .font(.karla(15, .medium)).foregroundStyle(isDark ? .white : Color(skyHex: 0x4B4B4B))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xC9C9C9), lineWidth: 1))
            }.buttonStyle(.plain)
            Button { confirmSell = true } label: {
                Text(aircraft.isLeased ? "TERMINATE LEASE" : "SELL AIRCRAFT")
                    .font(.karla(15, .medium)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(red)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xFF9292), lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }

    // MARK: Shared bits
    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private func labeled(_ label: String, _ value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(label).font(.karla(14)).foregroundStyle(secondary)
            Text(value).font(.karla(14, .bold)).foregroundStyle(primary)
        }
    }

    private var routeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(secondary)
            if aircraft.isIdleSpare {
                Text("No route").font(.karla(16, .heavy)).foregroundStyle(secondary)
            } else {
                Text(aircraft.origin.code).font(.karla(16, .heavy)).foregroundStyle(primary)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(green)
                Text(aircraft.dest.code).font(.karla(16, .heavy)).foregroundStyle(primary)
            }
            Spacer()
        }
    }

    private var statusChip: some View {
        let (text, color): (String, Color) = {
            if aircraft.holdReason == .aog { return ("GROUNDED", red) }
            if aircraft.isIdleSpare { return ("IDLE", Color(skyHex: 0xFFB700)) }
            return ("FLYING", green)
        }()
        return Text(text).font(.karla(10, .bold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(isDark ? 0.18 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
    }

    private func ownershipChip(_ leased: Bool) -> some View {
        Group {
            if leased {
                Text("LEASED").font(.karla(10, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(skyHex: 0x4B4B4B)).clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xC9C9C9), lineWidth: 1))
            } else {
                // Figma (5:6673 / 1:892): solid Light Blue #BDE0FF bg, Core Blue
                // #497AA5 border, Dark Blue #4E67A0 text — the SAME in both themes
                // (matches the Fleet Home chip; dark mode was wrongly translucent).
                Text("OWNED").font(.karla(10, .bold)).foregroundStyle(Color(skyHex: 0x4E67A0))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(skyHex: 0xBDE0FF))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0x497AA5), lineWidth: 1))
            }
        }
    }

    private func progressBar(_ frac: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(track)
                RoundedRectangle(cornerRadius: 4).fill(fill)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, frac))))
            }
        }.frame(height: 8)
    }

    // MARK: Flight timing
    /// Ticks until the aircraft reaches the destination gate (end of taxi-in).
    private func ticksToArrival() -> Int? {
        guard !aircraft.isIdleSpare, aircraft.state != .turnaround else { return nil }
        let s = aircraft.state
        var rem = s.durationTicks - aircraft.stateTick
        if s.rawValue < FlightState.taxiIn.rawValue {
            for raw in (s.rawValue + 1)...FlightState.taxiIn.rawValue {
                rem += FlightState(rawValue: raw)?.durationTicks ?? 0
            }
        }
        return max(0, rem)
    }

    private func legProgress() -> Double {
        guard !aircraft.isIdleSpare else { return 0 }
        let total = [FlightState.boarding, .taxiOut, .takeoff, .cruise, .approach, .landing, .taxiIn]
            .reduce(0) { $0 + $1.durationTicks }
        guard let rem = ticksToArrival() else { return 1 }   // turnaround/arrived
        return Double(total - min(total, rem)) / Double(total)
    }

    private func etaString(_ ticks: Int) -> String {
        let h = ticks / 60, m = ticks % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func phaseLabel(_ s: FlightState) -> String {
        switch s {
        case .parked:     return "At gate (parked)"
        case .boarding:   return "Boarding"
        case .taxiOut:    return "Taxiing out"
        case .takeoff:    return "Takeoff / climb"
        case .cruise:     return "En-route (cruising)"
        case .approach:   return "On approach"
        case .landing:    return "Landing"
        case .taxiIn:     return "Taxiing in"
        case .turnaround: return "Turnaround"
        }
    }

    private var cashString: String {
        let v = sim.playerBalance, a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}
