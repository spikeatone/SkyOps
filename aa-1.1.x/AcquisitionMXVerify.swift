//
//  AcquisitionMXVerify.swift — the acquisition MX-seeding bug (player-reported,
//  8 Sep 2026) + the auto-slow exemption for routine MX cards.
//
//  BUG A: inheritFleet was the ONLY path building an owned aircraft without
//  seedMXState, so an inherited airframe carried its real accrued cycles against
//  lastCycle/lastTick = 0. mxProgress then read its ENTIRE life as time-since-
//  service: every A/C/D check instantly past the hard legal window, the whole
//  fleet force-grounded on day one at the 2.5x OVERDUE surcharge — on a fleet the
//  paid-for stage-2 books had just called airworthy.
//
//  BUG B: the auto-slow snapped the sim to 1x for ANY new card, including routine
//  scheduled MX. At a large fleet one comes due every few sim-hours, pinning the
//  sim at 1x permanently.
//
//  Compile like the other harnesses (see aa-1.1.x/README.md — needs
//  RepaintVerifyStubs.swift); rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func printResult() { print("\nAcquisitionMXVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }
    func newSim() -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Acq Air", tailCode: "AQ"); s.devInjectCash(20_000_000_000)
        return s
    }

    // ── A. An acquired fleet arrives AIRWORTHY, not force-grounded ───────────────
    do {
        let sim = newSim()
        // Buy the cheapest relevant carrier we can actually afford.
        let targets = sim.relevantCompetitors.sorted { sim.askingPrice(for: $0) < sim.askingPrice(for: $1) }
        guard let target = targets.first else { check(false, "setup A: no competitor"); printResult(); return }
        let priceBefore = sim.askingPrice(for: target)
        check(sim.acquire(target), "A: acquisition completes (\(target.name), \(priceBefore))")
        let inherited = sim.aircraft.filter { $0.purchased && $0.subsidiaryCode == target.id }
        check(!inherited.isEmpty, "A: inherited a fleet (\(inherited.count) aircraft)")
        // THE REGRESSION: none of them may be past the hard legal window at close.
        let grounded = inherited.filter { sim.mxPastHardWindow($0) }
        check(grounded.isEmpty, "A: NO inherited aircraft is past the MX hard window at close (got \(grounded.count)/\(inherited.count))")
        let dueNow = inherited.filter { sim.mxIsDue($0) }
        check(dueNow.isEmpty, "A: no inherited aircraft is DUE a check at close (got \(dueNow.count)/\(inherited.count))")
        let overdue = inherited.filter { sim.mxIsOverdue($0) }
        check(overdue.isEmpty, "A: none is OVERDUE (the 2.5x surcharge) at close (got \(overdue.count)/\(inherited.count))")
        // The D clock must sit at the airframe's prior D boundary, not zero — a
        // mid-life jet is partway to its next D, not fresh out of the factory.
        for ac in inherited where ac.cyclesAccrued > 0 {
            let dInterval = sim.mxCycleInterval(.d, ac)
            let expected = (ac.cyclesAccrued / dInterval) * dInterval
            check(ac.mxD.lastCycle == expected, "A: \(ac.tail) D clock seeded to its prior boundary (\(ac.mxD.lastCycle) vs \(expected))")
            check(ac.mxA.lastCycle == ac.cyclesAccrued && ac.mxC.lastCycle == ac.cyclesAccrued,
                  "A: \(ac.tail) A/C clocks seeded to 'just serviced'")
        }
        // And the fleet must actually FLY, not sit in the shop for its first month.
        let spendBefore = sim.totalMaintenanceCheckSpend
        for _ in 0..<(30 * 1440) {
            sim.advanceTick()
            for d in sim.decisionQueue where d.kind == .aog { sim.resolveAOGStandard(d) }
            for d in sim.decisionQueue where d.kind == .crew { sim.resolveCrewWait(d) }
        }
        let forcedSpend = sim.totalMaintenanceCheckSpend - spendBefore
        check(forcedSpend < priceBefore / 10,
              "A: first 30 days of MX is not a hidden fraction of the price (\(forcedSpend) on a \(priceBefore) deal)")
        let flown = inherited.reduce(0) { $0 + $1.cyclesAccrued }
        check(flown > 0, "A: the inherited fleet flies in its first 30 days")
        // devInjectCash is TRACKED (devInjectedCash is an invariant term), so a LIVE
        // sim residual is 0; only a save/load round-trip leaves the −injected residual.
        check(sim.cashInvariantResidual() == 0, "A: cash invariant holds (residual \(sim.cashInvariantResidual()))")
    }

    // ── B. A routine MX card does NOT snap the sim to 1x; an AOG still does ──────
    do {
        let sim = newSim()
        check(Simulation.Decision.Kind.mxCheck.warrantsAutoSlow == false, "B: a scheduled MX check is not auto-slow-worthy")
        for k in [Simulation.Decision.Kind.aog, .crew, .offer, .hubOffer, .activist, .airportOffer, .sell, .training] {
            check(k.warrantsAutoSlow, "B: \(k) still snaps the sim to 1x")
        }
        // Drive it for real: an MX-due fleet at 25x must stay at 25x.
        guard let t = AircraftType.all.first(where: { $0.id == "A320" }),
              let den = sim.airport("DEN"), let ord = sim.airport("ORD") else { check(false, "setup B"); printResult(); return }
        guard let ac = sim.buyAircraft(t) else { check(false, "setup B buy"); printResult(); return }
        _ = sim.openRoute(from: den, to: ord, using: ac)
        // Force an MX check due right now.
        ac.mxA = Aircraft.MXCheck(lastCycle: ac.cyclesAccrued - Simulation.mxACycles - 5, lastTick: 0)
        sim.requestSpeed(25)
        var sawMXCard = false, n = 0
        while n < 40_000 && !sawMXCard {
            sim.advanceTick(); n += 1
            if sim.decisionQueue.contains(where: { $0.kind == .mxCheck }) { sawMXCard = true }
            // Keep other kinds out of the way so we isolate the MX path.
            for d in sim.decisionQueue where d.kind == .crew { sim.resolveCrewWait(d) }
            for d in sim.decisionQueue where d.kind == .aog { sim.resolveAOGStandard(d) }
        }
        check(sawMXCard, "B: an MX card arrived")
        check(sim.speed == 25, "B: the sim stayed at 25x through a routine MX card (got \(sim.speed))")
        check(sim.autoSlowRestoreSpeed == nil, "B: no restore intent was armed by an MX card")
        check(!sim.opsCollapsedSections.contains(.maintenance), "B: the MX card still auto-opened its Ops drawer")
    }
    printResult()
}
MainActor.assumeIsolated { main() }
