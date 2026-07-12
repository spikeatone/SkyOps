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

    private let speeds: [Double] = [1, 5, 10, 25]
    private let fleetSizes: [Int] = [10, 60, 120, 250]

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
                    selectedID: selected?.id)
                .gesture(dragOrTapGesture.simultaneously(with: zoomGesture))

            hud
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Bottom stack: aircraft tooltip (when selected), then decision
            // cards — the sim NEVER pauses for any of these (core design
            // thesis). Stable IDs keep SwiftUI diffing instead of recreating
            // views each tick — the SwiftUI idiom for the prototype's
            // thrice-recurring "per-tick re-render destroys buttons" bug
            // family. Don't key these off tick.
            VStack(spacing: 10) {
                Spacer()
                if let ac = selected {
                    AircraftTooltip(aircraft: ac, sim: sim, tick: sim.tick) {
                        selectedID = nil
                    }
                }
                ForEach(sim.decisionQueue) { decision in
                    switch decision.kind {
                    case .aog:  AOGCard(decision: decision, sim: sim)
                    case .crew: CrewCard(decision: decision, sim: sim)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task {
            // Start the async tick loop; it cancels when the view goes away.
            await sim.run()
        }
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
                if !isDragging {
                    // genuine tap — set the selection exactly once
                    selectedID = sim.aircraft(atScreenPoint: v.location)?.id
                }
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
                    Text("SkyOps")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    Text("tick \(sim.tick)  ·  \(sim.fleetCount) aircraft")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("net " + netString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(sim.netRevenue < 0 ? Color(red: 1, green: 0x5C/255, blue: 0x5C/255)
                                                            : Color(red: 0x37/255, green: 1, blue: 0xB0/255))
                }
                Spacer()
                controlRow(speeds, isActive: { sim.speed == $0 }, label: speedLabel) {
                    sim.speed = $0
                }
            }
            if !sim.currentEvent.isNormal {
                economicEventBanner
            }
            HStack {
                Text("FLEET")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                controlRow(fleetSizes, isActive: { sim.fleetCount == $0 }, label: { "\($0)" }) {
                    sim.setFleetSize($0)
                }
                Spacer()
                Button { sim.resetCamera() } label: {
                    Text("RESET VIEW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(aircraft.origin.code) → \(aircraft.dest.code)")
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
