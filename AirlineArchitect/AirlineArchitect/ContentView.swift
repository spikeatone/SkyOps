//
//  ContentView.swift
//  Airline Architect
//
//  Created by Michael Stevens on 7/12/26.
//
//  Phase 1 shell: the live map plus a minimal HUD. The speed buttons change
//  how often the tick loop fires WITHOUT touching the tick logic itself —
//  the clearest demonstration that the sim clock is decoupled from real time.
//

import SwiftUI

struct ContentView: View {
    @State private var sim = Simulation()
    @State private var store = Store()
    /// Bumped on a fresh start (after bankruptcy) so the `.task(id:)` cancels the
    /// old sim's run loop and starts a new one on the replacement instance.
    @State private var gameID = UUID()
    @State private var tab = 0
    @State private var showAlerts = false
    @State private var paywallReason: String?
    @State private var showPaywall = false
    /// Which save slot the current game occupies (autosave / SAVE target).
    @State private var currentSlot: Int?
    /// Showing the load / slot-picker menu (cold launch with saves, or QUIT).
    @State private var showLoadMenu = false
    /// Active first-play walkthrough step (nil = not running).
    @State private var tutorialStep: Int?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Custom bottom nav (SkyTabBar) — the Figma tab bar (yellow-on-dark /
        // blue-on-light, custom icons) isn't a stock UITabBar, so we drive tab
        // selection ourselves and switch the content. Only NETWORK is built;
        // the others are placeholders. safeAreaInset reserves the bar's space
        // so the content lays out above it.
        Group {
            switch tab {
            case 0:  NetworkView(sim: sim, store: store, onBell: { showAlerts = true }, onUpgrade: upgrade,
                                 onSave: saveCurrent, onQuit: quitToMenu)
            case 1:  FleetView(sim: sim, tab: $tab, store: store, onBell: { showAlerts = true },
                               onSave: saveCurrent, onQuit: quitToMenu, onUpgrade: upgrade)
            case 2:  CrewsView(sim: sim, onBell: { showAlerts = true }, onSave: saveCurrent, onQuit: quitToMenu)
            case 3:  OpsView(sim: sim, onBell: { showAlerts = true }, onSave: saveCurrent, onQuit: quitToMenu)
            default: FinanceView(sim: sim, store: store, onBell: { showAlerts = true },
                                 onSave: saveCurrent, onQuit: quitToMenu, onUpgrade: { upgrade(nil) })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SkyTabBar(selection: $tab, opsBadge: sim.unseenOpsEventCount)
        }
        // Run the sim for the whole session, independent of the selected tab.
        // Keyed on gameID so a fresh start (post-bankruptcy) cancels the old
        // loop and runs the new instance.
        .task(id: gameID) { await sim.run() }
        // Load + observe the Pro entitlement from RevenueCat.
        .task { await store.start() }
        // On cold launch, show the load menu if any saved game exists; otherwise
        // fall through to the naming screen for a fresh airline in slot 0.
        .onAppear {
            if currentSlot == nil, sim.playerAirlineName == nil, GameStore.anySave {
                showLoadMenu = true
            }
        }
        // Autosave to the current slot whenever the app leaves the foreground.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, sim.playerAirlineName != nil, !sim.isBankrupt, let s = currentSlot {
                GameStore.save(sim.snapshot(), slot: s)
            }
        }
        // Haptics on the big observed moments (the delight layer). Player-initiated
        // actions (buy / open route) tap at their own call sites; these are the
        // events that arrive from the sim itself.
        .onChange(of: sim.celebrations.first?.id) { _, id in if id != nil { Feedback.milestone() } }
        .onChange(of: sim.decisionQueue.count) { old, new in if new > old { Feedback.alert() } }
        .onChange(of: sim.isBankrupt) { _, bankrupt in if bankrupt { Feedback.gameOver() } }
        .overlay {
            // Load / slot-picker menu — takes precedence over naming.
            if showLoadMenu {
                SaveSlotsView(onLoad: loadSlot, onNew: newGame(in:), onDelete: { GameStore.clear(slot: $0) })
                    .transition(.opacity)
            } else if sim.playerAirlineName == nil {
                // First-launch: name the airline before anything else.
                AirlineNamingView { name, tailCode in
                    if currentSlot == nil { currentSlot = GameStore.firstFreeSlot ?? 0 }
                    sim.nameAirline(name, tailCode: tailCode)
                    if let s = currentSlot { GameStore.save(sim.snapshot(), slot: s) }
                    if !TutorialState.seen { tab = tutorialSteps[0].tab; tutorialStep = 0 }
                }
                .transition(.opacity)
            }
        }
        // First-play walkthrough — bottom coach card that navigates the tabs.
        .overlay(alignment: .bottom) {
            if let step = tutorialStep, step < tutorialSteps.count {
                TutorialCard(step: tutorialSteps[step], index: step, total: tutorialSteps.count,
                             onNext: {
                                 if step + 1 < tutorialSteps.count {
                                     tutorialStep = step + 1; tab = tutorialSteps[step + 1].tab
                                 } else { TutorialState.seen = true; tutorialStep = nil; tab = 0 }
                             },
                             onSkip: { TutorialState.seen = true; tutorialStep = nil; tab = 0 })
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.glide, value: tutorialStep)
        // Alerts modal — the bell's target, over everything, on any tab.
        .overlay {
            if showAlerts {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .onTapGesture { showAlerts = false }
                    ScrollView {
                        AlertsModal(sim: sim, onClose: { showAlerts = false })
                            .frame(maxWidth: 440)
                            .padding(16)
                    }
                    .padding(.top, 44)
                }
                .transition(.opacity)
            }
        }
        // Paywall — the target of every in-context upgrade prompt, over any tab.
        .overlay {
            if showPaywall {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                        .onTapGesture { showPaywall = false }
                    ScrollView {
                        PaywallView(store: store, reason: paywallReason,
                                    onClose: { showPaywall = false })
                            .frame(maxWidth: 440)
                            .padding(16)
                    }
                }
                .transition(.opacity)
            }
        }
        // Milestone celebrations — glide down from the top, auto-dismiss.
        .overlay(alignment: .top) {
            if let c = sim.celebrations.first {
                MilestoneToast(celebration: c)
                    .id(c.id)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: c.id) {
                        try? await Task.sleep(for: .seconds(3.6))
                        sim.dismissCelebration(c.id)
                    }
            }
        }
        .animation(Motion.toast, value: sim.celebrations.first?.id)
        // Game over — bankruptcy. Modal recap + fresh start (new sim instance).
        .overlay {
            if sim.isBankrupt {
                GameOverView(sim: sim) {
                    if let s = currentSlot { GameStore.clear(slot: s) }  // failed airline gone for good
                    sim = Simulation()
                    gameID = UUID()
                    currentSlot = nil
                    tab = 0
                    // Other saved airlines? Back to the menu; else a fresh start.
                    showLoadMenu = GameStore.anySave
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: sim.playerAirlineName)
        .animation(.easeOut(duration: 0.25), value: showLoadMenu)
        .animation(.easeOut(duration: 0.2), value: showAlerts)
        .animation(.easeOut(duration: 0.2), value: showPaywall)
        .animation(.easeOut(duration: 0.3), value: sim.isBankrupt)
    }

    /// Show the paywall with an optional context line (which cap was hit).
    private func upgrade(_ reason: String?) {
        paywallReason = reason
        showPaywall = true
    }

    // MARK: - Save slots

    /// SAVE button — persist the current game to its slot.
    private func saveCurrent() {
        if currentSlot == nil { currentSlot = GameStore.firstFreeSlot ?? 0 }
        if let s = currentSlot { GameStore.save(sim.snapshot(), slot: s) }
    }

    /// QUIT button — save the current game, then return to the load menu.
    private func quitToMenu() {
        saveCurrent()
        withAnimation(.easeOut(duration: 0.25)) { showLoadMenu = true }
    }

    /// Load a saved slot into a fresh sim instance (so no residue from a prior
    /// game survives), restart its run loop, and enter it.
    private func loadSlot(_ slot: Int) {
        guard let snap = GameStore.load(slot: slot) else { return }
        let fresh = Simulation()
        fresh.restore(from: snap)
        sim = fresh
        gameID = UUID()
        currentSlot = slot
        tab = 0
        showLoadMenu = false
    }

    /// Start a brand-new airline in the given (empty) slot.
    private func newGame(in slot: Int) {
        sim = Simulation()
        gameID = UUID()
        currentSlot = slot
        tab = 0
        showLoadMenu = false   // naming screen shows next (playerAirlineName == nil)
    }

    /// Fleet / Crews / Ops / Finance — the other four tabs are designed later.
    private func placeholder(_ title: String, _ icon: String) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 44))
                    .foregroundStyle(Sky.brightBlue.opacity(0.6))
                Text(title.uppercased()).font(.karla(22, .bold))
                    .foregroundStyle(Sky.brightBlue)
                Text("Coming soon").font(.karla(13)).foregroundStyle(.secondary)
            }
        }
    }
}



/// "$28k" / "$1.2M" compact money for tight decision-card buttons.
func compactMoney(_ v: Int) -> String {
    let a = abs(v), sign = v < 0 ? "−" : ""
    if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
    if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
    return sign + "$\(a)"
}


/// The route-opening flow's UI state.
enum RouteMode: Equatable {
    case off
    case pickOrigin
    case pickDest(String)
    case confirm(String, String)
}

/// ACQUIRE — per-aircraft profile cards (Figma 4:1993 / 3:2052): name, an
/// illustration (placeholder = the app's body-type vector icon until real
/// side-view art is supplied), a Seats / Range / Lifespan spec row, then Buy
/// new / Lease new / Buy used(×listings) rows each with a BUY (green) or LEASE
/// (gray) button. Live affordability; @Observable re-renders on balance change.
struct BuyPanel: View {
    let sim: Simulation
    var store: Store
    var onUpgrade: () -> Void = {}
    let onBought: (Aircraft) -> Void
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var panelBG: Color     { isDark ? Sky.navBarDark : Color(skyHex: 0xF1F1F1) }
    private var panelBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Priciest/biggest first, matching the Figma card order.
                ForEach(AircraftType.all.sorted { $0.purchasePrice < $1.purchasePrice }) { t in
                    AircraftProfileCard(sim: sim, type: t, store: store, onUpgrade: onUpgrade, onBought: onBought)
                }
            }
        }
        // No height cap — the Acquire browser fills the space its container gives
        // it (control bar → speed bar), per the parent's frame(maxHeight:.infinity).
        .padding(8)
        .background(panelBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(panelBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }
}

/// One aircraft's acquisition card.
struct AircraftProfileCard: View {
    let sim: Simulation
    let type: AircraftType
    var store: Store
    var onUpgrade: () -> Void = {}
    let onBought: (Aircraft) -> Void

    private let gray = Color(skyHex: 0x8C8C8C)
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xE6E6E6) }
    private var titleC: Color     { isDark ? .white : .black }
    private var bodyC: Color      { isDark ? .white : Color(skyHex: 0x64748B) }
    private var labelC: Color     { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    /// Free-tier gate: at the fleet cap, tapping any acquire button opens the
    /// paywall instead of purchasing. `perform` runs only when allowed.
    private func gated(_ perform: () -> Void) {
        if store.canAcquireAircraft(sim) { perform() } else { onUpgrade() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(type.name).font(.karla(20, .heavy)).foregroundStyle(titleC)

            illustration

            HStack(alignment: .top) {
                spec("Seats:", "\(type.seats)")
                Spacer()
                spec("Practical Range:", "\(type.rangeNM.formatted()) NM")
                Spacer()
                spec("Avg Lifespan:", "\(type.expectedLifespanCycles.formatted()) cycles")
            }

            Rectangle().fill(cardBorder).frame(height: 1)

            row("Buy new:", money(type.purchasePrice), lease: false,
                afford: sim.playerBalance >= type.purchasePrice) {
                gated { if let ac = sim.buyAircraft(type) { onBought(ac) } }
            }
            row("Lease new:",
                "\(money(sim.leaseUpfront(type))) upfront + \(money(type.monthlyLeaseCost)) / mo",
                lease: true, afford: sim.playerBalance >= sim.leaseUpfront(type)) {
                gated { if let ac = sim.leaseAircraft(type) { onBought(ac) } }
            }
            ForEach(sim.usedInventory[type.id] ?? []) { listing in
                let pct = 100 * listing.cyclesAccrued / max(1, type.expectedLifespanCycles)
                row("Buy used:",
                    "\(money(listing.price)) - \(listing.cyclesAccrued.formatted()) cycles (~\(pct)%)",
                    lease: false, afford: sim.playerBalance >= listing.price) {
                    gated { if let ac = sim.buyUsedAircraft(listing) { onBought(ac) } }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// Real side-view illustration if one is bundled for this type; otherwise
    /// the body-type vector icon as a placeholder (enlarged, centred).
    @ViewBuilder private var illustration: some View {
        if let art = AircraftArt.image(for: type.id) {
            art.resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            Canvas { ctx, size in
                guard let icon = AircraftIcon.byBodyType[type.bodyType] else { return }
                let len = min(size.width * 0.82, 210)
                let rs = len * icon.scale / type.bodyType.iconLength
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                g.scaleBy(x: rs, y: rs)
                g.translateBy(x: -icon.center.x, y: -icon.center.y)
                g.fill(icon.path, with: .color(isDark ? .white.opacity(0.85) : .black.opacity(0.55)))
            }
            .frame(height: 66)
            .frame(maxWidth: .infinity)
        }
    }

    private func spec(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.karla(14, .bold)).foregroundStyle(labelC)
            Text(value).font(.karla(14)).foregroundStyle(bodyC)
        }
    }

    private func row(_ label: String, _ detail: String, lease: Bool, afford: Bool,
                     action: @escaping () -> Void) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.karla(14, .bold)).foregroundStyle(labelC)
                Text(detail).font(.karla(14)).foregroundStyle(bodyC)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Text(lease ? "LEASE" : "BUY")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(!afford ? Color(skyHex: 0xC9C9C9) : (lease ? Color(skyHex: 0x4B4B4B) : Sky.coreGreen))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain).disabled(!afford)
        }
    }

    private func money(_ v: Int) -> String {
        "$" + v.formatted(.number.grouping(.automatic))
    }
}


/// Confirm panel for a picked origin→dest pair.
/// Open Route — step three ("New Route Confirm", Figma 19:6758): the ORIG → DEST
/// header, a Distance / Slots / Range check / Opening cost readout, and the
/// Open route / Abandon buttons. Buying mid-flow is still reachable — with no
/// spare, "Open route" opens the Acquire panel (which auto-assigns on purchase).
struct RouteConfirmPanel: View {
    let sim: Simulation
    let origin: Airport
    let dest: Airport
    let onOpen: () -> Void
    let onCancel: () -> Void

    private let netGreen = Color(skyHex: 0x87ED7A)
    private let netRed   = Color(skyHex: 0xFF9292)
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xE6E6E6) }
    private var primaryC: Color   { isDark ? .white : .black }
    private var labelC: Color     { isDark ? .white : Color(skyHex: 0x64748B) }
    private var green: Color      { isDark ? netGreen : Color(skyHex: 0x10B981) }
    private var red: Color        { isDark ? netRed : Color(skyHex: 0xD70000) }

    var body: some View {
        let cost = sim.routeOpeningCost(origin, dest)
        let spare = sim.idleSpares.first
        let slotsOK = origin.slotsAvailable > 0 && dest.slotsAvailable > 0
        let affordable = sim.playerBalance >= cost
        VStack(alignment: .leading, spacing: 8) {
            // Header: ORIG → DEST
            HStack(spacing: 8) {
                Text(origin.code).font(.karla(20, .heavy)).foregroundStyle(primaryC)
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold)).foregroundStyle(primaryC)
                Text(dest.code).font(.karla(20, .heavy)).foregroundStyle(primaryC)
                Spacer(minLength: 0)
            }
            infoRow("Distance", "\(distanceNM.formatted()) nm", primaryC)
            infoRow("Fare/seat", "$\(Int(FareModel.farePerSeat(distanceNM: Double(distanceNM)).rounded()))", primaryC)
            // Demand model (prototype): show this city pair's estimated daily
            // demand and the load factor the spare that'd be assigned would fly
            // it at — so the player can size the aircraft to the route.
            if sim.useDemandModel {
                infoRow("Est. demand", "\(sim.routeDailyDemand(origin, dest).formatted()) pax/day", primaryC)
                // Network/hub effect: connecting pax from your other routes here.
                let hubBonus = sim.hubBonusPercent(originCode: origin.code, destCode: dest.code)
                if hubBonus > 0 {
                    infoRow("Hub bonus", "+\(hubBonus)% (connecting traffic)", green)
                }
                if let spare {
                    let lf = sim.projectedLoadFactor(seats: spare.type.seats, from: origin, to: dest)
                    let c = lf >= 0.7 ? green : (lf >= 0.45 ? Color(skyHex: 0xFFB300) : red)
                    infoRow("Projected load", "\(Int((lf * 100).rounded()))% · \(spare.type.name)", c)
                }
            }
            infoRow("Slots", slotsOK ? "Avail both ends" : "Buyout needed",
                    slotsOK ? green : red)
            let cap = capability(spare)
            infoRow("Aircraft check", cap.text, cap.ok ? green : red)
            infoRow("Opening cost", "$\(cost.formatted())", affordable ? green : red)

            Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 2)

            HStack(spacing: 8) {
                confirmButton("Open route", disabled: spare != nil && (!affordable || !cap.ok), action: onOpen)
                confirmButton("Abandon", disabled: false, action: onCancel)
            }
            .frame(height: 32)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func infoRow(_ label: String, _ value: String, _ valueColor: Color) -> some View {
        HStack {
            Text(label).font(.karla(14)).foregroundStyle(labelC)
            Spacer()
            Text(value).font(.karla(14, .bold)).foregroundStyle(valueColor)
        }
    }

    private func confirmButton(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.karla(16, .medium))
                .foregroundStyle(disabled ? primaryC.opacity(0.35) : primaryC)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    /// Great-circle distance origin→dest in nautical miles.
    private var distanceNM: Int {
        let r = 3440.065
        let lat1 = origin.lat * .pi / 180, lat2 = dest.lat * .pi / 180
        let dLat = (dest.lat - origin.lat) * .pi / 180
        let dLon = (dest.lon - origin.lon) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        return Int((r * 2 * atan2(sqrt(a), sqrt(1 - a))).rounded())
    }

    /// Whether the spare that would be assigned can PHYSICALLY fly this route —
    /// range + runway at both ends. Blocks Open Route when it can't.
    private func capability(_ spare: Aircraft?) -> (text: String, ok: Bool) {
        guard let spare else { return ("a/c not assigned", false) }
        switch sim.routeBlock(for: spare, from: origin, to: dest) {
        case .range:
            return ("out of range (\(spare.type.rangeNM.formatted()) nm max)", false)
        case .runway(let code):
            return ("\(code) runway too short for \(spare.type.name)", false)
        case nil:
            return ("in range · runway OK", true)
        }
    }
}

/// ROUTES panel: list of every route (open + closed, newest first); tap one
/// for full P&L detail. All figures read from @Observable sim state, so an
/// open route's numbers tick up live as its aircraft completes flights.
/// ROUTES — Figma list (5:5908): ACTIVE / CLOSED sections of route cards, each
/// "ORIG → DEST" + a Profitable/Recouping status chip, assigned type, Net
/// Revenue (vs opening cost, green/red), and a disclosure triangle that expands
/// the card inline to the full P&L + profitability chart + recent flights.
struct RoutesPanel: View {
    let sim: Simulation
    @State private var expandedId: Int?
    /// Measured content height so the panel HUGS its content (one collapsed route
    /// card is short), only scrolling when the list exceeds the cap.
    @State private var contentHeight: CGFloat = 0

    private let netGreen = Color(skyHex: 0x87ED7A)
    private let netRed   = Color(skyHex: 0xFF9292)
    private let chipGreenBG = Color(skyHex: 0xDCFCE7)
    private let chipAmberBG = Color(skyHex: 0xFEF3C7)
    private let chipAmberFG = Color(skyHex: 0xF59E0B)

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color      { isDark ? Sky.navBarDark.opacity(0.92) : Color.white.opacity(0.96) }
    private var innerCardBG: Color { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var labelColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private var primaryC: Color    { isDark ? .white : .black }
    private var green: Color       { isDark ? netGreen : Color(skyHex: 0x10B981) }
    private var red: Color         { isDark ? netRed : Color(skyHex: 0xD70000) }

    var body: some View {
        let active = sim.playerRoutes.sorted { $0.openedTick > $1.openedTick }
        let closed = sim.closedPlayerRoutes.sorted { ($0.closedTick ?? 0) > ($1.closedTick ?? 0) }
        Group {
            if active.isEmpty && closed.isEmpty {
                Text("No routes opened yet.")
                    .font(.karla(14)).foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24).padding(.horizontal, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !active.isEmpty { section("ACTIVE ROUTES", active) }
                        if !closed.isEmpty { section("CLOSED ROUTES", closed) }
                    }
                    .padding(8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                // Hug the content (a single collapsed route card is short) — only
                // scroll once the list exceeds the cap. Expanding a route's caret
                // grows the content, so the panel grows with it.
                .frame(height: min(max(contentHeight, 1), 376))
            }
        }
        .frame(maxWidth: .infinity)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func section(_ title: String, _ routes: [Route]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(.karla(14)).foregroundStyle(labelColor)
                Rectangle().fill(cardBorder).frame(height: 1)
            }
            ForEach(routes) { card($0) }
        }
    }

    private func card(_ r: Route) -> some View {
        let expanded = expandedId == r.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 12) {
                    Text(r.originCode).font(.karla(20, .heavy)).foregroundStyle(primaryC)
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(primaryC)
                    Text(r.destCode).font(.karla(20, .heavy)).foregroundStyle(primaryC)
                }
                Spacer()
                if r.isOpen { statusChip(profitable: r.isProfitable) }
            }
            if r.isOpen {
                HStack(alignment: .top) {
                    labeled("Aircraft Types Assigned", r.assignmentHistory.last?.typeName ?? "—", .leading)
                    Spacer()
                    let n = r.netVsOpeningCost
                    labeledValue("Net Revenue",
                                 (n >= 0 ? "+" : "") + compactMoney(n),
                                 n >= 0 ? green : red, .trailing)
                }
            } else {
                Text("Closed · \(Simulation.simDate(fromTick: r.closedTick ?? 0))")
                    .font(.karla(14)).foregroundStyle(labelColor)
            }
            if expanded { detail(r) }
            Image(systemName: expanded ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 11)).foregroundStyle(labelColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(innerCardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expandedId = expanded ? nil : r.id } }
    }

    private func statusChip(profitable: Bool) -> some View {
        Text(profitable ? "PROFITABLE" : "RECOUPING")
            .font(.karla(10, .bold))
            .foregroundStyle(profitable ? Sky.coreGreen : chipAmberFG)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(profitable ? chipGreenBG : chipAmberBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(profitable ? Sky.coreGreen : Sky.lightYellow, lineWidth: 1))
    }

    private func labeled(_ label: String, _ value: String, _ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 0) {
            Text(label).font(.karla(14)).foregroundStyle(labelColor)
            Text(value).font(.karla(16, .semibold)).foregroundStyle(primaryC)
        }
    }
    private func labeledValue(_ label: String, _ value: String, _ color: Color, _ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 0) {
            Text(label).font(.karla(14)).foregroundStyle(labelColor)
            Text(value).font(.karla(16, .semibold)).foregroundStyle(color)
        }
    }

    @ViewBuilder private func detail(_ r: Route) -> some View {
        Rectangle().fill(cardBorder).frame(height: 1).padding(.top, 2)
        RouteProfitChart(route: r, flights: r.history.count)
        VStack(alignment: .leading, spacing: 3) {
            line("Start", Simulation.simDate(fromTick: r.openedTick))
            line("Flights", "\(r.flights)")
            line("Opening cost", money(r.openingCost))
            line("Cumulative net", money(r.cumulativeNet))
            line("Revenue", money(r.totalRevenue))
            line("Fees", "−" + money(r.totalFees))
            line("Operating cost", "−" + money(r.totalOperatingCost))
            line("Lease cost", "−" + money(r.totalLeaseCost))
            line("Avg load", "\(r.averageLoadPct)%")
        }
        if !r.history.isEmpty {
            Text(r.history.count > 8 ? "RECENT FLIGHTS (last 8 of \(r.history.count))" : "RECENT FLIGHTS")
                .font(.karla(10, .bold)).foregroundStyle(labelColor).padding(.top, 2)
            ForEach(r.history.suffix(8).reversed()) { h in
                Text("\(Simulation.simDate(fromTick: h.tick)): \(h.pax)/\(h.seats) (\(Int((h.loadFactor*100).rounded()))%) · net \(h.net < 0 ? "−" : "")\(compactMoney(abs(h.net)))")
                    .font(.karla(11)).foregroundStyle(h.net < 0 ? red : primaryC.opacity(0.85))
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.karla(12)).foregroundStyle(labelColor).frame(width: 112, alignment: .leading)
            Text(value).font(.karla(12, .semibold)).foregroundStyle(primaryC)
            Spacer(minLength: 0)
        }
    }

    private func money(_ v: Int) -> String { (v < 0 ? "−$" : "$") + abs(v).formatted(.number.grouping(.automatic)) }
}


/// Profitability-over-time chart for a route: cumulative net measured AGAINST
/// its opening cost, so the dashed break-even (zero) line shows exactly when —
/// and whether — the route recouped what it cost to open. The line is red
/// below break-even, mint above, split precisely at the crossing; a dot marks
/// the recoup point. Data comes straight from route.history (verified
/// sufficient to reconstruct the whole curve). Hand-drawn in a Canvas to match
/// the map's rendering + the current dev aesthetic (Figma restyle repaints it
/// later); re-renders live via ContentView's per-tick refresh.
struct RouteProfitChart: View {
    let route: Route
    /// Completed-flight count — a CHANGING VALUE input so SwiftUI re-invokes
    /// this view's body (and redraws the Canvas) when new flight data lands.
    /// Without it, `route` alone is a stable reference and the chart freezes.
    let flights: Int
    private let mint = Color(red: 0x37/255, green: 1, blue: 0xB0/255)
    private let red = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

    /// netVsOpeningCost at flight 0 (route opened — the full hole), then one
    /// value per completed flight.
    private var series: [Double] {
        [Double(-route.openingCost)] + route.history.map { Double($0.cumulativeNet - route.openingCost) }
    }
    /// First 1-based flight index that reached break-even, if any.
    private var recoupFlight: Int? {
        let s = series
        return s.indices.first { $0 >= 1 && s[$0] >= 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROFITABILITY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            if route.history.isEmpty {
                Text("No flight data yet.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 22)
            } else {
                Canvas { ctx, size in draw(ctx, size) }
                    .frame(height: 116)
                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder private var caption: some View {
        if let k = recoupFlight, k - 1 < route.history.count {
            Text("Recouped at flight \(k) · \(Simulation.simDate(fromTick: route.history[k - 1].tick))")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(mint)
        } else {
            Text("Not yet recouped · \(money(abs(route.netVsOpeningCost))) to break-even")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(red)
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let s = series
        let leftPad: CGFloat = 48, rightPad: CGFloat = 8, topPad: CGFloat = 8, bottomPad: CGFloat = 6
        let plotW = size.width - leftPad - rightPad
        let plotH = size.height - topPad - bottomPad
        let n = s.count
        let maxY = max(s.max() ?? 0, 0)
        let minY = min(s.min() ?? 0, 0)
        let range = max(1, maxY - minY)
        func sx(_ i: Int) -> CGFloat { leftPad + (n <= 1 ? 0 : plotW * CGFloat(i) / CGFloat(n - 1)) }
        func sy(_ v: Double) -> CGFloat { topPad + plotH * CGFloat(1 - (v - minY) / range) }

        ctx.stroke(Path(CGRect(x: leftPad, y: topPad, width: plotW, height: plotH)),
                   with: .color(.white.opacity(0.10)), lineWidth: 1)

        // Break-even (zero) line — dashed, prominent.
        let zy = sy(0)
        var z = Path(); z.move(to: CGPoint(x: leftPad, y: zy)); z.addLine(to: CGPoint(x: leftPad + plotW, y: zy))
        ctx.stroke(z, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Y labels: max (top), $0 (break-even), min (bottom).
        yLabel(ctx, money(Int(maxY)), CGPoint(x: leftPad - 5, y: sy(maxY)))
        yLabel(ctx, "$0", CGPoint(x: leftPad - 5, y: zy))
        yLabel(ctx, money(Int(minY)), CGPoint(x: leftPad - 5, y: sy(minY)))

        // P&L line, split at each zero crossing and coloured by sign.
        for i in 0..<(n - 1) {
            let x0 = sx(i), x1 = sx(i + 1), v0 = s[i], v1 = s[i + 1]
            if (v0 < 0) != (v1 < 0), v1 != v0 {
                let xc = x0 + (x1 - x0) * CGFloat(-v0 / (v1 - v0))
                seg(ctx, CGPoint(x: x0, y: sy(v0)), CGPoint(x: xc, y: zy), green: v0 >= 0)
                seg(ctx, CGPoint(x: xc, y: zy), CGPoint(x: x1, y: sy(v1)), green: v1 >= 0)
            } else {
                seg(ctx, CGPoint(x: x0, y: sy(v0)), CGPoint(x: x1, y: sy(v1)), green: (v0 + v1) >= 0)
            }
        }

        // Recoup marker at the break-even crossing.
        if let k = recoupFlight, k < n {
            let v0 = s[k - 1], v1 = s[k]
            let xc = (v0 < 0) != (v1 < 0) && v1 != v0
                ? sx(k - 1) + (sx(k) - sx(k - 1)) * CGFloat(-v0 / (v1 - v0))
                : sx(k)
            ctx.fill(Path(ellipseIn: CGRect(x: xc - 3, y: zy - 3, width: 6, height: 6)), with: .color(mint))
        }
    }

    private func seg(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, green: Bool) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(green ? mint : red), lineWidth: 1.5)
    }

    private func yLabel(_ ctx: GraphicsContext, _ s: String, _ at: CGPoint) {
        ctx.draw(Text(s).font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                 at: at, anchor: .trailing)
    }

    private func money(_ v: Int) -> String {
        let a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }
}

/// Tap-selected aircraft info card. Field ORDER follows the prototype's
/// documented designer decision (Route → Tail → Type → Status → …). The crew
/// legal-hours and Revenue/Fees/Operating-cost/Net rows slot in RIGHT HERE
/// once the crew system and Phase 5 economy are ported — the layout is built
/// to receive them, not to be rebuilt. Visual design is deliberately the dev
/// aesthetic; the real Figma restyle is the Phase 4 pass (designer decision).
struct AircraftTooltip: View {
    let aircraft: Aircraft
    let sim: Simulation
    let tick: Int            // changing value input — keeps status/crew live
    let onClose: () -> Void

    @Environment(\.colorScheme) private var scheme

    // Figma tokens (3:1662): On Dark Green / Red for the P&L rows, purple for
    // competitor identity, light blue for ordinary values. Negative numbers use
    // the app-wide red convention: #FF9292 dark / #D70000 light.
    private var heldColor: Color { scheme == .dark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    private let onDarkGreen   = Color(skyHex: 0x87ED7A)
    private let othersColor   = Color(skyHex: 0xD767FF)

    // Theme-aware card chrome (Figma 3:1542 light = white@90% + #64748B labels +
    // #0EA5E9 values + #10B981/#D70000 for net/P&L). Dark keeps the navBarDark
    // card. On the white light map the card is near-opaque white + a grey border
    // + soft shadow so it reads.
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark.opacity(0.9) : Color.white.opacity(0.96) }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var labelColor: Color { isDark ? .white : Color(skyHex: 0x64748B) }
    private var valueColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x0EA5E9) }
    private var greenValue: Color { isDark ? onDarkGreen : Color(skyHex: 0x10B981) }

    var body: some View {
        // Per Figma 3:1662: a stack of "Label:" (white Karla-Bold 14) + value
        // (light-blue Karla-Regular 14) rows. No close button (tap the map to
        // dismiss) and no separate LEASED badge (folded into the Tail value).
        VStack(alignment: .leading, spacing: 4) {
            // Airline identity: competitor (purple) for background traffic, the
            // player's own (green) for owned — a useful ownership signal layered
            // on the Figma row layout.
            if let airline = aircraft.airlineName {
                row("Airline", airline, valueColor: othersColor)
            } else if let mine = sim.playerAirlineName {
                row("Airline", mine, valueColor: greenValue)
            }
            routeRow
            row("Tail", aircraft.isLeased ? "\(aircraft.tail) (leased)" : aircraft.tail)
            row("Type", aircraft.type.name)
            row("Status", statusText, valueColor: aircraft.isHeld ? heldColor : valueColor)

            // Crew / load / cycles / economics are the PLAYER's operational
            // detail only — a rival's books aren't visible. Ported from the
            // prototype's deliberately-reduced background-traffic tooltip.
            if aircraft.airlineName == nil {
                row("Cycles", cyclesText)
                row("Crew legal hours", crewText, valueColor: crewValueColor)
                row("Load", loadText)

                let econ = sim.legEconomics(for: aircraft)
                row("Revenue", money(econ.revenue))
                // Fees and operating cost are always negative (costs) → red.
                row("Fees", "−" + money(econ.fees), valueColor: heldColor)
                // Op cost folds in a smoothed lease estimate for leased aircraft
                // (display-only); the real lease is a fixed monthly bill.
                row("Operating cost", "−" + money(econ.displayOperatingCost), valueColor: heldColor)
                row("Net for this leg", (econ.displayNet < 0 ? "−" : "") + money(abs(econ.displayNet)),
                    valueColor: econ.displayNet < 0 ? heldColor : greenValue)
                if let pl = routePLText {
                    row("Route P&L", pl.text, valueColor: pl.positive ? greenValue : heldColor)
                }
            }
        }
        .padding(8)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func row(_ label: String, _ value: String, valueColor: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(label):")
                .font(.karla(14, .bold))
                .foregroundStyle(labelColor)
            Text(value)
                .font(.karla(14))
                .foregroundStyle(valueColor ?? self.valueColor)
            Spacer(minLength: 0)
        }
    }

    /// Route row: airport codes in Karla-ExtraBold 12 with an arrow between,
    /// or a SPARE marker when the aircraft has no assigned route.
    private var routeRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Route:")
                .font(.karla(14, .bold))
                .foregroundStyle(labelColor)
            if aircraft.isIdleSpare {
                Text("SPARE · at \(aircraft.origin.code)")
                    .font(.karla(12, .heavy))
                    .foregroundStyle(valueColor)
            } else {
                Text(aircraft.origin.code)
                    .font(.karla(12, .heavy))
                    .foregroundStyle(valueColor)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(valueColor)
                Text(aircraft.dest.code)
                    .font(.karla(12, .heavy))
                    .foregroundStyle(valueColor)
            }
            Spacer(minLength: 0)
        }
    }

    /// Route P&L vs opening cost — a route is only "profitable" once its
    /// cumulative net recoups the opening cost (Route.isProfitable), matching
    /// the Figma "$X short of $Y opening cost" phrasing.
    private var routePLText: (text: String, positive: Bool)? {
        guard let id = aircraft.assignedRouteId,
              let r = sim.playerRoutes.first(where: { $0.id == id }) else { return nil }
        if r.isProfitable {
            return ("recouped its \(money(r.openingCost)) opening cost, +\(money(r.netVsOpeningCost))", true)
        } else {
            return ("\(money(-r.netVsOpeningCost)) short of \(money(r.openingCost)) opening cost", false)
        }
    }

    private var statusText: String {
        switch aircraft.holdReason {
        case .weather:
            return aircraft.state == .approach
                ? "HELD — holding pattern at \(aircraft.dest.code) (weather)"
                : "HELD — ground stop at \(aircraft.origin.code)"
        case .rejoin:  return "Rejoining approach at \(aircraft.dest.code)"
        case .aog:     return "AOG — grounded at \(aircraft.origin.code)"
        case .crew:    return "HELD — no legal crew at \(aircraft.origin.code)"
        case nil:      return phaseLabel(aircraft.state)
        }
    }

    /// Crew legal hours (Part 117 duty clock), or the reason there's no crew.
    /// Figma phrasing: "N.N hrs remaining".
    private var crewText: String {
        if aircraft.holdReason == .crew { return "none — awaiting legal crew" }
        guard let d = sim.crewDuty(for: aircraft) else { return "—" }
        return String(format: "%.1f hrs remaining", max(0, d.max - d.used))
    }

    private var crewValueColor: Color {
        if aircraft.holdReason == .crew { return heldColor }
        // amber as the crew nears its duty limit
        if let d = sim.crewDuty(for: aircraft), d.used > d.max * 0.8 {
            return Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255)
        }
        return valueColor
    }

    private var loadText: String {
        let pct = Int((aircraft.currentLoadFactor * 100).rounded())
        return "\(aircraft.currentPax) / \(aircraft.type.seats) pax (\(pct)%)"
    }

    private func money(_ v: Int) -> String {
        "$" + v.formatted(.number.grouping(.automatic))
    }

    private var cyclesText: String {
        let pct = 100 * aircraft.cyclesAccrued / max(1, aircraft.type.expectedLifespanCycles)
        return "\(aircraft.cyclesAccrued.formatted()) / \(aircraft.type.expectedLifespanCycles.formatted()) (\(pct)%)"
    }

    private func phaseLabel(_ state: FlightState) -> String {
        String(describing: state)
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .uppercased()
    }
}

#Preview {
    ContentView()
}
