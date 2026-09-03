import Foundation

// MX COVERAGE (temporary substitution) verification.
// Validates the C/D-check coverage mechanic: an idle spare covers a routed aircraft's
// route while it's in the shop, and the original RECLAIMS its route on return while the
// sub goes back to the bench. Plus: A-checks don't require coverage, no-spare blocks a
// C/D service, the cash invariant holds (MX spend is a real invariant term), and a
// save/load mid-cover restores the swap-back links. Rename to main.swift to run.

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    func newSim() -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Cover Air", tailCode: "CV"); s.devInjectCash(2_000_000_000)
        return s
    }
    // Buy a jet and route it DEN↔ORD; return it.
    func buyRouted(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }), let ac = sim.buyAircraft(t) else { return nil }
        if let o = sim.airport("DEN"), let d = sim.airport("ORD") { _ = sim.openRoute(from: o, to: d, using: ac) }
        return ac
    }
    // Buy an idle spare (no route).
    func buySpare(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { return nil }
        return sim.buyAircraft(t)
    }
    // Force a check due NOW by setting the last-serviced cycle far enough back.
    // A: 150 cyc · C: 1200 · D: lifespan/3. `over` = how far past the interval.
    func forceCheck(_ sim: Simulation, _ ac: Aircraft, _ kind: Aircraft.MXKind, over: Int) {
        let interval = sim.mxCycleInterval(kind, ac)
        ac.cyclesAccrued = max(ac.cyclesAccrued, interval + over + 10)
        let now = ac.cyclesAccrued, t = sim.tick
        // Set the target kind overdue; keep the others fresh so it's the most-urgent.
        ac.mxA = Aircraft.MXCheck(lastCycle: now, lastTick: t)
        ac.mxC = Aircraft.MXCheck(lastCycle: now, lastTick: t)
        ac.mxD = Aircraft.MXCheck(lastCycle: now, lastTick: t)
        switch kind {
        case .a: ac.mxA = Aircraft.MXCheck(lastCycle: now - (interval + over), lastTick: t)
        case .c: ac.mxC = Aircraft.MXCheck(lastCycle: now - (interval + over), lastTick: t)
        case .d: ac.mxD = Aircraft.MXCheck(lastCycle: now - (interval + over), lastTick: t)
        }
    }

    // ---- 1. C-check on a routed aircraft REQUIRES coverage; spare exists → covered service works. ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320"), let spare = buySpare(sim, "A320") else { check(false, "setup 1"); printResult(); return }
        let routeId = jet.assignedRouteId
        forceCheck(sim, jet, .c, over: 60)
        check(sim.mxIsDue(jet), "1: C check is due")
        check(sim.mxCoverageRequired(jet), "1: coverage required for C on a routed jet")
        check(sim.spareCandidates(for: sim.currentRoute(of: jet)!).contains { $0 === spare }, "1: spare is an in-range candidate")
        let cashBefore = sim.playerBalance
        let cost = sim.mxCheckCost(.c, jet)
        let ok = sim.serviceMXWithCoverage(jet, coverWith: spare)
        check(ok, "1: covered service succeeds")
        check(jet.inMXShop, "1: original is now in the shop")
        check(jet.assignedRouteId == nil, "1: original released its route")
        check(jet.mxReclaimRouteId == routeId, "1: original remembers the route to reclaim")
        check(spare.assignedRouteId == routeId, "1: sub took over the route")
        check(spare.coveringForTail == jet.tail, "1: sub is tagged as covering the original")
        check(sim.playerBalance == cashBefore - cost, "1: charged exactly the check cost")
        check(sim.cashInvariantResidual() == 0, "1: cash invariant holds after covered service")
    }

    // ---- 2. Swap-back on shop return: original reclaims route, sub → bench. ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320"), let spare = buySpare(sim, "A320") else { check(false, "setup 2"); printResult(); return }
        let routeId = jet.assignedRouteId
        forceCheck(sim, jet, .c, over: 60)
        _ = sim.serviceMXWithCoverage(jet, coverWith: spare)
        // Tick through the downtime (C = 7 days = 7*1440 ticks) plus slack.
        for _ in 0..<(9 * 1440) { sim.advanceTick() }
        check(!jet.inMXShop, "2: original is out of the shop")
        check(jet.assignedRouteId == routeId, "2: original RECLAIMED its route")
        check(jet.mxReclaimRouteId == nil, "2: reclaim link cleared")
        check(spare.assignedRouteId == nil, "2: sub returned to the bench (idle spare)")
        check(spare.coveringForTail == nil, "2: sub's covering tag cleared")
        // Exactly one aircraft flies the route (no double-staffing).
        let onRoute = sim.aircraft.filter { $0.assignedRouteId == routeId }.count
        check(onRoute == 1, "2: exactly one aircraft on the route after swap-back")
        check(sim.cashInvariantResidual() == 0, "2: cash invariant holds after swap-back")
    }

    // ---- 3. A-check on a routed aircraft does NOT require coverage; plain service works. ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320") else { check(false, "setup 3"); printResult(); return }
        forceCheck(sim, jet, .a, over: 20)
        check(sim.mxIsDue(jet), "3: A check is due")
        check(!sim.mxCoverageRequired(jet), "3: A check does NOT require coverage")
        let ok = sim.sendToMX(jet)
        check(ok, "3: plain service succeeds for an A check")
        check(jet.inMXShop, "3: A-check aircraft in shop")
        check(jet.mxReclaimRouteId == nil, "3: no coverage link for an A check")
        check(sim.cashInvariantResidual() == 0, "3: invariant holds")
    }

    // ---- 4. No in-range spare → covered service is refused (blocked), nothing changes. ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320") else { check(false, "setup 4"); printResult(); return }
        forceCheck(sim, jet, .d, over: 60)
        check(sim.mxCoverageRequired(jet), "4: D check requires coverage")
        check(sim.spareCandidates(for: sim.currentRoute(of: jet)!).isEmpty, "4: no spare available")
        let cashBefore = sim.playerBalance
        // Try to cover with the jet itself (invalid) — must be refused.
        let ok = sim.serviceMXWithCoverage(jet, coverWith: jet)
        check(!ok, "4: covered service refused with no valid sub")
        check(!jet.inMXShop, "4: aircraft NOT sent to shop (blocked)")
        check(sim.playerBalance == cashBefore, "4: no charge on a blocked service")
    }

    // ---- 5. Save/load MID-COVER restores the swap-back links, and the swap-back still fires. ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320"), let spare = buySpare(sim, "A320") else { check(false, "setup 5"); printResult(); return }
        let routeId = jet.assignedRouteId
        forceCheck(sim, jet, .c, over: 60)
        _ = sim.serviceMXWithCoverage(jet, coverWith: spare)
        let snap = sim.snapshot()
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
        sim2.restore(from: snap)
        let jet2 = sim2.aircraft.first { $0.tail == jet.tail }
        let spare2 = sim2.aircraft.first { $0.tail == spare.tail }
        check(jet2?.inMXShop == true, "5: original still in shop after reload")
        check(jet2?.mxReclaimRouteId == routeId, "5: reclaim link survived reload")
        check(spare2?.coveringForTail == jet.tail, "5: sub's covering tag survived reload")
        check(spare2?.assignedRouteId == routeId, "5: sub still flying the route after reload")
        // Run out the downtime in the restored sim → swap-back must still happen.
        for _ in 0..<(9 * 1440) { sim2.advanceTick() }
        check(jet2?.assignedRouteId == routeId, "5: original reclaimed route after reload + downtime")
        check(spare2?.assignedRouteId == nil, "5: sub benched after reload + downtime")
        // devInjectCash ($2B) is a DEBUG hook that is NOT persisted, so a restored
        // sim's residual is exactly minus the injection — which PROVES the balance
        // restored exactly (the documented RoundTripVerify convention). A residual of
        // 0 here would actually mean the restore was WRONG. It must stay constant as
        // the restored sim runs (the swap-back moves no cash).
        check(sim2.cashInvariantResidual() == -2_000_000_000, "5: restored residual == -(un-persisted dev injection), and swap-back moves no cash")
    }

    // ---- 6. MX clocks now survive a plain save/load (the latent-decode fix). ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320") else { check(false, "setup 6"); printResult(); return }
        // Give it real, non-default MX progress (halfway to a C check).
        jet.cyclesAccrued = 3000
        jet.mxC = Aircraft.MXCheck(lastCycle: 2400, lastTick: sim.tick)   // 600/1200 cyc used
        let progBefore = sim.mxProgress(.c, jet)
        let snap = sim.snapshot()
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
        sim2.restore(from: snap)
        guard let jet2 = sim2.aircraft.first(where: { $0.tail == jet.tail }) else { check(false, "6: jet restored"); printResult(); return }
        let progAfter = sim2.mxProgress(.c, jet2)
        check(abs(progBefore - progAfter) < 0.001, "6: MX C-check progress survives save/load (was silently dropped before the decode fix)")
        check(jet2.mxC.lastCycle == 2400, "6: mxC.lastCycle restored exactly")
    }

    // ---- 7. D-check grounding deadline is CALENDAR-based, not a decade of cycles. ----
    // (The "D check due now, forced grounding in ~3,660 days" bug: D's interval is
    // lifespan/3 ~15k cyc, so 1.5× of THAT is thousands of cycles away. D now uses a
    // fixed calendar grace past due.)
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "B789") else { check(false, "setup 7"); printResult(); return }
        // Make the D check JUST due (0 cycles past due).
        let dInt = sim.mxCycleInterval(.d, jet)
        jet.cyclesAccrued = max(jet.cyclesAccrued, dInt + 2)
        jet.mxA = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued, lastTick: sim.tick)
        jet.mxC = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued, lastTick: sim.tick)
        jet.mxD = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (dInt + 2), lastTick: sim.tick)
        check(sim.mxIsDue(jet), "7: D check is due")
        let ground = sim.mxDaysUntilForcedGrounding(jet) ?? -1
        // Must be the calendar grace (~45d), NOT thousands of days.
        check(ground > 0 && ground <= Simulation.mxDHardGroundingGraceDays + 1,
              "7: D forced-grounding is a sane near-term deadline (~\(ground)d, not thousands) — the 3,660-day bug is fixed")
        check(!sim.mxIsOverdue(jet), "7: a JUST-due D check is not yet OVERDUE (grace window)")
        // Push it well past the D overdue grace → OVERDUE, and eventually force-groundable.
        jet.mxD = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (dInt + (Simulation.mxDOverdueGraceDays + 5) * 2), lastTick: sim.tick)
        check(sim.mxIsOverdue(jet), "7: D check past its calendar grace IS overdue (surcharge applies)")
        check(sim.mxCheckCost(.d, jet) > sim.mxCheckBaseCost(.d, jet), "7: overdue D check costs the surcharge")
        // Past the hard grounding grace → force-groundable.
        jet.mxD = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (dInt + (Simulation.mxDHardGroundingGraceDays + 5) * 2), lastTick: sim.tick)
        check(sim.mxPastHardWindow(jet), "7: D check past the hard grace is force-groundable")
    }

    // ---- 8. A-check grounding still uses the interval-multiple rule (unchanged). ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "A320") else { check(false, "setup 8"); printResult(); return }
        forceCheck(sim, jet, .a, over: 20)   // A just past due
        let ground = sim.mxDaysUntilForcedGrounding(jet) ?? -1
        // A interval 150 cyc, 1.5× = 225; ~205 used → ~20 cyc ≈ ~10 days left. Sane, small.
        check(ground >= 0 && ground < 120, "8: A forced-grounding deadline stays near-term (~\(ground)d)")
    }

    // ---- 9. C-check ALSO uses a fixed calendar grace, not the huge 1.5×-interval window. ----
    // (The "C check due now, forced grounding in ~265 days" issue — same class as D, milder.)
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "B739") else { check(false, "setup 9"); printResult(); return }
        let cInt = sim.mxCycleInterval(.c, jet)   // 1200
        // Make the C check JUST due; keep A/D fresh so C is the most-urgent.
        jet.cyclesAccrued = max(jet.cyclesAccrued, cInt + 2)
        jet.mxA = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued, lastTick: sim.tick)
        jet.mxC = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (cInt + 2), lastTick: sim.tick)
        jet.mxD = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued, lastTick: sim.tick)
        check(sim.mxIsDue(jet), "9: C check is due")
        let ground = sim.mxDaysUntilForcedGrounding(jet) ?? -1
        // Must be the calendar grace (~60d), NOT ~265 (the old 1.5×-interval window).
        check(ground > 0 && ground <= Simulation.mxCHardGroundingGraceDays + 1,
              "9: C forced-grounding is near-term (~\(ground)d, not ~265) — the interval-multiple window is gone for C")
        check(!sim.mxIsOverdue(jet), "9: a JUST-due C check is not yet OVERDUE (grace window)")
        // Past the C overdue grace → OVERDUE + surcharge.
        jet.mxC = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (cInt + (Simulation.mxCOverdueGraceDays + 5) * 2), lastTick: sim.tick)
        check(sim.mxIsOverdue(jet), "9: C past its calendar grace IS overdue")
        check(sim.mxCheckCost(.c, jet) > sim.mxCheckBaseCost(.c, jet), "9: overdue C check costs the surcharge")
        // Past the hard grace → force-groundable.
        jet.mxC = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (cInt + (Simulation.mxCHardGroundingGraceDays + 5) * 2), lastTick: sim.tick)
        check(sim.mxPastHardWindow(jet), "9: C past the hard grace is force-groundable")
    }

    // ---- 10. Coverage requires a LIKE-SIZE aircraft: an A320 can't cover a 787. ----
    do {
        let sim = newSim()
        // 787 on a route it can fly (transcon), + an A320 idle spare (wrong size).
        guard let big = AircraftType.all.first(where: { $0.id == "B789" }),
              let jet = sim.buyAircraft(big) else { check(false, "setup 10"); printResult(); return }
        if let o = sim.airport("JFK"), let d = sim.airport("LAX") { _ = sim.openRoute(from: o, to: d, using: jet) }
        guard let small = AircraftType.all.first(where: { $0.id == "A320" }), let a320 = sim.buyAircraft(small) else { check(false, "setup 10 a320"); printResult(); return }
        forceCheck(sim, jet, .d, over: 60)
        check(sim.mxCoverageRequired(jet), "10: 787 D check gets the coverage flow")
        check(!sim.mxIsSuitableCover(a320, for: jet), "10: an A320 is NOT a suitable cover for a 787 (wrong capacity/range)")
        check(sim.mxCoverageCandidates(for: jet).isEmpty, "10: no suitable cover offered (the A320 is filtered out)")
        // The A320 CAN physically fly the route (it's an in-range idle spare) — proving
        // the filter is capacity/range comparability, not just route feasibility.
        check(sim.spareCandidates(for: sim.currentRoute(of: jet)!).contains { $0 === a320 } == (sim.routeBlock(for: a320, from: sim.airport("JFK")!, to: sim.airport("LAX")!) == nil),
              "10: (the A320's route-feasibility is whatever routeBlock says; the coverage filter is stricter)")
        // Attempting to cover with the A320 is refused server-side.
        check(!sim.serviceMXWithCoverage(jet, coverWith: a320), "10: covering a 787 with an A320 is refused")
        check(!jet.inMXShop, "10: refused cover changed nothing")
        // A second 787 (like-size) IS a suitable cover.
        guard let jet2 = sim.buyAircraft(big) else { check(false, "setup 10 jet2"); printResult(); return }
        check(sim.mxIsSuitableCover(jet2, for: jet), "10: a second 787 IS a suitable cover")
        check(sim.mxCoverageCandidates(for: jet).contains { $0 === jet2 }, "10: the like-size 787 is offered")
        check(sim.serviceMXWithCoverage(jet, coverWith: jet2), "10: covering with the like-size 787 works")
    }

    // ---- 11. Suspend-route path: sendToMX on a routed C/D keeps the route (it resumes). ----
    do {
        let sim = newSim()
        guard let jet = buyRouted(sim, "B739") else { check(false, "setup 11"); printResult(); return }
        let rid = jet.assignedRouteId
        forceCheck(sim, jet, .c, over: 60)
        // No coverage — just service (suspend the route).
        check(sim.sendToMX(jet), "11: suspend-service a routed C check works")
        check(jet.inMXShop, "11: aircraft in shop")
        check(jet.assignedRouteId == rid, "11: route STAYS assigned (it's suspended, not handed off) — resumes on return")
        check(jet.mxReclaimRouteId == nil, "11: no coverage reclaim link (this is a suspend, not a cover)")
        // Run out the downtime → aircraft resumes its own route.
        for _ in 0..<(9 * 1440) { sim.advanceTick() }
        check(!jet.inMXShop, "11: out of the shop")
        check(jet.assignedRouteId == rid, "11: resumed its own route after the check")
    }

    // ---- 12. Suspend "lost revenue" reflects ONGOING per-leg profit, not the
    // opening-cost-amortized average (which reads ~$0 on a fresh route — the bug). ----
    do {
        let sim = newSim()
        guard let t = AircraftType.all.first(where: { $0.id == "B789" }), let jet = sim.buyAircraft(t) else { check(false, "setup 12"); printResult(); return }
        // Long-haul where a 787 is PROFITABLE (a short domestic hop loses money → $0).
        guard let o = sim.airport("JFK"), let d = sim.airport("LHR") else { check(false, "12 LHR"); printResult(); return }
        guard case .success = sim.openRoute(from: o, to: d, using: jet) else { check(false, "12 route"); printResult(); return }
        let dInt = sim.mxCycleInterval(.d, jet)
        jet.cyclesAccrued = dInt + 10
        // Stage like the seed: A/C FRESH (else the ~14k accrued cycles make the A check
        // wildly overdue and mxMostUrgent picks A, whose 1-day downtime gives the wrong
        // foregone figure — a real test-setup trap). D just due → D is most-urgent.
        jet.mxA = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued, lastTick: sim.tick)
        jet.mxC = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued, lastTick: sim.tick)
        jet.mxD = Aircraft.MXCheck(lastCycle: jet.cyclesAccrued - (dInt + 10), lastTick: sim.tick)
        check(sim.mxNextCheckETA(jet)?.kind == .d, "12: D is the most-urgent check (A/C staged fresh)")
        let perLeg = sim.legEconomics(for: jet).net
        check(perLeg > 0, "12: 787 on JFK-LHR is profitable per leg (\(perLeg))")
        let foregone = sim.mxForegoneRevenue(jet)
        // Must be a real figure (~$178k for a 21-day D at ~$50k/leg), NOT ~$0 from
        // cumulativeNet/flights on a route that hasn't recouped its opening cost.
        check(foregone > 50_000, "12: suspend lost-revenue is the ONGOING earnings over the downtime (\(foregone)), not ~$0")
        // Sanity: ≈ per-leg net × legs in the downtime.
        let legsPerDay = 1440.0 / 409.0
        let expected = Int(Double(perLeg) * legsPerDay * Double(sim.mxDowntimeDays(.d)))
        check(abs(foregone - expected) <= 2, "12: foregone == per-leg net × legs over the ~\(sim.mxDowntimeDays(.d))d downtime")
    }

    // ---- 13. Acquire-to-cover auto-flow: buy a like-size jet → it auto-covers. ----
    do {
        let sim = newSim()
        guard let big = AircraftType.all.first(where: { $0.id == "B789" }), let jet = sim.buyAircraft(big) else { check(false, "setup 13"); printResult(); return }
        if let o = sim.airport("JFK"), let d = sim.airport("LHR") { _ = sim.openRoute(from: o, to: d, using: jet) }
        forceCheck(sim, jet, .d, over: 60)
        let rid = jet.assignedRouteId
        // Player taps "Acquire a replacement" on jet's MX card → pendingCoverFor set.
        sim.pendingCoverFor = jet.tail
        // Buys an UNSUITABLE jet first (A320) → must NOT auto-cover.
        guard let small = AircraftType.all.first(where: { $0.id == "A320" }), let a320 = sim.buyAircraft(small) else { check(false, "13 a320"); printResult(); return }
        check(sim.tryAutoCoverAfterPurchase(a320) == nil, "13: buying an unsuitable A320 does NOT auto-cover the 787")
        check(!jet.inMXShop, "13: 787 not serviced by the wrong-size buy")
        check(sim.pendingCoverFor == jet.tail, "13: pending-cover intent survives an unsuitable buy")
        // Now buys a SUITABLE jet (787) → auto-covers.
        guard let jet2 = sim.buyAircraft(big) else { check(false, "13 jet2"); printResult(); return }
        let covered = sim.tryAutoCoverAfterPurchase(jet2)
        check(covered == jet.tail, "13: buying a like-size 787 auto-covers the route")
        check(jet.inMXShop, "13: original 787 is now in the shop")
        check(jet2.coveringForTail == jet.tail, "13: the new 787 is covering the original")
        check(jet2.assignedRouteId == rid, "13: the new 787 took over the route")
        check(sim.pendingCoverFor == nil, "13: pending-cover intent cleared after auto-cover")
        check(sim.mxCoverConfirm?.sub == jet2.tail && sim.mxCoverConfirm?.covered == jet.tail, "13: confirm banner data set (sub + covered)")
        // And the swap-back still works: after the check the original reclaims, sub benches.
        for _ in 0..<(23 * 1440) { sim.advanceTick() }
        check(jet.assignedRouteId == rid, "13: original reclaimed its route after the check")
        check(jet2.assignedRouteId == nil, "13: the covering 787 idled (assignable to a new route)")
    }

    printResult()
    func printResult() { print("\nMXCoverageVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }
}
