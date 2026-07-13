//
//  ContentView.swift
//  SkyOps
//
//  Created by Michael Stevens on 7/12/26.
//
//  Phase 1 shell: the live map plus a minimal HUD. The speed buttons change
//  how often the tick loop fires WITHOUT touching the tick logic itself —
//  the clearest demonstration that the sim clock is decoupled from real time.
//

import SwiftUI

struct ContentView: View {
    @State private var sim = Simulation()
    @State private var tab = 0

    var body: some View {
        // Custom bottom nav (SkyTabBar) — the Figma tab bar (yellow-on-dark /
        // blue-on-light, custom icons) isn't a stock UITabBar, so we drive tab
        // selection ourselves and switch the content. Only NETWORK is built;
        // the others are placeholders. safeAreaInset reserves the bar's space
        // so the content lays out above it.
        Group {
            switch tab {
            case 0:  NetworkView(sim: sim)
            case 1:  placeholder("Fleet", "airplane")
            case 2:  placeholder("Crews", "person.2.fill")
            case 3:  placeholder("Ops", "list.clipboard.fill")
            default: placeholder("Finance", "chart.bar.fill")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { SkyTabBar(selection: $tab) }
        // Run the sim for the whole session, independent of the selected tab.
        .task { await sim.run() }
        .overlay {
            // First-launch: name the airline before anything else.
            if sim.playerAirlineName == nil {
                AirlineNamingView { name in sim.nameAirline(name) }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: sim.playerAirlineName)
    }

    /// Fleet / Crews / Ops / Finance — the other four tabs are designed later.
    private func placeholder(_ title: String, _ icon: String) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 44))
                    .foregroundStyle(Sky.brightBlue.opacity(0.6))
                Text(title.uppercased()).font(.karla(22, .bold))
                    .foregroundStyle(Sky.brightBlue)
                Text("Coming soon").font(.karla(13)).foregroundStyle(.secondary)
            }
        }
    }
}


private let heldColor = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

/// Shared decision-card chrome (red-bordered, titled, subject line + buttons).
/// The sim never pauses while a card is up (core design thesis).
struct DecisionCardChrome<Buttons: View>: View {
    let title: String
    let subject: String
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(heldColor).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(heldColor)
            }
            Text(subject)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) { buttons() }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(heldColor.opacity(0.45), lineWidth: 1))
    }
}

/// A single decision-card action button.
struct CardButton: View {
    let label: String
    var emphasized = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(emphasized ? heldColor.opacity(0.22) : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct AOGCard: View {
    let decision: Simulation.Decision
    let sim: Simulation
    var body: some View {
        let ac = decision.aircraft
        DecisionCardChrome(title: "AOG — GROUNDED FOR MAINTENANCE",
                           subject: "\(ac.tail) · \(ac.type.name) · at \(ac.origin.code)") {
            CardButton(label: "Expedite · $15,000 · ready now", emphasized: true) {
                sim.resolveAOGExpedite(decision)
            }
            CardButton(label: "Standard · $3,000 · ~3hr") {
                sim.resolveAOGStandard(decision)
            }
        }
    }
}

struct CrewCard: View {
    let decision: Simulation.Decision
    let sim: Simulation
    var body: some View {
        let ac = decision.aircraft
        let hasReserve = sim.hasReserve(for: ac)
        let canHire = sim.canAffordCrewHire(for: ac)
        let hireCost = sim.crewHireCost(family: ac.type.family)
        DecisionCardChrome(title: "NO LEGAL CREW AVAILABLE",
                           subject: "\(ac.tail) · \(ac.type.name) · at \(ac.origin.code)") {
            CardButton(label: hasReserve ? "Reserve · $5k" : "No reserves",
                       emphasized: true, disabled: !hasReserve) {
                sim.resolveCrewReserve(decision)
            }
            CardButton(label: canHire ? "Hire · \(compactMoney(hireCost))" : "Can't afford hire",
                       disabled: !canHire) {
                sim.resolveCrewHire(decision)
            }
            CardButton(label: "Wait") {
                sim.resolveCrewWait(decision)
            }
        }
    }
}

/// "$28k" / "$1.2M" compact money for tight decision-card buttons.
func compactMoney(_ v: Int) -> String {
    let a = abs(v), sign = v < 0 ? "−" : ""
    if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
    if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
    return sign + "$\(a)"
}

struct SellCard: View {
    let decision: Simulation.Decision
    let sim: Simulation
    var body: some View {
        let ac = decision.aircraft
        let pct = 100 * ac.cyclesAccrued / max(1, ac.type.expectedLifespanCycles)
        DecisionCardChrome(title: "NEARING END OF SERVICE LIFE",
                           subject: "\(ac.tail) · \(ac.type.name) · \(pct)% of lifespan") {
            CardButton(label: "Sell · $\(sim.sellValue(of: ac).formatted())", emphasized: true) {
                sim.resolveSell(decision)
            }
            CardButton(label: "Keep flying") {
                sim.resolveSellKeep(decision)
            }
        }
    }
}

/// The route-opening flow's UI state.
enum RouteMode: Equatable {
    case off
    case pickOrigin
    case pickDest(String)
    case confirm(String, String)
}

/// ACQUIRE — per-aircraft profile cards (Figma 4:1993 / 3:2052): name, an
/// illustration (placeholder = the app's body-type vector icon until real
/// side-view art is supplied), a Seats / Range / Lifespan spec row, then Buy
/// new / Lease new / Buy used(×listings) rows each with a BUY (green) or LEASE
/// (gray) button. Live affordability; @Observable re-renders on balance change.
struct BuyPanel: View {
    let sim: Simulation
    let onBought: (Aircraft) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Priciest/biggest first, matching the Figma card order.
                ForEach(AircraftType.all.sorted { $0.purchasePrice > $1.purchasePrice }) { t in
                    AircraftProfileCard(sim: sim, type: t, onBought: onBought)
                }
            }
        }
        .frame(maxHeight: 460)
        .padding(8)
        .background(Sky.navBarDark)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Sky.onDarkStroke, lineWidth: 1))
    }
}

/// One aircraft's acquisition card.
struct AircraftProfileCard: View {
    let sim: Simulation
    let type: AircraftType
    let onBought: (Aircraft) -> Void

    private let gray = Color(skyHex: 0x8C8C8C)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(type.name).font(.karla(20, .heavy)).foregroundStyle(.white)

            illustration

            HStack(alignment: .top) {
                spec("Seats:", "\(type.seats)")
                Spacer()
                spec("Practical Range:", "\(type.rangeNM.formatted()) NM")
                Spacer()
                spec("Avg Lifespan:", "\(type.expectedLifespanCycles.formatted()) cycles")
            }

            Rectangle().fill(Sky.onDarkStroke).frame(height: 1)

            row("Buy new:", money(type.purchasePrice), lease: false,
                afford: sim.playerBalance >= type.purchasePrice) {
                if let ac = sim.buyAircraft(type) { onBought(ac) }
            }
            row("Lease new:",
                "\(money(sim.leaseUpfront(type))) upfront + \(money(type.monthlyLeaseCost)) / mo",
                lease: true, afford: sim.playerBalance >= sim.leaseUpfront(type)) {
                if let ac = sim.leaseAircraft(type) { onBought(ac) }
            }
            ForEach(sim.usedInventory[type.id] ?? []) { listing in
                let pct = 100 * listing.cyclesAccrued / max(1, type.expectedLifespanCycles)
                row("Buy used:",
                    "\(money(listing.price)) - \(listing.cyclesAccrued.formatted()) cycles (~\(pct)%)",
                    lease: false, afford: sim.playerBalance >= listing.price) {
                    if let ac = sim.buyUsedAircraft(listing) { onBought(ac) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sky.navBarDark)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Sky.onDarkStroke, lineWidth: 1))
    }

    /// Real side-view illustration if one is bundled for this type; otherwise
    /// the body-type vector icon as a placeholder (enlarged, centred).
    @ViewBuilder private var illustration: some View {
        if let art = AircraftArt.image(for: type.id) {
            art.resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            Canvas { ctx, size in
                guard let icon = AircraftIcon.byBodyType[type.bodyType] else { return }
                let len = min(size.width * 0.82, 210)
                let rs = len * icon.scale / type.bodyType.iconLength
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                g.scaleBy(x: rs, y: rs)
                g.translateBy(x: -icon.center.x, y: -icon.center.y)
                g.fill(icon.path, with: .color(.white.opacity(0.85)))
            }
            .frame(height: 66)
            .frame(maxWidth: .infinity)
        }
    }

    private func spec(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.karla(14, .bold)).foregroundStyle(Sky.lightBlue)
            Text(value).font(.karla(14)).foregroundStyle(.white)
        }
    }

    private func row(_ label: String, _ detail: String, lease: Bool, afford: Bool,
                     action: @escaping () -> Void) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.karla(14, .bold)).foregroundStyle(Sky.lightBlue)
                Text(detail).font(.karla(14)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Text(lease ? "LEASE" : "BUY")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(lease ? gray : Sky.coreGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(afford ? 1 : 0.4)
            }
            .buttonStyle(.plain).disabled(!afford)
        }
    }

    private func money(_ v: Int) -> String {
        "$" + v.formatted(.number.grouping(.automatic))
    }
}


/// Confirm panel for a picked origin→dest pair.
struct RouteConfirmPanel: View {
    let sim: Simulation
    let origin: Airport
    let dest: Airport
    let onOpen: () -> Void
    let onBuy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let cost = sim.routeOpeningCost(origin, dest)
        let spares = sim.idleSpares.count
        VStack(alignment: .leading, spacing: 8) {
            Text("OPEN ROUTE  \(origin.code) ↔ \(dest.code)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            Text("cost $\(cost.formatted()) · slots \(origin.slotsAvailable)+\(dest.slotsAvailable) free · \(spares) spare\(spares == 1 ? "" : "s")")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                CardButton(label: spares > 0 ? "Open Route" : "Buy an aircraft first",
                           emphasized: true, disabled: spares > 0 && sim.playerBalance < cost) {
                    spares > 0 ? onOpen() : onBuy()
                }
                CardButton(label: "Cancel") { onCancel() }
            }
        }
        .foregroundStyle(.white).padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.6), lineWidth: 1))
    }
}

/// ROUTES panel: list of every route (open + closed, newest first); tap one
/// for full P&L detail. All figures read from @Observable sim state, so an
/// open route's numbers tick up live as its aircraft completes flights.
/// ROUTES — Figma list (5:5908): ACTIVE / CLOSED sections of route cards, each
/// "ORIG → DEST" + a Profitable/Recouping status chip, assigned type, Net
/// Revenue (vs opening cost, green/red), and a disclosure triangle that expands
/// the card inline to the full P&L + profitability chart + recent flights.
struct RoutesPanel: View {
    let sim: Simulation
    @State private var expandedId: Int?

    private let netGreen = Color(skyHex: 0x87ED7A)
    private let netRed   = Color(skyHex: 0xFF9292)
    private let chipGreenBG = Color(skyHex: 0xDCFCE7)
    private let chipAmberBG = Color(skyHex: 0xFEF3C7)
    private let chipAmberFG = Color(skyHex: 0xF59E0B)

    var body: some View {
        let active = sim.playerRoutes.sorted { $0.openedTick > $1.openedTick }
        let closed = sim.closedPlayerRoutes.sorted { ($0.closedTick ?? 0) > ($1.closedTick ?? 0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if active.isEmpty && closed.isEmpty {
                    Text("No routes opened yet.")
                        .font(.karla(14)).foregroundStyle(Sky.lightBlue).padding(.vertical, 14)
                }
                if !active.isEmpty { section("ACTIVE ROUTES", active) }
                if !closed.isEmpty { section("CLOSED ROUTES", closed) }
            }
            .padding(8)
        }
        .frame(maxHeight: 480)
        .background(Sky.navBarDark.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Sky.onDarkStroke, lineWidth: 1))
    }

    private func section(_ title: String, _ routes: [Route]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(.karla(14)).foregroundStyle(Sky.lightBlue)
                Rectangle().fill(Sky.onDarkStroke).frame(height: 1)
            }
            ForEach(routes) { card($0) }
        }
    }

    private func card(_ r: Route) -> some View {
        let expanded = expandedId == r.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 12) {
                    Text(r.originCode).font(.karla(20, .heavy)).foregroundStyle(.white)
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text(r.destCode).font(.karla(20, .heavy)).foregroundStyle(.white)
                }
                Spacer()
                if r.isOpen { statusChip(profitable: r.isProfitable) }
            }
            if r.isOpen {
                HStack(alignment: .top) {
                    labeled("Aircraft Types Assigned", r.assignmentHistory.last?.typeName ?? "—", .leading)
                    Spacer()
                    let n = r.netVsOpeningCost
                    labeledValue("Net Revenue",
                                 (n >= 0 ? "+" : "") + compactMoney(n),
                                 n >= 0 ? netGreen : netRed, .trailing)
                }
            } else {
                Text("Closed · \(Simulation.simDate(fromTick: r.closedTick ?? 0))")
                    .font(.karla(14)).foregroundStyle(Sky.lightBlue)
            }
            if expanded { detail(r) }
            Image(systemName: expanded ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 11)).foregroundStyle(Sky.lightBlue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sky.navBarDark)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Sky.onDarkStroke, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expandedId = expanded ? nil : r.id } }
    }

    private func statusChip(profitable: Bool) -> some View {
        Text(profitable ? "PROFITABLE" : "RECOUPING")
            .font(.karla(10, .bold))
            .foregroundStyle(profitable ? Sky.coreGreen : chipAmberFG)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(profitable ? chipGreenBG : chipAmberBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(profitable ? Sky.coreGreen : Sky.lightYellow, lineWidth: 1))
    }

    private func labeled(_ label: String, _ value: String, _ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 0) {
            Text(label).font(.karla(14)).foregroundStyle(Sky.lightBlue)
            Text(value).font(.karla(16, .semibold)).foregroundStyle(.white)
        }
    }
    private func labeledValue(_ label: String, _ value: String, _ color: Color, _ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 0) {
            Text(label).font(.karla(14)).foregroundStyle(Sky.lightBlue)
            Text(value).font(.karla(16, .semibold)).foregroundStyle(color)
        }
    }

    @ViewBuilder private func detail(_ r: Route) -> some View {
        Rectangle().fill(Sky.onDarkStroke).frame(height: 1).padding(.top, 2)
        RouteProfitChart(route: r, flights: r.history.count)
        VStack(alignment: .leading, spacing: 3) {
            line("Start", Simulation.simDate(fromTick: r.openedTick))
            line("Flights", "\(r.flights)")
            line("Opening cost", money(r.openingCost))
            line("Cumulative net", money(r.cumulativeNet))
            line("Revenue", money(r.totalRevenue))
            line("Fees", "−" + money(r.totalFees))
            line("Operating cost", "−" + money(r.totalOperatingCost))
            line("Lease cost", "−" + money(r.totalLeaseCost))
            line("Avg load", "\(r.averageLoadPct)%")
        }
        if !r.history.isEmpty {
            Text(r.history.count > 8 ? "RECENT FLIGHTS (last 8 of \(r.history.count))" : "RECENT FLIGHTS")
                .font(.karla(10, .bold)).foregroundStyle(Sky.lightBlue).padding(.top, 2)
            ForEach(r.history.suffix(8).reversed()) { h in
                Text("\(Simulation.simDate(fromTick: h.tick)): \(h.pax)/\(h.seats) (\(Int((h.loadFactor*100).rounded()))%) · net \(h.net < 0 ? "−" : "")\(compactMoney(abs(h.net)))")
                    .font(.karla(11)).foregroundStyle(h.net < 0 ? netRed : .white.opacity(0.85))
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.karla(12)).foregroundStyle(Sky.lightBlue).frame(width: 112, alignment: .leading)
            Text(value).font(.karla(12, .semibold)).foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    private func money(_ v: Int) -> String { (v < 0 ? "−$" : "$") + abs(v).formatted(.number.grouping(.automatic)) }
}


/// Profitability-over-time chart for a route: cumulative net measured AGAINST
/// its opening cost, so the dashed break-even (zero) line shows exactly when —
/// and whether — the route recouped what it cost to open. The line is red
/// below break-even, mint above, split precisely at the crossing; a dot marks
/// the recoup point. Data comes straight from route.history (verified
/// sufficient to reconstruct the whole curve). Hand-drawn in a Canvas to match
/// the map's rendering + the current dev aesthetic (Figma restyle repaints it
/// later); re-renders live via ContentView's per-tick refresh.
struct RouteProfitChart: View {
    let route: Route
    /// Completed-flight count — a CHANGING VALUE input so SwiftUI re-invokes
    /// this view's body (and redraws the Canvas) when new flight data lands.
    /// Without it, `route` alone is a stable reference and the chart freezes.
    let flights: Int
    private let mint = Color(red: 0x37/255, green: 1, blue: 0xB0/255)
    private let red = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

    /// netVsOpeningCost at flight 0 (route opened — the full hole), then one
    /// value per completed flight.
    private var series: [Double] {
        [Double(-route.openingCost)] + route.history.map { Double($0.cumulativeNet - route.openingCost) }
    }
    /// First 1-based flight index that reached break-even, if any.
    private var recoupFlight: Int? {
        let s = series
        return s.indices.first { $0 >= 1 && s[$0] >= 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROFITABILITY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            if route.history.isEmpty {
                Text("No flight data yet.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 22)
            } else {
                Canvas { ctx, size in draw(ctx, size) }
                    .frame(height: 116)
                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder private var caption: some View {
        if let k = recoupFlight, k - 1 < route.history.count {
            Text("Recouped at flight \(k) · \(Simulation.simDate(fromTick: route.history[k - 1].tick))")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(mint)
        } else {
            Text("Not yet recouped · \(money(abs(route.netVsOpeningCost))) to break-even")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(red)
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let s = series
        let leftPad: CGFloat = 48, rightPad: CGFloat = 8, topPad: CGFloat = 8, bottomPad: CGFloat = 6
        let plotW = size.width - leftPad - rightPad
        let plotH = size.height - topPad - bottomPad
        let n = s.count
        let maxY = max(s.max() ?? 0, 0)
        let minY = min(s.min() ?? 0, 0)
        let range = max(1, maxY - minY)
        func sx(_ i: Int) -> CGFloat { leftPad + (n <= 1 ? 0 : plotW * CGFloat(i) / CGFloat(n - 1)) }
        func sy(_ v: Double) -> CGFloat { topPad + plotH * CGFloat(1 - (v - minY) / range) }

        ctx.stroke(Path(CGRect(x: leftPad, y: topPad, width: plotW, height: plotH)),
                   with: .color(.white.opacity(0.10)), lineWidth: 1)

        // Break-even (zero) line — dashed, prominent.
        let zy = sy(0)
        var z = Path(); z.move(to: CGPoint(x: leftPad, y: zy)); z.addLine(to: CGPoint(x: leftPad + plotW, y: zy))
        ctx.stroke(z, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Y labels: max (top), $0 (break-even), min (bottom).
        yLabel(ctx, money(Int(maxY)), CGPoint(x: leftPad - 5, y: sy(maxY)))
        yLabel(ctx, "$0", CGPoint(x: leftPad - 5, y: zy))
        yLabel(ctx, money(Int(minY)), CGPoint(x: leftPad - 5, y: sy(minY)))

        // P&L line, split at each zero crossing and coloured by sign.
        for i in 0..<(n - 1) {
            let x0 = sx(i), x1 = sx(i + 1), v0 = s[i], v1 = s[i + 1]
            if (v0 < 0) != (v1 < 0), v1 != v0 {
                let xc = x0 + (x1 - x0) * CGFloat(-v0 / (v1 - v0))
                seg(ctx, CGPoint(x: x0, y: sy(v0)), CGPoint(x: xc, y: zy), green: v0 >= 0)
                seg(ctx, CGPoint(x: xc, y: zy), CGPoint(x: x1, y: sy(v1)), green: v1 >= 0)
            } else {
                seg(ctx, CGPoint(x: x0, y: sy(v0)), CGPoint(x: x1, y: sy(v1)), green: (v0 + v1) >= 0)
            }
        }

        // Recoup marker at the break-even crossing.
        if let k = recoupFlight, k < n {
            let v0 = s[k - 1], v1 = s[k]
            let xc = (v0 < 0) != (v1 < 0) && v1 != v0
                ? sx(k - 1) + (sx(k) - sx(k - 1)) * CGFloat(-v0 / (v1 - v0))
                : sx(k)
            ctx.fill(Path(ellipseIn: CGRect(x: xc - 3, y: zy - 3, width: 6, height: 6)), with: .color(mint))
        }
    }

    private func seg(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, green: Bool) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(green ? mint : red), lineWidth: 1.5)
    }

    private func yLabel(_ ctx: GraphicsContext, _ s: String, _ at: CGPoint) {
        ctx.draw(Text(s).font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                 at: at, anchor: .trailing)
    }

    private func money(_ v: Int) -> String {
        let a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }
}

/// Tap-selected aircraft info card. Field ORDER follows the prototype's
/// documented designer decision (Route → Tail → Type → Status → …). The crew
/// legal-hours and Revenue/Fees/Operating-cost/Net rows slot in RIGHT HERE
/// once the crew system and Phase 5 economy are ported — the layout is built
/// to receive them, not to be rebuilt. Visual design is deliberately the dev
/// aesthetic; the real Figma restyle is the Phase 4 pass (designer decision).
struct AircraftTooltip: View {
    let aircraft: Aircraft
    let sim: Simulation
    let tick: Int            // changing value input — keeps status/crew live
    let onClose: () -> Void

    private let heldColor = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

    private let othersColor = Color(red: 0xD7/255, green: 0x67/255, blue: 0xFF/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header airline name: the competitor's for background traffic,
            // the player's own airline (green) for owned aircraft.
            if let airline = aircraft.airlineName {
                Text(airline.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(othersColor)
            } else if let mine = sim.playerAirlineName {
                Text(mine.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(climbColor)
            }
            HStack {
                Text(aircraft.isIdleSpare ? "SPARE · at \(aircraft.origin.code)"
                                          : "\(aircraft.origin.code) → \(aircraft.dest.code)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            // Leased aircraft carry a fixed monthly obligation — flag it (amber)
            // so a higher op-cost line reads as expected, not a bug.
            if aircraft.isLeased {
                Text("LEASED · \(money(aircraft.type.monthlyLeaseCost))/mo")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255))
            }
            row("TAIL", aircraft.tail)
            row("TYPE", aircraft.type.name)
            row("STATUS", statusText, valueColor: aircraft.isHeld ? heldColor : .white)

            // Crew / load / cycles / economics are the PLAYER's operational
            // detail only — a rival's books aren't visible. Ported from the
            // prototype's deliberately-reduced background-traffic tooltip.
            if aircraft.airlineName == nil {
                row("CREW", crewText, valueColor: crewValueColor)
                row("LOAD", loadText)
                row("CYCLES", cyclesText)

                Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 2)

                let econ = sim.legEconomics(for: aircraft)
                row("REVENUE", money(econ.revenue))
                row("FEES", "−" + money(econ.fees))
                // Op cost folds in a smoothed lease estimate for leased aircraft
                // (display-only); the real lease is a fixed monthly bill.
                row("OP COST", "−" + money(econ.displayOperatingCost))
                row("NET / LEG", (econ.displayNet < 0 ? "−" : "") + money(abs(econ.displayNet)),
                    valueColor: econ.displayNet < 0 ? heldColor : climbColor)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func row(_ label: String, _ value: String, valueColor: Color = .white) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(valueColor.opacity(0.92))
            Spacer(minLength: 0)
        }
    }

    private var statusText: String {
        switch aircraft.holdReason {
        case .weather:
            return aircraft.state == .approach
                ? "HELD — holding pattern at \(aircraft.dest.code) (weather)"
                : "HELD — ground stop at \(aircraft.origin.code)"
        case .rejoin:  return "Rejoining approach at \(aircraft.dest.code)"
        case .aog:     return "AOG — grounded at \(aircraft.origin.code)"
        case .crew:    return "HELD — no legal crew at \(aircraft.origin.code)"
        case nil:      return phaseLabel(aircraft.state)
        }
    }

    /// Crew legal hours (Part 117 duty clock), or the reason there's no crew.
    private var crewText: String {
        if aircraft.holdReason == .crew { return "none — awaiting legal crew" }
        guard let d = sim.crewDuty(for: aircraft) else { return "—" }
        return String(format: "%.1f / %.0f duty hrs", d.used, d.max)
    }

    private var crewValueColor: Color {
        if aircraft.holdReason == .crew { return heldColor }
        // amber as the crew nears its duty limit
        if let d = sim.crewDuty(for: aircraft), d.used > d.max * 0.8 {
            return Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255)
        }
        return .white
    }

    private let climbColor = Color(red: 0x37/255, green: 0xFF/255, blue: 0xB0/255)

    private var loadText: String {
        let pct = Int((aircraft.currentLoadFactor * 100).rounded())
        return "\(aircraft.currentPax) / \(aircraft.type.seats) pax (\(pct)%)"
    }

    private func money(_ v: Int) -> String {
        "$" + v.formatted(.number.grouping(.automatic))
    }

    private var cyclesText: String {
        let pct = 100 * aircraft.cyclesAccrued / max(1, aircraft.type.expectedLifespanCycles)
        return "\(aircraft.cyclesAccrued.formatted()) / \(aircraft.type.expectedLifespanCycles.formatted()) (\(pct)%)"
    }

    private func phaseLabel(_ state: FlightState) -> String {
        String(describing: state)
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .uppercased()
    }
}

#Preview {
    ContentView()
}
