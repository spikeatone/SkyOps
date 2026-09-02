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
    /// SELL → "Acquire a replacement": go to the Network Acquire panel (a pending
    /// replacement is set first, so buying there swaps + sells in one step).
    var onAcquireReplacement: () -> Void = {}
    /// When shown in the iPad landscape list+detail split, the list side already
    /// carries the cash/FLEET header, so the detail pane hides its own header
    /// (no back button either — you switch aircraft by tapping the list).
    var embedded: Bool = false

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @State private var confirmSell = false
    /// Selling a ROUTE-ASSIGNED aircraft routes through this replace-or-close
    /// modal instead of the plain confirm, so the player can keep the route.
    @State private var showReplaceOrClose = false
    @State private var showSparePicker = false
    /// PARK: close the route and keep the plane as an idle spare.
    @State private var confirmPark = false

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
    /// Pending-reassignment notice — the app's existing attention amber.
    private var amber: Color { Color(skyHex: 0xFFAB44) }

    var body: some View {
        let _ = sim.displayTick   // throttled UI heartbeat (not raw tick) — keeps status/progress live without churning
        ScrollView {
            VStack(spacing: 16) {
                if !embedded { header }
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
            // Only idle spares reach this confirm now (route-assigned aircraft use
            // the replace-or-close modal below), so there's no route to warn about.
            Text(aircraft.isLeased
                 ? "Early termination hands the jet back and costs a \(money(sim.leaseTerminationPenalty(aircraft))) penalty (≈3 months' lease). Crew returns to the pool."
                 : "Returns its crew to the pool.")
        }
        // PARK → close the route, keep the plane as an idle spare.
        .confirmationDialog(parkConfirmTitle,
                            isPresented: $confirmPark, titleVisibility: .visible) {
            Button("Close route & park") {
                Feedback.impact(.light); sim.parkAircraft(aircraft)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(sim.isEnRoute(aircraft)
                 ? "The route closes and \(aircraft.tail) becomes an idle spare after it finishes the leg it's flying. You can assign it to a new route anytime; its crew stays with you."
                 : "The route closes and \(aircraft.tail) becomes an idle spare. You can assign it to a new route anytime; its crew stays with you.")
        }
        // Route-assigned SELL → keep the route by swapping in another aircraft, or
        // knowingly close it. Custom AA-styled modal (not the native action sheet).
        .overlay {
            if showReplaceOrClose {
                ReplaceOrCloseModal(
                    sim: sim, aircraft: aircraft,
                    onAssignFromFleet: { showReplaceOrClose = false; showSparePicker = true },
                    onAcquire: { showReplaceOrClose = false; sim.beginReplacement(aircraft); onAcquireReplacement() },
                    onSellClose: {
                        showReplaceOrClose = false; Feedback.impact(.light)
                        aircraft.isLeased ? sim.terminateLease(aircraft) : sim.sellAircraft(aircraft)
                        onSold()
                    },
                    onCancel: { showReplaceOrClose = false })
                .transition(.opacity)
            }
        }
        .animation(Motion.glide, value: showReplaceOrClose)
        .sheet(isPresented: $showSparePicker) {
            ReplacementPicker(sim: sim, sell: aircraft, onDone: onSold)
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
                if let flavor = aircraft.type.flavor {
                    Text(flavor).font(.karla(12).italic()).foregroundStyle(secondary.opacity(0.75))
                }
            }
            ownershipChip(aircraft.isLeased)
            if let subName = aircraft.airlineName, aircraft.subsidiaryCode != nil {
                // A subsidiary aircraft flies its OWN flag, not the player's.
                Text("Operated by \(subName)")
                    .font(.karla(13, .semibold)).foregroundStyle(Color(skyHex: 0xD767FF))
            }
            if AircraftArt.uiImage(for: aircraft.type.id) != nil {
                // Owned aircraft wear the player's livery (name + tail emblem);
                // a subsidiary's aircraft keeps its own identity — bare metal
                // here rather than the player's paint on someone else's flag.
                AircraftLiveryImage(typeID: aircraft.type.id,
                                    name: sim.liveryTitle,
                                    livery: sim.livery,
                                    showLivery: aircraft.subsidiaryCode == nil)
                    .frame(maxWidth: .infinity)
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
                labeled("Phase", aircraft.isIdleSpare ? String(localized: "Idle — no route") : phaseLabel(aircraft.state))
                Spacer()
                labeled("ETA", eta.map(etaString) ?? (aircraft.isIdleSpare ? "—" : String(localized: "At gate")), trailing: true)
            }
            progressBar(prog, planeTip: !aircraft.isIdleSpare)
            // Deferred reassignment: the aircraft finishes the leg it's flying
            // before moving, so say where it's going and that it's not there yet.
            if let next = sim.pendingRoute(for: aircraft) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 12)).foregroundStyle(amber)
                    Text("Moves to \(next.originCode)–\(next.destCode) after landing at \(aircraft.dest.code)")
                        .font(.karla(13, .medium)).foregroundStyle(amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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

    private func econRow(_ label: LocalizedStringKey, _ value: Int, positive: Bool) -> some View {
        HStack {
            Text(label).font(.karla(14)).foregroundStyle(secondary)
            Spacer()
            Text((value < 0 ? "−" : "") + money(abs(value)))
                .font(.karla(14, .bold)).foregroundStyle(positive ? green : red)
        }
    }

    // MARK: Action buttons
    private var actionButtons: some View {
        let onRoute = sim.currentRoute(of: aircraft) != nil
        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                outlineButton(onRoute ? "ASSIGN TO NEW ROUTE" : "ASSIGN TO ROUTE", action: onAssignRoute)
                // PARK only makes sense for an aircraft currently on a route — an
                // idle spare has nothing to close.
                if onRoute { outlineButton("PARK (CLOSE ROUTE)") { confirmPark = true } }
            }
            // Discoverability (player feedback T1.1): players didn't realize you
            // can swap/move a plane without closing the route by hand. Spell out
            // what the two buttons do, in-context, only when it's relevant.
            if onRoute {
                Text("Move this aircraft to a different route with ASSIGN TO NEW ROUTE (a small route fee applies), or free it up as a spare with PARK. No need to close the route by hand — a route it leaves closes automatically.")
                    .font(.karla(11)).foregroundStyle(secondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            transferMenu
            sellButton
        }
    }

    /// Move this aircraft between the mainline and a subsidiary (identity only —
    /// the escape hatch for a purchase made under the wrong flag, and the way to
    /// grow a sub with aircraft already owned). Shown only when subs exist.
    @ViewBuilder private var transferMenu: some View {
        if !sim.subsidiaries.isEmpty {
            let _ = sim.routeEditSeq   // re-render on transfer (Aircraft isn't @Observable)
            Menu {
                if aircraft.subsidiaryCode != nil {
                    Button("\(sim.playerAirlineName ?? "Mainline") (mainline)") {
                        Feedback.impact(.light); sim.assignAircraft(aircraft, toSubsidiary: nil)
                    }
                }
                ForEach(sim.subsidiaries.filter { $0.code != aircraft.subsidiaryCode }) { sub in
                    Button(sub.name) {
                        Feedback.impact(.light); sim.assignAircraft(aircraft, toSubsidiary: sub.code)
                    }
                }
            } label: {
                Text("TRANSFER WITHIN GROUP")
                    .font(.karla(15, .medium)).foregroundStyle(isDark ? .white : Color(skyHex: 0x4B4B4B))
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xC9C9C9), lineWidth: 1))
            }
        }
    }

    /// "ORIG–DEST" of the aircraft's current route, for the park confirm title.
    private var parkRouteLabel: String? {
        sim.currentRoute(of: aircraft).map { "\($0.originCode)–\($0.destCode)" }
    }

    /// Park confirm title as a LocalizedStringKey (the `.map{}??` String form would
    /// bypass the catalog via the StringProtocol overload).
    private var parkConfirmTitle: LocalizedStringKey {
        if let label = parkRouteLabel { return "Close \(label) and park \(aircraft.tail)?" }
        return "Park \(aircraft.tail)?"
    }

    /// Secondary outline action (matches the ASSIGN button chrome).
    private func outlineButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.karla(15, .medium)).foregroundStyle(isDark ? .white : Color(skyHex: 0x4B4B4B))
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xC9C9C9), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var sellButton: some View {
        HStack(spacing: 16) {
            Button {
                // A route-assigned aircraft opens the replace-or-close modal; an
                // idle spare (no route to lose) uses the plain confirm.
                if sim.currentRoute(of: aircraft) != nil { showReplaceOrClose = true }
                else { confirmSell = true }
            } label: {
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

    private func labeled(_ label: LocalizedStringKey, _ value: String, trailing: Bool = false) -> some View {
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
        let (text, color): (LocalizedStringKey, Color) = {
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

    /// `planeTip` rides a little aircraft icon on the tip of the fill — used by
    /// the Current Status leg bar to reinforce that the plane is en route (the
    /// airframe-life bar keeps the plain fill).
    private func progressBar(_ frac: Double, planeTip: Bool = false) -> some View {
        GeometryReader { geo in
            let f = CGFloat(max(0, min(1, frac)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(track)
                RoundedRectangle(cornerRadius: 4).fill(fill)
                    .frame(width: geo.size.width * f)
                if planeTip {
                    // The plane leads the fill just past the tip. Theme-aware per
                    // designer spec: #FFFFFF on dark (pops against the dark track),
                    // the fill blue on light (white washed out on the pale track).
                    Image(systemName: "airplane")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isDark ? Color.white : fill)
                        .offset(x: min(geo.size.width * f + 2, geo.size.width - 20))
                }
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
        case .parked:     return String(localized: "At gate (parked)")
        case .boarding:   return String(localized: "Boarding")
        case .taxiOut:    return String(localized: "Taxiing out")
        case .takeoff:    return String(localized: "Takeoff / climb")
        case .cruise:     return String(localized: "En-route (cruising)")
        case .approach:   return String(localized: "On approach")
        case .landing:    return String(localized: "Landing")
        case .taxiIn:     return String(localized: "Taxiing in")
        case .turnaround: return String(localized: "Turnaround")
        }
    }

    private var cashString: String {
        let v = sim.playerBalance, a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + Currency.symbol + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + Currency.symbol + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + Currency.symbol + "\(a)"
    }

    private func money(_ v: Int) -> String { Currency.symbol + v.formatted(.number.grouping(.automatic)) }
}

/// The replace-or-close choice when selling a route-assigned aircraft, in AA's
/// own card/button language (Karla + Sky tokens) rather than the native action
/// sheet: a dimmed backdrop + a centered card with the keep-the-route options.
private struct ReplaceOrCloseModal: View {
    let sim: Simulation
    let aircraft: Aircraft
    var onAssignFromFleet: () -> Void
    var onAcquire: () -> Void
    var onSellClose: () -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xC9C9C9) }
    private var primary: Color    { isDark ? .white : .black }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.8) : Color(skyHex: 0x64748B) }
    private var stroke: Color     { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    private let blue = Color(skyHex: 0x497AA5)

    private enum Style { case filled, outlined, destructive, plain }

    var body: some View {
        let route = sim.currentRoute(of: aircraft)
        let code = route.map { "\($0.originCode)–\($0.destCode)" } ?? String(localized: "a route")
        let hasSpares = route.map { !sim.spareCandidates(for: $0).isEmpty } ?? false
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: 12) {
                Text(aircraft.isLeased ? "Return \(aircraft.tail)?" : "Sell \(aircraft.tail)?")
                    .font(.karla(22, .heavy)).foregroundStyle(primary)
                Text(aircraft.isLeased
                     ? "\(aircraft.tail) is flying \(code). If you don't put another aircraft on the route, it closes when you hand this one back."
                     : "\(aircraft.tail) is flying \(code). If you don't put another aircraft on the route, it closes when you sell it.")
                    .font(.karla(14)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    if hasSpares { button("Assign one from your fleet", .filled, onAssignFromFleet) }
                    button("Acquire a replacement", .outlined, onAcquire)
                    button(aircraft.isLeased ? "End lease & close route" : "Sell & close the route", .destructive, onSellClose)
                    button("Cancel", .plain, onCancel)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(isDark ? 0.45 : 0.18), radius: 22, y: 8)
            .padding(.horizontal, 24)
        }
    }

    private func button(_ title: LocalizedStringKey, _ style: Style, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.karla(15, .bold))
                .foregroundStyle(style == .filled ? .white : style == .destructive ? red : style == .plain ? secondary : primary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(style == .filled ? blue : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                    style == .outlined ? stroke : style == .destructive ? red.opacity(0.7) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// "Assign one from your fleet" — the idle spares that can take over the route
/// being vacated (only in-range spares are listed). Tap one to swap it onto the
/// route and sell/return the original in a single step.
private struct ReplacementPicker: View {
    let sim: Simulation
    let sell: Aircraft
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var titleColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }

    var body: some View {
        let route = sim.currentRoute(of: sell)
        let spares = route.map { sim.spareCandidates(for: $0) } ?? []
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASSIGN FROM FLEET").font(.karla(12, .bold)).foregroundStyle(titleColor).tracking(0.5)
                    if let r = route {
                        Text("Take over \(r.originCode)–\(r.destCode)").font(.karla(20, .heavy)).foregroundStyle(primary)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundStyle(secondary)
                }.buttonStyle(.plain)
            }
            Text(sell.isLeased
                 ? "The picked aircraft takes the route; \(sell.tail) is handed back."
                 : "The picked aircraft takes the route; \(sell.tail) is sold.")
                .font(.karla(13)).foregroundStyle(secondary)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(spares, id: \.id) { spare in
                        Button {
                            sim.replaceRouteAircraft(sell: sell, with: spare)
                            Feedback.impact(.medium)
                            dismiss(); onDone()
                        } label: { spareCard(spare) }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func spareCard(_ ac: Aircraft) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ac.tail).font(.karla(17, .heavy)).foregroundStyle(primary)
                Text(ac.type.name).font(.karla(13)).foregroundStyle(secondary)
                Text(ac.isLeased
                     ? "\(ac.type.seats) seats · \(ac.type.rangeNM.formatted()) nm · leased"
                     : "\(ac.type.seats) seats · \(ac.type.rangeNM.formatted()) nm · owned")
                    .font(.karla(12)).foregroundStyle(secondary)
            }
            Spacer(minLength: 8)
            Text("ASSIGN").font(.karla(13, .bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 34)
                .background(Color(skyHex: 0x497AA5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
    }
}
