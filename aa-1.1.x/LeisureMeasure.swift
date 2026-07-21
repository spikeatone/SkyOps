import Foundation

// Measure the REAL economics of leisure routes vs the leisure multipliers.
// For each route: fly it in-sim, read route.history for stable per-flight net /
// revenue / load, then isolate the leisure effect via counterfactual:
//   fare premium $/flt  = rev − rev/1.15
//   extra opening cost  = openCost − openCost/1.75
//   premium payback     = extra opening / fare premium  (flights for the +15% fare
//                          to cover the +75% opening penalty — the design thesis)
//   total recoup        = openCost / net-per-flt (flights to recoup the whole open)
// Non-leisure controls show the demand/load confound (island = low pax → low load).

@MainActor
func run() {
    let LF = 1.15                     // leisure fare multiplier (unchanged)
    let LSUR = 500_000.0             // NEW: flat leisure establishment surcharge

    func measure(_ label: String, _ oCode: String, _ dCode: String, leisure: Bool) {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("M", tailCode: "MR")
        sim.devInjectCash(3_000_000_000)
        // longest-range narrowbody covers every pair here (incl. LAX-OGG ~2480nm)
        guard let type = AircraftType.all.filter({ $0.bodyType == .narrowbody }).max(by: { $0.rangeNM < $1.rangeNM }),
              let o = sim.airport(oCode), let d = sim.airport(dCode) else { print("  \(label): setup fail"); return }
        let nm = Int(o.greatCircleNM(to: d).rounded())
        let openCost = sim.routeOpeningCost(o, d)
        guard let ac = sim.buyAircraft(type) else { print("  \(label): buy fail"); return }
        let res = sim.openRoute(from: o, to: d, using: ac)
        guard case .success = res else { print("  \(label) \(oCode)-\(dCode): openRoute \(res)"); return }
        for _ in 0..<12 { _ = sim.hireCrew(family: type.family) }
        // Fly ~6 sim-months, resolving holds so the aircraft flies continuously.
        for t in 0..<(Simulation.ticksPerMonth * 6) {
            sim.advanceTick()
            if t % 1440 == 0 {
                for dec in Array(sim.decisionQueue) {
                    switch dec.kind {
                    case .aog: sim.resolveAOGExpedite(dec)
                    case .crew: sim.resolveCrewHire(dec)
                    case .sell: sim.resolveSellKeep(dec)
                    default: break
                    }
                }
            }
        }
        guard let r = sim.playerRoutes.first(where: { ($0.originCode == oCode && $0.destCode == dCode) || ($0.originCode == dCode && $0.destCode == oCode) }),
              r.history.count > 5 else { print("  \(label): too few flights"); return }
        // Average over stable flights (skip first 3 ramp).
        let h = Array(r.history.dropFirst(3))
        let n = h.count
        let avgRev  = Double(h.reduce(0) { $0 + $1.revenue }) / Double(n)
        let avgNet  = Double(h.reduce(0) { $0 + $1.net }) / Double(n)
        let avgLoad = h.reduce(0.0) { $0 + $1.loadFactor } / Double(n)
        let seats = h.first!.seats

        let inv = sim.cashInvariantResidual()
        let farePremium = leisure ? avgRev - avgRev / LF : 0
        let baseOpen = leisure ? Double(openCost) - LSUR : Double(openCost)
        let extraOpen = Double(openCost) - baseOpen
        let premiumPayback = farePremium > 0 ? extraOpen / farePremium : 0
        let totalRecoup = avgNet > 0 ? Double(openCost) / avgNet : -1

        print(String(format: "  %-18@ %@-%@  %5dnm  load %2.0f%% (%d seats)", label as NSString, oCode as NSString, dCode as NSString, nm, avgLoad * 100, seats))
        print(String(format: "      open $%@ (base $%@, +$%@ leisure)  rev/flt $%@  net/flt $%@",
                     fmt(openCost), fmt(Int(baseOpen)), fmt(Int(extraOpen)), fmt(Int(avgRev)), fmt(Int(avgNet))))
        if leisure {
            print(String(format: "      fare premium $%@/flt  ->  premium payback %.0f flts   |   total recoup %@ flts   inv=%d",
                         fmt(Int(farePremium)), premiumPayback, totalRecoup > 0 ? String(Int(totalRecoup.rounded())) : "NEVER (net<=0)", inv))
        } else {
            print(String(format: "      total recoup %@ flts", totalRecoup > 0 ? String(Int(totalRecoup.rounded())) : "NEVER (net<=0)"))
        }
    }

    print("=== LEISURE ROUTES (fare x\(LF), opening +$\(Int(LSUR/1000))k flat) ===  [inv should == -3000000000]")
    measure("short island", "MIA", "NAS", leisure: true)   // Nassau ~185nm, 4.1M pax
    measure("mid island",   "MIA", "AUA", leisure: true)   // Aruba ~1080nm, 2.9M pax
    measure("long island",  "LAX", "OGG", leisure: true)   // Maui ~2480nm, 7.9M pax
    print("\n=== NON-LEISURE CONTROLS (matched-ish distance, mainland) ===")
    measure("short control", "MIA", "TPA", leisure: false) // ~200nm, 24.8M pax
    measure("mid control",   "LAX", "SEA", leisure: false) // ~955nm, 50.9M pax
    measure("long control",  "LAX", "BOS", leisure: false) // ~2600nm, 40.7M pax
}

func fmt(_ v: Int) -> String {
    let a = abs(v), s = v < 0 ? "-" : ""
    if a >= 1_000_000 { return s + String(format: "%.2fM", Double(a)/1_000_000) }
    if a >= 1_000 { return s + String(format: "%.0fk", Double(a)/1_000) }
    return s + "\(a)"
}

MainActor.assumeIsolated { run() }
