import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    // ---- 1. Curfew timing: LHR (2300-0600 = 420 min/day) is active ~420 ticks/day ----
    let t = Simulation()
    t.configure(viewport: CGSize(width: 400, height: 800))
    guard let lhr = t.airport("LHR"), let jfk = t.airport("JFK") else { print("airport fail"); return }
    check(Airport.hasCurfew("LHR") && !Airport.hasCurfew("JFK"), "LHR has a curfew, JFK does not")
    var lhrActive = 0, jfkActive = 0
    for _ in 0..<1440 { t.advanceTick(); if lhr.curfew { lhrActive += 1 }; if jfk.curfew { jfkActive += 1 } }
    // window length for LHR (1380->360 wrapping) = (1440-1380)+360 = 420
    check(abs(lhrActive - 420) <= 3, "LHR curfew active ~420 min/sim-day (got \(lhrActive))")
    check(jfkActive == 0, "JFK (no curfew) is never curfewed (got \(jfkActive))")

    // ---- 2. Operational effect + NO DEADLOCK: fly a curfew route vs a control ----
    let g = Simulation()
    g.configure(viewport: CGSize(width: 400, height: 800))
    g.setHomeRegion(.northAmerica)
    g.nameAirline("Curfew Air", tailCode: "MR")
    g.devInjectCash(2_000_000_000)
    guard let ty = AircraftType.all.first(where: { $0.id == "A320" }) else { print("no A320"); return }
    func openRoute(_ o: String, _ d: String) {
        guard let oa = g.airport(o), let da = g.airport(d), let ac = g.buyAircraft(ty) else { print("  \(o)-\(d) setup fail"); return }
        if case .success = g.openRoute(from: oa, to: da, using: ac) {} else { print("  \(o)-\(d) open FAILED") }
    }
    openRoute("LHR", "CDG")   // curfew at LHR (one endpoint)
    openRoute("JFK", "BOS")   // control — neither endpoint curfewed
    for fam in g.ownedFamilies { for _ in 0..<8 { _ = g.hireCrew(family: fam) } }
    for tk in 0..<(1440 * 14) {   // 14 sim-days
        g.advanceTick()
        if tk % 720 == 0 {
            for dec in Array(g.decisionQueue) {
                switch dec.kind { case .aog: g.resolveAOGExpedite(dec); case .crew: g.resolveCrewHire(dec); case .sell: g.resolveSellKeep(dec); default: break }
            }
        }
    }
    let curfewR = g.playerRoutes.first { $0.originCode == "LHR" || $0.destCode == "LHR" }
    let ctlR    = g.playerRoutes.first { $0.originCode == "JFK" || $0.destCode == "JFK" }
    let cf = curfewR?.flights ?? 0, ct = ctlR?.flights ?? 0
    print("  curfew LHR-CDG flights: \(cf)   |   control JFK-BOS flights: \(ct)")
    check(cf > 8, "curfew route still completes flights — NO deadlock (\(cf))")
    check(ct > 8, "control route completes flights (\(ct))")
    check(cf < ct, "curfew reduces throughput vs control (\(cf) < \(ct))")
    check(g.cashInvariantResidual() == 0, "cash invariant intact on the live sim (curfew holds don't corrupt accounting)")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
