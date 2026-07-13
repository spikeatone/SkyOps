//
//  NetworkView.swift
//  SkyOps — the NETWORK tab (the live map + game controls)
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
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

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

    private let fleetSizes: [Int] = [10, 60, 120, 250]

    private var routeHighlights: Set<String> {
        switch routeMode {
        case .off, .pickOrigin: return []
        case .pickDest(let o):  return [o]
        case .confirm(let o, let d): return [o, d]
        }
    }

    var body: some View {
        let selected = sim.aircraft.first { $0.id == selectedID }
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
                    .foregroundStyle(Sky.brightBlue)
                Spacer()
                Button { showOverlays.toggle() } label: {
                    Image(systemName: showOverlays ? "eye" : "eye.slash")
                        .font(.system(size: 18)).foregroundStyle(Sky.brightBlue)
                }.buttonStyle(.plain)
                Button { /* events feed — not built yet */ } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 18)).foregroundStyle(Sky.brightBlue)
                        .overlay(alignment: .topTrailing) {
                            if !sim.decisionQueue.isEmpty {
                                Circle().fill(Sky.red).frame(width: 8, height: 8).offset(x: 3, y: -2)
                            }
                        }
                }.buttonStyle(.plain)
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
                if showOverlays { speedBar; trafficBar }
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
            case .acquire: BuyPanel(sim: sim, onBought: handleBought)
            case .routes:  RoutesPanel(sim: sim)
            case .hire:    AddCrewPanel(sim: sim) { panel = .none }
            case .hedge:   FuelHedgePanel(sim: sim) { panel = .none }
            case .none:    EmptyView()
            }
            routeFlowPanel
            if let ac = selected {
                AircraftTooltip(aircraft: ac, sim: sim, tick: sim.tick) { selectedID = nil }
            }
            ForEach(sim.decisionQueue) { decision in
                switch decision.kind {
                case .aog:  AOGCard(decision: decision, sim: sim)
                case .crew: CrewCard(decision: decision, sim: sim)
                case .sell: SellCard(decision: decision, sim: sim)
                }
            }
        }
    }

    // MARK: - Network Control Bar

    private var controlBar: some View {
        HStack(spacing: 0) {
            barButton("Acquire A/C", active: panel == .acquire) { toggle(.acquire) }
            barDivider
            barButton("Open Route", active: routeMode != .off) {
                panel = .none
                if routeMode == .off { routeMode = .pickOrigin; selectedID = nil } else { routeMode = .off }
            }
            barDivider
            barButton("Routes", active: panel == .routes) { toggle(.routes) }
            barDivider
            barButton("Hire Crew", active: panel == .hire) { toggle(.hire) }
            barDivider
            barButton("Fuel Hedge", active: panel == .hedge) { toggle(.hedge) }
        }
        .padding(.vertical, 4)
        .background(Sky.navBarDark.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Sky.onDarkStroke.opacity(0.7), lineWidth: 1))
    }

    private func toggle(_ p: NetPanel) {
        routeMode = .off
        panel = (panel == p) ? .none : p
    }

    private func barButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.karla(12, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)   // long labels (Acquire A/C) shrink to fit rather than crowd
                .foregroundStyle(active ? Sky.brightBlue : Sky.lightBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7).padding(.horizontal, 5)
                .background(active ? Sky.brightBlue.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var barDivider: some View {
        Rectangle().fill(Sky.onDarkStroke.opacity(0.5)).frame(width: 1, height: 16)
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
                        .foregroundStyle(active ? .white : (quarterBlocked ? Sky.lightBlue.opacity(0.35) : Sky.lightBlue))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Sky.brightBlue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Sky.navBarDark.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Sky.onDarkStroke.opacity(0.7), lineWidth: 1))
    }

    private func speedLabel(_ s: Double) -> String {
        switch s {
        case 0.25: return "¼×"
        case 0.5:  return "½×"
        default:   return s == s.rounded() ? "\(Int(s))×" : "\(s)×"
        }
    }

    /// DEV stress-test traffic control (not in the Figma) — kept behind the eye
    /// overlays so it's out of the way in the clean map view.
    private var trafficBar: some View {
        HStack(spacing: 6) {
            Text("DEV · TRAFFIC").font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Sky.lightBlue.opacity(0.6))
            ForEach(fleetSizes, id: \.self) { n in
                Button { sim.setFleetSize(sim.stressTestCount == n ? 0 : n) } label: {
                    Text("\(n)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(sim.stressTestCount == n ? .white : Sky.lightBlue.opacity(0.7))
                        .padding(.vertical, 3).padding(.horizontal, 7)
                        .background(sim.stressTestCount == n ? Sky.brightBlue.opacity(0.7) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Route-opening flow

    @ViewBuilder private var routeFlowPanel: some View {
        switch routeMode {
        case .off:
            EmptyView()
        case .pickOrigin:
            routeHint("OPEN ROUTE — tap the ORIGIN airport")
        case .pickDest:
            routeHint("OPEN ROUTE — tap the DESTINATION airport")
        case .confirm(let o, let d):
            if let origin = sim.airports.first(where: { $0.code == o }),
               let dest = sim.airports.first(where: { $0.code == d }) {
                RouteConfirmPanel(sim: sim, origin: origin, dest: dest,
                                  onOpen: { openConfirmedRoute(origin, dest) },
                                  onBuy: { panel = .acquire },
                                  onCancel: { routeMode = .off })
            }
        }
    }

    private func routeHint(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
            Button("Cancel") { routeMode = .off }.font(.system(size: 12, design: .monospaced))
        }
        .foregroundStyle(.white).padding(12)
        .background(Sky.navBarDark.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Sky.brightBlue.opacity(0.6), lineWidth: 1))
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

/// FUEL HEDGE — buy a call option on fuel cost (Figma restyle comes next).
struct FuelHedgePanel: View {
    let sim: Simulation
    let onClose: () -> Void
    var body: some View {
        NetPanelBox(title: "FUEL HEDGE", onClose: onClose) {
            if sim.ownedCount == 0 {
                Text("No aircraft owned yet — nothing to hedge.")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else if sim.fuelHedgeActive {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hedge active · \(sim.fuelHedgeDaysRemaining) days left")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Sky.coreGreen)
                    Text("Caps a fuel-price spike at today's cost. A genuine price drop still helps you — the hedge only removes the upside risk, not the downside benefit.")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                }
            } else {
                ForEach(Simulation.fuelHedgeDurations, id: \.self) { days in
                    let premium = sim.fuelHedgePremium(days: days)
                    let afford = sim.playerBalance >= premium
                    HStack {
                        Text("\(days) days").font(.system(size: 12, weight: .medium, design: .monospaced))
                        Spacer()
                        Button { sim.buyFuelHedge(days: days) } label: {
                            Text("Buy · \(compactMoney(premium))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.vertical, 6).padding(.horizontal, 10)
                                .background((afford ? Sky.lightYellow : Color.white).opacity(afford ? 0.22 : 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6)).opacity(afford ? 1 : 0.4)
                        }.buttonStyle(.plain).disabled(!afford)
                    }
                    .padding(.vertical, 3)
                }
                Text("A call option: pay now to cap a future spike. If no spike hits, the premium is a sunk cost — not free insurance.")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
            }
        }
    }
}
