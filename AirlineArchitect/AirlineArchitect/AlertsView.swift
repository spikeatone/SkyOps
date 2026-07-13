//
//  AlertsView.swift
//  Airline Architect — Alerts modal + badged bell
//
//  The bell in each tab's header shows a count badge of pending alerts and
//  opens the Alerts modal (Figma 5:4488 light / 5:4552 dark). Alerts are the
//  events that need the player's attention — the sim's decisionQueue (AOG,
//  crew, end-of-life sell). Each alert is an accent-bordered "Needs Attention"
//  sub-card with the same actions as the map's decision cards, wired to the
//  same resolvers so acting here or there is identical.
//

import SwiftUI

// MARK: - Badged bell (header)

struct AlertBell: View {
    let count: Int
    /// The bell tint (matches each header's title colour).
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell")
                .font(.system(size: 18)).foregroundStyle(tint)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 9 ? "9+" : "\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, count > 9 ? 3 : 0)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(Circle().fill(Color(skyHex: 0xEF4444)))
                            .offset(x: 7, y: -7)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Alerts modal

struct AlertsModal: View {
    let sim: Simulation
    let onClose: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    // Tokens (Figma 5:4488 / 5:4552).
    private var modalBG: Color     { isDark ? Sky.navBarDark : .white }
    private var modalBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var subCardBG: Color    { isDark ? Sky.darkBG : Color(skyHex: 0xF9F9F9) }
    private var primary: Color      { isDark ? .white : .black }
    private var subtitle: Color     { isDark ? Sky.lightBlue.opacity(0.7) : Color(skyHex: 0x64748B) }
    private var btnBorder: Color    { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var btnText: Color      { isDark ? .white : Color(skyHex: 0x4B4B4B) }
    private var accentRed: Color    { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    private let accentBlue = Color(skyHex: 0x5B98CE)
    private let accentAmber = Color(skyHex: 0xFFB700)

    var body: some View {
        let _ = sim.tick   // keep erosion rate / affordability live
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Alerts • \(sim.decisionQueue.count)")
                    .font(.karla(20, .heavy)).foregroundStyle(primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(subtitle)
                }.buttonStyle(.plain)
            }
            if sim.decisionQueue.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle").font(.system(size: 32))
                        .foregroundStyle(Sky.coreGreen.opacity(0.8))
                    Text("You're all caught up").font(.karla(15, .semibold)).foregroundStyle(subtitle)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ForEach(sim.decisionQueue) { NeedsAttentionCard(sim: sim, decision: $0) }
            }
        }
        .padding(16)
        .background(modalBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(modalBorder, lineWidth: 1))
    }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}

// MARK: - Shared "Needs Attention" sub-card (used by the Alerts modal AND Ops)

/// One accent-bordered decision sub-card (AOG red / crew red / end-of-service
/// amber), wired to the same resolvers the map cards used. Reused verbatim by
/// the Alerts modal and the Ops tab's Needs Attention group.
struct NeedsAttentionCard: View {
    let sim: Simulation
    let decision: Simulation.Decision
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    private var subCardBG: Color { isDark ? Sky.darkBG : Color(skyHex: 0xF9F9F9) }
    private var primary: Color   { isDark ? .white : .black }
    private var subtitle: Color  { isDark ? Sky.lightBlue.opacity(0.7) : Color(skyHex: 0x64748B) }
    private var btnBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var btnText: Color   { isDark ? .white : Color(skyHex: 0x4B4B4B) }
    private var accentRed: Color { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    private let accentAmber = Color(skyHex: 0xFFB700)

    var body: some View {
        let _ = sim.tick   // keep erosion rate / affordability live
        let m = model(for: decision)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: m.icon).font(.system(size: 18)).foregroundStyle(m.accent)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.category).font(.karla(16, .semibold)).foregroundStyle(m.accent)
                    Text(m.title).font(.karla(16, .semibold)).foregroundStyle(primary)
                    Text(m.subtitle).font(.karla(14)).foregroundStyle(subtitle)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                ForEach(Array(m.buttons.enumerated()), id: \.offset) { _, b in
                    Button(action: b.action) {
                        Text(b.label)
                            .font(.karla(15, .medium)).foregroundStyle(btnText)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(height: 32).padding(.horizontal, 8)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(btnBorder, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subCardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(m.accent, lineWidth: 1))
    }

    private struct AlertModel {
        let accent: Color, icon: String, category: String, title: String, subtitle: String
        let buttons: [(label: String, action: () -> Void)]
    }

    private func model(for d: Simulation.Decision) -> AlertModel {
        let ac = d.aircraft
        switch d.kind {
        case .aog:
            let rate = Int((Double(ac.type.holdCostPerTick) * sim.effectiveCostMultiplier).rounded())
            return AlertModel(
                accent: accentRed, icon: "exclamationmark.triangle.fill", category: "AOG",
                title: "\(ac.tail) grounded at \(ac.origin.code)",
                subtitle: "Eroding \(money(rate))/min",
                buttons: [
                    ("Expedite $15,000", { sim.resolveAOGExpedite(d) }),
                    ("Std Repair", { sim.resolveAOGStandard(d) }),
                ])
        case .crew:
            var btns: [(String, () -> Void)] = []
            if sim.hasReserve(for: ac) { btns.append(("Reserve $5k", { sim.resolveCrewReserve(d) })) }
            if sim.canAffordCrewHire(for: ac) {
                btns.append(("Hire \(compactMoney(sim.crewHireCost(family: ac.type.family)))", { sim.resolveCrewHire(d) }))
            }
            btns.append(("Wait", { sim.resolveCrewWait(d) }))
            return AlertModel(
                accent: accentRed, icon: "person.crop.circle.badge.exclamationmark", category: "Crew",
                title: "\(ac.tail) — no legal crew at \(ac.origin.code)",
                subtitle: "Awaiting a rested crew",
                buttons: btns.map { (label: $0.0, action: $0.1) })
        case .sell:
            let pct = 100 * ac.cyclesAccrued / max(1, ac.type.expectedLifespanCycles)
            let value = sim.sellValue(of: ac)
            return AlertModel(
                accent: accentAmber, icon: "clock.arrow.circlepath", category: "End of service",
                title: "\(ac.tail) nearing retirement",
                subtitle: "\(pct)% of lifespan · sell value \(money(value))",
                buttons: [
                    ("Sell \(compactMoney(value))", { sim.resolveSell(d) }),
                    ("Keep flying", { sim.resolveSellKeep(d) }),
                ])
        }
    }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}
