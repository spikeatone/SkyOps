//
//  FinanceView.swift
//  Airline Architect — the FINANCE tab
//
//  No Figma mockup for this screen — built to the app's established design
//  language (Sky tokens, Karla, the CrewsView/OpsView card + header pattern)
//  to surface the financial info that matters: net worth (and its trend over
//  time), whether flight operations are actually profitable, where the money
//  is going, and a cash-flow reconciliation that ties EXACTLY to cash on hand.
//
//  A period selector (Total / This month / Last month) drives the P&L,
//  breakdown, and cash-flow cards. Period figures are the difference between
//  two month-boundary snapshots (Simulation.financeSnapshots), so they
//  reconcile the same way the cumulative ledger does. The net-worth trend
//  chart plots those same monthly snapshots.
//

import SwiftUI

struct FinanceView: View {
    let sim: Simulation
    var onBell: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    enum Period: String, CaseIterable { case total = "Total", thisMonth = "This month", lastMonth = "Last month" }
    @State private var period: Period = .total

    // Theme tokens (light Figma-family / dark Sky), matched to Crews/Ops.
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color    { isDark ? .white : .black }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private let green = Sky.coreGreen
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    private var trackBG: Color    { isDark ? Sky.darkBG : Color(skyHex: 0xEDEFF2) }

    // MARK: Point-in-time figures (always current, independent of period)
    private var cash: Int { sim.playerBalance }
    private var fleetValue: Int { sim.fleetMarketValue }
    private var netWorth: Int { cash + fleetValue }
    private var fleetFootnote: String {
        let n = sim.ownedOutrightCount
        let base = "Fleet value = resale value of \(n) aircraft owned outright"
        let leased = sim.leasedCount
        return leased > 0 ? base + " (\(leased) leased, not counted)." : base + "."
    }

    var body: some View {
        let _ = sim.tick   // live totals refresh every tick
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                periodSelector
                ScrollView {
                    VStack(spacing: 16) {
                        if !sim.currentEvent.isNormal { marketBanner }
                        netWorthCard
                        if netWorthSeries.count >= 2 { trendCard }
                        if let f = figures {
                            flightOpsCard(f)
                            breakdownCard(f)
                            cashFlowCard(f)
                        } else {
                            unavailableCard
                        }
                    }
                    .padding(.bottom, 8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    // MARK: Header (matches Crews/Ops)
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(compactMoney(cash)).font(.karla(15, .semibold))
                    .foregroundStyle(cash < 0 ? red : green)
                Spacer()
            }
            Divider().overlay(cardBorder)
            HStack {
                Text("FINANCE").font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    // MARK: Period selector (segmented pill)
    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases, id: \.self) { p in
                let on = period == p
                Button { period = p } label: {
                    Text(p.rawValue)
                        .font(.karla(13, on ? .bold : .regular))
                        .foregroundStyle(on ? (isDark ? Sky.navBarDark : .white) : primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(on ? titleColor : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(trackBG)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Market condition banner (active economic event)
    private var marketBanner: some View {
        let ev = sim.currentEvent
        func pct(_ m: Double) -> String { (m >= 1 ? "+" : "") + "\(Int(((m - 1) * 100).rounded()))%" }
        let harmful = ev.fareMultiplier < 1 || ev.costMultiplier > 1
        let accent = harmful ? Color(skyHex: 0xFFAB44) : green
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Market: \(ev.label)").font(.karla(14, .bold)).foregroundStyle(primary)
                Text("Fares \(pct(ev.fareMultiplier)) · Costs \(pct(ev.costMultiplier)) · Demand \(pct(ev.loadMultiplier))")
                    .font(.karla(12)).foregroundStyle(secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.6), lineWidth: 1))
    }

    // MARK: Net worth hero (delta reflects the selected period)
    private var netWorthCard: some View {
        let delta = netWorthDelta
        return card {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("NET WORTH")
                Text(compactMoney(netWorth))
                    .font(.karla(38, .heavy))
                    .foregroundStyle(netWorth < 0 ? red : primary)
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(compactMoney(abs(delta))) \(deltaLabel)")
                        .font(.karla(13, .semibold))
                }
                .foregroundStyle(delta >= 0 ? green : red)
                Divider().overlay(cardBorder)
                HStack(spacing: 12) {
                    miniStat("Cash on hand", compactMoney(cash), cash < 0 ? red : green)
                    miniStat("Fleet value", compactMoney(fleetValue), primary)
                }
                Text(fleetFootnote).font(.karla(11)).foregroundStyle(secondary)
            }
        }
    }

    /// Net-worth change over the selected period (falls back to since-launch).
    private var netWorthDelta: Int {
        switch period {
        case .total:     return netWorth - Simulation.startingCapital
        case .thisMonth: return netWorth - (sim.financeSnapshots.last?.netWorth ?? Simulation.startingCapital)
        case .lastMonth:
            let s = sim.financeSnapshots
            guard s.count >= 2 else { return 0 }
            return s[s.count - 1].netWorth - s[s.count - 2].netWorth
        }
    }
    private var deltaLabel: String {
        switch period {
        case .total: return "since launch"
        case .thisMonth: return "this month"
        case .lastMonth: return "last month"
        }
    }

    // MARK: Net worth trend (monthly snapshots + live point)
    private var netWorthSeries: [Int] { sim.financeSnapshots.map(\.netWorth) + [netWorth] }
    private var trendCard: some View {
        let series = netWorthSeries
        let months = max(0, series.count - 1)
        return card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("NET WORTH TREND")
                NetWorthSparkline(values: series, baseline: Simulation.startingCapital,
                                  up: green, down: red, grid: cardBorder)
                    .frame(height: 120)
                HStack {
                    Text("Launch").font(.karla(10)).foregroundStyle(secondary)
                    Spacer()
                    Text("\(months) sim-month\(months == 1 ? "" : "s") · dashed = launch")
                        .font(.karla(10)).foregroundStyle(secondary)
                    Spacer()
                    Text("Now").font(.karla(10)).foregroundStyle(secondary)
                }
            }
        }
    }

    // MARK: Period figures
    /// nil only for Last month before a full sim-month has elapsed.
    private var figures: PeriodFigures? {
        let s = sim.financeSnapshots
        switch period {
        case .total:
            return PeriodFigures(
                revenue: sim.totalRevenue, fees: sim.totalFees, operatingCost: sim.totalOperatingCost,
                leaseCost: sim.totalLeaseCost, insurance: sim.totalInsuranceSpent, maintenance: sim.maintenanceSpend,
                acquisition: sim.totalAcquisitionSpend, routeSpend: sim.totalRouteSpend, hedgeSpend: sim.totalHedgeSpend,
                saleProceeds: sim.totalSaleProceeds, offerIncome: sim.totalOfferIncome, flights: sim.totalFlightsFlown,
                cashStart: Simulation.startingCapital, cashEnd: sim.playerBalance, isTotal: true)
        case .thisMonth:
            return delta(from: s.last, toLive: true)
        case .lastMonth:
            guard s.count >= 2 else { return nil }
            return delta(from: s[s.count - 2], to: s[s.count - 1])
        }
    }

    /// current-live − base (thisMonth), or `to` − `from` (lastMonth).
    private func delta(from base: Simulation.FinanceSnapshot?, to end: Simulation.FinanceSnapshot? = nil, toLive: Bool = false) -> PeriodFigures {
        func d(_ live: Int, _ kp: KeyPath<Simulation.FinanceSnapshot, Int>) -> Int {
            (toLive ? live : (end?[keyPath: kp] ?? 0)) - (base?[keyPath: kp] ?? 0)
        }
        return PeriodFigures(
            revenue: d(sim.totalRevenue, \.revenue),
            fees: d(sim.totalFees, \.fees),
            operatingCost: d(sim.totalOperatingCost, \.operatingCost),
            leaseCost: d(sim.totalLeaseCost, \.leaseCost),
            insurance: d(sim.totalInsuranceSpent, \.insurance),
            maintenance: d(sim.maintenanceSpend, \.maintenance),
            acquisition: d(sim.totalAcquisitionSpend, \.acquisition),
            routeSpend: d(sim.totalRouteSpend, \.routeSpend),
            hedgeSpend: d(sim.totalHedgeSpend, \.hedgeSpend),
            saleProceeds: d(sim.totalSaleProceeds, \.saleProceeds),
            offerIncome: d(sim.totalOfferIncome, \.offerIncome),
            flights: d(sim.totalFlightsFlown, \.flights),
            cashStart: base?.cash ?? Simulation.startingCapital,
            cashEnd: toLive ? sim.playerBalance : (end?.cash ?? sim.playerBalance),
            isTotal: false)
    }

    // MARK: Flight operations P&L
    private func flightOpsCard(_ f: PeriodFigures) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("FLIGHT OPERATIONS")
                ledgerRow("Ticket revenue", f.revenue, sign: .plus)
                ledgerRow("Airport fees", f.fees, sign: .minus)
                ledgerRow("Operating costs", f.operatingCost, sign: .minus)
                Divider().overlay(cardBorder)
                ledgerRow(f.operatingProfit >= 0 ? "Operating profit" : "Operating loss",
                          f.operatingProfit, sign: .net, bold: true)
                Text(f.flights == 0
                     ? "No flights \(period == .total ? "flown yet" : "in this period")."
                     : "\(f.flights) flights · avg \(signedMoney(f.operatingProfit / max(1, f.flights)))/flight")
                    .font(.karla(11)).foregroundStyle(secondary)
            }
        }
    }

    // MARK: Overhead & capital breakdown
    private func breakdownCard(_ f: PeriodFigures) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("OVERHEAD & CAPITAL")
                ledgerRow("Lease payments", f.leaseCost, sign: .minus)
                ledgerRow("Insurance premiums", f.insurance, sign: .minus)
                ledgerRow("Maintenance & crew", f.maintenance, sign: .minus)
                Divider().overlay(cardBorder.opacity(0.5))
                ledgerRow("Aircraft acquisition", f.acquisition, sign: .minus)
                ledgerRow("Route openings", f.routeSpend, sign: .minus)
                ledgerRow("Fuel hedges", f.hedgeSpend, sign: .minus)
                Divider().overlay(cardBorder.opacity(0.5))
                ledgerRow("Aircraft sales", f.saleProceeds, sign: .plus)
                ledgerRow("Slot buybacks", f.offerIncome, sign: .plus)
            }
        }
    }

    // MARK: Cash-flow reconciliation (ties to cash)
    private func cashFlowCard(_ f: PeriodFigures) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("CASH FLOW")
                ledgerRow(f.isTotal ? "Starting capital" : "Cash, period start", f.cashStart, sign: .plus)
                ledgerRow("Operating profit", f.operatingProfit, sign: .net)
                ledgerRow("Overhead", f.overhead, sign: .minus)
                ledgerRow("Capital spending", f.capitalOut, sign: .minus)
                ledgerRow("Capital income", f.capitalIn, sign: .plus)
                Divider().overlay(cardBorder)
                ledgerRow(f.isTotal ? "Cash on hand" : "Cash, period end", f.cashEnd, sign: .net, bold: true)
            }
        }
    }

    private var unavailableCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("LAST MONTH")
                Text("No completed sim-month yet.").font(.karla(15, .bold)).foregroundStyle(primary)
                Text("A full month of history appears here after your first sim-month of operations.")
                    .font(.karla(12)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Building blocks

    private enum Sign { case plus, minus, net }

    private func ledgerRow(_ label: String, _ value: Int, sign: Sign, bold: Bool = false) -> some View {
        let text: String
        let color: Color
        switch sign {
        case .plus:  text = "+" + money(value); color = value == 0 ? secondary : green
        case .minus: text = "−" + money(value); color = value == 0 ? secondary : red
        case .net:   text = signedMoney(value); color = value < 0 ? red : green
        }
        return HStack {
            Text(label).font(.karla(bold ? 15 : 14, bold ? .bold : .regular)).foregroundStyle(primary)
            Spacer()
            Text(text).font(.karla(bold ? 15 : 14, bold ? .bold : .semibold)).foregroundStyle(color)
        }
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.karla(12)).foregroundStyle(secondary)
            Text(value).font(.karla(18, .heavy)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.karla(12, .bold)).foregroundStyle(titleColor).tracking(0.5)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Money formatting (full grouped figures — a finance screen wants
    // precision, unlike the compact hero/header numbers).
    private func money(_ v: Int) -> String { "$" + abs(v).formatted(.number.grouping(.automatic)) }
    private func signedMoney(_ v: Int) -> String { (v < 0 ? "−$" : "+$") + abs(v).formatted(.number.grouping(.automatic)) }
}

/// A period's worth of financial activity (a difference between two snapshots,
/// or the running cumulative totals for Total). Reconciles: cashStart +
/// operatingProfit − overhead − capitalOut + capitalIn == cashEnd.
struct PeriodFigures {
    var revenue, fees, operatingCost: Int
    var leaseCost, insurance, maintenance: Int
    var acquisition, routeSpend, hedgeSpend: Int
    var saleProceeds, offerIncome, flights: Int
    var cashStart, cashEnd: Int
    var isTotal: Bool
    var operatingProfit: Int { revenue - fees - operatingCost }
    var overhead: Int { leaseCost + insurance + maintenance }
    var capitalOut: Int { acquisition + routeSpend + hedgeSpend }
    var capitalIn: Int { saleProceeds + offerIncome }
}

/// A compact net-worth-over-time line. Line is green above the launch baseline,
/// red below (split per segment); a dashed line marks the launch balance.
/// Drawn in a Canvas but kept as a plain value-input view — `values` changes
/// every tick (the live last point), so it re-renders and never freezes.
private struct NetWorthSparkline: View {
    let values: [Int]
    let baseline: Int
    let up, down, grid: Color

    var body: some View {
        Canvas { ctx, size in
            guard values.count >= 2 else { return }
            let lo = min(values.min()!, baseline), hi = max(values.max()!, baseline)
            let span = max(1, hi - lo)
            let padY: CGFloat = 8
            func x(_ i: Int) -> CGFloat { size.width * CGFloat(i) / CGFloat(values.count - 1) }
            func y(_ v: Int) -> CGFloat {
                let t = CGFloat(v - lo) / CGFloat(span)
                return size.height - padY - t * (size.height - 2 * padY)
            }
            var base = Path()
            base.move(to: CGPoint(x: 0, y: y(baseline)))
            base.addLine(to: CGPoint(x: size.width, y: y(baseline)))
            ctx.stroke(base, with: .color(grid), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            for i in 0..<(values.count - 1) {
                var seg = Path()
                seg.move(to: CGPoint(x: x(i), y: y(values[i])))
                seg.addLine(to: CGPoint(x: x(i + 1), y: y(values[i + 1])))
                let avg = (values[i] + values[i + 1]) / 2
                ctx.stroke(seg, with: .color(avg >= baseline ? up : down),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            let last = values.count - 1
            let r: CGFloat = 3.5
            let dot = Path(ellipseIn: CGRect(x: x(last) - r, y: y(values[last]) - r, width: 2 * r, height: 2 * r))
            ctx.fill(dot, with: .color(values[last] >= baseline ? up : down))
        }
    }
}
