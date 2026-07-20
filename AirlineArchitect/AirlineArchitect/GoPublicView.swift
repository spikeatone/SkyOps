//
//  GoPublicView.swift
//  Airline Architect — the IPO flow
//
//  Pick a ticker, choose how much of the company to sell, and see — before
//  committing — exactly how much cash it raises and how exposed the dilution
//  leaves you. Per the designer: no hard float cap, but the risk of diluting
//  your own stake has to be visceral, because (step 4) the board-ouster trigger
//  accelerates the more you sell.
//

import SwiftUI

struct GoPublicView: View {
    let sim: Simulation
    var onClose: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var ticker = ""
    @State private var floatPct: Double = 25   // percent

    private var isDark: Bool { scheme == .dark }
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color    { isDark ? .white : Color(skyHex: 0x1F232D) }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }

    private var cleanTicker: String { Simulation.sanitizeTicker(ticker) }
    private var fraction: Double { floatPct / 100 }
    private var proceeds: Int { sim.ipoProceeds(floatFraction: fraction) }
    private var stake: Double { 1 - fraction }
    private var risk: Simulation.ControlRisk { Simulation.controlRisk(stake: stake) }
    private var canList: Bool { !cleanTicker.isEmpty && sim.canGoPublic }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text("GO PUBLIC").font(.karla(22, .bold)).foregroundStyle(titleColor)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24))
                            .foregroundStyle(secondary.opacity(0.7))
                    }.buttonStyle(.plain)
                }
                ScrollView {
                    VStack(spacing: 14) {
                        intro
                        tickerCard
                        floatCard
                        summaryCard
                        listButton
                    }.padding(.bottom, 16)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, 6)
        }
    }

    private var intro: some View {
        Text("List the airline on the public market. You'll raise cash with no repayment — but you sell a permanent slice of the company and answer to shareholders from now on.")
            .font(.karla(12)).foregroundStyle(secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14).background(cardBG).clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private var tickerCard: some View {
        box {
            Text("TICKER SYMBOL").font(.karla(12, .bold)).foregroundStyle(titleColor)
            Text("Your airline's badge on the market — up to 4 letters.")
                .font(.karla(11)).foregroundStyle(secondary)
            TextField("e.g. ASTR", text: $ticker)
                .font(.karla(22, .bold)).foregroundStyle(primary)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .onChange(of: ticker) { _, v in ticker = Simulation.sanitizeTicker(v) }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(bg).clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }
    }

    private var floatCard: some View {
        box {
            HStack {
                Text("HOW MUCH TO SELL").font(.karla(12, .bold)).foregroundStyle(titleColor)
                Spacer()
                Text("\(Int(floatPct))%").font(.karla(16, .bold)).foregroundStyle(primary)
            }
            Slider(value: $floatPct, in: 5...90, step: 1).tint(Sky.brightBlue)
            HStack {
                Text("You keep \(Int(stake*100))%").font(.karla(12, .semibold)).foregroundStyle(primary)
                Spacer()
                Text(risk.rawValue).font(.karla(12, .semibold))
                    .foregroundStyle(stake >= 0.5 ? Sky.coreGreen : red)
            }
            // The visceral part: dilution risk, spelled out.
            Text(riskExplanation)
                .font(.karla(11)).foregroundStyle(stake >= 0.5 ? secondary : red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var riskExplanation: String {
        switch risk {
        case .controlling:
            return "You retain majority control. The board can grumble, but it can't remove you."
        case .exposed:
            return "⚠︎ You've dropped below 50%. If the airline underperforms, the board can move against you."
        case .vulnerable:
            return "⚠︎ You're a minority owner. Poor performance could see the board force you out fast."
        case .powerless:
            return "⚠︎ You'd barely own your own airline. One bad stretch and the board removes you."
        }
    }

    private var summaryCard: some View {
        box {
            Text("THE DEAL").font(.karla(12, .bold)).foregroundStyle(titleColor)
            line("Market valuation", compactMoney(Int(sim.marketCap)))
            line("You raise", compactMoney(proceeds), Sky.coreGreen)
            line("Cash after listing", compactMoney(sim.playerBalance + proceeds))
            line("Ticker", cleanTicker.isEmpty ? "—" : cleanTicker)
        }
    }

    private var listButton: some View {
        Button {
            if sim.goPublic(ticker: cleanTicker, floatFraction: fraction) {
                Feedback.milestone(); onClose()
            }
        } label: {
            Text(canList ? "List \(cleanTicker) · raise \(compactMoney(proceeds))" : "Enter a ticker to list")
                .font(.karla(15, .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(canList ? Sky.coreGreen : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }.buttonStyle(.plain).disabled(!canList)
    }

    private func box<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(cardBG).clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private func line(_ label: String, _ value: String, _ tint: Color? = nil) -> some View {
        HStack {
            Text(label).font(.karla(13)).foregroundStyle(secondary)
            Spacer()
            Text(value).font(.karla(14, .semibold)).foregroundStyle(tint ?? primary)
        }
    }
}
