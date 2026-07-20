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
    var store: Store
    var onBell: () -> Void = {}
    var onSave: () -> Void = {}
    var onQuit: () -> Void = {}
    var onUpgrade: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    // Top-level split: REPORTS (the period-scoped financial statements) vs
    // FUNDING (ways to raise capital — loans and going public). The period
    // selector below is the sub-nav for REPORTS only.
    enum Section: String, CaseIterable { case reports = "REPORTS", funding = "FUNDING" }
    @State private var section: Section = .reports

    enum Period: String, CaseIterable { case total = "Total", thisMonth = "This month", lastMonth = "Last month" }
    @State private var period: Period = .total
    @State private var showIntel = false
    @State private var showIPO = false

    // Theme tokens (light Figma-family / dark Sky), matched to Crews/Ops.
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color    { isDark ? .white : .black }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private let green = Sky.coreGreen
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    // Period selector (Figma Bar Nav — dark 5:6947 / light 5:6932).
    private var segTrack: Color        { isDark ? Color(skyHex: 0x1F232D) : Color(skyHex: 0xE6E6E6) }
    private var segActivePill: Color   { isDark ? Color(skyHex: 0x2B303D) : .white }
    private var segActiveText: Color   { isDark ? Color(skyHex: 0xBDE0FF) : Color(skyHex: 0x64748B) }
    private var segInactiveText: Color { isDark ? Color(skyHex: 0xC9C9C9) : Color(skyHex: 0x64748B) }

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
        let _ = sim.displayTick   // throttled UI heartbeat — keeps scrolling smooth
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                sectionSelector
                if section == .reports { periodSelector }
                ScrollView {
                    VStack(spacing: 16) {
                        if section == .reports { reportsContent } else { fundingContent }
                    }
                    .padding(.bottom, 8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .fullScreenCover(isPresented: $showIntel) {
            CompetitorIntelView(sim: sim, onClose: { showIntel = false })
        }
        .fullScreenCover(isPresented: $showIPO) {
            GoPublicView(sim: sim, onClose: { showIPO = false })
        }
    }

    // MARK: Content — REPORTS (period-scoped statements)
    @ViewBuilder private var reportsContent: some View {
        planCard
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

    // MARK: Content — FUNDING (raise capital, then deploy it)
    // Financing/Go Public raise capital; Market Intelligence scouts rivals for
    // Competitor Acquisition — the capital-deployment endgame — so it lives here.
    @ViewBuilder private var fundingContent: some View {
        financingCard
        publicCard
        marketIntelCard
    }

    // MARK: Section selector (REPORTS | FUNDING) — same pill styling as period.
    private var sectionSelector: some View {
        HStack(spacing: 4) {
            ForEach(Section.allCases, id: \.self) { s in
                let on = section == s
                Button { section = s } label: {
                    Text(s.rawValue)
                        .font(.karla(14, .bold))
                        .foregroundStyle(on ? segActiveText : segInactiveText)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(on ? segActivePill : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(segTrack)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Public company — GO PUBLIC entry, or the live listing summary.
    private var publicCard: some View {
        Group {
            if let pc = sim.publicCompany {
                let price = sim.displaySharePrice
                let up = price >= pc.ipoPrice
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("PUBLIC COMPANY").font(.karla(12, .bold)).foregroundStyle(titleColor)
                        Spacer()
                        Text(pc.ticker).font(.karla(13, .bold)).foregroundStyle(primary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "$%.2f", price)).font(.karla(26, .heavy))
                            .foregroundStyle(up ? green : red)
                        Text(String(format: "%@%.1f%% vs IPO", up ? "+" : "", (price/pc.ipoPrice - 1)*100))
                            .font(.karla(13, .semibold)).foregroundStyle(up ? green : red)
                    }
                    ledgerLine("Your stake", String(format: "%.1f%%", pc.playerStake*100))
                    ledgerLine("Market cap", compactMoney(Int(sim.marketCap)))
                    ledgerLine("Raised (IPO + secondary)", compactMoney(sim.totalEquityRaised))
                    let risk = Simulation.controlRisk(stake: pc.playerStake)
                    Text(risk.rawValue)
                        .font(.karla(11, .semibold))
                        .foregroundStyle(pc.playerStake >= 0.5 ? green : red)
                    // Board pressure — visceral once it's actually building. Only
                    // possible below majority control (≥50% = immunity).
                    if pc.playerStake < Simulation.boardControlThreshold, sim.boardPressure > 0.01 {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Board patience").font(.karla(10, .semibold)).foregroundStyle(secondary)
                                Spacer()
                                Text(sim.boardPressure >= 0.5 ? "Weighing your removal" : "Watching")
                                    .font(.karla(10, .semibold)).foregroundStyle(sim.boardPressure >= 0.5 ? red : secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(cardBorder)
                                    RoundedRectangle(cornerRadius: 2).fill(red)
                                        .frame(width: geo.size.width * min(1, sim.boardPressure))
                                }
                            }.frame(height: 4)
                        }
                    }

                    Divider().overlay(cardBorder.opacity(0.5)).padding(.vertical, 2)
                    leverSection("DIVIDEND", "Pay shareholders — lifts sentiment, costs cash",
                                 Simulation.dividendYieldOptions.map { y in
                        let cost = sim.dividendCost(yield: y)
                        return LeverOption(label: "\(Int(y*100))%", detail: "−\(compactMoney(cost))",
                                           enabled: cost > 0 && sim.playerBalance >= cost, tint: red) {
                            if sim.payDividend(yield: y) { Feedback.success() }
                        }
                    })
                    leverSection("BUY BACK STOCK", "Shrink the float — raises your stake, defends control",
                                 Simulation.buybackFloatOptions.map { fr in
                        let cost = sim.buybackCost(floatFraction: fr)
                        return LeverOption(label: "\(Int(fr*100))% float", detail: "−\(compactMoney(cost))",
                                           enabled: cost > 0 && sim.playerBalance >= cost, tint: red) {
                            if sim.buyBackShares(floatFraction: fr) { Feedback.success() }
                        }
                    })
                    leverSection("SECONDARY OFFERING", "Sell new shares for cash — dilutes your stake",
                                 Simulation.secondaryOptions.map { fr in
                        let proceeds = sim.secondaryProceeds(fraction: fr)
                        return LeverOption(label: "+\(Int(fr*100))%", detail: "+\(compactMoney(proceeds))",
                                           enabled: proceeds > 0, tint: green) {
                            if sim.secondaryOffering(fraction: fr) { Feedback.success() }
                        }
                    })
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBG).clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
            } else {
                Button { if sim.canGoPublic { showIPO = true } } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GO PUBLIC").font(.karla(12, .bold)).foregroundStyle(titleColor)
                            if sim.canGoPublic {
                                Text("List the airline to raise capital")
                                    .font(.karla(14, .semibold)).foregroundStyle(primary)
                                Text("Sell equity for cash — no repayment, but you answer to shareholders")
                                    .font(.karla(11)).foregroundStyle(secondary)
                            } else {
                                Text("Unlocks at \(compactMoney(Simulation.goPublicNetWorthGate)) net worth")
                                    .font(.karla(14, .semibold)).foregroundStyle(primary)
                                Text("\(compactMoney(max(0, Simulation.goPublicNetWorthGate - sim.netWorth))) to go")
                                    .font(.karla(11)).foregroundStyle(secondary)
                            }
                        }
                        Spacer()
                        if sim.canGoPublic {
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(secondary)
                        }
                    }
                    .padding(14).background(cardBG).clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
                }.buttonStyle(.plain).disabled(!sim.canGoPublic)
            }
        }
    }

    private func ledgerLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.karla(13)).foregroundStyle(secondary)
            Spacer()
            Text(value).font(.karla(14, .semibold)).foregroundStyle(primary)
        }
    }

    // MARK: Public-company levers (step 2) — dividend / buyback / secondary chips.
    private struct LeverOption: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let enabled: Bool
        let tint: Color
        let action: () -> Void
    }

    private func leverSection(_ title: String, _ subtitle: String, _ options: [LeverOption]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.karla(11, .bold)).foregroundStyle(titleColor)
            Text(subtitle).font(.karla(10)).foregroundStyle(secondary)
            HStack(spacing: 6) {
                ForEach(options) { opt in
                    Button(action: opt.action) {
                        VStack(spacing: 1) {
                            Text(opt.label).font(.karla(12, .bold))
                            Text(opt.detail).font(.karla(9, .semibold))
                        }
                        .foregroundStyle(opt.enabled ? opt.tint : secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(opt.enabled ? opt.tint.opacity(0.55) : cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!opt.enabled)
                }
            }
        }
    }

    // MARK: Market intelligence — entry point to competitor scouting.
    // Lives in Finance because sizing up a rival carrier is an investment
    // question. Ungated: public information is public.
    private var marketIntelCard: some View {
        Button { showIntel = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MARKET INTELLIGENCE").font(.karla(12, .bold)).foregroundStyle(titleColor)
                    Text("\(sim.relevantCompetitors.count) carriers in your markets")
                        .font(.karla(14, .semibold)).foregroundStyle(primary)
                    if !sim.rivalsOnMyRoutes.isEmpty {
                        Text("\(sim.rivalsOnMyRoutes.count) contesting your routes")
                            .font(.karla(11)).foregroundStyle(red)
                    } else {
                        Text("Study their fleets, networks, and books")
                            .font(.karla(11)).foregroundStyle(secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(secondary)
            }
            .padding(14)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: Header (matches Crews/Ops)
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(cashLabel(cash)).font(.karla(15, .semibold))
                    .foregroundStyle(cash < 0 ? red : green)
                Spacer(minLength: 8)
                SaveQuitBar(onSave: onSave, onQuit: onQuit)
            }
            Divider().overlay(cardBorder)
            HStack {
                Text("FINANCE").font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    // MARK: Period selector (segmented pill — Figma Bar Nav 5:6947 / 5:6932)
    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases, id: \.self) { p in
                let on = period == p
                Button { period = p } label: {
                    Text(p.rawValue)
                        .font(.karla(14, .semibold))
                        .foregroundStyle(on ? segActiveText : segInactiveText)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(on ? segActivePill : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(segTrack)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Plan card (free-tier usage vs caps + upgrade, or Pro confirmation)
    @ViewBuilder private var planCard: some View {
        if store.isPro {
            card {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Airline Architect Pro").font(.karla(16, .bold)).foregroundStyle(primary)
                        Text("Unlimited routes & fleet — thanks for your support.")
                            .font(.karla(12)).foregroundStyle(secondary)
                    }
                    Spacer(minLength: 0)
                    ManageSubscriptionButton(tint: titleColor)
                }
            }
        } else {
            card {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionTitle("FREE PLAN")
                        Text("\(sim.ownedCount)/\(Store.freeFleetCap) aircraft · \(sim.playerRoutes.count)/\(Store.freeRouteCap) routes")
                            .font(.karla(14, .semibold)).foregroundStyle(primary)
                        Text("Upgrade for an unlimited fleet and network.")
                            .font(.karla(11)).foregroundStyle(secondary)
                    }
                    Spacer(minLength: 0)
                    Button(action: onUpgrade) {
                        Text("Upgrade").font(.karla(13, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(height: 38)
                            .background(green).clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Market condition banner (active economic event)
    private var marketBanner: some View {
        let ev = sim.currentEvent
        func pct(_ m: Double) -> String { (m >= 1 ? "+" : "") + "\(Int(((m - 1) * 100).rounded()))%" }
        let harmful = ev.fareMultiplier < 1 || ev.costMultiplier > 1
        let accent = harmful ? Color(skyHex: 0xFFAB44) : green
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Market: \(ev.label)").font(.karla(14, .bold)).foregroundStyle(primary)
                Text("Fares \(pct(ev.fareMultiplier)) · Fuel \(pct(ev.costMultiplier)) · Demand \(pct(ev.loadMultiplier))")
                    .font(.karla(12)).foregroundStyle(secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.6), lineWidth: 1))
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
                loanProceeds: sim.totalLoanProceeds, debtService: sim.totalDebtService,
                hubSpend: sim.totalHubSpend, hubLabor: sim.totalHubLabor, clubRent: sim.totalClubRent,
                airlineAcquisition: sim.totalAcquisitionPrice,
                integrationSpend: sim.totalIntegrationSpend + sim.totalSenioritySpend + sim.totalDiligenceSpend,
                equityRaised: sim.totalEquityRaised,
                dividendsPaid: sim.totalDividendsPaid, buybackSpend: sim.totalBuybackSpend,
                marketingSpend: sim.totalMarketingSpend,
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
            loanProceeds: d(sim.totalLoanProceeds, \.loanProceeds),
            debtService: d(sim.totalDebtService, \.debtService),
            hubSpend: d(sim.totalHubSpend, \.hubSpend),
            hubLabor: d(sim.totalHubLabor, \.hubLabor),
            clubRent: d(sim.totalClubRent, \.clubRent),
            airlineAcquisition: d(sim.totalAcquisitionPrice, \.airlineAcquisition),
            integrationSpend: d(sim.totalIntegrationSpend + sim.totalSenioritySpend + sim.totalDiligenceSpend, \.integrationSpend),
            equityRaised: d(sim.totalEquityRaised, \.equityRaised),
            dividendsPaid: d(sim.totalDividendsPaid, \.dividendsPaid),
            buybackSpend: d(sim.totalBuybackSpend, \.buybackSpend),
            marketingSpend: d(sim.totalMarketingSpend, \.marketingSpend),
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
                ledgerRow("Hub operations", f.hubLabor, sign: .minus)
                ledgerRow("Club rent", f.clubRent, sign: .minus)
                Divider().overlay(cardBorder.opacity(0.5))
                ledgerRow("Aircraft acquisition", f.acquisition, sign: .minus)
                ledgerRow("Route openings", f.routeSpend, sign: .minus)
                ledgerRow("Hubs & clubs built", f.hubSpend, sign: .minus)
                ledgerRow("Fuel hedges", f.hedgeSpend, sign: .minus)
                if f.marketingSpend > 0 { ledgerRow("Marketing", f.marketingSpend, sign: .minus) }
                ledgerRow("Debt service", f.debtService, sign: .minus)
                if sim.isPublic || f.dividendsPaid > 0 || f.buybackSpend > 0 {
                    ledgerRow("Dividends paid", f.dividendsPaid, sign: .minus)
                    ledgerRow("Share buybacks", f.buybackSpend, sign: .minus)
                }
                Divider().overlay(cardBorder.opacity(0.5))
                ledgerRow("Aircraft sales", f.saleProceeds, sign: .plus)
                ledgerRow("Slot buybacks", f.offerIncome, sign: .plus)
                ledgerRow("Loans drawn", f.loanProceeds, sign: .plus)
                if sim.isPublic || f.equityRaised > 0 {
                    ledgerRow("Equity raised", f.equityRaised, sign: .plus)
                }
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

    // MARK: Financing (loans)
    private var financingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("FINANCING")
                if sim.loans.isEmpty {
                    Text("No active loans. Borrow to expand faster than cash flow allows — you'll owe interest and a fixed monthly payment.")
                        .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack {
                        Text("Total debt").font(.karla(13)).foregroundStyle(secondary)
                        Spacer()
                        Text(compactMoney(sim.totalDebtOutstanding)).font(.karla(14, .bold)).foregroundStyle(red)
                    }
                    HStack {
                        Text("Monthly debt service").font(.karla(13)).foregroundStyle(secondary)
                        Spacer()
                        Text("\(compactMoney(sim.monthlyDebtService))/mo").font(.karla(14, .bold)).foregroundStyle(red)
                    }
                    ForEach(sim.loans) { loan in
                        HStack(spacing: 8) {
                            Text("\(compactMoney(loan.originalPrincipal)) loan").font(.karla(12, .semibold)).foregroundStyle(primary)
                            Spacer()
                            Text("\(compactMoney(Int(loan.remainingPrincipal.rounded()))) left")
                                .font(.karla(12)).foregroundStyle(secondary)
                            // The pay-off action only appears once the player has
                            // the cash on hand to settle the whole balance — no
                            // partial payments, no unaffordable button.
                            if sim.canPayOffLoan(loan) {
                                Button {
                                    if sim.payOffLoan(loan.id) { Feedback.success() }
                                } label: {
                                    Text("PAY OFF").font(.karla(11, .bold)).foregroundStyle(.white)
                                        .padding(.horizontal, 9).frame(height: 24)
                                        .background(Sky.coreGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider().overlay(cardBorder.opacity(0.5))
                }
                Text("BORROW").font(.karla(11, .bold)).foregroundStyle(secondary)
                ForEach(LoanOffer.all) { loanOfferRow($0) }
                Text("Limit: \(compactMoney(sim.borrowingLimit)) total debt (a credit line + your fleet's resale value).")
                    .font(.karla(11)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func loanOfferRow(_ offer: LoanOffer) -> some View {
        let ok = sim.canBorrow(offer)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(offer.name) · \(compactMoney(offer.principal))").font(.karla(14, .bold)).foregroundStyle(primary)
                Text("\(Int((offer.apr * 100).rounded()))% APR · \(offer.termMonths) mo · \(compactMoney(offer.monthlyPayment))/mo")
                    .font(.karla(12)).foregroundStyle(secondary)
            }
            Spacer(minLength: 8)
            Button { if sim.takeLoan(offer) { Feedback.loanTaken() } } label: {
                Text("BORROW").font(.karla(12, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(ok ? Sky.coreGreen : Color(skyHex: 0xC9C9C9))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain).disabled(!ok)
        }
        .padding(.vertical, 3)
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
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
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
    var loanProceeds = 0, debtService = 0
    var hubSpend = 0, hubLabor = 0, clubRent = 0
    /// Buying a competitor airline outright (acquisitions). Distinct from
    /// `acquisition`, which is aircraft purchases.
    var airlineAcquisition = 0
    /// Merger integration bills + seniority settlement.
    var integrationSpend = 0
    /// Equity raised via IPO / secondary offerings.
    var equityRaised = 0
    /// Dividends paid to shareholders + share buybacks (cash returned to owners).
    var dividendsPaid = 0, buybackSpend = 0
    /// Player route marketing — fare wars / ad campaigns / loyalty pushes.
    var marketingSpend = 0
    var cashStart, cashEnd: Int
    var isTotal: Bool
    var operatingProfit: Int { revenue - fees - operatingCost }
    var overhead: Int { leaseCost + insurance + maintenance + debtService + hubLabor + clubRent + integrationSpend }
    var capitalOut: Int { acquisition + routeSpend + hedgeSpend + hubSpend + airlineAcquisition + dividendsPaid + buybackSpend + marketingSpend }
    var capitalIn: Int { saleProceeds + offerIncome + loanProceeds + equityRaised }
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
