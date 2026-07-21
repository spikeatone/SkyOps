import Foundation

// START-REGION PARITY via the OPPORTUNITY LANDSCAPE (robust; avoids the fragile
// growth-autopilot that kept tripping on the known early-game regional-jet trap).
//
// The real "trap or cakewalk" question for a $20M starter: does the region OFFER
// viable early routes? For each region we ask its own region-aware opportunity
// finder for the top markets, keep only those a STARTER-AFFORDABLE aircraft
// (<= $20M: turboprops + cheap regional jets) can physically fly (range + runway),
// then FLY the best few and measure real per-flight net / load. Cash is injected
// so we measure ROUTE economics cleanly (the separate affordability gauntlet is
// captured by "how many viable starter routes exist" + which aircraft is needed).

let env = ProcessInfo.processInfo.environment
let REGIONS: [(String, Airline.PlayerRegion)] = [
    ("North America ", .northAmerica),
    ("Europe        ", .europe),
    ("Asia          ", .asia),
    ("Africa        ", .africa),
    ("South America ", .southAmerica),
    ("Central Am/Car", .centralAmerica),
    ("Oceania       ", .oceania),
]
let STARTER_MAX_PRICE = 20_000_000
let FLY_TOP = 3
let MONTHS = 4

// Best-gauged STARTER aircraft: among affordable (<= $20M) types that can
// physically fly the route (range + runway), pick the one with the MOST seats
// (best demand capture) — what a competent starter would choose, not the tiniest.
func cheapestFlyable(_ o: Airport, _ d: Airport) -> AircraftType? {
    let nm = Int(o.greatCircleNM(to: d).rounded())
    return AircraftType.all
        .filter { t in
            t.purchasePrice <= STARTER_MAX_PRICE
            && t.rangeNM >= nm
            && (o.info.map { $0.longestRunwayFt >= t.minRunwayFt } ?? true)
            && (d.info.map { $0.longestRunwayFt >= t.minRunwayFt } ?? true)
        }
        .max { $0.seats < $1.seats }
}

@MainActor
func flyRouteNet(_ region: Airline.PlayerRegion, _ oCode: String, _ dCode: String, _ type: AircraftType) -> (net: Int, load: Int)? {
    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.setHomeRegion(region)
    sim.nameAirline("M", tailCode: "MR")
    sim.devInjectCash(2_000_000_000)
    guard let o = sim.airport(oCode), let d = sim.airport(dCode), let ac = sim.buyAircraft(type) else { return nil }
    guard case .success = sim.openRoute(from: o, to: d, using: ac) else { return nil }
    for _ in 0..<12 { _ = sim.hireCrew(family: type.family) }
    for t in 0..<(Simulation.ticksPerMonth * MONTHS) {
        sim.advanceTick()
        if t % 1440 == 0 {
            for dec in Array(sim.decisionQueue) {
                switch dec.kind { case .aog: sim.resolveAOGExpedite(dec); case .crew: sim.resolveCrewHire(dec); case .sell: sim.resolveSellKeep(dec); default: break }
            }
        }
    }
    guard let r = sim.playerRoutes.first, r.history.count > 5 else { return nil }
    let h = Array(r.history.dropFirst(3))
    let net = h.reduce(0) { $0 + $1.net } / h.count
    let load = Int((h.reduce(0.0) { $0 + $1.loadFactor } / Double(h.count) * 100).rounded())
    return (net, load)
}

@MainActor
func run() {
    print("START-REGION PARITY — opportunity landscape (starter aircraft <= $20M)\n")
    print("region         | viable | starter-route economics (top \(FLY_TOP) by demand, \(MONTHS)mo flown)")
    print(String(repeating: "-", count: 100))
    for (label, region) in REGIONS {
        // Region-aware opportunity finder; wide net across tiers.
        let probe = Simulation()
        probe.configure(viewport: CGSize(width: 400, height: 800))
        probe.setHomeRegion(region)
        probe.nameAirline("M", tailCode: "MR")
        let opps = probe.topRouteOpportunities(perClass: 10)
        // Keep opps a starter-affordable aircraft can physically fly.
        var viable: [(Simulation.RouteOpportunity, AircraftType)] = []
        for opp in opps {
            guard let o = probe.airport(opp.originCode), let d = probe.airport(opp.destCode),
                  let type = cheapestFlyable(o, d) else { continue }
            viable.append((opp, type))
        }
        viable.sort { $0.0.demandPerDay > $1.0.demandPerDay }
        let flown = viable.prefix(FLY_TOP).map { (opp, type) -> String in
            let r = flyRouteNet(region, opp.originCode, opp.destCode, type)
            let net = r.map { fmt($0.net) } ?? "—"
            let load = r.map { "\($0.load)%" } ?? "—"
            return "\(opp.originCode)-\(opp.destCode) \(type.id)(\(type.seats)s) d\(opp.demandPerDay) \(opp.distanceNM)nm net \(net) load \(load)"
        }
        print("\(label) | \(String(format: "%2d/%2d", viable.count, opps.count))  | " + (flown.first ?? "none viable"))
        for line in flown.dropFirst() { print("\(String(repeating: " ", count: 14)) |        | \(line)") }
    }
    print("\n(viable = starter-flyable opps / total opps returned;  net = avg per-flight net, the starter-route quality)")

    // MID-GAME CEILING: fly a 165-seat A320 on each region's TOP-demand route.
    // A 50-seat jet fills anywhere; a narrowbody needs real demand — this shows
    // whether low-demand regions choke when you try to scale up (the growth ceiling).
    print("\n\n=== MID-GAME up-gauge ceiling — 165-seat A320 on each region's top route ===")
    print("region         | top route (by demand)          | A320 load | A320 net/flt")
    print(String(repeating: "-", count: 80))
    let a320 = AircraftType.all.first { $0.id == "A320" }!
    for (label, region) in REGIONS {
        let probe = Simulation()
        probe.configure(viewport: CGSize(width: 400, height: 800))
        probe.setHomeRegion(region)
        probe.nameAirline("M", tailCode: "MR")
        // top route the A320 can physically fly
        let opps = probe.topRouteOpportunities(perClass: 10)
            .sorted { $0.demandPerDay > $1.demandPerDay }
        guard let opp = opps.first(where: { o in
            guard let a = probe.airport(o.originCode), let b = probe.airport(o.destCode) else { return false }
            return a.greatCircleNM(to: b) <= Double(a320.rangeNM)
                && (a.info.map { $0.longestRunwayFt >= a320.minRunwayFt } ?? true)
                && (b.info.map { $0.longestRunwayFt >= a320.minRunwayFt } ?? true)
        }) else { print("\(label) | (no A320-flyable top route)"); continue }
        let r = flyRouteNet(region, opp.originCode, opp.destCode, a320)
        let load = r.map { "\($0.load)%" } ?? "—"
        let net = r.map { fmt($0.net) } ?? "—"
        print(String(format: "%@ | %@-%@ d%-5d %5dnm        | %8@ | %@",
                     label as NSString, opp.originCode as NSString, opp.destCode as NSString,
                     opp.demandPerDay, opp.distanceNM, load as NSString, net as NSString))
    }
    print("\n(A320 near 92% load + strong net = real up-gauge headroom;  low load = demand-capped, stuck at regional scale)")
}

func fmt(_ v: Int) -> String {
    let a = abs(v), s = v < 0 ? "-$" : "$"
    if a >= 1000 { return s + String(format: "%.0fk", Double(a)/1000) }
    return s + "\(a)"
}

MainActor.assumeIsolated { run() }
