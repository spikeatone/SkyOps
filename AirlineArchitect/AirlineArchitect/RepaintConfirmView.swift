//
//  RepaintConfirmView.swift
//  Airline Architect — the ITEMIZED quote a player sees before repainting the
//  whole fleet into a new livery.
//
//  Why itemized and not a single total (designer): a six-figure bill needs to
//  show WHERE it goes. One line per aircraft type — count × per-airframe cost —
//  so the player can see that the widebodies are what's expensive, and that a
//  bigger fleet is a bigger commitment.
//
//  The DOWNTIME is given equal billing with the money, because in reality it IS
//  the larger cost: a jet in the paint shop earns nothing while it's there. So
//  each line carries its LOST REVENUE alongside the paint bill, and the two are
//  summed into a TRUE COST at the bottom.
//
//  Lost revenue is an estimate, not a charge — it's income that never arrives,
//  so it is deliberately NOT a cash-invariant term and the confirm button bills
//  only the paint cost. Idle spares contribute nothing (grounding a jet that
//  wasn't flying costs no revenue), which is why the figure tracks the fleet the
//  player is actually working.
//
//  Aircraft go through the shop `repaintShopSlots` at a time, so the program
//  spans MONTHS on a big fleet rather than the length of one paint job.
//

import SwiftUI

struct RepaintConfirmView: View {
    let sim: Simulation
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var bodyColor: Color  { isDark ? .white : Color(skyHex: 0x1C2028) }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var red: Color        { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    /// Forgone revenue is a real cost but NOT a charge, so it reads amber (a
    /// warning) rather than red (unaffordable).
    private var amber: Color      { isDark ? Color(skyHex: 0xFFAB44) : Color(skyHex: 0xB45309) }

    private var quote: [Simulation.RepaintLine] { sim.repaintQuote }
    private var total: Int { sim.repaintTotal }
    private var affordable: Bool { sim.canAffordRepaint }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                Text("REPAINT FLEET")
                    .font(.karla(20, .bold)).foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                Text("Every aircraft goes into the paint shop. They earn nothing until they come out.")
                    .font(.karla(13)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 14)

                // ITEMIZED — one line per type.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(quote) { line in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.typeName)
                                        .font(.karla(14, .semibold)).foregroundStyle(bodyColor)
                                    Text("\(line.count) × \(money(line.eachCost)) · \(line.days)d each")
                                        .font(.karla(12)).foregroundStyle(secondary)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(money(line.lineCost))
                                        .font(.karla(14, .semibold)).foregroundStyle(bodyColor)
                                    if line.lineLostRevenue > 0 {
                                        Text("− " + money(line.lineLostRevenue) + " rev")
                                            .font(.karla(11)).foregroundStyle(amber)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            if line.id != quote.last?.id {
                                Divider().overlay(cardBorder)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)

                Divider().overlay(cardBorder).padding(.vertical, 10)

                HStack {
                    Text("Paint cost").font(.karla(14)).foregroundStyle(secondary)
                    Spacer()
                    Text(money(total))
                        .font(.karla(15, .semibold))
                        .foregroundStyle(affordable ? bodyColor : red)
                }
                if sim.repaintLostRevenueTotal > 0 {
                    HStack {
                        Text("Lost revenue (grounded)").font(.karla(14)).foregroundStyle(secondary)
                        Spacer()
                        Text(money(sim.repaintLostRevenueTotal))
                            .font(.karla(15, .semibold)).foregroundStyle(amber)
                    }
                    .padding(.top, 2)
                    Divider().overlay(cardBorder).padding(.vertical, 8)
                    HStack {
                        Text("True cost").font(.karla(15, .bold)).foregroundStyle(bodyColor)
                        Spacer()
                        Text(money(sim.repaintTrueCost))
                            .font(.karla(17, .bold)).foregroundStyle(bodyColor)
                    }
                }
                HStack {
                    Text("Program length").font(.karla(13)).foregroundStyle(secondary)
                    Spacer()
                    Text("~\(sim.repaintProgramDays) days")
                        .font(.karla(13, .semibold)).foregroundStyle(secondary)
                }
                .padding(.top, 2)
                Text("Aircraft go through \(Simulation.repaintShopSlots) at a time — the rest keep flying until their slot comes up.")
                    .font(.karla(11)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                if !affordable {
                    Text("Not enough cash — you have \(cashLabel(sim.playerBalance)).")
                        .font(.karla(12, .semibold)).foregroundStyle(red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.karla(15, .semibold)).foregroundStyle(titleColor)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
                    }
                    Button(action: onConfirm) {
                        Text("Repaint · \(money(total))")
                            .font(.karla(15, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(affordable ? Sky.brightBlue : Color.gray.opacity(0.4)))
                    }
                    .disabled(!affordable)
                }
                .padding(.top, 16)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16).fill(cardBG))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
            .padding(.horizontal, 22)
        }
    }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}
