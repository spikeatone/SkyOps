//
//  CompetitorIntelView.swift
//  Airline Architect — scouting the competition
//
//  Presented from the Finance tab, because evaluating a rival carrier is an
//  investment question, not an operations one.
//
//  DISCLOSURE PRINCIPLE (designer): show what a public filing would show —
//  topline performance open to scrutiny, the way a real airline's is. Fleet,
//  network size, revenue, margin, load factor, service reputation. NOT their
//  per-route P&L; that's owner's information the player hasn't earned.
//
//  Scouting is deliberately NOT gated on the $1B acquisition threshold: public
//  information is public, it makes the world richer for every player, and it
//  gives the endgame something visible to aim at.
//

import SwiftUI

struct CompetitorIntelView: View {
    var sim: Simulation
    var onClose: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var selected: CompetitorProfile?
    /// Two-tap confirm — an acquisition is permanent and expensive.
    @State private var confirming: String?
    @State private var flash: String?

    private var isDark: Bool { scheme == .dark }
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color    { isDark ? .white : Color(skyHex: 0x1F232D) }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    // Orange for the ESTIMATE badge — bright on dark, deeper on white so it pops
    // (a light orange washes out on the light background).
    private var orange: Color     { isDark ? Color(skyHex: 0xFFAB44) : Color(skyHex: 0xD97706) }

    private var carriers: [CompetitorProfile] { sim.relevantCompetitors }
    private var rivals: Set<String> { sim.rivalsOnMyRoutes }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                if let sel = selected {
                    ScrollView { detail(sel).padding(.bottom, 12) }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            intro
                            ForEach(carriers) { row($0) }
                        }
                        .padding(.bottom, 12)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            if let flash {
                VStack {
                    Text(flash).font(.karla(13, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Sky.coreGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.opacity)
                .task { try? await Task.sleep(for: .seconds(2.6)); self.flash = nil }
            }
        }
        .animation(Motion.glide, value: flash)
    }

    // MARK: Header

    private var header: some View {
        // Back-arrow navigation (like AIRCRAFT DETAIL): the leading chevron steps
        // carrier-profile → list → back out to Finance. No modal X.
        HStack(alignment: .center, spacing: 6) {
            Button { if selected != nil { selected = nil } else { onClose() } } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(titleColor)
            }.buttonStyle(.plain)
            Text(selected == nil ? "MARKET INTELLIGENCE" : "CARRIER PROFILE")
                .font(.karla(22, .bold)).foregroundStyle(titleColor)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(carriers.count) carriers operate in your markets. Figures are public topline disclosures — the same scrutiny your own airline would face.")
                .font(.karla(12)).foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !rivals.isEmpty {
                Text("\(rivals.count) currently contest one of your routes.")
                    .font(.karla(12, .semibold)).foregroundStyle(red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: List row

    private func row(_ p: CompetitorProfile) -> some View {
        Button { selected = p } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(p.name).font(.karla(15, .bold)).foregroundStyle(primary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    if !p.code.isEmpty {
                        Text(p.code).font(.karla(11, .bold)).foregroundStyle(secondary)
                    }
                    Spacer(minLength: 4)
                    if sim.isSubsidiary(p.id) { chip("YOURS", Sky.coreGreen) }
                    else if rivals.contains(p.name) { chip("CONTESTING YOU", red) }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondary.opacity(0.7))
                }
                HStack(spacing: 14) {
                    stat("Fleet", "\(p.fleetSize)")
                    stat("Routes", "\(p.routeCount)")
                    stat("Revenue", compactMoney(Int(p.annualRevenue)) + "/yr")
                    stat("Margin", marginLabel(p), p.operatingMargin < 0 ? red : Sky.coreGreen)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: Detail

    private func detail(_ p: CompetitorProfile) -> some View {
        VStack(spacing: 14) {
            // Identity
            box {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(p.name).font(.karla(20, .bold)).foregroundStyle(primary)
                            .lineLimit(2).minimumScaleFactor(0.7)
                        if !p.code.isEmpty {
                            Text(p.code).font(.karla(13, .bold)).foregroundStyle(secondary)
                        }
                    }
                    Text(p.region).font(.karla(12)).foregroundStyle(secondary)
                    HStack(spacing: 8) {
                        chip(p.trend.rawValue.uppercased(), trendColor(p.trend))
                        if sim.isSubsidiary(p.id) { chip("YOUR SUBSIDIARY", Sky.coreGreen) }
                        else if rivals.contains(p.name) { chip("CONTESTING YOU", red) }
                    }.padding(.top, 2)
                }
            }

            // Topline financials
            box {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TOPLINE PERFORMANCE").font(.karla(12, .bold)).foregroundStyle(titleColor)
                    line("Annual revenue", compactMoney(Int(p.annualRevenue)))
                    line("Operating margin", marginLabel(p),
                         p.operatingMargin < 0 ? red : Sky.coreGreen)
                    line("Operating profit", compactMoney(Int(p.annualOperatingProfit)),
                         p.annualOperatingProfit < 0 ? red : Sky.coreGreen)
                    line("Load factor", String(format: "%.0f%%", p.loadFactor * 100))
                    line("Service score", String(format: "%.0f / 100", p.serviceScore))
                }
            }

            // Fleet
            box {
                VStack(alignment: .leading, spacing: 10) {
                    Text("FLEET").font(.karla(12, .bold)).foregroundStyle(titleColor)
                    line("Aircraft", "\(p.fleetSize)")
                    line("Average age", p.averageFleetAgeLabel)
                    ForEach(p.fleetByType.sorted { $0.value > $1.value }, id: \.key) { id, n in
                        if let t = AircraftType.all.first(where: { $0.id == id }) {
                            HStack {
                                Text(t.name).font(.karla(12)).foregroundStyle(secondary)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Spacer()
                                Text("\(n)").font(.karla(12, .semibold)).foregroundStyle(primary)
                            }
                        }
                    }
                }
            }

            // Network
            box {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NETWORK").font(.karla(12, .bold)).foregroundStyle(titleColor)
                    line("Routes", "\(p.routeCount)")
                    line("Cities served", "\(p.citiesServed)")
                    line("Hubs", p.hubCodes.joined(separator: " · "))
                }
            }

            // Valuation — the bridge to acquisition (1.1)
            box {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ESTIMATED VALUE").font(.karla(12, .bold)).foregroundStyle(titleColor)
                    Text(compactMoney(Int(p.estimatedValue)))
                        .font(.karla(26, .heavy)).foregroundStyle(primary)
                    Text("Depreciated fleet value plus goodwill on operating profit. A carrier losing money is worth less than its metal.")
                        .font(.karla(11)).foregroundStyle(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            diligenceBox(p)
            acquisitionBox(p)
        }
    }

    // MARK: Due diligence (two stages)

    @ViewBuilder
    private func diligenceBox(_ p: CompetitorProfile) -> some View {
        let stage = sim.diligenceStage(p.id)
        let proj = sim.projection(for: p, stage: stage)
        let cost = sim.diligenceCost(for: p)
        box {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(stage >= 2 ? "DUE DILIGENCE — FULL BOOKS" : "DUE DILIGENCE — PRELIMINARY")
                        .font(.karla(12, .bold)).foregroundStyle(titleColor)
                    Spacer()
                    chip(stage >= 2 ? "VERIFIED" : "ESTIMATE", stage >= 2 ? Sky.coreGreen : orange)
                }
                Text(stage >= 2
                     ? "Their books are open. These are the actual airframes and the real renewal bill."
                     : "Public filings only — the same thin picture a buyer has before an NDA. Ranges are wide because the fleet's age SPREAD isn't disclosed.")
                    .font(.karla(11)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Headline risk: region fit — the systematic trap.
                if !proj.sameRegion {
                    Text("⚠︎ Outside your regions. Their hubs and routes don't connect to your network — no overlap to rationalise, no connecting traffic. These rarely pay back.")
                        .font(.karla(11, .semibold)).foregroundStyle(red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                line("Real cost of the deal", compactMoney(proj.economicCost))
                line("Fleet value (metal)", compactMoney(Int(p.fleetLiquidationValue)))
                line(stage >= 2 ? "Aircraft needing renewal" : "Aircraft likely needing renewal",
                     "\(proj.agedAircraft) of \(p.fleetSize)",
                     proj.agedAircraft > p.fleetSize / 3 ? red : primary)
                line("Renewal capital",
                     proj.renewalCostHigh == 0 ? "None near-term"
                     : "\(compactMoney(proj.renewalCostLow)) – \(compactMoney(proj.renewalCostHigh))")

                Divider().overlay(cardBorder).padding(.vertical, 2)
                Text("SCENARIOS").font(.karla(11, .bold)).foregroundStyle(titleColor)
                ForEach(proj.scenarios, id: \.label) { sc in
                    HStack {
                        Text(sc.label).font(.karla(12)).foregroundStyle(secondary)
                        Spacer()
                        Text(sc.paybackYears.map { String(format: "%.1f yrs to break even", $0) }
                             ?? "never breaks even")
                            .font(.karla(12, .semibold))
                            .foregroundStyle(sc.paybackYears == nil ? red
                                             : (sc.paybackYears! <= 10 ? Sky.coreGreen : primary))
                    }
                }
                Text(stage >= 2
                     ? "Projections remain estimates — how it actually goes depends on how you run it."
                     : "Best guesses from public numbers. Open their books for a firmer picture.")
                    .font(.karla(10)).foregroundStyle(secondary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                if stage < 2 {
                    Button {
                        if sim.openBooks(on: p) { Feedback.success() }
                    } label: {
                        Text(sim.playerBalance >= cost
                             ? "Open their books · \(compactMoney(cost))"
                             : "Need \(compactMoney(cost)) to open their books")
                            .font(.karla(13, .bold))
                            .foregroundStyle(sim.playerBalance >= cost ? .white : titleColor)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(sim.playerBalance >= cost ? Sky.brightBlue : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(sim.playerBalance >= cost ? .clear : cardBorder, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(sim.playerBalance < cost)
                }
            }
        }
    }

    // MARK: Acquisition

    @ViewBuilder
    private func acquisitionBox(_ p: CompetitorProfile) -> some View {
        let block = sim.acquisitionBlock(for: p)
        let price = sim.askingPrice(for: p)
        box {
            VStack(alignment: .leading, spacing: 10) {
                Text("ACQUISITION").font(.karla(12, .bold)).foregroundStyle(titleColor)

                if sim.isSubsidiary(p.id) {
                    Text("Part of your group. \(p.name) continues to fly under its own flag.")
                        .font(.karla(12)).foregroundStyle(Sky.coreGreen)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    line("Asking price", compactMoney(price),
                         block == nil ? Sky.coreGreen : primary)
                    Text("Includes a control premium over estimated value. You would inherit their fleet, network, and hubs — and they keep flying under their own flag.")
                        .font(.karla(11)).foregroundStyle(secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let block {
                        Text(blockMessage(block)).font(.karla(11, .semibold))
                            .foregroundStyle(red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if confirming == p.id {
                        Text("This is permanent. \(compactMoney(price)) leaves your balance now.")
                            .font(.karla(11, .semibold)).foregroundStyle(red)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Button {
                                if sim.acquire(p) {
                                    Feedback.milestone()
                                    flash = "\(p.name) is yours."
                                    selected = sim.relevantCompetitors.first { $0.id == p.id } ?? p
                                }
                                confirming = nil
                            } label: {
                                Text("Confirm acquisition").font(.karla(13, .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).frame(height: 40)
                                    .background(Sky.coreGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }.buttonStyle(.plain)
                            Button { confirming = nil } label: {
                                Text("Cancel").font(.karla(13, .semibold))
                                    .foregroundStyle(secondary)
                                    .frame(maxWidth: .infinity).frame(height: 40)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    } else {
                        Button { confirming = p.id } label: {
                            Text("Make an offer").font(.karla(13, .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(Sky.coreGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Player-facing copy for a block reason. Lives here, not in the Sim layer,
    /// which stays framework-free for the headless harness.
    private func blockMessage(_ b: AcquisitionBlock) -> String {
        switch b {
        case .belowNetWorthGate(let needed):
            return "Acquisitions unlock at $1B net worth — \(compactMoney(needed)) to go."
        case .alreadyOwned:          return "Already part of your group."
        case .integrationInProgress(let name):
            return "You're still integrating \(name). One at a time."
        case .lifetimeCapReached(let cap):
            return "You've acquired \(cap) carriers — no regulator will approve another."
        case .cannotAfford(let needed):
            return "You need \(compactMoney(needed)) more in cash."
        case .notInYourMarkets:      return "You don't operate in this carrier's markets."
        }
    }

    // MARK: Bits

    private func box<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private func line(_ label: String, _ value: String, _ tint: Color? = nil) -> some View {
        HStack {
            Text(label).font(.karla(13)).foregroundStyle(secondary)
            Spacer()
            Text(value).font(.karla(14, .semibold)).foregroundStyle(tint ?? primary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func stat(_ label: String, _ value: String, _ tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.karla(10)).foregroundStyle(secondary.opacity(0.9))
            Text(value).font(.karla(12, .semibold)).foregroundStyle(tint ?? primary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func chip(_ text: String, _ tint: Color) -> some View {
        Text(text).font(.karla(9, .bold)).foregroundStyle(tint)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(tint.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func marginLabel(_ p: CompetitorProfile) -> String {
        String(format: "%@%.1f%%", p.operatingMargin < 0 ? "−" : "+", abs(p.operatingMargin) * 100)
    }

    private func trendColor(_ t: CompetitorProfile.Trend) -> Color {
        switch t {
        case .growing:   return Sky.coreGreen
        case .stable:    return secondary
        case .shrinking: return red
        }
    }
}
