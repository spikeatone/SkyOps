import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ cond: Bool, _ msg: String) {
        if cond { pass += 1 } else { fail += 1; print("FAIL: \(msg)") }
    }

    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("Test", tailCode: "MR")
    sim.devInjectCash(2_000_000_000)
    check(sim.cashInvariantResidual() == 0, "invariant after inject")

    // Open a contested route.
    guard let type = AircraftType.all.first(where: { $0.bodyType == .narrowbody }),
          let ac = sim.buyAircraft(type),
          let o = sim.airport("DEN"), let d = sim.airport("ORD") else { print("setup failed"); return }
    let opened = sim.openRoute(from: o, to: d, using: ac)
    guard case .success = opened, let r = sim.playerRoutes.first else { print("route open failed: \(opened)"); return }
    r.competitors = ["Delta Air Lines", "JetBlue"]
    r.competitionLevel = 2
    check(sim.cashInvariantResidual() == 0, "invariant after route+competition")

    // --- Fare war ---
    let balBefore = sim.playerBalance
    let fwCost = sim.fareWarCost(r)
    check(sim.startFareWar(r.id), "startFareWar succeeds on contested route")
    check(sim.playerBalance == balBefore - fwCost, "fare war deducts exact cost")
    check(sim.totalMarketingSpend == fwCost, "marketing spend tracks fare war")
    check(sim.fareWarActive(r.id), "fare war active")
    check(!sim.startFareWar(r.id), "fare war can't double-start")
    check(sim.cashInvariantResidual() == 0, "invariant after fare war")

    // --- Ad campaign ---
    let adCost = sim.adCampaignCost(r)
    let msBefore = sim.totalMarketingSpend
    check(sim.launchAdCampaign(r.id), "launchAdCampaign succeeds")
    check(sim.adCampaignActive(r.id), "ad campaign active")
    check(sim.totalMarketingSpend == msBefore + adCost, "marketing spend tracks ad")
    check(sim.cashInvariantResidual() == 0, "invariant after ad campaign")

    // --- Loyalty push ---
    let loyCost = sim.loyaltyPushCost(r)
    let ms2 = sim.totalMarketingSpend
    check(sim.startLoyaltyPush(r.id), "startLoyaltyPush succeeds")
    check(sim.loyaltyPushActive(r.id), "loyalty push active")
    check(sim.totalMarketingSpend == ms2 + loyCost, "marketing spend tracks loyalty")
    check(sim.cashInvariantResidual() == 0, "invariant after loyalty push")

    // Cost ladder: ad < fare war < loyalty
    check(adCost < fwCost && fwCost < loyCost, "cost ladder ad<fare<loyalty (\(adCost) < \(fwCost) < \(loyCost))")

    // --- Run a few sim-months; invariant must hold throughout ---
    for _ in 0..<(1440 * 90) { sim.advanceTick() }
    check(sim.cashInvariantResidual() == 0, "invariant after 90 sim-days")

    // --- Insufficient funds guard ---
    let sim2 = Simulation()
    sim2.configure(viewport: CGSize(width: 400, height: 800))
    sim2.nameAirline("Broke", tailCode: "MR")
    if let a2 = sim2.buyAircraft(type) { _ = sim2.openRoute(from: o, to: d, using: a2) }
    if let r2 = sim2.playerRoutes.first {
        r2.competitionLevel = 1; r2.competitors = ["Delta Air Lines"]
        check(!sim2.startFareWar(r2.id), "fare war blocked when broke")
        check(sim2.totalMarketingSpend == 0, "no spend when blocked")
    }

    // --- save / load round-trip preserves marketing state ---
    let snap = sim.snapshot()
    let restored = Simulation()
    restored.configure(viewport: CGSize(width: 400, height: 800))
    restored.restore(from: snap)
    check(restored.totalMarketingSpend == sim.totalMarketingSpend, "marketing spend persists")
    check(restored.playerFareWarUntil == sim.playerFareWarUntil, "fare war dict persists")
    check(restored.adCampaignUntil == sim.adCampaignUntil, "ad dict persists")
    check(restored.loyaltyPushUntil == sim.loyaltyPushUntil, "loyalty dict persists")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
