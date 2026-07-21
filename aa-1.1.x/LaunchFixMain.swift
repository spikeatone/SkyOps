import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("Test", tailCode: "MR")
    sim.devInjectCash(2_000_000_000)

    guard let type = AircraftType.all.first(where: { $0.bodyType == .narrowbody }),
          let ac = sim.buyAircraft(type),
          let o = sim.airport("DEN"), let d = sim.airport("ATL") else { print("setup failed"); return }
    guard case .success = sim.openRoute(from: o, to: d, using: ac), let r = sim.playerRoutes.first
    else { print("route open failed"); return }
    // Crew it up so it flies mostly continuously.
    for _ in 0..<3 { _ = sim.hireCrew(family: type.family) }

    // Fly it long enough to exceed the history cap.
    for _ in 0..<600_000 { sim.advanceTick(); if r.flights > 66 { break } }

    // --- Cap + running aggregates ---
    check(r.flights > Route.maxHistory, "route flew > maxHistory legs (\(r.flights))")
    check(r.history.count == Route.maxHistory, "history capped at \(Route.maxHistory) (got \(r.history.count))")
    // Running lifetime aggregates tie to the independently-tracked cumulativeNet
    // (owned/non-leased route: net == revenue − fees − opCost each leg).
    check(r.revenueTotal - r.feesTotal - r.opCostTotal == r.cumulativeNet,
          "aggregates tie to cumulativeNet: \(r.revenueTotal)-\(r.feesTotal)-\(r.opCostTotal) vs \(r.cumulativeNet)")
    check(r.totalRevenue == r.revenueTotal, "totalRevenue uses running field")
    check(r.averageLoadPct >= 0 && r.averageLoadPct <= 100, "avg load sane (\(r.averageLoadPct))")
    // The running totals include DROPPED flights (exceed the retained window's sum).
    let retainedRev = r.history.reduce(0) { $0 + $1.revenue }
    check(r.revenueTotal > retainedRev, "lifetime revenue > retained-window revenue (dropped flights counted)")
    // Record ids are the GLOBAL flight index, still increasing after the cap.
    check(r.history.last!.id == r.flights - 1, "last record id is the global flight index")
    check(sim.cashInvariantResidual() == 0, "cash invariant holds after heavy flying")

    // --- save/load round-trip: aggregates preserved, history stays capped ---
    let snap = sim.snapshot()
    let restored = Simulation()
    restored.configure(viewport: CGSize(width: 400, height: 800))
    restored.restore(from: snap)
    guard let rr = restored.playerRoutes.first else { print("restore lost route"); return }
    check(rr.revenueTotal == r.revenueTotal, "revenueTotal persists")
    check(rr.feesTotal == r.feesTotal && rr.opCostTotal == r.opCostTotal, "fees/opcost totals persist")
    check(rr.flights == r.flights, "flights persists")
    check(rr.history.count == Route.maxHistory, "restored history stays capped")
    check(rr.totalRevenue == r.totalRevenue && rr.averageLoadPct == r.averageLoadPct, "aggregates match after reload")

    // --- back-compat: a pre-1.1 save (nil totals + FULL uncapped history) ---
    var oldSnap = snap
    if !oldSnap.routes.isEmpty {
        oldSnap.routes[0].revenueTotal = nil
        oldSnap.routes[0].feesTotal = nil
        oldSnap.routes[0].opCostTotal = nil
        oldSnap.routes[0].loadFactorSum = nil
        oldSnap.routes[0].flights = 100
        oldSnap.routes[0].history = (0..<100).map { i in
            FlightRecordSave(id: i, tick: i * 400, tail: "N1MR", revenue: 10, fees: 2, operatingCost: 3,
                             leaseCostEstimate: 0, net: 5, pax: 100, seats: 150, loadFactor: 0.5, cumulativeNet: (i + 1) * 5)
        }
        let old = Simulation()
        old.configure(viewport: CGSize(width: 400, height: 800))
        old.restore(from: oldSnap)
        if let or = old.playerRoutes.first(where: { $0.id == oldSnap.routes[0].id }) {
            check(or.revenueTotal == 1000, "legacy: revenueTotal recomputed from full history (\(or.revenueTotal))")
            check(or.feesTotal == 200 && or.opCostTotal == 300, "legacy: fees/opcost recomputed")
            check(abs(or.loadFactorSum - 50.0) < 0.001, "legacy: loadFactorSum recomputed")
            check(or.averageLoadPct == 50, "legacy: avg load correct (\(or.averageLoadPct))")
            check(or.history.count == Route.maxHistory, "legacy: oversized history capped on load")
        } else { check(false, "legacy route not restored") }
    }

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
