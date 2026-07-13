//
//  ContentView.swift
//  SkyOps
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

    // Gesture accumulators (cumulative values → per-frame deltas).
    @State private var dragLast: CGSize = .zero
    @State private var magLast: CGFloat = 1
    /// True once a touch has moved far enough to be a pan (vs a tap). Tracked
    /// so ONE gesture handles both — separate tap + drag recognizers fought
    /// each other (the tap fired, then the drag cleared it: "flash then gone").
    @State private var isDragging = false

    /// Tap-selected aircraft (tooltip subject). UI state, not sim state.
    @State private var selectedID: UUID?

    /// Route-opening flow + buy panel (UI state).
    @State private var routeMode: RouteMode = .off
    @State private var showBuyPanel = false
    @State private var flash: String?

    private let speeds: [Double] = [1, 5, 10, 25]
    private let fleetSizes: [Int] = [10, 60, 120, 250]

    /// Airports the route picker is currently highlighting.
    private var routeHighlights: Set<String> {
        switch routeMode {
        case .off, .pickOrigin: return []
        case .pickDest(let o):  return [o]
        case .confirm(let o, let d): return [o, d]
        }
    }

    var body: some View {
        // Resolve the selection every render — a shrunk fleet must not leave
        // the tooltip pointing at an aircraft that no longer exists (same
        // stale-reference family as the decision-card cleanup).
        let selected = sim.aircraft.first(where: { $0.id == selectedID })

        ZStack(alignment: .top) {
            MapView(sim: sim,
                    tick: sim.tick,
                    cameraZoom: sim.cameraZoom,
                    cameraCenter: sim.cameraCenter,
                    selectedID: selected?.id,
                    highlightCodes: routeHighlights)
                .gesture(dragOrTapGesture.simultaneously(with: zoomGesture))

            hud
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Bottom stack: buy panel / route-confirm / route-hint, then the
            // aircraft tooltip, then decision cards. The sim NEVER pauses for
            // any of these. Stable IDs keep SwiftUI diffing instead of
            // recreating views each tick (don't key these off tick).
            VStack(spacing: 10) {
                Spacer()
                if let flash {
                    Text(flash).font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white).padding(8)
                        .background(Color.black.opacity(0.7)).clipShape(Capsule())
                }
                if showBuyPanel {
                    BuyPanel(sim: sim, onBought: handleBought)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task { await sim.run() }
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
                                  onBuy: { showBuyPanel = true },
                                  onCancel: { routeMode = .off })
            }
        }
    }

    private func routeHint(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
            Button("Cancel") { routeMode = .off }
                .font(.system(size: 12, design: .monospaced))
        }
        .foregroundStyle(.white).padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.6), lineWidth: 1))
    }

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
            showBuyPanel = true
            return
        }
        switch sim.openRoute(from: origin, to: dest, using: spare) {
        case .success:
            showFlash("Route \(origin.code) ↔ \(dest.code) opened — \(spare.tail) assigned")
            routeMode = .off; showBuyPanel = false
        case .insufficientFunds(let c):
            showFlash("Need $\(c.formatted()) to open this route")
        case .alreadyOpen:   showFlash("That route is already open")
        case .sameAirport:   showFlash("Pick two different airports")
        case .noSpare:       showFlash("No spare aircraft available")
        }
    }

    private func handleBought(_ ac: Aircraft) {
        showFlash("Bought \(ac.type.name) — now a spare")
        // If we're mid-route-open, try to complete it with the new aircraft.
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

    /// One gesture for both pan and tap-select, so they can't fight. A touch
    /// that moves past the threshold pans; a touch that ends without moving is
    /// a tap → select the aircraft under it (or clear on empty map).
    private var dragOrTapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !isDragging, hypot(v.translation.width, v.translation.height) > 8 {
                    isDragging = true
                    dragLast = v.translation        // no jump on the frame it flips
                }
                if isDragging {
                    let delta = CGSize(width: v.translation.width - dragLast.width,
                                       height: v.translation.height - dragLast.height)
                    sim.pan(by: delta)
                    dragLast = v.translation
                }
            }
            .onEnded { v in
                if !isDragging { handleTap(at: v.location) }
                isDragging = false
                dragLast = .zero
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

    private var hud: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(balanceString)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(sim.playerBalance < 0 ? Color(red: 1, green: 0x5C/255, blue: 0x5C/255)
                                                              : Color(red: 0x37/255, green: 1, blue: 0xB0/255))
                    Text("\(sim.ownedCount) owned · \(sim.playerRoutes.count) routes · tick \(sim.tick)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                controlRow(speeds, isActive: { sim.speed == $0 }, label: speedLabel) {
                    sim.speed = $0
                }
            }
            if !sim.currentEvent.isNormal {
                economicEventBanner
            }
            // Primary player actions.
            HStack(spacing: 8) {
                actionButton("ACQUIRE", active: showBuyPanel) {
                    showBuyPanel.toggle()
                }
                actionButton("OPEN ROUTE", active: routeMode != .off) {
                    if routeMode == .off { routeMode = .pickOrigin; selectedID = nil }
                    else { routeMode = .off }
                }
                Spacer()
                Button { sim.resetCamera() } label: {
                    Text("RESET VIEW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.vertical, 6).padding(.horizontal, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            // Competitor background traffic — real other airlines, to make the
            // airspace feel alive. Tap to set how busy the skies are.
            HStack {
                Text("TRAFFIC")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                controlRow(fleetSizes, isActive: { sim.stressTestCount == $0 }, label: { "\($0)" }) {
                    sim.setFleetSize(sim.stressTestCount == $0 ? 0 : $0)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func actionButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.vertical, 7).padding(.horizontal, 12)
                .background(active ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var balanceString: String {
        let v = sim.playerBalance
        let sign = v < 0 ? "−" : ""
        let a = abs(v)
        if a >= 1_000_000 { return sign + "$" + String(format: "%.2fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }

    /// Active economic-event banner — red when it hurts the airline (higher
    /// costs or lower fares), green when it helps.
    private var economicEventBanner: some View {
        let e = sim.currentEvent
        let hurts = e.costMultiplier > 1 || e.fareMultiplier < 1
        let color = hurts ? Color(red: 1, green: 0x5C/255, blue: 0x5C/255)
                          : Color(red: 0x37/255, green: 1, blue: 0xB0/255)
        return HStack(spacing: 8) {
            Text(e.label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text("cost \(pct(e.costMultiplier)) · fare \(pct(e.fareMultiplier)) · demand \(pct(e.loadMultiplier)) · \(sim.eventDaysLeft)d left")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.5), lineWidth: 1))
    }

    private func pct(_ m: Double) -> String { "\(Int((m * 100).rounded()))%" }

    /// A row of pill buttons for a set of values.
    private func controlRow<T: Hashable>(_ values: [T],
                                         isActive: @escaping (T) -> Bool,
                                         label: @escaping (T) -> String,
                                         action: @escaping (T) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { v in
                Button { action(v) } label: {
                    Text(label(v))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 34)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 2)
                        .background(isActive(v) ? Color.accentColor.opacity(0.85)
                                                : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func speedLabel(_ s: Double) -> String {
        s == s.rounded() ? "\(Int(s))×" : "\(s)×"
    }

    /// Compact signed money for the HUD (e.g. "+$1.2M", "−$340k").
    private var netString: String {
        let v = sim.netRevenue
        let sign = v < 0 ? "−" : "+"
        let a = abs(v)
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }
}

private let heldColor = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

/// Shared decision-card chrome (red-bordered, titled, subject line + buttons).
/// The sim never pauses while a card is up (core design thesis).
struct DecisionCardChrome<Buttons: View>: View {
    let title: String
    let subject: String
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(heldColor).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(heldColor)
            }
            Text(subject)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) { buttons() }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(heldColor.opacity(0.45), lineWidth: 1))
    }
}

/// A single decision-card action button.
struct CardButton: View {
    let label: String
    var emphasized = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(emphasized ? heldColor.opacity(0.22) : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct AOGCard: View {
    let decision: Simulation.Decision
    let sim: Simulation
    var body: some View {
        let ac = decision.aircraft
        DecisionCardChrome(title: "AOG — GROUNDED FOR MAINTENANCE",
                           subject: "\(ac.tail) · \(ac.type.name) · at \(ac.origin.code)") {
            CardButton(label: "Expedite · $15,000 · ready now", emphasized: true) {
                sim.resolveAOGExpedite(decision)
            }
            CardButton(label: "Standard · $3,000 · ~3hr") {
                sim.resolveAOGStandard(decision)
            }
        }
    }
}

struct CrewCard: View {
    let decision: Simulation.Decision
    let sim: Simulation
    var body: some View {
        let ac = decision.aircraft
        let hasReserve = sim.hasReserve(for: ac)
        DecisionCardChrome(title: "NO LEGAL CREW AVAILABLE",
                           subject: "\(ac.tail) · \(ac.type.name) · at \(ac.origin.code)") {
            CardButton(label: hasReserve ? "Call reserve · $5,000" : "No reserves left",
                       emphasized: true, disabled: !hasReserve) {
                sim.resolveCrewReserve(decision)
            }
            CardButton(label: "Wait for next crew") {
                sim.resolveCrewWait(decision)
            }
        }
    }
}

struct SellCard: View {
    let decision: Simulation.Decision
    let sim: Simulation
    var body: some View {
        let ac = decision.aircraft
        let pct = 100 * ac.cyclesAccrued / max(1, ac.type.expectedLifespanCycles)
        DecisionCardChrome(title: "NEARING END OF SERVICE LIFE",
                           subject: "\(ac.tail) · \(ac.type.name) · \(pct)% of lifespan") {
            CardButton(label: "Sell · $\(sim.sellValue(of: ac).formatted())", emphasized: true) {
                sim.resolveSell(decision)
            }
            CardButton(label: "Keep flying") {
                sim.resolveSellKeep(decision)
            }
        }
    }
}

/// The route-opening flow's UI state.
enum RouteMode: Equatable {
    case off
    case pickOrigin
    case pickDest(String)
    case confirm(String, String)
}

/// Scrollable buy list (cheapest first); each row's Buy disables when unaffordable.
struct BuyPanel: View {
    let sim: Simulation
    let onBought: (Aircraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACQUIRE AIRCRAFT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(AircraftType.all.sorted { $0.purchasePrice < $1.purchasePrice }) { t in
                        let afford = sim.playerBalance >= t.purchasePrice
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.name).font(.system(size: 12, weight: .medium, design: .monospaced))
                                Text("\(t.seats) seats · \(FAMILY_LABELS[t.family] ?? t.family)")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                if let ac = sim.buyAircraft(t) { onBought(ac) }
                            } label: {
                                Text("$\((t.purchasePrice / 1_000_000))M")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background((afford ? Color(red: 0x37/255, green: 1, blue: 0xB0/255)
                                                        : Color.white).opacity(afford ? 0.22 : 0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .opacity(afford ? 1 : 0.4)
                            }
                            .buttonStyle(.plain).disabled(!afford)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 4).padding(.horizontal, 6)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

/// Confirm panel for a picked origin→dest pair.
struct RouteConfirmPanel: View {
    let sim: Simulation
    let origin: Airport
    let dest: Airport
    let onOpen: () -> Void
    let onBuy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let cost = sim.routeOpeningCost(origin, dest)
        let spares = sim.idleSpares.count
        VStack(alignment: .leading, spacing: 8) {
            Text("OPEN ROUTE  \(origin.code) ↔ \(dest.code)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            Text("cost $\(cost.formatted()) · slots \(origin.slotsAvailable)+\(dest.slotsAvailable) free · \(spares) spare\(spares == 1 ? "" : "s")")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                CardButton(label: spares > 0 ? "Open Route" : "Buy an aircraft first",
                           emphasized: true, disabled: spares > 0 && sim.playerBalance < cost) {
                    spares > 0 ? onOpen() : onBuy()
                }
                CardButton(label: "Cancel") { onCancel() }
            }
        }
        .foregroundStyle(.white).padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.6), lineWidth: 1))
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

    private let heldColor = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)

    private let othersColor = Color(red: 0xD7/255, green: 0x67/255, blue: 0xFF/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Competitor traffic shows the operating airline; the player's own
            // fleet doesn't need a name here.
            if let airline = aircraft.airlineName {
                Text(airline.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(othersColor)
            }
            HStack {
                Text(aircraft.isIdleSpare ? "SPARE · at \(aircraft.origin.code)"
                                          : "\(aircraft.origin.code) → \(aircraft.dest.code)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            row("TAIL", aircraft.tail)
            row("TYPE", aircraft.type.name)
            row("STATUS", statusText, valueColor: aircraft.isHeld ? heldColor : .white)

            // Crew / load / cycles / economics are the PLAYER's operational
            // detail only — a rival's books aren't visible. Ported from the
            // prototype's deliberately-reduced background-traffic tooltip.
            if aircraft.airlineName == nil {
                row("CREW", crewText, valueColor: crewValueColor)
                row("LOAD", loadText)
                row("CYCLES", cyclesText)

                Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 2)

                let econ = sim.legEconomics(for: aircraft)
                row("REVENUE", money(econ.revenue))
                row("FEES", "−" + money(econ.fees))
                row("OP COST", "−" + money(econ.operatingCost))
                row("NET / LEG", (econ.net < 0 ? "−" : "") + money(abs(econ.net)),
                    valueColor: econ.net < 0 ? heldColor : climbColor)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func row(_ label: String, _ value: String, valueColor: Color = .white) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(valueColor.opacity(0.92))
            Spacer(minLength: 0)
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
    private var crewText: String {
        if aircraft.holdReason == .crew { return "none — awaiting legal crew" }
        guard let d = sim.crewDuty(for: aircraft) else { return "—" }
        return String(format: "%.1f / %.0f duty hrs", d.used, d.max)
    }

    private var crewValueColor: Color {
        if aircraft.holdReason == .crew { return heldColor }
        // amber as the crew nears its duty limit
        if let d = sim.crewDuty(for: aircraft), d.used > d.max * 0.8 {
            return Color(red: 0xFF/255, green: 0xB3/255, blue: 0x00/255)
        }
        return .white
    }

    private let climbColor = Color(red: 0x37/255, green: 0xFF/255, blue: 0xB0/255)

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
