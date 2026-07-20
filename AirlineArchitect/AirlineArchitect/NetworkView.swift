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
    /// Persist the current game to its slot (SAVE button).
    var onSave: () -> Void = {}
    /// Save + return to the load menu (QUIT button).
    var onQuit: () -> Void = {}
    /// "Don't Open" on a previewed Ops route suggestion → back to the Ops tab.
    var onReturnToOps: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @Environment(\.horizontalSizeClass) private var hSize
    private var isPad: Bool { hSize == .regular }
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
    /// Tapped airport (info card) — mutually exclusive with a selected aircraft.
    @State private var selectedAirportCode: String?
    @State private var routeMode: RouteMode = .off
    @State private var flash: String?
    /// Which control-bar panel is open (mutually exclusive). Route-opening is
    /// its own flow (`routeMode`), not a panel.
    @State private var panel: NetPanel = .none
    /// Eye toggle — hides the Control Bar + Speed Bar for a clean map.
    @State private var showOverlays = true
    /// Easter-egg counter — bumped when the NETWORK title is tapped (plane fly-by).
    @State private var flyByID = 0

    enum NetPanel { case none, acquire, routes, hire, hubs }

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
            GeometryReader { geo in
                // Side-dock only when there's real width to spare (iPad in
                // landscape). Portrait iPad + iPhone keep the panels floating over
                // the map — a tall screen has no room for a 380pt rail alongside.
                let wide = geo.size.width > geo.size.height
                Group {
                    if isPad && wide {
                        // The map is ALWAYS laid out at the full available width;
                        // when a panel docks we simply show a narrower window onto
                        // it (clipped at the right) rather than resizing the map.
                        // That keeps the whole screen usable when idle AND avoids
                        // the old "flinch" — narrowing the card used to recompute
                        // the map's world-scale and visibly rescale the whole map.
                        let docked = hasSidePanel(selected)
                        let full = geo.size.width
                        let cardW = docked ? max(320, full - 390) : full
                        HStack(alignment: .top, spacing: 10) {
                            mapCard(selected: selected, sideDocked: true,
                                    mapWidth: full, cardWidth: cardW)
                            if docked {
                                sidePanelColumn(selected: selected)
                                    .frame(width: 380)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .animation(Motion.glide, value: panel)
                        .animation(Motion.glide, value: routeMode)
                        .animation(Motion.glide, value: selectedID)
                        .animation(Motion.glide, value: selectedAirportCode)
                    } else {
                        mapCard(selected: selected, sideDocked: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .background((isDark ? Sky.darkBG : Color.white).ignoresSafeArea())
        // A route suggestion tapped in Ops arrives via sim.pendingSuggestion
        // (it survives the tab switch). Drive the existing .confirm flow with
        // it, so opening/buying reuses all the normal machinery; the panel
        // relabels its buttons and the map draws the dashed preview.
        .onAppear { adoptSuggestionIfAny() }
        .onChange(of: sim.pendingSuggestion) { _, _ in adoptSuggestionIfAny() }
        // Fleet → ASSIGN TO NEW ROUTE arrives as sim.pendingAssignment; start the
        // pick flow immediately so the tab switch visibly does something.
        .onChange(of: sim.pendingAssignment?.id) { _, _ in adoptAssignmentIfAny() }
    }

    /// True when the iPad side rail actually has something to show — used to
    /// collapse the rail (and give the map the full width) when idle.
    private func hasSidePanel(_ selected: Aircraft?) -> Bool {
        panel != .none || isRouteConfirm || selected != nil || selectedAirport != nil
    }

    /// If Ops queued a route suggestion, enter the confirm step on it.

    /// Adopt a Fleet "assign this aircraft" intent: jump straight into the
    /// origin-pick step. Without this the tab switch looked like a no-op.
    private func adoptAssignmentIfAny() {
        guard sim.pendingAssignment != nil else { return }
        panel = .none
        selectedID = nil
        selectedAirportCode = nil
        routeMode = .pickOrigin
    }

    private func adoptSuggestionIfAny() {
        guard let sug = sim.pendingSuggestion else { return }
        panel = .none
        routeMode = .confirm(sug.origin, sug.dest)
    }

    /// The route flow's confirm step (step 3) — the one that docks into the rail.
    /// The pick-origin / pick-dest HINTS overlay the map instead (see mapCard),
    /// so picking airports doesn't cost the whole rail.
    private var isRouteConfirm: Bool {
        if case .confirm = routeMode { return true }
        return false
    }

    /// The pick-step instruction that floats over the map (nil outside pick steps).
    private var routePickHintText: String? {
        switch routeMode {
        case .pickOrigin:
            if let ac = sim.pendingAssignment {
                return "Assigning \(ac.tail): tap the first airport of the new city pair"
            }
            return "Step One: Tap one of the airports you want in the city pair"
        case .pickDest:
            if let ac = sim.pendingAssignment {
                return "Assigning \(ac.tail): now tap the other airport"
            }
            return "Step Two: Now tap the other airport pair"
        default:          return nil
        }
    }

    /// iPad: the docked right-hand rail. Mirrors the height treatment the panels
    /// had in the floating overlay — Acquire/Routes fill (they scroll internally),
    /// the shorter panels sit at the top.
    @ViewBuilder private func sidePanelColumn(selected: Aircraft?) -> some View {
        switch panel {
        case .acquire:
            BuyPanel(sim: sim, store: store, onUpgrade: { onUpgrade(store.capMessage(.fleet)) }, onBought: handleBought)
                .frame(maxHeight: .infinity, alignment: .top)
        case .routes:
            RoutesPanel(sim: sim).frame(maxHeight: .infinity, alignment: .top)
        case .hire:
            VStack(spacing: 0) {
                AddCrewPanel(sim: sim) { withAnimation(Motion.glide) { panel = .none } }
                Spacer(minLength: 0)
            }
        case .hubs:
            HubsPanel(sim: sim).frame(maxHeight: .infinity, alignment: .top)
        case .none:
            VStack(spacing: 8) {
                if isRouteConfirm {
                    routeFlowPanel
                } else if let ac = selected {
                    AircraftTooltip(aircraft: ac, sim: sim, tick: sim.tick) { withAnimation(Motion.glide) { selectedID = nil } }
                } else if let ap = selectedAirport {
                    AirportInfoCard(airport: ap, sim: sim)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Header (cash + NETWORK + eye/bell)

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                // Shorten the label when the ticker is also on this line, so a
                // wide cash figure + ticker + Save/Quit still fit without wrapping.
                Text(sim.isPublic ? "Cash:" : "Cash on hand:")
                    .font(.karla(15, .semibold))
                    .foregroundStyle(isDark ? .white : .black)
                    .lineLimit(1).fixedSize()
                Text(cashString)
                    .font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    // Rolling counter — the money ticks up/down instead of snapping.
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: sim.playerBalance)
                // Stock ticker — appears the moment the airline lists (designer:
                // "display on top next to the CASH figure").
                if let pc = sim.publicCompany { stockTicker(pc) }
                Spacer(minLength: 8)
                // Save / Quit — flushed right on the cash line (persistent on every tab).
                SaveQuitBar(onSave: onSave, onQuit: onQuit)
            }
            Divider().overlay((isDark ? Sky.onDarkStroke : Color(skyHex: 0xE2E8F0)).opacity(0.6))
            HStack {
                Text("NETWORK")
                    .font(.karla(22, .bold))
                    .foregroundStyle(titleColor)
                    // Easter egg: tap the title and a plane zips across the header.
                    .onTapGesture { flyByID += 1 }
                Spacer()
                Button { showOverlays.toggle() } label: {
                    Image(systemName: showOverlays ? "eye" : "eye.slash")
                        .font(.system(size: 18)).foregroundStyle(titleColor)
                }.pressable()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
            .overlay(alignment: .leading) {
                if flyByID > 0 { PlaneFlyBy().id(flyByID) }
            }
        }
    }


    private var cashString: String { cashLabel(sim.playerBalance) }

    /// Live stock ticker chip: SYMBOL + share price, coloured vs the IPO price
    /// (green = shareholders are up on the listing, red = under water).
    @ViewBuilder
    private func stockTicker(_ pc: PublicCompany) -> some View {
        let price = sim.displaySharePrice
        let up = price >= pc.ipoPrice
        let tint = up ? Sky.coreGreen : Sky.red
        HStack(spacing: 3) {
            Text(pc.ticker).font(.karla(13, .bold)).foregroundStyle(isDark ? .white : .black)
            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8)).foregroundStyle(tint)
            Text(String(format: "$%.2f", price)).font(.karla(13, .semibold)).foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.35), value: price)
        }
        .lineLimit(1).fixedSize()
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background((isDark ? Sky.navBarDark : Color(skyHex: 0xF1F1F1)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(tint.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Map card + overlays

    /// `mapWidth` lays the MAP out at a fixed width (the full landscape width)
    /// while `cardWidth` constrains the visible card — so docking a panel clips
    /// the map's right edge instead of rescaling it. Both nil = fill naturally.
    /// The bars are attached AFTER the card frame, so they always size to the
    /// visible width and never get clipped.
    private func mapCard(selected: Aircraft?, sideDocked: Bool,
                         mapWidth: CGFloat? = nil, cardWidth: CGFloat? = nil) -> some View {
        ZStack(alignment: .leading) {
            // LiveMap isolates the hot tick/camera reads to the map ALONE.
            // Reading sim.tick here (in mapCard, part of NetworkView's body)
            // made the whole card — including the docked Acquire panel's
            // ScrollView — re-render every sim-tick (~125×/sec at 25×), which
            // fought scrolling and dropped taps. Now only LiveMap re-renders per
            // tick; the control bar / panels / Acquire browser stay stable.
            LiveMap(sim: sim, selectedID: selected?.id,
                    highlightCodes: routeHighlights, mapWidth: mapWidth)
        }
        .frame(width: cardWidth, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Sky.onDarkStroke.opacity(0.5), lineWidth: 1))
        // The Canvas fills this card, so the card's local space IS the Canvas
        // draw space — read taps in the named map space to match exactly.
        .coordinateSpace(.named("mapCanvas"))
        .gesture(dragOrTapGesture.simultaneously(with: zoomGesture))
        // One overlay spanning the whole map: control bar pinned to the top,
        // speed/dev bars pinned to the bottom, and the panel region filling the
        // space between them. The Acquire browser fills that whole gap; the
        // shorter panels sit at the top with a Spacer holding the bars down.
        .overlay {
            VStack(spacing: 8) {
                controlBar.opacity(showOverlays ? 1 : 0).allowsHitTesting(showOverlays)
                // iPad docks panels into the side rail (see body); the map overlay
                // keeps only the bars. EXCEPTION: the route-pick hints (Step One /
                // Step Two) float over the map as a chip instead of taking the rail
                // — you're tapping the map, so the instruction belongs on it.
                if sideDocked {
                    if let hint = routePickHintText {
                        HStack(alignment: .top, spacing: 0) {
                            routeHint(hint).frame(maxWidth: 460)
                            Spacer(minLength: 0)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                } else {
                    panelMiddle(selected: selected)
                }
                if let flash {
                    Text(flash).font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white).padding(8)
                        .background(Color.black.opacity(0.75)).clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // Reserve the speed/dev bars' space even when hidden so the layout
                // doesn't shift when the overlays toggle.
                speedBar.opacity(showOverlays ? 1 : 0).allowsHitTesting(showOverlays)
                trafficBox.opacity(showOverlays ? 1 : 0).allowsHitTesting(showOverlays)
                #if DEBUG
                devToggles.opacity(showOverlays ? 1 : 0).allowsHitTesting(showOverlays)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(8)
            // Panels / route flow / tooltip glide instead of snapping.
            .animation(Motion.glide, value: panel)
            .animation(Motion.glide, value: routeMode)
            .animation(Motion.glide, value: selectedID)
            .animation(Motion.glide, value: selectedAirportCode)
            .animation(Motion.pop, value: flash)
        }
    }

    /// The panel region between the control bar and the speed bar. Acquire fills
    /// all of it; the others sit at the top with a Spacer pushing the bars down;
    /// with no panel open, the route-flow / tooltip dock just above the bars.
    @ViewBuilder private func panelMiddle(selected: Aircraft?) -> some View {
        // Panels glide in from the top and out; driven by the .animation on the
        // overlay stack (see mapCard). A slide+fade reads as the panel "opening".
        let slide = AnyTransition.move(edge: .top).combined(with: .opacity)
        switch panel {
        case .acquire:
            BuyPanel(sim: sim, store: store, onUpgrade: { onUpgrade(store.capMessage(.fleet)) }, onBought: handleBought)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(slide)
        case .routes:
            RoutesPanel(sim: sim).transition(slide)
            Spacer(minLength: 0)
        case .hire:
            AddCrewPanel(sim: sim) { withAnimation(Motion.glide) { panel = .none } }.transition(slide)
            Spacer(minLength: 0)
        case .hubs:
            HubsPanel(sim: sim).transition(slide)
            Spacer(minLength: 0)
        case .none:
            Spacer(minLength: 0)
            bottomDocked(selected: selected)
        }
    }

    /// The route-open flow and the aircraft tooltip, docked just above the bars
    /// when no control-bar panel is open.
    @ViewBuilder private func bottomDocked(selected: Aircraft?) -> some View {
        let rise = AnyTransition.move(edge: .bottom).combined(with: .opacity)
        VStack(spacing: 8) {
            routeFlowPanel
            if let ac = selected {
                AircraftTooltip(aircraft: ac, sim: sim, tick: sim.tick) { withAnimation(Motion.glide) { selectedID = nil } }
                    .transition(rise)
            } else if let ap = selectedAirport {
                AirportInfoCard(airport: ap, sim: sim).transition(rise)
            }
            // Alerts (AOG / crew / sell) live in the bell's Alerts modal, not here.
        }
    }

    /// The tapped airport's info card target — only in the clean state (no
    /// control-bar panel open, not mid route-pick), mirroring the aircraft tooltip.
    private var selectedAirport: Airport? {
        guard panel == .none, routeMode == .off, let code = selectedAirportCode else { return nil }
        return sim.airports.first { $0.code == code }
    }

    // MARK: - Network Control Bar

    private var controlBar: some View {
        // Content-sized labels with equal Spacers between them (NOT equal-width
        // columns) — equal columns put the label CENTERS evenly apart, but since
        // the labels differ in width the visible GAPS between them read as
        // uneven. Spacers make the inter-label gaps equal instead. No dividers
        // (Figma 2:1592).
        ViewThatFits(in: .horizontal) {
            controlBarRow(font: 13.5)
            controlBarRow(font: 12)
            controlBarRow(font: 11)
            controlBarRow(font: 10)
            controlBarRow(font: 9)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(barBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(barBorder, lineWidth: 1))
        .shadow(color: barShadow, radius: 3, y: 1)
    }

    /// One control-bar row at a uniform font — ViewThatFits picks the largest
    /// size whose full-text row fits, so every label matches (no per-label
    /// scaling / truncation). Content-sized labels + equal Spacers keep the gaps
    /// even (not equal-width columns, which read as uneven gaps).
    private func controlBarRow(font: CGFloat) -> some View {
        HStack(spacing: 0) {
            barButton("Acquire A/C", font: font, active: panel == .acquire) { toggle(.acquire) }
            Spacer(minLength: 5)
            barButton("Open Route", font: font, active: routeMode != .off) {
                panel = .none
                if routeMode != .off { sim.clearAssignment() }
                if routeMode == .off {
                    // Free tier: block a new route at the cap, show the paywall.
                    guard store.canOpenRoute(sim) else { onUpgrade(store.capMessage(.route)); return }
                    routeMode = .pickOrigin; selectedID = nil; selectedAirportCode = nil
                } else { routeMode = .off }
            }
            Spacer(minLength: 5)
            barButton("Routes", font: font, active: panel == .routes) { toggle(.routes) }
            Spacer(minLength: 5)
            barButton("Hire Crew", font: font, active: panel == .hire) { toggle(.hire) }
            // "Hubs" appears only once the player has established a hub — a 5th
            // control-bar item that would otherwise be dead weight.
            if !sim.hubs.isEmpty {
                Spacer(minLength: 5)
                barButton("Hubs", font: font, active: panel == .hubs) { toggle(.hubs) }
            }
        }
    }

    private func toggle(_ p: NetPanel) {
        routeMode = .off
        selectedID = nil            // never stack a control-bar panel over a tooltip
        selectedAirportCode = nil
        panel = (panel == p) ? .none : p
    }

    private func barButton(_ title: String, font: CGFloat, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.karla(font, .semibold))   // uniform across the row (chosen by ViewThatFits)
                .lineLimit(1)
                .foregroundStyle(active ? Sky.brightBlue : barText)
                .padding(.vertical, 8).padding(.horizontal, 6)
                .background(active ? Sky.brightBlue.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .pressable()
    }

    // MARK: - Sim Speed Control Bar (¼×–25×, ¼× rate-limited)

    private var speedBar: some View {
        HStack(spacing: 0) {
            ForEach(Simulation.speedOptions, id: \.self) { s in
                let active = sim.speed == s
                let quarterBlocked = (s == 0.25) && sim.quarterSpeedUsesRemaining == 0
                Button { sim.requestSpeed(s) } label: {
                    Text(speedLabel(s))
                        .font(.karla(15, .semibold))
                        .foregroundStyle(active ? .white : (quarterBlocked ? barText.opacity(0.35) : barText))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Sky.brightBlue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .pressable(0.9)
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

    /// Competitive-traffic slider in its OWN themed box — this is the
    /// player-facing control, so it ships in every build and sits snug under
    /// the speed bar (designer request: no dev-box gap in the player version).
    private var trafficBox: some View {
        trafficBar
            .padding(.vertical, 8).padding(.horizontal, 4)
            .background(barBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(barBorder, lineWidth: 1))
            .shadow(color: barShadow, radius: 3, y: 1)
    }

    /// DEV-only toggles (Pro / Demand) in their own box — compiled OUT of
    /// Release builds entirely (#if DEBUG at the call site), so TestFlight
    /// players never see them.
    private var devToggles: some View {
        VStack(spacing: 8) {
            devProToggle
            devDemandToggle
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

    /// DEV: flip the passenger-demand model (prototype) on/off to A/B it against
    /// the old flat 83.8% load factor. ON = load factor is an outcome of route
    /// demand vs. aircraft capacity.
    private var devDemandToggle: some View {
        HStack(spacing: 10) {
            Text("Demand (DEV)").font(.karla(12, .semibold))
                .foregroundStyle(titleColor).fixedSize()
            Spacer()
            Button { sim.useDemandModel.toggle() } label: {
                Text(sim.useDemandModel ? "ON" : "OFF")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 22)
                    .background(sim.useDemandModel ? Sky.coreGreen : Sky.onDarkStroke)
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
        case .pickOrigin, .pickDest:
            if let t = routePickHintText { routeHint(t) }
        case .confirm(let o, let d):
            if let origin = sim.airports.first(where: { $0.code == o }),
               let dest = sim.airports.first(where: { $0.code == d }) {
                // From an Ops suggestion → "Open This Route" / "Don't Open"
                // (Don't Open returns to Ops). From the manual pick flow →
                // the normal "Open route" / "Abandon".
                let fromSuggestion = sim.pendingSuggestion != nil
                RouteConfirmPanel(
                    sim: sim, origin: origin, dest: dest,
                    onOpen: { openConfirmedRoute(origin, dest) },
                    onCancel: {
                        if fromSuggestion { sim.clearSuggestion(); routeMode = .off; onReturnToOps() }
                        else { routeMode = .off; sim.clearAssignment() }
                    },
                    openTitle: fromSuggestion ? "Open This Route" : "Open route",
                    cancelTitle: fromSuggestion ? "Don't Open" : "Abandon",
                    subtitle: fromSuggestion ? "Suggested market · ~\(sim.routeDailyDemand(origin, dest).formatted()) pax/day" : nil)
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
                .foregroundStyle(titleColor)   // Dark Blue #4E67A0 in light
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(barBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(barBorder, lineWidth: 1))
        .shadow(color: barShadow, radius: 3, y: 1)
    }

    // MARK: - Handlers

    private func handleTap(at p: CGPoint) {
        // A tap on the visible map dismisses an open control-bar panel (Routes /
        // Hire Crew — Acquire fills the whole map so there's nothing to tap).
        if panel != .none {
            withAnimation(Motion.glide) { panel = .none }
            return
        }
        switch routeMode {
        case .off:
            // Tapping a NEW aircraft or a NEW airport shows its card; tapping the
            // one already shown, or empty map, DISMISSES. On a dense map an
            // "empty" tap often lands within tolerance of the shown airport — that
            // should close it, not re-open it.
            let tappedAircraft = sim.aircraft(atScreenPoint: p)
            let tappedAirport = sim.airport(atScreenPoint: p)
            if let ac = tappedAircraft, ac.id != selectedID {
                selectedID = ac.id; selectedAirportCode = nil
            } else if tappedAircraft == nil, let ap = tappedAirport, ap.code != selectedAirportCode {
                selectedAirportCode = ap.code; selectedID = nil
            } else {
                selectedID = nil; selectedAirportCode = nil
            }
        case .pickOrigin:
            if let ap = sim.airport(atScreenPoint: p) { routeMode = .pickDest(ap.code) }
        case .pickDest(let o):
            if let ap = sim.airport(atScreenPoint: p), ap.code != o { routeMode = .confirm(o, ap.code) }
        case .confirm:
            break
        }
    }

    /// `announce` is false when this follows an aircraft purchase (handleBought) —
    /// the jet whoosh already played, so we skip the "now boarding" voice to avoid
    /// the two sounds colliding.
    private func openConfirmedRoute(_ origin: Airport, _ dest: Airport, announce: Bool = true) {
        // A Fleet "assign this aircraft" intent targets ONE specific aircraft —
        // reassign() moves it even if it's already flying a route (archiving
        // that one). Otherwise this is a normal open, flown by the first spare.
        let targeted = sim.pendingAssignment
        guard let spare = targeted ?? sim.idleSpares.first else {
            showFlash("No spare aircraft — buy one to fly this route")
            panel = .acquire
            return
        }
        let result = targeted != nil
            ? sim.reassign(spare, from: origin, to: dest)
            : sim.openRoute(from: origin, to: dest, using: spare)
        switch result {
        case .success:
            Feedback.routeOpened(airline: sim.playerAirlineName, announce: announce)
            if spare.pendingRouteId != nil {
                showFlash("\(origin.code) ↔ \(dest.code) opened — \(spare.tail) moves over after it lands at \(spare.dest.code)")
            } else {
                showFlash("Route \(origin.code) ↔ \(dest.code) opened — \(spare.tail) assigned")
            }
            routeMode = .off; panel = .none
            sim.clearSuggestion(); sim.clearAssignment()
        case .insufficientFunds(let c): showFlash("Need $\(c.formatted()) to open this route")
        case .alreadyOpen:  showFlash("That route is already open")
        case .sameAirport:  showFlash("Pick two different airports")
        case .noSpare:      showFlash("No spare aircraft available")
        case .outOfRange:   showFlash("\(spare.type.name) can't fly this far — too far for its range")
        case .runwayTooShort(let code): showFlash("\(code)'s runway is too short for the \(spare.type.name)")
        }
    }

    private func handleBought(_ ac: Aircraft) {
        Feedback.aircraftAcquired(isFirst: sim.ownedCount == 1)
        let verb = ac.isLeased ? "Leased" : "Bought"
        showFlash("\(verb) \(ac.type.name) — now a spare")
        if case .confirm(let o, let d) = routeMode,
           let origin = sim.airports.first(where: { $0.code == o }),
           let dest = sim.airports.first(where: { $0.code == d }) {
            openConfirmedRoute(origin, dest, announce: false)   // jet whoosh already played
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
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

/// ADD CREW — hire crew into families the player owns (no Figma yet; dev-styled).
struct AddCrewPanel: View {
    let sim: Simulation
    var onClose: () -> Void = {}   // kept for the call site; the control-bar toggle closes it
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xE6E6E6) }
    private var titleC: Color     { isDark ? .white : .black }
    private var bodyC: Color      { isDark ? .white : Color(skyHex: 0x64748B) }
    private var labelC: Color     { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Crew").font(.karla(20, .heavy)).foregroundStyle(titleC)
            let families = sim.ownedFamilies
            if families.isEmpty {
                Text("No aircraft owned yet — nothing to crew.")
                    .font(.karla(14)).foregroundStyle(bodyC)
            } else {
                ForEach(Array(families.enumerated()), id: \.element) { i, fam in
                    if i > 0 { Rectangle().fill(cardBorder).frame(height: 1) }
                    let cost = sim.crewHireCost(family: fam)
                    let afford = sim.playerBalance >= cost
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FAMILY_LABELS[fam] ?? fam).font(.karla(14, .bold)).foregroundStyle(labelC)
                            Text("\(sim.crewCount(family: fam)) crew · \(sim.ownedCount(family: fam)) aircraft · \(money(cost))")
                                .font(.karla(14)).foregroundStyle(bodyC)
                        }
                        Spacer(minLength: 8)
                        Button { if sim.hireCrew(family: fam) != nil { Feedback.crewHired() } } label: {
                            Text("HIRE")
                                .font(.karla(12, .bold)).foregroundStyle(.white)
                                .frame(height: 24).padding(.horizontal, 8)
                                .background(afford ? Sky.coreGreen : Color(skyHex: 0xC9C9C9))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }.buttonStyle(.plain).disabled(!afford)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }
    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}

/// FUEL HEDGE — Figma "Fuel Hedge Card" (19:6920): title, an explainer, then a
/// 30/60/90-day premium row each with a green BUY. Closing is the highlighted
/// "Fuel Hedge" control-bar button (toggle), so the card carries no X — matching
/// the Figma.
struct FuelHedgePanel: View {
    let sim: Simulation
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke : Color(skyHex: 0xE6E6E6) }
    private var titleC: Color     { isDark ? .white : .black }
    private var bodyC: Color      { isDark ? .white : Color(skyHex: 0x64748B) }
    private var labelC: Color     { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fuel Hedge").font(.karla(20, .heavy)).foregroundStyle(titleC)

            if sim.ownedCount == 0 {
                Text("No aircraft owned yet — nothing to hedge. The premium is priced against your current fleet's real hold cost, so buy an aircraft first.")
                    .font(.karla(14)).foregroundStyle(bodyC)
            } else {
                let owned = sim.ownedCount
                Text("Fuel hedging locks your operating costs at a baseline for the chosen term, regardless of future oil-price spikes. Premium is based on your current fleet's real hold cost (\(owned) aircraft owned). Real airline fuel hedges work the same way, priced against expected consumption at purchase time and not adjusted later if your fleet size changes.")
                    .font(.karla(14)).foregroundStyle(bodyC)
                    .fixedSize(horizontal: false, vertical: true)

                divider

                if sim.fuelHedgeActive {
                    Text("Hedge active · \(sim.fuelHedgeDaysRemaining) days left")
                        .font(.karla(14, .bold)).foregroundStyle(Sky.coreGreen)
                    Text("A genuine price drop still helps you — the hedge only removes the upside risk, not the downside benefit.")
                        .font(.karla(14)).foregroundStyle(bodyC.opacity(0.9))
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
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func hedgeSlot(days: Int) -> some View {
        let premium = sim.fuelHedgePremium(days: days)
        let afford = sim.playerBalance >= premium
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(days)-day hedge:").font(.karla(14, .bold)).foregroundStyle(labelC)
                Text("$\(premium.formatted()) premium").font(.karla(14)).foregroundStyle(bodyC)
            }
            Spacer()
            Button { sim.buyFuelHedge(days: days) } label: {
                Text("BUY")
                    .font(.karla(12, .bold)).foregroundStyle(.white)
                    .frame(height: 24).padding(.horizontal, 8)
                    .background(afford ? Sky.coreGreen : Color(skyHex: 0xC9C9C9))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }.buttonStyle(.plain).disabled(!afford)
        }
    }

    private var divider: some View {
        Rectangle().fill(cardBorder).frame(height: 1)
    }
}

/// The map, isolated so ONLY it depends on the hot per-tick/camera values.
/// Reading `sim.tick` / `sim.cameraZoom` / `sim.cameraCenter` in NetworkView's
/// body re-rendered the whole map card — including any docked panel's
/// ScrollView — on every sim-tick, which made the Acquire list stick while
/// scrolling and dropped taps at speed. Keeping these reads inside a dedicated
/// child struct means the tick change re-runs only THIS body; the overlays
/// (control bar, route/Acquire panels) stay put unless their own inputs change.
/// The map still needs `tick` as a real value input (the Phase-1 freeze bug),
/// which it gets here.
private struct LiveMap: View {
    let sim: Simulation
    let selectedID: UUID?
    let highlightCodes: Set<String>
    let mapWidth: CGFloat?
    var body: some View {
        MapView(sim: sim, tick: sim.tick,
                cameraZoom: sim.cameraZoom, cameraCenter: sim.cameraCenter,
                selectedID: selectedID, highlightCodes: highlightCodes)
            .frame(width: mapWidth)
    }
}
