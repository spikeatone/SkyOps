//
//  FleetView.swift
//  Airline Architect — the FLEET tab
//
//  Built to the Figma (Airline-Architect-Production, fleet home 1:725 light /
//  1:1057 dark). A My Fleet / Marketplace segmented screen: a 4-box status bar
//  (Total / Flying / Idle / Grounded) and a scrollable list of fleet cards
//  (tail, type, live status chip, current route, ownership chip, airframe-life
//  bar). Theme-aware via the Sky tokens + light-mode Figma colours. Marketplace
//  and the per-aircraft detail screen land in follow-up passes.
//

import SwiftUI

struct FleetView: View {
    let sim: Simulation
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    @State private var segment: Segment = .myFleet
    enum Segment: Hashable { case myFleet, marketplace }

    // MARK: Theme tokens (light Figma / dark Sky)
    private var bg: Color        { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color    { isDark ? .white : .black }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var segBG: Color      { isDark ? Sky.navBarDark : Color(skyHex: 0xE6E6E6) }
    private var segActiveBG: Color { isDark ? Color(skyHex: 0x3A4150) : .white }
    private var track: Color      { isDark ? Color.white.opacity(0.12) : Color(skyHex: 0xE6E6E6) }
    private let fill = Sky.brightBlue
    private let yellow = Color(skyHex: 0xFFB700)
    private let red = Color(skyHex: 0xD70000)

    var body: some View {
        // Reading `tick` subscribes this view to per-tick updates (Observation),
        // so live statuses/counts refresh as aircraft fly. The owned fleet is
        // small, so a per-tick body re-eval is cheap (unlike the 250-acircraft
        // Canvas).
        let _ = sim.tick
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                segmentedControl
                if segment == .myFleet {
                    statusBar
                    fleetList
                } else {
                    marketplacePlaceholder
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    // MARK: Header (cash + FLEET HOME + bell)
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(cashString).font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                Spacer()
            }
            Divider().overlay(cardBorder)
            HStack {
                Text("FLEET HOME").font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                Image(systemName: "bell")
                    .font(.system(size: 18)).foregroundStyle(titleColor)
                    .overlay(alignment: .topTrailing) {
                        if !sim.decisionQueue.isEmpty {
                            Circle().fill(Sky.red).frame(width: 8, height: 8).offset(x: 3, y: -2)
                        }
                    }
            }
        }
    }

    private var cashString: String {
        let v = sim.playerBalance, a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }

    // MARK: Segmented control (My Fleet / Marketplace)
    private var segmentedControl: some View {
        HStack(spacing: 4) {
            segButton("My Fleet", .myFleet)
            segButton("Marketplace", .marketplace)
        }
        .padding(4)
        .background(segBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func segButton(_ title: String, _ seg: Segment) -> some View {
        let active = segment == seg
        return Button { segment = seg } label: {
            Text(title)
                .font(.karla(14, .semibold))
                .foregroundStyle(active ? (isDark ? .white : secondary) : secondary)
                .frame(maxWidth: .infinity).frame(height: 28)
                .background(active ? segActiveBG : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }.buttonStyle(.plain)
    }

    // MARK: Status bar (Total / Flying / Idle / Grounded)
    private var statusBar: some View {
        let owned = sim.aircraft.filter { $0.purchased }
        let flying = owned.filter { status($0) == .flying }.count
        let idle = owned.filter { status($0) == .idle }.count
        let grounded = owned.filter { status($0) == .grounded }.count
        return HStack(spacing: 4) {
            statusBox("Total", owned.count, primary)
            statusBox("Flying", flying, Sky.coreGreen)
            statusBox("Idle", idle, yellow)
            statusBox("Grounded", grounded, red)
        }
        .padding(4)
        .background(segBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusBox(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.karla(14)).foregroundStyle(secondary)
            Text("\(value)").font(.karla(20, .heavy)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Fleet list
    private var fleetList: some View {
        let owned = sim.aircraft.filter { $0.purchased }
            .sorted { $0.tail < $1.tail }
        return Group {
            if owned.isEmpty {
                VStack(spacing: 8) {
                    Text("No aircraft yet").font(.karla(16, .bold)).foregroundStyle(primary)
                    Text("Acquire aircraft from the Network tab or the Marketplace.")
                        .font(.karla(14)).foregroundStyle(secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(owned) { fleetCard($0) }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func fleetCard(_ ac: Aircraft) -> some View {
        let pct = 100 * ac.cyclesAccrued / max(1, ac.type.expectedLifespanCycles)
        let st = status(ac)
        return VStack(alignment: .leading, spacing: 12) {
            // Tail + type + status chip
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ac.tail).font(.karla(20, .heavy)).foregroundStyle(primary)
                    Text(ac.type.name).font(.karla(14)).foregroundStyle(secondary)
                }
                Spacer()
                statusChip(st)
            }
            // Route + ownership chip
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(secondary)
                if ac.isIdleSpare {
                    Text("No route").font(.karla(16, .heavy)).foregroundStyle(secondary)
                } else {
                    HStack(spacing: 8) {
                        Text(ac.origin.code).font(.karla(16, .heavy)).foregroundStyle(primary)
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Sky.coreGreen)
                        Text(ac.dest.code).font(.karla(16, .heavy)).foregroundStyle(primary)
                    }
                }
                Rectangle().fill(track).frame(height: 1)
                ownershipChip(ac.isLeased)
            }
            // Airframe life
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Airframe Life").font(.karla(14)).foregroundStyle(secondary)
                    Spacer()
                    Text("\(ac.cyclesAccrued.formatted()) cycles / \(pct)%")
                        .font(.karla(14, .bold)).foregroundStyle(secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(track)
                        RoundedRectangle(cornerRadius: 4).fill(fill)
                            .frame(width: geo.size.width * CGFloat(min(100, pct)) / 100)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Status model
    enum FleetStatus { case flying, idle, grounded }
    private func status(_ ac: Aircraft) -> FleetStatus {
        if ac.holdReason == .aog { return .grounded }
        if ac.isIdleSpare { return .idle }
        return .flying
    }

    private func statusChip(_ st: FleetStatus) -> some View {
        let (text, color): (String, Color) = {
            switch st {
            case .flying:   return ("FLYING", Sky.coreGreen)
            case .idle:     return ("IDLE", yellow)
            case .grounded: return ("GROUNDED", red)
            }
        }()
        return Text(text)
            .font(.karla(10, .bold))
            .foregroundStyle(color)
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
                    .background(Color(skyHex: 0x4B4B4B))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xC9C9C9), lineWidth: 1))
            } else {
                Text("OWNED").font(.karla(10, .bold)).foregroundStyle(Color(skyHex: 0x4E67A0))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(isDark ? Color(skyHex: 0x497AA5).opacity(0.35) : Color(skyHex: 0xBDE0FF))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0x497AA5), lineWidth: 1))
            }
        }
    }

    // MARK: Marketplace (built in a follow-up pass)
    private var marketplacePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart").font(.system(size: 40)).foregroundStyle(titleColor.opacity(0.6))
            Text("Marketplace").font(.karla(18, .bold)).foregroundStyle(primary)
            Text("Coming next").font(.karla(14)).foregroundStyle(secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}
