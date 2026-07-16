//
//  FleetView.swift
//  Airline Architect — the FLEET tab
//
//  Built to the Figma (Airline-Architect-Production, fleet home 1:725 light /
//  1:1057 dark, marketplace 5:6501 / 5:6941). A My Fleet / Marketplace
//  segmented screen. My Fleet: a 4-box status bar (Total / Flying / Idle /
//  Grounded) and a scrollable list of fleet cards (tail, type, live status
//  chip, current route, ownership chip, airframe-life bar); tapping a card
//  opens FleetDetailView. Marketplace: buy-new / lease-new / buy-used profile
//  cards per type (reuses the sim's real purchase functions). Theme-aware via
//  the Sky tokens + light-mode Figma colours.
//

import SwiftUI

struct FleetView: View {
    let sim: Simulation
    @Binding var tab: Int
    var store: Store
    var onBell: () -> Void = {}
    var onSave: () -> Void = {}
    var onQuit: () -> Void = {}
    var onUpgrade: (String?) -> Void = { _ in }

    /// Free-tier gate for Marketplace acquires — paywall at the fleet cap.
    private func gatedAcquire(_ perform: () -> Void) {
        if store.canAcquireAircraft(sim) { perform() } else { onUpgrade(store.capMessage(.fleet)) }
    }
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var segment: Segment = .myFleet
    @State private var detailID: UUID?
    /// Fleet-list status filter, driven by tapping a status box (nil = all).
    @State private var fleetFilter: FleetStatus?
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
    // Red reads too dark on the dark theme — use the On-Dark red there.
    private var red: Color { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }

    // Status-bar palette (Figma 1:1060 dark / 1:955 light). Its BOXES sit at the
    // page-bg shade (#2B303D) inside a DARKER container (#1F232D) in dark, and
    // white inside #E6E6E6 in light — a deliberate subtle contrast. Values use
    // the On-Dark variants in dark; white labels in dark.
    private var statusBoxBG: Color   { isDark ? Sky.darkBG : .white }
    private var statusLabel: Color   { isDark ? .white : Color(skyHex: 0x64748B) }
    private var totalColor: Color    { isDark ? Sky.lightBlue : .black }
    private var flyingColor: Color   { isDark ? Color(skyHex: 0x87ED7A) : Color(skyHex: 0x10B981) }
    private var groundedColor: Color { isDark ? Color(skyHex: 0xFF9292) : red }

    var body: some View {
        // Reading `tick` subscribes this view to per-tick updates (Observation),
        // so live statuses/counts refresh as aircraft fly. The owned fleet is
        // small, so a per-tick body re-eval is cheap (unlike the 250-acircraft
        // Canvas).
        let _ = sim.tick
        let owned = sim.aircraft.filter { $0.purchased }.sorted { $0.tail < $1.tail }
        ZStack {
            bg.ignoresSafeArea()
            GeometryReader { geo in
                // iPad landscape + My Fleet → list on the left, live detail on the
                // right. Portrait / iPhone / Marketplace keep the tap-to-push flow.
                let split = PadLayout.isPad(hSize) && geo.size.width > geo.size.height
                    && segment == .myFleet && !owned.isEmpty
                Group {
                    if split {
                        fleetSplitLayout(owned: owned)
                    } else if segment == .myFleet, let id = detailID,
                              let ac = sim.aircraft.first(where: { $0.id == id }) {
                        // Portrait / iPhone: the detail pushes in from the trailing
                        // edge while the list slides off — an eased slide, iOS-push
                        // style. Keyed on detailID only, so rotation stays instant.
                        FleetDetailView(sim: sim, aircraft: ac,
                                        onBack: { detailID = nil },
                                        onAssignRoute: { detailID = nil; tab = 0 },
                                        onSold: { detailID = nil },
                                        onBell: onBell)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        stackedLayout
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: detailID)
            }
        }
    }

    /// Portrait / iPhone / Marketplace: the single-column stack.
    private var stackedLayout: some View {
        VStack(spacing: 16) {
            header
            segmentedControl
            if segment == .myFleet {
                statusBar
                fleetList(selectedID: nil)
            } else {
                marketplacePlaceholder
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    /// iPad landscape My Fleet: the list on the left, the selected aircraft's
    /// detail on the right (defaulting to the first aircraft until one is tapped).
    private func fleetSplitLayout(owned: [Aircraft]) -> some View {
        let detailAC = owned.first { $0.id == detailID } ?? owned.first
        return VStack(spacing: 16) {
            header
            segmentedControl
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    statusBar
                    fleetList(selectedID: detailAC?.id)
                }
                .frame(maxWidth: .infinity)   // 50/50 split with the detail pane
                Group {
                    if let ac = detailAC {
                        FleetDetailView(sim: sim, aircraft: ac,
                                        onBack: {},
                                        onAssignRoute: { tab = 0 },
                                        onSold: { detailID = nil },
                                        onBell: onBell,
                                        embedded: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: Header (cash + FLEET HOME + bell)
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(cashString).font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                Spacer(minLength: 8)
                SaveQuitBar(onSave: onSave, onQuit: onQuit)
            }
            Divider().overlay(cardBorder)
            HStack {
                Text(segment == .myFleet ? "FLEET HOME" : "MARKETPLACE")
                    .font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    private var cashString: String { cashLabel(sim.playerBalance) }

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
            statusBox("Total", owned.count, totalColor, filter: nil)
            statusBox("Flying", flying, flyingColor, filter: .flying)
            statusBox("Idle", idle, yellow, filter: .idle)
            statusBox("Grounded", grounded, groundedColor, filter: .grounded)
        }
        .padding(4)
        .background(segBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Tapping a box filters the fleet list to that state (tap again, or tap
    /// Total, to clear). The active filter shows a ring in the box's own colour.
    private func statusBox(_ label: String, _ value: Int, _ color: Color, filter: FleetStatus?) -> some View {
        let selected = fleetFilter != nil && fleetFilter == filter
        return VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.karla(14)).foregroundStyle(statusLabel)
            Text("\(value)").font(.karla(20, .heavy)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(statusBoxBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? color : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Motion.glide) { fleetFilter = (fleetFilter == filter) ? nil : filter }
        }
    }

    // MARK: Fleet list
    private func fleetList(selectedID: UUID?) -> some View {
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
                let shown = fleetFilter == nil ? owned : owned.filter { status($0) == fleetFilter }
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if shown.isEmpty, let f = fleetFilter {
                            Text("No aircraft currently \(filterLabel(f)).")
                                .font(.karla(14)).foregroundStyle(secondary)
                                .frame(maxWidth: .infinity).padding(.top, 24)
                        }
                        ForEach(shown) { fleetCard($0, selected: $0.id == selectedID) }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func filterLabel(_ f: FleetStatus) -> String {
        switch f {
        case .flying:   return "flying"
        case .idle:     return "idle"
        case .grounded: return "grounded"
        }
    }

    private func fleetCard(_ ac: Aircraft, selected: Bool = false) -> some View {
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
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(selected ? fill : cardBorder, lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { detailID = ac.id }
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
                // Figma (1:1063): solid Light Blue #BDE0FF bg, Core Blue #497AA5
                // border, Dark Blue #4E67A0 text — the SAME in both themes.
                Text("OWNED").font(.karla(10, .bold)).foregroundStyle(Color(skyHex: 0x4E67A0))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(skyHex: 0xBDE0FF))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0x497AA5), lineWidth: 1))
            }
        }
    }

    // MARK: Marketplace — buy new / lease new / buy used per type (Figma 5:6501).
    // Reuses the sim's real purchase functions; live affordability from balance.
    private var marketplacePlaceholder: some View {
        let types = AircraftType.all.sorted { $0.purchasePrice < $1.purchasePrice }
        return ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(types) { marketplaceCard($0) }
            }
            .padding(.bottom, 8)
        }
    }

    private func marketplaceCard(_ type: AircraftType) -> some View {
        let used = sim.usedInventory[type.id] ?? []
        return VStack(alignment: .leading, spacing: 12) {
            Text(type.name).font(.karla(20, .heavy)).foregroundStyle(primary)
            if let img = AircraftArt.image(for: type.id) {
                img.resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: PadLayout.isPad(hSize) ? 340 : nil)
            }
            // Spec row
            HStack(alignment: .top) {
                spec("Seats:", "\(type.seats)")
                Spacer()
                spec("Practical Range:", "\(type.rangeNM.formatted()) NM")
                Spacer()
                spec("Avg Lifespan:", "\(type.expectedLifespanCycles.formatted()) cycles")
            }
            Rectangle().fill(cardBorder).frame(height: 1)
            // Buy new
            offerRow("Buy new:", money(type.purchasePrice),
                     kind: .buy, cost: type.purchasePrice) {
                gatedAcquire { if sim.buyAircraft(type) != nil { Feedback.aircraftAcquired(isFirst: sim.ownedCount == 1) } }
            }
            // Lease new
            offerRow("Lease new:",
                     "\(money(sim.leaseUpfront(type))) upfront + \(money(type.monthlyLeaseCost)) / mo",
                     kind: .lease, cost: sim.leaseUpfront(type)) {
                gatedAcquire { if sim.leaseAircraft(type) != nil { Feedback.aircraftAcquired(isFirst: sim.ownedCount == 1) } }
            }
            // Buy used (one row per listing, cheapest first)
            ForEach(used.sorted { $0.price < $1.price }) { listing in
                let pct = 100 * listing.cyclesAccrued / max(1, type.expectedLifespanCycles)
                offerRow("Buy used:",
                         "\(money(listing.price)) · \(listing.cyclesAccrued.formatted()) cycles (~\(pct)%)",
                         kind: .buy, cost: listing.price) {
                    gatedAcquire { if sim.buyUsedAircraft(listing) != nil { Feedback.aircraftAcquired(isFirst: sim.ownedCount == 1) } }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    private func spec(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.karla(14, .bold)).foregroundStyle(secondary)
            Text(value).font(.karla(14)).foregroundStyle(secondary)
        }
    }

    private enum OfferKind { case buy, lease }
    private func offerRow(_ label: String, _ detail: String, kind: OfferKind,
                          cost: Int, action: @escaping () -> Void) -> some View {
        let afford = sim.playerBalance >= cost
        let short = cost - sim.playerBalance
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.karla(14, .bold)).foregroundStyle(secondary)
                Text(detail).font(.karla(14)).foregroundStyle(secondary)
                if !afford {
                    Text("Need \(money(short)) more").font(.karla(12, .semibold)).foregroundStyle(red)
                }
            }
            Spacer(minLength: 8)
            Button(action: action) {
                // Affordable → the Figma colours (BUY #10B981 / LEASE #4B4B4B);
                // unaffordable → a neutral grey so it reads as disabled rather
                // than a washed-out faded green.
                let bg: Color = !afford ? Color(skyHex: 0xC9C9C9)
                    : (kind == .buy ? Sky.coreGreen : Color(skyHex: 0x4B4B4B))
                Text(kind == .buy ? "BUY" : "LEASE")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .frame(height: 24).padding(.horizontal, 8)
                    .background(bg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }.buttonStyle(.plain).disabled(!afford)
        }
    }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}
