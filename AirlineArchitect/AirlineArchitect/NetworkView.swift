//
//  NetworkView.swift
//  Airline Architect — the NETWORK tab (the live map + game controls)
//
//  Built to the designer's Figma (SkyOps-Production, network light 2:1592 /
//  dark 2:1994). Chrome: a Cash-on-hand + NETWORK header (eye toggles the
//  overlay bars, bell is the events glyph), a Network Control Bar (Acquire /
//  Open Route / Routes / Hire Crew / Fuel Hedge), the map as a bounded rounded
//  card, and a Sim Speed Control Bar (¼×–25×). The five-tab bottom nav is the
//  standard TabView shell in ContentView; only NETWORK carries these overlay
//  bars. Colours/typography from the Figma tokens (Karla approximated with the
//  system font for now — bundle the OFL family for pixel-exact type).
//

import SwiftUI

extension Color {
    init(skyHex hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Figma design tokens (SkyOps-Production).
enum Sky {
    static let brightBlue  = Color(skyHex: 0x0EA5E9)   // NETWORK title / interactive / active
    static let coreGreen   = Color(skyHex: 0x10B981)   // cash + profit
    static let lightBlue   = Color(skyHex: 0xBDE0FF)
    static let lightYellow = Color(skyHex: 0xFFC73B)
    static let onDarkStroke = Color(skyHex: 0x4C5D88)
    static let navBarDark  = Color(skyHex: 0x1F232D)
    static let darkBG      = Color(skyHex: 0x2B303D)
    static let red         = Color(skyHex: 0xFF5C5C)
}

struct NetworkView: View {
    let sim: Simulation
    var store: Store
    var onBell: () -> Void = {}
    var onUpgrade: (String?) -> Void = { _ in }
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    /// Section-header / icon blue — matches the other tabs (Figma "Dark Blue"
    /// #4E67A0 in light, light-blue in dark). Was the brighter #0EA5E9.
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }

    // Floating map-overlay bars (control bar / speed bar / dev controls). Dark
    // slate on dark; on the white light map, opaque white + a grey border +
    // soft shadow so they read as clean controls instead of black boxes (Figma
    // 2:1592 uses white@80% + #497AA5 "Core Blue" text — opaque here since the
    // map is white, not the Figma's dark screenshot).
    private var barBG: Color     { isDark ? Sky.navBarDark.opacity(0.92) : .white }
    private var barBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.7) : Color(skyHex: 0xC9C9C9) }
    private var barText: Color   { isDark ? Sky.lightBlue : Color(skyHex: 0x497AA5) }
    private var barShadow: Color { isDark ? .clear : .black.opacity(0.12) }

    // Gesture accumulators.
    @State private var dragLast: CGSize = .zero
    @State private var magLast: CGFloat = 1
    @State private var isDragging = false

    // Game UI state.
    @State private var selectedID: UUID?
    @State private var routeMode: RouteMode = .off
    @State private var flash: String?
    /// Which control-bar panel is open (mutually exclusive). Route-opening is
    /// its own flow (`routeMode`), not a panel.
    @State private var panel: NetPanel = .none
    /// Eye toggle — hides the Control Bar + Speed Bar for a clean map.
    @State private var showOverlays = true

    enum NetPanel { case none, acquire, routes, hire, hedge }

    private var routeHighlights: Set<String> {
        switch routeMode {
        case .off, .pickOrigin: return []
        case .pickDest(let o):  return [o]
        case .confirm(let o, let d): return [o, d]
        }
    }

    var body: some View {
        // Show the aircraft tooltip ONLY in the clean state — no control-bar
        // panel open, not mid route-pick. Otherwise a tall tooltip stacked on a
        // panel/route-confirm box grows up over the top control bar and blocks it.
        let selected = (panel == .none && routeMode == .off) ? sim.aircraft.first { $0.id == selectedID } : nil
        VStack(spacing: 10) {
            header
            mapCard(selected: selected)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .background((isDark ? Sky.darkBG : Color.white).ignoresSafeArea())
    }

    // MARK: - Header (cash + NETWORK + eye/bell)

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:")
                    .font(.karla(15, .semibold))
                    .foregroundStyle(isDark ? .white : .black)
                Text(cashString)
                    .font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                Spacer()
            }
            Divider().overlay((isDark ? Sky.onDarkStroke : Color(skyHex: 0xE2E8F0)).opacity(0.6))
            HStack {
                Text("NETWORK")
                    .font(.karla(22, .bold))
                    .foregroundStyle(titleColor)
                Spacer()
                Button { showOverlays.toggle() } label: {
                    Image(systemName: showOverlays ? "eye" : "eye.slash")
                        .font(.system(size: 18)).foregroundStyle(titleColor)
                }.buttonStyle(.plain)
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    private var cashString: String {
        let v = sim.playerBalance, a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }

    // MARK: - Map card + overlays

    private func mapCard(selected: Aircraft?) -> some View {
        ZStack {
            MapView(sim: sim, tick: sim.tick,
                    cameraZoom: sim.cameraZoom, cameraCenter: sim.cameraCenter,
                    selectedID: selected?.id, highlightCodes: routeHighlights)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Sky.onDarkStroke.opacity(0.5), lineWidth: 1))
        // The Canvas fills this card, so the card's local space IS the Canvas
        // draw space — read taps in the named map space to match exactly.
        .coordinateSpace(.named("mapCanvas"))
        .gesture(dragOrTapGesture.simultaneously(with: zoomGesture))
        .overlay(alignment: .top) {
            if showOverlays { controlBar.padding(8) }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                bottomStack(selected: selected)
                if showOverlays { speedBar; devControls }
            }
            .padding(8)
        }
    }

    /// Panels / tooltip / decision cards, stacked above the speed bar.
    @ViewBuilder private func bottomStack(selected: Aircraft?) -> some View {
        VStack(spacing: 8) {
            if let flash {
                Text(flash).font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white).padding(8)
                    .background(Color.black.opacity(0.75)).clipShape(Capsule())
            }
            switch panel {
            case .acquire: BuyPanel(sim: sim, store: store, onUpgrade: { onUpgrade(store.capMessage(.fleet)) }, onBought: handleBought)
            case .routes:  RoutesPanel(sim: sim)
            case .hire:    AddCrewPanel(sim: sim) { panel = .none }
            case .hedge:   FuelHedgePanel(sim: sim)
            case .none:    EmptyView()
            }
            routeFlowPanel
            if let ac = selected {
                AircraftTooltip(aircraft: ac, sim: sim, tick: sim.tick) { selectedID = nil }
            }
            // Alerts (AOG / crew / sell) now live in the bell's Alerts modal
            // (any tab), not as always-on map cards — see AlertsModal.
        }
    }

    // MARK: - Network Control Bar

    private var controlBar: some View {
        // Even columns, no dividers (matches Figma 2:1592 — the dividers made the
        // equal-width columns read as unevenly spaced).
        HStack(spacing: 0) {
            barButton("Acquire A/C", active: panel == .acquire) { toggle(.acquire) }
            barButton("Open Route", active: routeMode != .off) {
                panel = .none
                if routeMode == .off {
                    // Free tier: block a new route at the cap, show the paywall.
                    guard store.canOpenRoute(sim) else { onUpgrade(store.capMessage(.route)); return }
                    routeMode = .pickOrigin; selectedID = nil
                } else { routeMode = .off }
            }
            barButton("Routes", active: panel == .routes) { toggle(.routes) }
            barButton("Hire Crew", active: panel == .hire) { toggle(.hire) }
            barButton("Fuel Hedge", active: panel == .hedge) { toggle(.hedge) }
        }
        .padding(4)
        .background(barBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(barBorder, lineWidth: 1))
        .shadow(color: barShadow, radius: 3, y: 1)
    }

    private func toggle(_ p: NetPanel) {
        routeMode = .off
        selectedID = nil            // never stack a control-bar panel over a tooltip
        panel = (panel == p) ? .none : p
    }

    private func barButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.karla(12, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)   // long labels (Acquire A/C) shrink to fit rather than crowd
                .foregroundStyle(active ? Sky.brightBlue : barText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7).padding(.horizontal, 5)
                .background(active ? Sky.brightBlue.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sim Speed Control Bar (¼×–25×, ¼× rate-limited)

    private var speedBar: some View {
        HStack(spacing: 0) {
            ForEach(Simulation.speedOptions, id: \.self) { s in
                let active = sim.speed == s
                let quarterBlocked = (s == 0.25) && sim.quarterSpeedUsesRemaining == 0
                Button { sim.requestSpeed(s) } label: {
                    Text(speedLabel(s))
                        .font(.karla(13, .semibold))
                        .foregroundStyle(active ? .white : (quarterBlocked ? barText.opacity(0.35) : barText))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Sky.brightBlue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(barBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(barBorder, lineWidth: 1))
        .shadow(color: barShadow, radius: 3, y: 1)
    }

    private func speedLabel(_ s: Double) -> String {
        switch s {
        case 0.25: return "¼×"
        case 0.5:  return "½×"
        default:   return s == s.rounded() ? "\(Int(s))×" : "\(s)×"
        }
    }

    /// DEV controls (Competitive Traffic + Pro toggle) in a themed container so
    /// they don't get lost on the white light map.
    private var devControls: some View {
        VStack(spacing: 8) {
            trafficBar
            devProToggle
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .background(barBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(barBorder, lineWidth: 1))
        .shadow(color: barShadow, radius: 3, y: 1)
    }

    /// DEV: flip the Pro entitlement to exercise free-cap vs. unlocked play
    /// without a real purchase. Removed once RevenueCat drives `store.isPro`.
    private var devProToggle: some View {
        HStack(spacing: 10) {
            Text("Pro (DEV)").font(.karla(12, .semibold))
                .foregroundStyle(titleColor).fixedSize()
            Spacer()
            Button { store.isPro.toggle() } label: {
                Text(store.isPro ? "ON" : "OFF")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 22)
                    .background(store.isPro ? Sky.coreGreen : Sky.onDarkStroke)
                    .clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }

    /// Competitive-traffic control — a continuous slider (0…250) setting how
    /// much background (rival-airline) traffic fills the airspace. Kept behind
    /// the eye overlays, out of the way in the clean map view.
    private var trafficBar: some View {
        HStack(spacing: 10) {
            Text("Competitive Traffic").font(.karla(12, .semibold))
                .foregroundStyle(titleColor)
                .fixedSize()
            trafficSlider
            Text("\(sim.stressTestCount)").font(.karla(12, .bold))
                .foregroundStyle(isDark ? .white : Color(skyHex: 0x497AA5))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 6)
    }

    /// Compact custom slider — a small themed handle (native Slider's thumb is
    /// too large/distracting). Handle: #2B303D on dark, white on light.
    private var trafficSlider: some View {
        let handleD: CGFloat = 13
        return GeometryReader { geo in
            let usable = max(1, geo.size.width - handleD)
            let frac = CGFloat(sim.stressTestCount) / 250
            let x = frac * usable
            ZStack(alignment: .leading) {
                Capsule().fill(Sky.onDarkStroke.opacity(0.45)).frame(height: 3)
                Capsule().fill(Sky.brightBlue).frame(width: x + handleD / 2, height: 3)
                Circle()
                    .fill(isDark ? Sky.darkBG : Color.white)
                    .frame(width: handleD, height: handleD)
                    .overlay(Circle().stroke(isDark ? Sky.brightBlue.opacity(0.9) : Color(skyHex: 0xC9C9C9), lineWidth: 1.5))
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let t = max(0, min(1, (v.location.x - handleD / 2) / usable))
                sim.setFleetSize(Int((t * 250 / 5).rounded()) * 5)
            })
        }
        .frame(height: handleD)
    }

    // MARK: - Route-opening flow

    @ViewBuilder private var routeFlowPanel: some View {
        switch routeMode {
        case .off:
            EmptyView()
        case .pickOrigin:
            routeHint("Step One: Tap one of the airports you want in the city pair")
        case .pickDest:
            routeHint("Step Two: Now tap the other airport pair")
        case .confirm(let o, let d):
            if let origin = sim.airports.first(where: { $0.code == o }),
               let dest = sim.airports.first(where: { $0.code == d }) {
                RouteConfirmPanel(sim: sim, origin: origin, dest: dest,
                                  onOpen: { openConfirmedRoute(origin, dest) },
                                  onCancel: { routeMode = .off })
            }
        }
    }

    /// Figma "Alert box" (5:8040 / 19:6705): a solid dark bar with a single
    /// Karla-Bold instruction line. Cancel is the highlighted "Open Route"
    /// control-bar button (tapping it again exits the flow).
    private func routeHint(_ text: String) -> some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.karla(14, .bold))
                .foregroundStyle(Sky.lightBlue)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sky.navBarDark)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Handlers

    private func handleTap(at p: CGPoint) {
        switch routeMode {
        case .off:
            selectedID = sim.aircraft(atScreenPoint: p)?.id
        case .pickOrigin:
            if let ap = sim.airport(atScreenPoint: p) { routeMode = .pickDest(ap.code) }
        case .pickDest(let o):
            if let ap = sim.airport(atScreenPoint: p), ap.code != o { routeMode = .confirm(o, ap.code) }
        case .confirm:
            break
        }
    }

    private func openConfirmedRoute(_ origin: Airport, _ dest: Airport) {
        guard let spare = sim.idleSpares.first else {
            showFlash("No spare aircraft — buy one to fly this route")
            panel = .acquire
            return
        }
        switch sim.openRoute(from: origin, to: dest, using: spare) {
        case .success:
            showFlash("Route \(origin.code) ↔ \(dest.code) opened — \(spare.tail) assigned")
            routeMode = .off; panel = .none
        case .insufficientFunds(let c): showFlash("Need $\(c.formatted()) to open this route")
        case .alreadyOpen:  showFlash("That route is already open")
        case .sameAirport:  showFlash("Pick two different airports")
        case .noSpare:      showFlash("No spare aircraft available")
        }
    }

    private func handleBought(_ ac: Aircraft) {
        let verb = ac.isLeased ? "Leased" : "Bought"
        showFlash("\(verb) \(ac.type.name) — now a spare")
        if case .confirm(let o, let d) = routeMode,
           let origin = sim.airports.first(where: { $0.code == o }),
           let dest = sim.airports.first(where: { $0.code == d }) {
            openConfirmedRoute(origin, dest)
        }
    }

    private func showFlash(_ msg: String) {
        flash = msg
        Task { try? await Task.sleep(for: .seconds(3)); if flash == msg { flash = nil } }
    }

    // MARK: - Map gestures

    /// One gesture handles both pan and tap-select. Read in the named map space
    /// — the Canvas fills the card, so that space matches the Canvas draw space.
    private var dragOrTapGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("mapCanvas"))
            .onChanged { v in
                if !isDragging, hypot(v.translation.width, v.translation.height) > 8 {
                    isDragging = true; dragLast = v.translation
                }
                if isDragging {
                    let delta = CGSize(width: v.translation.width - dragLast.width,
                                       height: v.translation.height - dragLast.height)
                    sim.pan(by: delta); dragLast = v.translation
                }
            }
            .onEnded { v in
                if !isDragging { handleTap(at: v.location) }
                isDragging = false; dragLast = .zero
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let factor = v.magnification / magLast
                sim.zoom(by: factor, anchor: v.startLocation)
                magLast = v.magnification
            }
            .onEnded { _ in magLast = 1 }
    }
}

/// Shared dev-styled panel chrome (restyled to Figma in the per-panel pass).
struct NetPanelBox<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6)).padding(4)
                }.buttonStyle(.plain)
            }
            content()
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

/// ADD CREW — hire crew into families the player owns (no Figma yet; dev-styled).
struct AddCrewPanel: View {
    let sim: Simulation
    let onClose: () -> Void
    var body: some View {
        NetPanelBox(title: "ADD CREW", onClose: onClose) {
            let families = sim.ownedFamilies
            if families.isEmpty {
                Text("No aircraft owned yet — nothing to crew.")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(families, id: \.self) { fam in
                    let cost = sim.crewHireCost(family: fam)
                    let afford = sim.playerBalance >= cost
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(FAMILY_LABELS[fam] ?? fam)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                            Text("\(sim.crewCount(family: fam)) crew · \(sim.ownedCount(family: fam)) aircraft")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { _ = sim.hireCrew(family: fam) } label: {
                            Text("Hire · \(compactMoney(cost))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.vertical, 6).padding(.horizontal, 10)
                                .background((afford ? Sky.coreGreen : Color.white).opacity(afford ? 0.22 : 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6)).opacity(afford ? 1 : 0.4)
                        }.buttonStyle(.plain).disabled(!afford)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }
}

/// FUEL HEDGE — Figma "Fuel Hedge Card" (19:6920): title, an explainer, then a
/// 30/60/90-day premium row each with a green BUY. Closing is the highlighted
/// "Fuel Hedge" control-bar button (toggle), so the card carries no X — matching
/// the Figma.
struct FuelHedgePanel: View {
    let sim: Simulation
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fuel Hedge").font(.karla(20, .heavy)).foregroundStyle(.white)

            if sim.ownedCount == 0 {
                Text("No aircraft owned yet — nothing to hedge. The premium is priced against your current fleet's real hold cost, so buy an aircraft first.")
                    .font(.karla(14)).foregroundStyle(.white)
            } else {
                let owned = sim.ownedCount
                Text("Fuel hedging locks your operating costs at a baseline for the chosen term, regardless of future oil-price spikes. Premium is based on your current fleet's real hold cost (\(owned) aircraft owned). Real airline fuel hedges work the same way, priced against expected consumption at purchase time and not adjusted later if your fleet size changes.")
                    .font(.karla(14)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                divider

                if sim.fuelHedgeActive {
                    Text("Hedge active · \(sim.fuelHedgeDaysRemaining) days left")
                        .font(.karla(14, .bold)).foregroundStyle(Sky.coreGreen)
                    Text("A genuine price drop still helps you — the hedge only removes the upside risk, not the downside benefit.")
                        .font(.karla(14)).foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(Simulation.fuelHedgeDurations.enumerated()), id: \.element) { i, days in
                        if i > 0 { divider }
                        hedgeSlot(days: days)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sky.navBarDark)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Sky.onDarkStroke, lineWidth: 1))
    }

    private func hedgeSlot(days: Int) -> some View {
        let premium = sim.fuelHedgePremium(days: days)
        let afford = sim.playerBalance >= premium
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(days)-day hedge:").font(.karla(14, .bold)).foregroundStyle(Sky.lightBlue)
                Text("$\(premium.formatted()) premium").font(.karla(14)).foregroundStyle(.white)
            }
            Spacer()
            Button { sim.buyFuelHedge(days: days) } label: {
                Text("BUY")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .frame(height: 24).padding(.horizontal, 8)
                    .background(Sky.coreGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(afford ? 1 : 0.4)
            }.buttonStyle(.plain).disabled(!afford)
        }
    }

    private var divider: some View {
        Rectangle().fill(Sky.onDarkStroke).frame(height: 1)
    }
}
