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
    /// Set from outside (the one-time update prompt) to open the livery editor.
    /// Adopted in BOTH .onAppear and .onChange: the tab bar recreates this view on
    /// a tab switch, and .onChange never fires for a value that was already set
    /// before the view existed — the documented rule for cross-tab intents.
    var openLivery: Binding<Bool>? = nil

    /// Free-tier gate for Marketplace acquires — paywall at the fleet cap.
    private func gatedAcquire(_ perform: () -> Void) {
        if store.canAcquireAircraft(sim) { perform() } else { onUpgrade(store.capMessage(.fleet)) }
    }
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var segment: Segment = .myFleet
    @State private var detailID: UUID?
    /// Presents the livery designer in EDIT mode (re-customise the fleet's livery).
    @State private var showLivery = false
    /// A livery chosen on the design screen, waiting on the repaint quote. Held
    /// here so backing out of the quote returns to the design screen with the
    /// choice intact. A struct (not a tuple) so it can drive `.animation(value:)`.
    struct PendingLivery: Equatable { let font: Int, palette: Int, tailArt: Int; let text: String }
    @State private var pendingLivery: PendingLivery?
    /// Fleet-list status filter, driven by tapping a status box (nil = all).
    @State private var fleetFilter: FleetStatus?
    enum Segment: Hashable { case myFleet, marketplace }

    /// Marketplace category filter (nil = all) + sort, to quickly narrow the
    /// list to the class/spec a route needs.
    @State private var marketCategory: MarketCategory?
    @State private var marketSort: MarketSort = .seats
    @State private var sortAsc = false
    /// My Fleet only: filter by ownership (bought outright vs leased).
    @State private var ownership: OwnershipFilter = .all
    enum OwnershipFilter: Hashable {
        case all, owned, leased
        var label: String { switch self { case .all: return "All"; case .owned: return "Owned"; case .leased: return "Leased" } }
        func matches(_ ac: Aircraft) -> Bool {
            switch self { case .all: return true; case .owned: return !ac.isLeased; case .leased: return ac.isLeased }
        }
    }
    enum MarketCategory: Hashable {
        case turboprop, regional, narrow, wide
        var label: String {
            switch self {
            case .turboprop: return "Turbo"; case .regional: return "RJ"
            case .narrow:    return "Narrow"; case .wide: return "Wide"
            }
        }
        func matches(_ b: BodyType) -> Bool {
            switch self {
            case .turboprop: return b == .turboprop
            case .regional:  return b == .regionalJet
            case .narrow:    return b == .narrowbody
            case .wide:      return b == .widebody2Engine || b == .widebody4Engine
            }
        }
    }
    enum MarketSort { case price, seats, range }

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
        let _ = sim.displayTick   // throttled UI heartbeat (not raw tick) — keeps scrolling smooth
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
                                        onAssignRoute: { sim.beginAssignment(ac); detailID = nil; tab = 0 },
                                        onSold: { detailID = nil },
                                        onBell: onBell,
                                        onAcquireReplacement: { detailID = nil; tab = 0 })
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        stackedLayout
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: detailID)
            }

            // Livery re-customise (edit mode) — full-screen over the Fleet tab.
            if showLivery {
                LiveryDesignView(airlineName: sim.playerAirlineName ?? "",
                                 initialLivery: sim.livery,
                                 initialText: sim.liveryTitle,
                                 // A player who has never chosen (a save from before
                                 // the livery feature) is picking for the FIRST time —
                                 // that's free, so don't promise a paid repaint.
                                 commitTitle: (sim.ownedCount > 0 && !sim.needsFirstLivery)
                                     ? "Repaint Fleet" : "Save Livery",
                                 onCancel: { showLivery = false }) { fontI, palI, tailI, text in
                    // With aircraft on the books a livery change is a REPAINT: it
                    // costs real money and grounds the fleet, so it goes through an
                    // itemized quote first. With no fleet there's nothing to repaint,
                    // so the choice is free and applies straight away.
                    // FREE when the player has never chosen: their fleet is wearing
                    // defaults nobody picked, so billing the first real choice would
                    // charge an existing player for the pick new players get free.
                    if sim.ownedCount > 0 && !sim.needsFirstLivery {
                        pendingLivery = PendingLivery(font: fontI, palette: palI, tailArt: tailI, text: text)
                    } else {
                        sim.setLivery(fontIndex: fontI, paletteIndex: palI, tailArtIndex: tailI, text: text)
                        onSave()
                        showLivery = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }

            // Itemized repaint quote — shown over the design screen so backing out
            // returns to the design, not to the fleet list.
            if let p = pendingLivery {
                RepaintConfirmView(sim: sim, onCancel: { pendingLivery = nil }) {
                    if sim.repaintFleet(fontIndex: p.font, paletteIndex: p.palette,
                                        tailArtIndex: p.tailArt, text: p.text) {
                        Feedback.success()
                        onSave()                 // a paid repaint must survive a kill
                        pendingLivery = nil
                        showLivery = false
                    }
                }
                .transition(.opacity)
                .zIndex(6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLivery)
        .onAppear { adoptOpenLiveryIfAny() }
        .onChange(of: openLivery?.wrappedValue ?? false) { _, _ in adoptOpenLiveryIfAny() }
        .animation(.easeInOut(duration: 0.2), value: pendingLivery != nil)
    }

    /// Consume an external "open the livery editor" intent exactly once.
    private func adoptOpenLiveryIfAny() {
        guard openLivery?.wrappedValue == true else { return }
        showLivery = true
        openLivery?.wrappedValue = false
    }

    /// Always persist a livery change right away so it survives even if the app is
    /// killed before the next autosave (true is fine; kept as a named flag for clarity).
    private var isFirstLiverySaveNeeded: Bool { true }

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
                                        onAssignRoute: { sim.beginAssignment(ac); tab = 0 },
                                        onSold: { detailID = nil },
                                        onBell: onBell,
                                        onAcquireReplacement: { tab = 0 },
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
            HStack(spacing: 14) {
                Text(segment == .myFleet ? "FLEET HOME" : "MARKETPLACE")
                    .font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                // Re-customise the fleet livery (also the ONLY way an existing/
                // pre-livery save gets to set one).
                Button { showLivery = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill").font(.system(size: 12, weight: .semibold))
                        // An existing player (pre-livery save) has no idea the feature
                        // exists and is currently wearing defaults nobody picked, so
                        // the button ASKS rather than sitting there unlabelled — and a
                        // dot marks that their one free choice is still waiting.
                        Text(sim.needsFirstLivery ? "Add Livery" : "Livery")
                            .font(.karla(13, .semibold))
                        if sim.needsFirstLivery {
                            Circle().fill(Sky.coreGreen).frame(width: 6, height: 6)
                        }
                    }
                    .foregroundStyle(titleColor)
                }
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
        // Switching My Fleet ↔ Marketplace resets the category/sort so each
        // starts fresh (avoids e.g. a "Wide" market filter hiding your fleet).
        return Button {
            segment = seg; marketCategory = nil; ownership = .all
            // Marketplace defaults to cheapest-first; My Fleet has no Price
            // option, so it defaults to biggest-first by seats.
            marketSort = (seg == .marketplace) ? .price : .seats
            sortAsc = (seg == .marketplace)
        } label: {
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
                let statusFiltered = fleetFilter == nil ? owned : owned.filter { status($0) == fleetFilter }
                let shown = applyCategorySort(statusFiltered)
                VStack(spacing: 8) {
                    // Examine capabilities: filter by class + ownership, sort by
                    // seats/range.
                    categoryPillRow
                    HStack(spacing: 8) {
                        ownershipMenu
                        Spacer(minLength: 8)
                        sortMenu(showPrice: false)
                    }
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if shown.isEmpty {
                                Text(fleetFilter != nil
                                     ? "No aircraft currently \(filterLabel(fleetFilter!))."
                                     : "No aircraft match these filters.")
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
                if ac.inPaintShop { liveryChip } else { statusChip(st) }
            }
            // Repaint progress — the four real stages, so a grounded aircraft
            // explains itself instead of just reading GROUNDED.
            if ac.inPaintShop { repaintRow(ac) }
            else if ac.repaintQueued { queuedRow }
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
        if ac.inPaintShop { return .grounded }     // in the paint shop = not flying
        if ac.holdReason == .aog { return .grounded }
        if ac.isIdleSpare { return .idle }
        return .flying
    }

    /// Purple "LIVERY UPDATE" chip — distinct from GROUNDED (a fault) because a
    /// repaint is planned, paid-for downtime, not something gone wrong.
    private var liveryChip: some View {
        let c = Color(skyHex: 0xC79CFF)
        return Text("LIVERY UPDATE")
            .font(.karla(10, .bold)).foregroundStyle(isDark ? c : Color(skyHex: 0x6E43A6))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background((isDark ? c : Color(skyHex: 0x6E43A6)).opacity(isDark ? 0.18 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(isDark ? c : Color(skyHex: 0x6E43A6), lineWidth: 1))
    }

    /// Current paint stage + a progress bar, for an aircraft in the shop.
    private func repaintRow(_ ac: Aircraft) -> some View {
        let p = ac.repaintProgress(at: sim.tick) ?? 0
        let stage = ac.repaintStage(at: sim.tick)?.rawValue ?? "In the shop"
        let daysLeft = max(0, ((ac.repaintUntilTick ?? sim.tick) - sim.tick + 1439) / 1440)
        let c = isDark ? Color(skyHex: 0xC79CFF) : Color(skyHex: 0x6E43A6)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stage).font(.karla(12, .semibold)).foregroundStyle(c)
                Spacer()
                Text("\(daysLeft)d left").font(.karla(12)).foregroundStyle(secondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule().fill(c).frame(width: g.size.width * p)
                }
            }
            .frame(height: 6)
        }
    }

    /// Booked into the repaint program but still flying until its slot opens.
    private var queuedRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "paintbrush.fill").font(.system(size: 10))
            Text("Scheduled for repaint").font(.karla(12))
        }
        .foregroundStyle(isDark ? Color(skyHex: 0xC79CFF) : Color(skyHex: 0x6E43A6))
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

    // MARK: Category filter + sort (shared by Marketplace and My Fleet)

    private func categoryTypeCount(_ c: MarketCategory) -> Int {
        AircraftType.all.filter { c.matches($0.bodyType) }.count
    }
    /// Marketplace types after the category filter + the chosen sort.
    private var marketTypes: [AircraftType] {
        var t = AircraftType.all
        if let c = marketCategory { t = t.filter { c.matches($0.bodyType) } }
        switch marketSort {
        case .price: t.sort { sortAsc ? $0.purchasePrice < $1.purchasePrice : $0.purchasePrice > $1.purchasePrice }
        case .seats: t.sort { sortAsc ? $0.seats < $1.seats : $0.seats > $1.seats }
        case .range: t.sort { sortAsc ? $0.rangeNM < $1.rangeNM : $0.rangeNM > $1.rangeNM }
        }
        return t
    }
    /// Owned aircraft after the category filter + sort (My Fleet). Price sort
    /// isn't offered for owned, so it falls back to tail order.
    private func applyCategorySort(_ owned: [Aircraft]) -> [Aircraft] {
        var a = owned.filter { ownership.matches($0) }
        if let c = marketCategory { a = a.filter { c.matches($0.type.bodyType) } }
        switch marketSort {
        case .seats: a.sort { sortAsc ? $0.type.seats < $1.type.seats : $0.type.seats > $1.type.seats }
        case .range: a.sort { sortAsc ? $0.type.rangeNM < $1.type.rangeNM : $0.type.rangeNM > $1.type.rangeNM }
        case .price: a.sort { $0.tail < $1.tail }
        }
        return a
    }

    /// Box-style category filter row (matches the fleet status boxes): a count
    /// per class, tap to filter, tap again / All to clear.
    private var categoryBoxRow: some View {
        HStack(spacing: 4) {
            categoryBox("All", nil, AircraftType.all.count)
            categoryBox("Turbo", .turboprop, categoryTypeCount(.turboprop))
            categoryBox("RJ", .regional, categoryTypeCount(.regional))
            categoryBox("Narrow", .narrow, categoryTypeCount(.narrow))
            categoryBox("Wide", .wide, categoryTypeCount(.wide))
        }
        .padding(4).background(segBG).clipShape(RoundedRectangle(cornerRadius: 4))
    }
    private func categoryBox(_ label: String, _ cat: MarketCategory?, _ count: Int) -> some View {
        let selected = marketCategory == cat
        return VStack(spacing: 2) {
            Text(label).font(.karla(12)).foregroundStyle(statusLabel).lineLimit(1).minimumScaleFactor(0.65)
            Text("\(count)").font(.karla(18, .heavy)).foregroundStyle(primary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(statusBoxBG).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Sky.brightBlue : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Motion.glide) { marketCategory = selected ? nil : cat } }
    }

    /// Compact category pills — for My Fleet (which already has the status boxes,
    /// so a second box row would be too heavy).
    private var categoryPillRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryPill("All", nil)
                categoryPill("Turbo", .turboprop); categoryPill("RJ", .regional)
                categoryPill("Narrow", .narrow); categoryPill("Wide", .wide)
            }
        }
    }
    private func categoryPill(_ label: String, _ cat: MarketCategory?) -> some View {
        let selected = marketCategory == cat
        return Button { withAnimation(Motion.glide) { marketCategory = selected ? nil : cat } } label: {
            Text(label).font(.karla(13, .medium)).lineLimit(1).fixedSize()
                .foregroundStyle(selected ? .white : statusLabel)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(selected ? Sky.brightBlue : statusBoxBG)
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    /// A compact labeled dropdown — deliberately styled UNLIKE the filter pills
    /// (rounded rect + caret + a "Label:" prefix) so sorting is never mistaken
    /// for another filter chip.
    private func menuControl(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(title):").font(.karla(12)).foregroundStyle(statusLabel)
            Text(value).font(.karla(13, .semibold)).foregroundStyle(primary)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                .foregroundStyle(statusLabel)
        }
        .lineLimit(1).fixedSize()
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(statusBoxBG)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
    }

    /// My Fleet: ownership is a filter (a dropdown, since it's 3 exclusive
    /// options) and sort is its own control — no more ambiguous pill soup.
    private var ownershipMenu: some View {
        Menu {
            Picker("Show", selection: $ownership) {
                Text("All aircraft").tag(OwnershipFilter.all)
                Text("Owned").tag(OwnershipFilter.owned)
                Text("Leased").tag(OwnershipFilter.leased)
            }
        } label: { menuControl("Show", ownership.label) }
    }

    private var sortValueLabel: String {
        let name: String
        switch marketSort {
        case .price: name = "Price"; case .seats: name = "Seats"; case .range: name = "Range"
        }
        return "\(name) \(sortAsc ? "↑" : "↓")"
    }
    private func sortMenu(showPrice: Bool) -> some View {
        Menu {
            Picker("Sort by", selection: $marketSort) {
                if showPrice { Text("Price").tag(MarketSort.price) }
                Text("Seats").tag(MarketSort.seats)
                Text("Range").tag(MarketSort.range)
            }
            Picker("Order", selection: $sortAsc) {
                Text("Low to high").tag(true)
                Text("High to low").tag(false)
            }
        } label: { menuControl("Sort", sortValueLabel) }
    }

    // MARK: Marketplace — buy new / lease new / buy used per type (Figma 5:6501).
    // Reuses the sim's real purchase functions; live affordability from balance.
    private var marketplacePlaceholder: some View {
        VStack(spacing: 10) {
            categoryBoxRow
            HStack { sortMenu(showPrice: true); Spacer(minLength: 0) }
            ScrollView {
                LazyVStack(spacing: 16) {
                    if marketTypes.isEmpty {
                        Text("No aircraft in this category.").font(.karla(14)).foregroundStyle(secondary)
                            .frame(maxWidth: .infinity).padding(.top, 24)
                    }
                    ForEach(marketTypes) { marketplaceCard($0) }
                }
                .padding(.bottom, 8)
            }
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
