//  OfferSpreadVerify.swift — AIRPORT RECRUITMENT OFFER SPREAD
//
//  Guards the fix for a PAYING CUSTOMER's report: all 35 of his airport incentives
//  were routes into ATL. The destination used to be `hubs.first(where: served…)` on
//  a traffic-sorted list — i.e. always the single busiest airport in the player's
//  network, so a big-hub player saw the same destination forever. Reproduced at
//  100% before the fix.
//
//  The bias toward a served hub is CORRECT (an airport courting you wants a link to
//  your network) — it just has to be a bias, not a constant. These assertions pin
//  both halves: real spread, and a hub bias that survives.
//
//  RUN (entry file must be named main.swift):
//    mkdir -p /tmp/osv && cp aa-1.1.x/OfferSpreadVerify.swift /tmp/osv/main.swift
//    cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/osv/
//    swiftc -O -DDEBUG -o /tmp/osv/osv \
//      AirlineArchitect/AirlineArchitect/Sim/*.swift \
//      AirlineArchitect/AirlineArchitect/Persistence.swift \
//      /tmp/osv/RepaintVerifyStubs.swift /tmp/osv/main.swift && /tmp/osv/osv

import Foundation

@MainActor func run() {
    var pass = 0, fail = 0
    func check(_ l: String, _ c: Bool, _ d: String = "") {
        if c { pass += 1; print("  ok   \(l)") } else { fail += 1; print("  FAIL \(l) \(d)") }
    }

    // A big-hub player, like the customer who reported this.
    let sim = Simulation()
    sim.nameAirline("Hub Air", tailCode: "HB")
    sim.devInjectCash(3_000_000_000)
    func open(_ a: String, _ b: String) {
        guard let o = sim.airports.first(where: { $0.code == a }),
              let d = sim.airports.first(where: { $0.code == b }),
              let t = AircraftType.all.first(where: { $0.id == "A320" }),
              let ac = sim.buyAircraft(t) else { return }
        _ = sim.openRoute(from: o, to: d, using: ac)
    }
    for c in ["ORD","DFW","DEN","LAX","JFK","SEA","MIA"] { open("ATL", c) }
    for (a,b) in [("ORD","DEN"),("LAX","SEA"),("JFK","MIA")] { open(a, b) }
    let served = Set(sim.playerRoutes.flatMap { [$0.originCode, $0.destCode] })

    var destCounts: [String: Int] = [:]
    var seen = Set<String>()
    for _ in 0..<(1440 * 2000) {
        sim.advanceTick()
        for d in sim.decisionQueue where d.kind == .airportOffer {
            guard let p = d.pitch, !seen.contains(d.id) else { continue }
            seen.insert(d.id)
            destCounts[p.destCode, default: 0] += 1
        }
    }
    let total = destCounts.values.reduce(0, +)
    check("offers actually generate", total >= 30, "only \(total)")

    // THE REGRESSION: no single destination may dominate. Pre-fix this was 100%.
    let topShare = Double(destCounts.values.max() ?? 0) / Double(max(1, total))
    check("no single destination dominates", topShare < 0.35,
          String(format: "top dest is %.0f%% of offers", topShare * 100))
    check("destinations are varied", destCounts.count >= 8, "only \(destCounts.count) distinct")

    // ...but the hub bias must SURVIVE — offers should still mostly connect to the
    // player's network, which is what makes them worth accepting.
    let servedShare = Double(destCounts.filter { served.contains($0.key) }.values.reduce(0,+))
        / Double(max(1, total))
    check("still biased toward hubs the player serves", servedShare > 0.35,
          String(format: "only %.0f%% land on a served hub", servedShare * 100))
    check("but not exclusively served hubs", servedShare < 0.95,
          String(format: "%.0f%% — new markets never offered", servedShare * 100))

    print("\n\(pass) passed, \(fail) failed")
    exit(fail == 0 ? 0 : 1)
}
MainActor.assumeIsolated { run() }
