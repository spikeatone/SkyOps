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
        TabView(selection: $tab) {
            NetworkView(sim: sim)
                .tabItem { Label("Network", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
                .tag(0)
            placeholder("Fleet", "airplane")
                .tabItem { Label("Fleet", systemImage: "airplane") }.tag(1)
            placeholder("Crews", "person.2.fill")
                .tabItem { Label("Crews", systemImage: "person.2.fill") }.tag(2)
            placeholder("Ops", "list.clipboard.fill")
                .tabItem { Label("Ops", systemImage: "list.clipboard.fill") }.tag(3)
            placeholder("Finance", "chart.bar.fill")
                .tabItem { Label("Finance", systemImage: "chart.bar.fill") }.tag(4)
        }
        .tint(Sky.brightBlue)
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
                Text(title.uppercased()).font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Sky.brightBlue)
                Text("Coming soon").font(.system(size: 13)).foregroundStyle(.secondary)
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

/// Acquire panel: NEW (buy outright or lease) and USED (buy pre-owned) tabs.
/// Every action re-checks affordability against the LIVE balance (which changes
/// every completed flight — @Observable re-renders this on change, no per-tick
/// refresh needed, avoiding the prototype's thrice-recurring flicker bug).
struct BuyPanel: View {
    let sim: Simulation
    let onBought: (Aircraft) -> Void
    @State private var showUsed = false

    private let mint = Color(red: 0x37/255, green: 1, blue: 0xB0/255)
    private let amber = Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ACQUIRE AIRCRAFT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    tab("NEW", active: !showUsed) { showUsed = false }
                    tab("USED", active: showUsed) { showUsed = true }
                }
            }
            ScrollView {
                VStack(spacing: 3) {
                    if showUsed { usedRows } else { newRows }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    // NEW: buy outright or lease (15% upfront + a fixed monthly bill).
    @ViewBuilder private var newRows: some View {
        ForEach(AircraftType.all.sorted { $0.purchasePrice < $1.purchasePrice }) { t in
            let leaseUp = sim.leaseUpfront(t)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.name).font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text("\(t.seats) seats · \(FAMILY_LABELS[t.family] ?? t.family)")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    Text("lease \(priceLabel(t.monthlyLeaseCost))/mo")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(amber.opacity(0.75))
                }
                Spacer()
                VStack(spacing: 3) {
                    acquireButton("Buy · \(priceLabel(t.purchasePrice))", tint: mint,
                                  afford: sim.playerBalance >= t.purchasePrice) {
                        if let ac = sim.buyAircraft(t) { onBought(ac) }
                    }
                    acquireButton("Lease · \(priceLabel(leaseUp))", tint: amber,
                                  afford: sim.playerBalance >= leaseUp) {
                        if let ac = sim.leaseAircraft(t) { onBought(ac) }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 4).padding(.horizontal, 6)
        }
    }

    // USED: persistent pre-owned inventory, cheapest first; each inherits its
    // real cycle count. Buy-only (no lease), matching the designer's decision.
    @ViewBuilder private var usedRows: some View {
        let listings = sim.usedListings
        if listings.isEmpty {
            Text("No used aircraft on the market right now.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
        } else {
            ForEach(listings) { l in
                if let t = AircraftType.all.first(where: { $0.id == l.typeId }) {
                    let pct = 100 * l.cyclesAccrued / max(1, t.expectedLifespanCycles)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.name).font(.system(size: 12, weight: .medium, design: .monospaced))
                            Text("\(l.cyclesAccrued.formatted()) cycles · \(pct)% of life used")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        acquireButton("Buy · \(priceLabel(l.price))", tint: mint,
                                      afford: sim.playerBalance >= l.price) {
                            if let ac = sim.buyUsedAircraft(l) { onBought(ac) }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 4).padding(.horizontal, 6)
                }
            }
        }
    }

    private func tab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.vertical, 4).padding(.horizontal, 10)
                .background(active ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func acquireButton(_ label: String, tint: Color, afford: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 118)
                .padding(.vertical, 6)
                .background((afford ? tint : Color.white).opacity(afford ? 0.22 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(afford ? 1 : 0.4)
        }
        .buttonStyle(.plain).disabled(!afford)
    }

    /// "$14M" for clean values ≥ $10M, "$2.1M" below, "$340k" under $1M.
    private func priceLabel(_ v: Int) -> String {
        let m = Double(v) / 1_000_000
        if m >= 10 { return "$\(Int(m.rounded()))M" }
        if m >= 1  { return String(format: "$%.1fM", m) }
        return "$\(Int((Double(v) / 1000).rounded()))k"
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
struct RoutesPanel: View {
    let sim: Simulation
    @Binding var detailId: Int?
    let onClose: () -> Void

    private let mint = Color(red: 0x37/255, green: 1, blue: 0xB0/255)
    private let red = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let id = detailId, let route = sim.allRoutes.first(where: { $0.id == id }) {
                detail(route)
            } else {
                list
            }
        }
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: List

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ROUTES").font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                closeButton
            }
            let routes = sim.allRoutes
            if routes.isEmpty {
                Text("No routes opened yet.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).padding(.vertical, 10)
            } else {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(routes) { r in
                            Button { detailId = r.id } label: { listRow(r) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func listRow(_ r: Route) -> some View {
        let remaining = r.openingCost - r.cumulativeNet
        let good = remaining <= 0
        return HStack {
            HStack(spacing: 6) {
                Text("\(r.originCode) ↔ \(r.destCode)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Text(r.isOpen ? "OPEN" : "CLOSED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(r.isOpen ? mint : .secondary)
            }
            Spacer()
            Text(good ? "profitable · \(r.flights) flts"
                      : "\(money(remaining)) short · \(r.flights) flts")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(good ? mint : .white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 5).padding(.horizontal, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: Detail

    private func detail(_ r: Route) -> some View {
        let remaining = r.openingCost - r.cumulativeNet
        let profitable = remaining <= 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { detailId = nil } label: {
                    Text("← Back").font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.vertical, 4).padding(.horizontal, 8)
                        .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain)
                Text("\(r.originCode) ↔ \(r.destCode) · \(r.isOpen ? "OPEN" : "CLOSED")")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Spacer()
                closeButton
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // `flights` is a CHANGING VALUE input — without it SwiftUI
                    // diffs this Canvas view as identical (its only other input,
                    // `route`, is a stable reference) and never redraws it, the
                    // same freeze family as the Phase 1 MapView bug.
                    RouteProfitChart(route: r, flights: r.history.count)
                    section {
                        line("Start", Simulation.simDate(fromTick: r.openedTick))
                        if let c = r.closedTick { line("Closed", Simulation.simDate(fromTick: c)) }
                        line("Flights", "\(r.flights)")
                        line("Opening cost", money(r.openingCost))
                        line("Cumulative net", money(r.cumulativeNet),
                             color: r.cumulativeNet < 0 ? red : .white)
                        line("Status",
                             profitable ? "profitable (+\(money(abs(remaining))))"
                                        : "\(money(remaining)) short",
                             color: profitable ? mint : red)
                    }
                    section {
                        line("Revenue", money(r.totalRevenue))
                        line("Fees", "−" + money(r.totalFees))
                        line("Operating cost", "−" + money(r.totalOperatingCost))
                        line("Lease cost", "−" + money(r.totalLeaseCost))
                        line("Avg load", "\(r.averageLoadPct)%")
                    }
                    section {
                        Text("ASSIGNED AIRCRAFT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        ForEach(r.assignmentHistory) { a in
                            Text("\(a.tail) (\(a.typeName)) — \(Simulation.simDate(fromTick: a.assignedTick))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    section {
                        Text(r.history.count > 15 ? "RECENT FLIGHTS (last 15 of \(r.history.count))"
                                                  : "RECENT FLIGHTS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if r.history.isEmpty {
                            Text("No completed flights yet.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        } else {
                            ForEach(r.history.suffix(15).reversed()) { h in
                                Text("\(Simulation.simDate(fromTick: h.tick)): \(h.pax)/\(h.seats) (\(Int((h.loadFactor*100).rounded()))%) · rev \(money(h.revenue)) · net \(h.net < 0 ? "−" : "")\(money(abs(h.net)))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(h.net < 0 ? red : .white.opacity(0.85))
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    // MARK: Bits

    private func section<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func line(_ label: String, _ value: String, color: Color = .white) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(color)
            Spacer(minLength: 0)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.6)).padding(6)
        }.buttonStyle(.plain)
    }

    private func money(_ v: Int) -> String {
        (v < 0 ? "−$" : "$") + abs(v).formatted(.number.grouping(.automatic))
    }
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
