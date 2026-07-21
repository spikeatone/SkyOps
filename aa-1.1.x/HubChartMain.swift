import Foundation

// Headless verification for the Hubs & Clubs payback chart (1.1.x).
// Drives the REAL sim: name airline -> buy 5 jets -> open 5 DEN routes ->
// establish hub -> build club -> run sim-months -> assert the ledger accrues
// correctly, the cash invariant is UNTOUCHED (no new cash flow), and the whole
// thing survives a save/load round-trip incl. legacy (no-ledger) backfill.
//
// Run: cp this to /tmp/main.swift, then compile the real Sim/*.swift (minus the
// two SwiftUI files) + Persistence.swift with `swiftc -O -DDEBUG`.

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ cond: Bool, _ msg: String) { if cond { pass += 1 } else { fail += 1; print("FAIL: \(msg)") } }

    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("Hub Test", tailCode: "MR")
    sim.devInjectCash(5_000_000_000)
    check(sim.cashInvariantResidual() == 0, "invariant after inject")

    guard let type = AircraftType.all.first(where: { $0.bodyType == .narrowbody }),
          let hub = sim.airport("DEN") else { print("setup failed"); return }

    // 5 routes touching DEN -> hub eligibility.
    for code in ["ORD", "LAX", "JFK", "ATL", "SFO"] {
        guard let d = sim.airport(code), let ac = sim.buyAircraft(type) else { check(false, "buy/airport \(code)"); continue }
        let res = sim.openRoute(from: hub, to: d, using: ac)
        if case .success = res {} else { check(false, "openRoute DEN-\(code): \(res)") }
    }
    check(sim.routesAt("DEN") == 5, "5 routes at DEN (got \(sim.routesAt("DEN")))")
    check(sim.hubEligible("DEN"), "DEN hub-eligible")
    check(sim.cashInvariantResidual() == 0, "invariant after 5 routes")

    // --- Establish hub ---
    let estCost = sim.hubEstablishCost(hub)
    let balBeforeHub = sim.playerBalance
    check(sim.establishHub(at: "DEN"), "establishHub DEN")
    check(sim.playerBalance == balBeforeHub - estCost, "hub deducts exact establish cost")
    guard let led0 = sim.hubLedgers["DEN"] else { print("no ledger after establish"); return }
    check(led0.establishCost == estCost, "ledger establishCost == charged (\(led0.establishCost) vs \(estCost))")
    check(led0.monthly.count == 1, "seed hole snapshot present (\(led0.monthly.count))")
    check(led0.monthly.first!.facilityCost == estCost, "seed facilityCost == establish")
    check(led0.monthly.first!.spokeNet == sim.hubSpokeNet("DEN"), "seed spokeNet matches")
    check(sim.hubFacilityCost("DEN") == estCost, "facilityCost == establish before any billing")
    check(sim.cashInvariantResidual() == 0, "invariant after establish")

    // --- Build club ---
    let clubCost = sim.clubBuildCost(hub)
    check(sim.buildClub(at: "DEN"), "buildClub DEN")
    check(sim.hubLedgers["DEN"]!.clubBuildCost == clubCost, "ledger clubBuildCost == charged")
    check(sim.hubFacilityCost("DEN") == estCost + clubCost, "facilityCost includes club build")
    check(sim.cashInvariantResidual() == 0, "invariant after club")

    // --- Run sim-months; RESOLVE decisions daily so the fleet keeps flying
    // (an unattended run freezes on the first unresolved AOG/crew hold, which
    // flatlines spoke net — a harness artifact, not real attended play). ---
    let months = 24
    for t in 0..<(Simulation.ticksPerMonth * months + 10) {
        sim.advanceTick()
        if t % 1440 == 0 {
            for d in Array(sim.decisionQueue) {
                switch d.kind {
                case .aog:  sim.resolveAOGExpedite(d)
                case .crew: sim.resolveCrewHire(d)
                case .sell: sim.resolveSellKeep(d)
                default: break
                }
            }
        }
    }

    guard let led = sim.hubLedgers["DEN"] else { print("ledger gone"); return }
    let billed = led.monthly.count - 1   // seed snapshot + one per billed month
    check(billed >= months - 1 && billed <= months + 1, "~\(months) billed months (got \(billed))")
    check(led.laborPaid == sim.hubMonthlyLabor("DEN") * billed,
          "laborPaid == monthlyLabor × billed (\(led.laborPaid) vs \(sim.hubMonthlyLabor("DEN") * billed))")
    check(led.rentPaid == sim.clubMonthlyRent(hub) * billed,
          "rentPaid == clubRent × billed (\(led.rentPaid) vs \(sim.clubMonthlyRent(hub) * billed))")
    check(sim.hubFacilityCost("DEN") == estCost + clubCost + led.laborPaid + led.rentPaid, "facilityCost sums all components")
    check(led.monthly.count <= Simulation.maxHubSnapshots, "snapshots within cap (\(led.monthly.count) <= \(Simulation.maxHubSnapshots))")
    check(led.monthly.last!.facilityCost == sim.hubFacilityCost("DEN"), "last snapshot facilityCost is current")
    check(sim.hubPaybackNow("DEN") == sim.hubSpokeNet("DEN") - sim.hubFacilityCost("DEN"), "paybackNow == spokeNet - facilityCost")
    check(sim.cashInvariantResidual() == 0, "invariant after \(months) sim-months")

    // With the fleet flying, the payback CLIMBS and crosses break-even
    // (spokeNet grows faster than the monthly facility bill) — the healthy case
    // the chart's mint segment + recoup marker depict.
    check(led.monthly.last!.payback > led.monthly.first!.payback, "payback climbs over the run (flying fleet)")
    check(sim.hubPaybackNow("DEN") > 0, "well-run DEN hub recoups (payback > 0)")

    // spokeNet counts only DEN-touching routes (open + closed).
    let denNet = (sim.playerRoutes + sim.closedPlayerRoutes)
        .filter { $0.originCode == "DEN" || $0.destCode == "DEN" }
        .reduce(0) { $0 + $1.cumulativeNet }
    check(sim.hubSpokeNet("DEN") == denNet, "spokeNet matches manual sum (\(sim.hubSpokeNet("DEN")) vs \(denNet))")

    // --- save / load round-trip preserves ledgers ---
    let snap = sim.snapshot()
    let restored = Simulation()
    restored.configure(viewport: CGSize(width: 400, height: 800))
    restored.restore(from: snap)
    check(restored.hubLedgers["DEN"]?.establishCost == led.establishCost, "establishCost persists")
    check(restored.hubLedgers["DEN"]?.clubBuildCost == led.clubBuildCost, "clubBuildCost persists")
    check(restored.hubLedgers["DEN"]?.laborPaid == led.laborPaid, "laborPaid persists")
    check(restored.hubLedgers["DEN"]?.rentPaid == led.rentPaid, "rentPaid persists")
    check(restored.hubLedgers["DEN"]?.monthly.count == led.monthly.count, "monthly snapshots persist (\(restored.hubLedgers["DEN"]?.monthly.count ?? -1))")
    check(restored.hubLedgers["DEN"]?.monthly.last?.payback == led.monthly.last?.payback, "last snapshot payback persists")
    // devInjectCash is deliberately NOT persisted (DEBUG hook), so the restored
    // residual is EXACTLY the injection and nothing else — the strong form that
    // proves every persisted invariant term survived (documented Acquisition lesson).
    check(restored.cashInvariantResidual() == -5_000_000_000, "restored invariant gap == exactly the un-persisted inject")

    // --- legacy backfill: a save with a hub but NO ledger gets one on restore ---
    var legacy = snap
    legacy.hubLedgers = nil
    let restored2 = Simulation()
    restored2.configure(viewport: CGSize(width: 400, height: 800))
    restored2.restore(from: legacy)
    check(restored2.hubLedgers["DEN"] != nil, "legacy hub gets a backfilled ledger")
    check(restored2.hubLedgers["DEN"]?.establishCost == sim.hubEstablishCost(hub), "backfill establishCost from formula")
    check(restored2.cashInvariantResidual() == -5_000_000_000, "legacy restore invariant gap == exactly the un-persisted inject")

    // --- teardown drops the ledger ---
    sim.decommissionHub(at: "DEN")
    check(sim.hubLedgers["DEN"] == nil, "decommission drops the ledger")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
