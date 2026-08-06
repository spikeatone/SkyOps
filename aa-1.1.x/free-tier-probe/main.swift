import Foundation

// Can a FREE player (caps: 6 aircraft / 5 routes) actually reach a hub?
// Hubs need 5 routes touching ONE airport, so the 5-route cap is exactly enough
// IF they fly hub-and-spoke and can afford the hub. Drives the REAL sim.
@MainActor func run() {
    let sim = Simulation()
    sim.nameAirline("Probe Air", tailCode: "PB")
    let start = sim.playerBalance
    print("Starting capital: $\(start / 1_000_000)M")

    let fleetCap = 6, routeCap = 5
    let types = AircraftType.all.sorted { $0.purchasePrice < $1.purchasePrice }
    print("Cheapest: " + types.prefix(3).map { "\($0.id) $\(String(format: "%.1f", Double($0.purchasePrice)/1e6))M" }.joined(separator: ", "))

    // A mid-size US airport as the hub (what a starter would realistically pick).
    guard let home = sim.airport("SLC") else { return }
    print("Hub candidate: \(home.code) (\(home.info?.city ?? "?"))")

    let spokes = sim.airports
        .filter { $0.code != home.code }
        .sorted { home.greatCircleNM(to: $0) < home.greatCircleNM(to: $1) }

    var opened = 0, bought = 0
    for spoke in spokes {
        if opened >= routeCap || bought >= fleetCap { break }
        let dist = home.greatCircleNM(to: spoke)
        guard let t = types.first(where: { Double($0.rangeNM) >= dist }) else { continue }
        guard sim.playerBalance >= t.purchasePrice else { print("  out of cash after \(bought) a/c"); break }
        guard let ac = sim.buyAircraft(t) else { continue }
        bought += 1
        let r = sim.openRoute(from: home, to: spoke, using: ac)
        if case .success = r { opened += 1 } else { bought -= 0; print("  \(home.code)-\(spoke.code) refused: \(r)") }
    }
    let spent = start - sim.playerBalance
    print("Bought \(bought) a/c, opened \(opened) routes. Spent $\(String(format: "%.1f", Double(spent)/1e6))M, left $\(String(format: "%.1f", Double(sim.playerBalance)/1e6))M")
    print("Routes at \(home.code): \(sim.routesAt(home.code)) (hub needs \(Simulation.hubMinRoutes)) · eligible: \(sim.hubEligible(home.code))")
    let cost = sim.hubEstablishCost(home)
    print("Hub cost: $\(String(format: "%.1f", Double(cost)/1e6))M · affordable immediately: \(sim.playerBalance >= cost)")

    for d in 1...180 {
        for _ in 0..<1440 { sim.advanceTick() }
        if d % 60 == 0 { print("  day \(d): cash $\(String(format: "%.1f", Double(sim.playerBalance)/1e6))M") }
        if sim.playerBalance >= cost, sim.hubEligible(home.code), sim.hubs.isEmpty {
            sim.establishHub(at: home.code)
            print("HUB ESTABLISHED at \(home.code) on sim-day \(d) ✓")
            break
        }
    }
    print(sim.hubs.isEmpty ? "NO HUB after 180 days ✗" : "Free player reaches the network effect ✓")
}
MainActor.assumeIsolated { run() }
