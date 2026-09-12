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
    // ⚠️ SECTION ROLL-CALL — the count alone CANNOT tell you a section ran.
    // Section A emits 2 checks PER INHERITED AIRCRAFT and the target carrier varies
    // with `competitorSeed` (rolled fresh per `Simulation()`), so the same code
    // legitimately prints 53, 56 or 63 — which is exactly how section D silently
    // skipping itself stayed invisible behind a green ✅. Each section stamps itself
    // on completion and a missing stamp is a FAILURE.
    let expectedSections = ["A", "B", "C", "D"]
    var sectionsRun: [String] = []
    func ran(_ id: String) { sectionsRun.append(id) }
    func printResult() {
        for id in expectedSections where !sectionsRun.contains(id) {
            fail += 1
            print("FAIL: section \(id) NEVER RAN — it tested nothing (bailed setup or an early return)")
        }
        print("\nAcquisitionMXVerify: \(pass)/\(pass + fail) passed  ·  sections \(sectionsRun.joined(separator: "+"))"
              + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED"))
    }
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
        ran("A")
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
        // Force an MX check due right now. The AUTO-A POLICY must be off for this
        // test: with it on (the default) a due A check is serviced silently and never
        // becomes a card at all — which is the point of that feature, but it would
        // leave this test with nothing to observe. This test is about auto-SLOW.
        sim.mxAutoServiceAChecks = false
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
        ran("B")
    }
    // ── C. The INTEGRATION readouts + the settle lever ──────────────────────────
    // ⚠️ WHY THIS SECTION EXISTS: `settleSeniority()` shipped with ZERO call sites
    // anywhere — app or harness — so the designed "manage it well" lever was
    // unreachable and untested, and the 12-seed sweep's MANAGED arm was measuring
    // something no player could do. A paying customer then hit the other half of
    // the same gap (no view read `activeIntegration`, so a blocked player was never
    // told that waiting IS the mechanic). These cover both.
    do {
        let sim = newSim()
        let targets = sim.relevantCompetitors.sorted { sim.askingPrice(for: $0) < sim.askingPrice(for: $1) }
        guard let target = targets.first else { check(false, "setup C"); printResult(); return }
        guard sim.acquire(target) else { check(false, "setup C: acquire"); printResult(); return }

        check(sim.integrationInProgress, "C: an integration is running after a close")
        check(!sim.opsCollapsedSections.contains(.integration),
              "C: closing AUTO-OPENS the Ops ▸ Integration drawer")
        // The countdown the customer never got to see.
        let m0 = sim.integrationMonthsRemaining
        check(m0 == Simulation.integrationMonths,
              "C: months-remaining starts at the full window (\(m0)/\(Simulation.integrationMonths))")
        check(sim.integrationProgress < 0.01, "C: progress starts at zero")

        // A second acquisition is blocked, and the copy now carries the duration.
        if let other = targets.dropFirst().first {
            if case .integrationInProgress = sim.acquisitionBlock(for: other) {
                check(true, "C: a second acquisition is blocked while one runs")
            } else { check(false, "C: a second acquisition is blocked while one runs") }
        }

        // Run a third of the window and confirm it actually counts DOWN.
        for _ in 0..<(6 * Simulation.ticksPerMonth) { sim.advanceTick() }
        let m1 = sim.integrationMonthsRemaining
        check(m1 < m0, "C: months-remaining counts down (\(m0) → \(m1))")
        check(sim.integrationProgress > 0.25, "C: progress advances (\(Int(sim.integrationProgress * 100))%)")
        ran("C")
    }
    // ── D. Settling the seniority dispute: the lever that had no button ─────────
    // ⚠️ THE SETUP IS DERIVED, NOT SEARCHED, AND A SKIP IS A **FAIL** HERE.
    // The first cut of this section searched the 12 cheapest carriers for one that
    // happened to dispute, and on a miss reported `check(true, "(skipped)")` —
    // which is this codebase's documented worst harness bug: the section's whole
    // point (the settle lever) silently vanished and the run still printed ✅
    // (53/53 green with section D never executing). Two reasons it missed:
    //   1. `disputed` = the player's MAINLINE families ∩ the target's families, so
    //      a lone A320 only disputes against an A320-family operator — a narrow
    //      window, and `competitorSeed` is rolled fresh per `Simulation()`.
    //   2. `applySeniorityDispute` sidelines `round(pool.count * 0.35)`, which is
    //      **ZERO for a one-crew pool** — so even a real family overlap sidelined
    //      nobody and `pendingSenioritySettlement` read nil.
    // So: pick the target FIRST, then buy aircraft in a family IT flies (overlap by
    // construction), and buy THREE so the pool is big enough to sideline ≥1.
    do {
        let sim = newSim()
        let targets = sim.relevantCompetitors
            .filter { !$0.fleetByType.isEmpty }
            .sorted { sim.askingPrice(for: $0) < sim.askingPrice(for: $1) }
        guard let target = targets.first else { check(false, "setup D: no competitor"); printResult(); return }

        // A family the TARGET flies, and the cheapest buyable type in it.
        let theirFamilies = Set(target.fleetByType.keys.compactMap { id in
            AircraftType.all.first { $0.id == id }?.family })
        guard let ty = AircraftType.all
            .filter({ theirFamilies.contains($0.family) })
            .min(by: { $0.purchasePrice < $1.purchasePrice }) else {
            check(false, "setup D: no buyable type in any of the target's families"); printResult(); return
        }
        // THREE, so round(3 * 0.35) == 1 crew can actually be sidelined.
        for _ in 0..<3 { _ = sim.buyAircraft(ty) }
        check(sim.crewCount(family: ty.family) >= 3, "D: setup seeded a crew pool in a shared family (\(sim.crewCount(family: ty.family)))")

        guard sim.acquire(target) else { check(false, "setup D: acquire"); printResult(); return }
        // A SKIP IS A FAILURE. If this is nil the section tested nothing.
        guard let cost = sim.pendingSenioritySettlement else {
            check(false, "D: the acquisition produced a seniority dispute — nothing to settle, so this section tested NOTHING")
            printResult(); return
        }

        check(sim.seniorityDaysRemaining != nil, "D: the dispute reports a countdown")
        check(sim.senioritySidelinedCount > 0,
              "D: crews are actually sidelined (\(sim.senioritySidelinedCount))")
        check(sim.canSettleSeniority, "D: settling is offered when affordable")

        let cashBefore = sim.playerBalance
        let spendBefore = sim.totalSenioritySpend
        check(sim.settleSeniority(), "D: settleSeniority() succeeds")
        check(sim.totalSenioritySpend - spendBefore == cost,
              "D: charged EXACTLY the quoted settlement (\(sim.totalSenioritySpend - spendBefore) vs \(cost))")
        check(cashBefore - sim.playerBalance == cost, "D: cash fell by exactly that amount")
        check(sim.senioritySidelinedCount == 0, "D: every sidelined crew is back on the line")
        check(sim.seniorityDaysRemaining == nil, "D: the dispute is over")
        check(!sim.canSettleSeniority && sim.pendingSenioritySettlement == nil,
              "D: the settle option is gone — it can't be paid twice")
        check(!sim.settleSeniority(), "D: a second settle is refused")
        check(sim.integrationInProgress, "D: settling does NOT end the integration itself")
        check(sim.cashInvariantResidual() == 0,
              "D: cash invariant holds after settling (residual \(sim.cashInvariantResidual()))")

        // And the integration still completes on time, on its own.
        for _ in 0..<(Simulation.integrationMonths * Simulation.ticksPerMonth + 2 * 1440) { sim.advanceTick() }
        check(!sim.integrationInProgress, "D: the integration completes on elapsed time alone")
        check(sim.integrationMonthsRemaining == 0, "D: months-remaining reads 0 once done")
        check(sim.cashInvariantResidual() == 0, "D: cash invariant holds through completion")
        ran("D")
    }

    printResult()
}
MainActor.assumeIsolated { main() }
