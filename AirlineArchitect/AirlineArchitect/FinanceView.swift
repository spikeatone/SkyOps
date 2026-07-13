//
//  FinanceView.swift
//  Airline Architect — the FINANCE tab
//
//  No Figma mockup for this screen — built to the app's established design
//  language (Sky tokens, Karla, the CrewsView/OpsView card + header pattern)
//  to surface the financial info that matters: net worth, whether flight
//  operations are actually profitable, where the money is going, and a cash-
//  flow reconciliation that ties EXACTLY to cash on hand.
//
//  Every number comes from a real running total on Simulation. Those totals
//  reconcile to playerBalance by construction (see the "Capital-account
//  totals" note in Simulation) — the Cash Flow card makes that visible, so
//  the screen can never quietly disagree with the header's cash figure.
//

import SwiftUI

struct FinanceView: View {
    let sim: Simulation
    var onBell: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    // Theme tokens (light Figma-family / dark Sky), matched to Crews/Ops.
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color    { isDark ? .white : .black }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private let green = Sky.coreGreen
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }

    // MARK: Derived figures
    private var cash: Int { sim.playerBalance }
    private var fleetValue: Int { sim.fleetMarketValue }
    private var netWorth: Int { cash + fleetValue }
    private var netWorthDelta: Int { netWorth - Simulation.startingCapital }
    private var operatingProfit: Int { sim.netRevenue }   // rev − fees − opcost
    private var overhead: Int { sim.totalLeaseCost + sim.totalInsuranceSpent + sim.maintenanceSpend }
    private var capitalOut: Int { sim.totalAcquisitionSpend + sim.totalRouteSpend + sim.totalHedgeSpend }
    private var capitalIn: Int { sim.totalSaleProceeds + sim.totalOfferIncome }
    private var totalFlights: Int {
        sim.playerRoutes.reduce(0) { $0 + $1.flights } + sim.closedPlayerRoutes.reduce(0) { $0 + $1.flights }
    }
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
            VStack(spacing: 16) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        if !sim.currentEvent.isNormal { marketBanner }
                        netWorthCard
                        flightOpsCard
                        breakdownCard
                        cashFlowCard
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

    // MARK: Market condition banner (active economic event)
    private var marketBanner: some View {
        let ev = sim.currentEvent
        // Cost/fare/load deltas as signed percentages.
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
        .background(isDark ? Sky.navBarDark : .white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.6), lineWidth: 1))
    }

    // MARK: Net worth hero
    private var netWorthCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("NET WORTH")
                Text(compactMoney(netWorth))
                    .font(.karla(38, .heavy))
                    .foregroundStyle(netWorth < 0 ? red : primary)
                HStack(spacing: 6) {
                    Image(systemName: netWorthDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(compactMoney(abs(netWorthDelta))) since launch")
                        .font(.karla(13, .semibold))
                }
                .foregroundStyle(netWorthDelta >= 0 ? green : red)
                Divider().overlay(cardBorder)
                HStack(spacing: 12) {
                    miniStat("Cash on hand", compactMoney(cash), cash < 0 ? red : green)
                    miniStat("Fleet value", compactMoney(fleetValue), primary)
                }
                Text(fleetFootnote)
                    .font(.karla(11)).foregroundStyle(secondary)
            }
        }
    }

    // MARK: Flight operations P&L
    private var flightOpsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("FLIGHT OPERATIONS")
                ledgerRow("Ticket revenue", sim.totalRevenue, sign: .plus)
                ledgerRow("Airport fees", sim.totalFees, sign: .minus)
                ledgerRow("Operating costs", sim.totalOperatingCost, sign: .minus)
                Divider().overlay(cardBorder)
                ledgerRow(operatingProfit >= 0 ? "Operating profit" : "Operating loss",
                          operatingProfit, sign: .net, bold: true)
                Text(totalFlights == 0
                     ? "No flights flown yet."
                     : "\(totalFlights) flights flown · avg \(signedMoney(totalFlights == 0 ? 0 : operatingProfit / max(1, totalFlights)))/flight")
                    .font(.karla(11)).foregroundStyle(secondary)
            }
        }
    }

    // MARK: Overhead & capital breakdown
    private var breakdownCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("OVERHEAD & CAPITAL")
                // Recurring overhead
                ledgerRow("Lease payments", sim.totalLeaseCost, sign: .minus)
                ledgerRow("Insurance premiums", sim.totalInsuranceSpent, sign: .minus)
                ledgerRow("Maintenance & crew", sim.maintenanceSpend, sign: .minus)
                Divider().overlay(cardBorder.opacity(0.5))
                // Capital out
                ledgerRow("Aircraft acquisition", sim.totalAcquisitionSpend, sign: .minus)
                ledgerRow("Route openings", sim.totalRouteSpend, sign: .minus)
                ledgerRow("Fuel hedges", sim.totalHedgeSpend, sign: .minus)
                Divider().overlay(cardBorder.opacity(0.5))
                // Capital in
                ledgerRow("Aircraft sales", sim.totalSaleProceeds, sign: .plus)
                ledgerRow("Slot buybacks", sim.totalOfferIncome, sign: .plus)
            }
        }
    }

    // MARK: Cash-flow reconciliation (ties to cash on hand)
    private var cashFlowCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("CASH FLOW")
                ledgerRow("Starting capital", Simulation.startingCapital, sign: .plus)
                ledgerRow("Operating profit", operatingProfit, sign: .net)
                ledgerRow("Overhead", overhead, sign: .minus)
                ledgerRow("Capital spending", capitalOut, sign: .minus)
                ledgerRow("Capital income", capitalIn, sign: .plus)
                Divider().overlay(cardBorder)
                ledgerRow("Cash on hand", cash, sign: .net, bold: true)
            }
        }
    }

    // MARK: - Building blocks

    private enum Sign { case plus, minus, net }

    /// One ledger line: label left, signed money right. `.plus`/`.minus` colour
    /// the value by role; `.net` colours by the value's own sign.
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
