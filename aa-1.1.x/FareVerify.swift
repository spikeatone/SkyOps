//  FareVerify.swift — PER-ROUTE FARE POSITIONING (the fare lever)
//
//  Verifies the fare lever end-to-end on the REAL sim: the static math, the
//  behavioral demand response, persistence, legacy-save default, and that the
//  cash invariant is untouched.
//
//  MEASUREMENT DESIGN (worth keeping): economic events fire ~15%/day and scale
//  fare AND load multipliers, which poisons any sequential A/B. So the
//  behavioral checks run TWO routes in the SAME sim at the SAME time — one
//  demand-capped trunk, one thin — and measure RATIOS between them, normalized
//  by a both-Standard baseline phase. Event multipliers, the ±10% wiggles,
//  reputation drift, and the hub bonus all apply to both routes identically,
//  so they cancel in the ratio; only the per-route fare level survives.
//  Competition entry and the rival fare-war event DON'T hit both routes
//  equally — the harness zeroes competition each tick and discards any phase a
//  fare war touched (rare; it restarts collection).
//
//  RUN (entry file must be named main.swift):
//    mkdir -p /tmp/fare && cp aa-1.1.x/FareVerify.swift /tmp/fare/main.swift
//    cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/fare/
//    swiftc -O -DDEBUG -o /tmp/fare/fare \
//      $(ls AirlineArchitect/AirlineArchitect/Sim/*.swift | grep -vE 'AircraftIcon|SVGPath') \
//      AirlineArchitect/AirlineArchitect/Persistence.swift \
//      /tmp/fare/RepaintVerifyStubs.swift /tmp/fare/main.swift && /tmp/fare/fare

import Foundation

@MainActor func run() {
    var pass = 0, fail = 0
    func check(_ l: String, _ c: Bool, _ d: String = "") {
        if c { pass += 1; print("  ok   \(l)") } else { fail += 1; print("  FAIL \(l) \(d)") }
    }

    // ---- Static math -------------------------------------------------------
    check("Standard is exactly neutral",
          Simulation.fareMultiplier(level: 2) == 1.0 && Simulation.fareDemandResponse(level: 2) == 1.0
          && Simulation.fareShareShift(level: 2) == 1.0)
    check("levels are clamped", Simulation.fareMultiplier(level: -3) == Simulation.fareLevelMultipliers[0]
          && Simulation.fareMultiplier(level: 99) == Simulation.fareLevelMultipliers[4])
    let flagshipDrop = Simulation.fareDemandResponse(level: 4)   // ≈ 0.828
    let discountGain = Simulation.fareDemandResponse(level: 0)   // ≈ 1.206
    check("raising sheds demand", flagshipDrop > 0.78 && flagshipDrop < 0.88, "\(flagshipDrop)")
    check("cutting wins demand back", discountGain > 1.14 && discountGain < 1.28, "\(discountGain)")
    // The asymmetry that keeps the lever from being globally solvable: the
    // uncapped revenue multiplier fare×demand is BELOW 1 for a raise, ~1 for a cut.
    check("raise is net-negative uncapped", Simulation.fareMultiplier(level: 4) * flagshipDrop < 0.985)
    check("cut is ~revenue-neutral uncapped", abs(Simulation.fareMultiplier(level: 0) * discountGain - 1.0) < 0.05)
    check("discount defends share / flagship concedes",
          Simulation.fareShareShift(level: 0) > 1.0 && Simulation.fareShareShift(level: 4) < 1.0)

    // ---- Behavioral: trunk + thin route in one sim -------------------------
    let sim = Simulation()
    sim.nameAirline("Fare Air", tailCode: "FZ")
    sim.devInjectCash(2_000_000_000)
    guard let a320 = AircraftType.all.first(where: { $0.id == "A320" }) else {
        print("  FAIL no A320 type"); exit(1)
    }
    // Pick pairs from the data, not hardcoded codes: trunk = raw demand/seat
    // buffer ≥ 1.6 (stays capped even at Flagship's −17%), thin = buffer
    // 0.50–0.62 (room to move both directions without hitting the cap).
    let usable = sim.airports.filter { $0.info != nil && Airport.curfews[$0.code] == nil
                                       && !Airport.isLeisure($0.code) }
    func buffer(_ o: Airport, _ d: Airport) -> Double {
        Double(sim.routeDailyDemand(o, d)) / 2.0 / Double(a320.seats)
    }
    var trunkPair: (Airport, Airport)? = nil, thinPair: (Airport, Airport)? = nil
    outer: for o in usable {
        for d in usable where o.code != d.code {
            let nm = o.greatCircleNM(to: d)
            guard nm > 300, nm < Double(a320.rangeNM) * 0.8 else { continue }
            let b = buffer(o, d)
            if trunkPair == nil, b >= 1.6 { trunkPair = (o, d) }
            if thinPair == nil, b >= 0.50, b <= 0.62,
               trunkPair.map({ $0.0.code != o.code && $0.1.code != d.code }) ?? true { thinPair = (o, d) }
            if trunkPair != nil && thinPair != nil { break outer }
        }
    }
    guard let (tO, tD) = trunkPair, let (nO, nD) = thinPair else {
        print("  FAIL no suitable pairs"); exit(1)
    }
    guard let trunkAC = sim.buyAircraft(a320), let thinAC = sim.buyAircraft(a320) else {
        print("  FAIL buy"); exit(1)
    }
    _ = sim.openRoute(from: tO, to: tD, using: trunkAC)
    _ = sim.openRoute(from: nO, to: nD, using: thinAC)
    guard sim.playerRoutes.count == 2 else { print("  FAIL routes didn't open"); exit(1) }
    let trunk = sim.playerRoutes[0], thin = sim.playerRoutes[1]
    for _ in 0..<6 { _ = sim.hireCrew(family: a320.family) }   // no crew-hold stalls

    /// Run until each route completes `legs` more flights; collect mean load +
    /// mean realized fare-per-pax per route. Discards and restarts if the rival
    /// fare-war event touches either route mid-phase.
    func collect(_ legs: Int) -> (trunkLoad: Double, thinLoad: Double, trunkFare: Double, thinFare: Double) {
        while true {
            // History-count markers, NOT FlightRecord.id — the id is the GLOBAL
            // flight index (the documented cap gotcha). Total legs here stay
            // under Route.maxHistory, so the log never trims mid-measurement.
            let startT = trunk.history.count, startN = thin.history.count
            var warred = false
            var guardTicks = 0
            while (trunk.history.count - startT < legs || thin.history.count - startN < legs) && guardTicks < 1_200_000 {
                sim.advanceTick(); guardTicks += 1
                if sim.fareWarRouteId != nil { warred = true }
                for r in [trunk, thin] where r.competitionLevel > 0 {
                    r.competitionLevel = 0; r.competitors = []
                }
            }
            if guardTicks >= 1_200_000 { print("  FAIL phase stalled"); exit(1) }
            if warred { continue }   // event polluted the phase — re-collect
            func stats(_ r: Route, _ start: Int) -> (Double, Double) {
                let recs = Array(r.history.dropFirst(start).prefix(legs))
                let load = recs.map { $0.loadFactor }.reduce(0, +) / Double(recs.count)
                let fare = recs.map { Double($0.revenue) / Double(max(1, $0.pax)) }.reduce(0, +) / Double(recs.count)
                return (load, fare)
            }
            let (tl, tf) = stats(trunk, startT), (nl, nf) = stats(thin, startN)
            return (tl, nl, tf, nf)
        }
    }

    // Phase 0 — both Standard (baseline).
    let p0 = collect(16)
    check("trunk really is demand-capped", p0.trunkLoad > 0.78, "\(p0.trunkLoad)")
    check("thin really is uncapped", p0.thinLoad < 0.70, "\(p0.thinLoad)")
    let r0 = p0.thinLoad / p0.trunkLoad
    let f0 = p0.trunkFare / p0.thinFare

    // Phase 1 — trunk→Flagship, thin→Discount.
    sim.setFareLevel(4, for: trunk.id)
    sim.setFareLevel(0, for: thin.id)
    let p1 = collect(16)
    // Realized fare ratio: (flagship trunk)/(discount thin), normalized by the
    // baseline ratio → expect 1.15/0.85 ≈ 1.353. Events cancel across routes.
    let fareShift = (p1.trunkFare / p1.thinFare) / f0
    check("fares actually move (Flagship vs Discount)", fareShift > 1.22 && fareShift < 1.50,
          String(format: "%.3f (expect ≈1.35)", fareShift))
    // Load ratio: discount lifts the thin route's load; the capped trunk holds →
    // thin/trunk rises vs baseline (expect ≈ ×1.2).
    let loadShift1 = (p1.thinLoad / p1.trunkLoad) / r0
    check("discount fills the thin route", loadShift1 > 1.08, String(format: "%.3f (expect ≈1.2)", loadShift1))
    check("flagship keeps the capped trunk full", p1.trunkLoad > 0.90 * p0.trunkLoad,
          String(format: "%.2f vs %.2f", p1.trunkLoad, p0.trunkLoad))

    // Phase 2 — trunk→Standard, thin→Flagship: a raise on an UNCAPPED route
    // sheds real load (expect thin/trunk ≈ ×0.83 of baseline).
    sim.setFareLevel(2, for: trunk.id)
    sim.setFareLevel(4, for: thin.id)
    let p2 = collect(16)
    let loadShift2 = (p2.thinLoad / p2.trunkLoad) / r0
    check("flagship sheds demand on an uncapped route", loadShift2 < 0.93,
          String(format: "%.3f (expect ≈0.83)", loadShift2))

    // ---- Persistence -------------------------------------------------------
    sim.setFareLevel(4, for: trunk.id)
    var snap = sim.snapshot()
    let restored = Simulation()
    restored.restore(from: snap)
    check("fareLevel survives save/load",
          restored.playerRoutes.first(where: { $0.id == trunk.id })?.fareLevel == 4)
    // Legacy save (no fareLevel key) → Standard.
    if let i = snap.routes.firstIndex(where: { $0.id == thin.id }) {
        snap.routes[i].fareLevel = nil
        let legacy = Simulation()
        legacy.restore(from: snap)
        check("legacy save defaults to Standard",
              legacy.playerRoutes.first(where: { $0.id == thin.id })?.fareLevel == Route.standardFareLevel)
    } else { check("legacy save defaults to Standard", false, "route not in snapshot") }
    // Raw decode with the key absent (the decodeSafe path itself).
    let bare = try? JSONDecoder().decode(RouteSave.self, from: Data("{}".utf8))
    check("RouteSave decodes without the key", bare != nil && bare?.fareLevel == nil)

    // ---- The lever moves amounts, never accounting -------------------------
    check("cash invariant holds", sim.cashInvariantResidual() == 0,
          "residual \(sim.cashInvariantResidual())")

    print("\n\(pass) passed, \(fail) failed")
    exit(fail == 0 ? 0 : 1)
}
MainActor.assumeIsolated { run() }
