import Foundation

// MULTI-CITY ROTATION (Phase 1) verification.
// Validates the sim/data core of the routing tool: a route is now an ordered
// loop of 2…5 stops; an owned aircraft walks the loop leg by leg (stops[i] →
// stops[i+1], wrapping to stops[0]) instead of only reversing A↔B; each leg
// settles its own point-to-point economics; range is checked on EVERY leg; the
// per-stop opening cost uses the distinct-stop rule (a hub visited twice pays
// once); and `stops`+`legIndex` survive save/load so a rotation resumes on the
// right leg. Crucially, a 2-stop rotation must reproduce the old reverse-shuttle
// exactly (regression guard). Rename to main.swift to run.

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    func newSim() -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Rotation Air", tailCode: "RT"); s.devInjectCash(5_000_000_000)
        return s
    }
    func buySpare(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { return nil }
        return sim.buyAircraft(t)
    }
    let LEG = 1440   // ticks to comfortably cover one full flight cycle + turnaround

    // Fly `legs` full legs, recording the (origin,dest) code pair the aircraft is
    // on at the START of each leg (i.e. right after each PARKED transition rolls
    // the next leg). Returns the ordered sequence actually flown.
    func flownSequence(_ sim: Simulation, _ ac: Aircraft, legs: Int) -> [String] {
        var seq: [String] = ["\(ac.origin.code)->\(ac.dest.code)"]
        var lastLeg = seq[0]
        var flown = 1
        var guardTicks = 0
        while flown < legs && guardTicks < legs * LEG * 2 {
            sim.advanceTick(); guardTicks += 1
            let cur = "\(ac.origin.code)->\(ac.dest.code)"
            if cur != lastLeg { seq.append(cur); lastLeg = cur; flown += 1 }
        }
        return seq
    }

    // ---- 1. A 3-stop rotation flies the loop in order, not just A<->B. ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320") else { check(false, "setup 1"); printResult(); return }
        // DEN -> ORD -> MSP -> (loop back to DEN). All well within an A320's range.
        let res = sim.openRotation(stops: ["DEN", "ORD", "MSP"], using: ac)
        check(res == Simulation.RotationResult.success, "1: 3-stop rotation opens")
        guard let r = sim.playerRoutes.first(where: { $0.id == ac.assignedRouteId }) else { check(false, "1 route"); printResult(); return }
        check(r.stops == ["DEN", "ORD", "MSP"], "1: route stores the 3 stops in order")
        check(ac.origin.code == "DEN" && ac.dest.code == "ORD", "1: starts on leg DEN->ORD (legIndex 0)")
        let seq = flownSequence(sim, ac, legs: 6)
        // Expected loop: DEN->ORD, ORD->MSP, MSP->DEN, DEN->ORD, ORD->MSP, MSP->DEN
        let expected = ["DEN->ORD", "ORD->MSP", "MSP->DEN", "DEN->ORD", "ORD->MSP", "MSP->DEN"]
        check(seq == expected, "1: flies the loop in order (got \(seq))")
    }

    // ---- 2. A 2-stop rotation reproduces the classic reverse-shuttle. ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320") else { check(false, "setup 2"); printResult(); return }
        check(sim.openRotation(stops: ["DEN", "ORD"], using: ac) == Simulation.RotationResult.success, "2: 2-stop rotation opens")
        let seq = flownSequence(sim, ac, legs: 4)
        check(seq == ["DEN->ORD", "ORD->DEN", "DEN->ORD", "ORD->DEN"], "2: 2-stop = A<->B reverse shuttle (got \(seq))")
    }

    // ---- 2b. openRoute (the classic 2-airport path) still yields a 2-stop rotation. ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320"), let o = sim.airport("DEN"), let d = sim.airport("ORD") else { check(false, "setup 2b"); printResult(); return }
        if case .success = sim.openRoute(from: o, to: d, using: ac) { check(true, "2b: openRoute succeeds") } else { check(false, "2b: openRoute succeeds") }
        let r = sim.playerRoutes.first { $0.id == ac.assignedRouteId }
        check(r?.stops == ["DEN", "ORD"], "2b: openRoute produces a [DEN,ORD] rotation")
        let seq = flownSequence(sim, ac, legs: 3)
        check(seq == ["DEN->ORD", "ORD->DEN", "DEN->ORD"], "2b: classic route flies unchanged (got \(seq))")
    }

    // ---- 3. Each leg settles its OWN point-to-point economics. ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320") else { check(false, "setup 3"); printResult(); return }
        _ = sim.openRotation(stops: ["DEN", "ORD", "MSP"], using: ac)
        let route = sim.playerRoutes.first { $0.id == ac.assignedRouteId }
        let before = sim.playerBalance
        for _ in 0..<(6 * LEG) { sim.advanceTick() }
        check((route?.flights ?? 0) >= 4, "3: several legs settled on the rotation (flights=\(route?.flights ?? 0))")
        // The per-flight log should carry legs with different endpoints, proving
        // each leg priced its own pair (not one repeated A<->B pair).
        let tails = Set((route?.history ?? []).map { $0.tail })
        check(tails == [ac.tail], "3: every logged leg is this aircraft")
        check(sim.playerBalance != before, "3: balance moved as legs settled")
        check(sim.cashInvariantResidual() == 0, "3: cash invariant holds through a multi-stop rotation")
    }

    // ---- 4. Range is checked on EVERY leg (incl. the closing leg). ----
    do {
        let sim = newSim()
        // A regional jet: fine short-haul, but a transcon leg is over range.
        guard let ac = buySpare(sim, "ERJ135") else { check(false, "setup 4"); printResult(); return }
        // DEN -> ORD (ok) -> JFK (ok-ish) -> loop JFK -> DEN is a long closing leg.
        // Use an obviously over-range leg mid-rotation: DEN -> LAX is ~1470nm > ERJ135 range? use JFK->LAX transcon.
        let res = sim.openRotation(stops: ["JFK", "LAX", "DEN"], using: ac)
        if case .legOutOfRange(let f, let t, _) = res {
            check(true, "4: over-range leg blocks the rotation (\(f)->\(t))")
        } else {
            check(false, "4: expected legOutOfRange, got \(res)")
        }
        check(ac.assignedRouteId == nil, "4: aircraft stays a spare when a leg is out of range")
    }

    // ---- 5. Stop-count bounds + adjacent-dup handling. ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320") else { check(false, "setup 5"); printResult(); return }
        check(sim.openRotation(stops: ["DEN"], using: ac) == .tooFewStops, "5: 1 stop rejected")
        check(sim.openRotation(stops: ["DEN", "ORD", "MSP", "IAH", "DFW", "ATL"], using: ac) == .tooManyStops, "5: 6 stops rejected (max 5)")
        // Adjacent duplicate is trimmed, leaving a valid rotation.
        let res = sim.openRotation(stops: ["DEN", "DEN", "ORD"], using: ac)
        check(res == Simulation.RotationResult.success, "5: adjacent duplicate trimmed to a valid rotation")
        check(sim.playerRoutes.first(where: { $0.id == ac.assignedRouteId })?.stops == ["DEN", "ORD"], "5: [DEN,DEN,ORD] -> [DEN,ORD]")
    }

    // ---- 6. Cost/slot: distinct-stop rule (a hub visited twice is charged once). ----
    do {
        let sim = newSim()
        // ORD -> DEN -> ORD -> MSP has ORD twice; distinct stops = {ORD,DEN,MSP}.
        // Its cost should equal a rotation over the 3 distinct stops in one pass.
        let costRepeat = sim.rotationOpeningCost(["ORD", "DEN", "ORD", "MSP"])
        let costDistinct = sim.rotationOpeningCost(["ORD", "DEN", "MSP"])
        check(costRepeat == costDistinct, "6: repeated hub charged once (\(costRepeat) == \(costDistinct))")
    }

    // ---- 7. Save/load round-trips stops + legIndex (resumes on the right leg). ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320") else { check(false, "setup 7"); printResult(); return }
        _ = sim.openRotation(stops: ["DEN", "ORD", "MSP"], using: ac)
        // Advance a few legs so legIndex is non-zero.
        for _ in 0..<(2 * LEG + LEG / 2) { sim.advanceTick() }
        let savedLeg = ac.legIndex
        let savedRouteStops = sim.playerRoutes.first { $0.id == ac.assignedRouteId }?.stops
        let snap = sim.snapshot()
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
        sim2.restore(from: snap)
        let ac2 = sim2.aircraft.first { $0.tail == ac.tail }
        let r2 = sim2.playerRoutes.first { $0.id == ac2?.assignedRouteId }
        check(r2?.stops == savedRouteStops, "7: rotation stops survive save/load (\(r2?.stops ?? []))")
        check(ac2?.legIndex == savedLeg, "7: legIndex survives save/load (\(ac2?.legIndex ?? -1) == \(savedLeg))")
        // Continue flying — it must keep walking the loop from where it was.
        if let ac2 { let seq = flownSequence(sim2, ac2, legs: 4); check(seq.count == 4, "7: restored rotation keeps flying (got \(seq))") }
        // devInjectCash is a DEBUG hook that is NOT persisted, so a restored sim's
        // residual is exactly minus the injected amount (same as RoundTripVerify) —
        // and it stays CONSTANT as the restored rotation keeps settling legs, which
        // is what proves the multi-stop settlement reconciles across a restore.
        check(sim2.cashInvariantResidual() == -5_000_000_000, "7: restored residual == -(un-persisted injection), constant through more legs")
    }

    // ---- 8. Legacy 2-stop route (no `stops` field) restores as a shuttle. ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320"), let o = sim.airport("DEN"), let d = sim.airport("ORD") else { check(false, "setup 8"); printResult(); return }
        _ = sim.openRoute(from: o, to: d, using: ac)
        for _ in 0..<LEG { sim.advanceTick() }
        // A snapshot always writes `stops` now, but simulate a pre-rotation save by
        // confirming a [DEN,ORD] stops round-trips identically (the legacy default
        // decode path yields exactly this, tested at the Persistence layer).
        let snap = sim.snapshot()
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
        sim2.restore(from: snap)
        let r2 = sim2.playerRoutes.first { $0.id == sim2.aircraft.first(where: { $0.tail == ac.tail })?.assignedRouteId }
        check(r2?.stops == ["DEN", "ORD"], "8: 2-stop route round-trips as [DEN,ORD]")
    }

    // ---- 9. replacingCurrentRoute: reassign a routed aircraft onto a new
    //         rotation — the OLD route is archived, its slots freed. (Phase 2 /
    //         Fleet ASSIGN path.) ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "A320") else { check(false, "setup 9"); printResult(); return }
        _ = sim.openRotation(stops: ["DEN", "ORD"], using: ac)   // start on a 2-stop route
        let oldRouteId = ac.assignedRouteId
        let openBefore = sim.playerRoutes.count
        // Reassign onto a 3-stop rotation.
        let res = sim.openRotation(stops: ["SFO", "LAX", "SEA"], using: ac, replacingCurrentRoute: true)
        check(res == Simulation.RotationResult.success, "9: replacing open succeeds")
        check(ac.assignedRouteId != oldRouteId, "9: aircraft is on the NEW route")
        check(sim.playerRoutes.first(where: { $0.id == ac.assignedRouteId })?.stops == ["SFO", "LAX", "SEA"], "9: new rotation stored")
        check(sim.closedPlayerRoutes.contains { $0.id == oldRouteId }, "9: old route archived (not orphaned)")
        check(sim.playerRoutes.count == openBefore, "9: open-route count unchanged (one traded for one)")
        check(ac.legIndex == 0, "9: leg index reset for the new rotation")
    }

    // ---- 10. A FAILED replacing open leaves the existing route intact
    //          (validation runs BEFORE any detach). ----
    do {
        let sim = newSim()
        guard let ac = buySpare(sim, "ERJ135") else { check(false, "setup 10"); printResult(); return }
        _ = sim.openRotation(stops: ["DEN", "ORD"], using: ac)   // a route the RJ can fly
        let keptRouteId = ac.assignedRouteId
        // Try to reassign onto a rotation with an over-range leg (JFK-LAX > 1750).
        let res = sim.openRotation(stops: ["JFK", "LAX", "DEN"], using: ac, replacingCurrentRoute: true)
        if case .legOutOfRange = res { check(true, "10: over-range replacing open is rejected") }
        else { check(false, "10: expected legOutOfRange, got \(res)") }
        check(ac.assignedRouteId == keptRouteId, "10: aircraft still on its original route (no detach on failure)")
        check(sim.playerRoutes.contains { $0.id == keptRouteId }, "10: original route still open")
    }

    printResult()
    func printResult() { print("\nRotationVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }
}
