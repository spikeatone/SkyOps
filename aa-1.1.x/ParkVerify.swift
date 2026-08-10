import Foundation

// Verifies the "close route / park aircraft" action (customer-reported gap: no way
// to close a route or force a plane idle). parkAircraft() archives the route (P&L
// history kept, slots freed) and leaves the plane as an IDLE SPARE — immediately if
// at a gate, deferred to leg-completion if airborne (the same "don't teleport a jet
// mid-air" rule reassignment uses). No cash moves (opening cost is already sunk).
@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    func fresh() -> (Simulation, AircraftType) {
        let s = Simulation()
        s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Aster Air", tailCode: "MR")
        s.devInjectCash(500_000_000)
        let nb = AircraftType.all.first { $0.bodyType == .narrowbody }!
        return (s, nb)
    }
    func slotsFree(_ s: Simulation, _ code: String) -> Int { s.airport(code)?.slotsAvailable ?? -1 }

    // ---- 1. Park an AT-GATE aircraft: immediate close → idle spare. ----
    do {
        let (s, nb) = fresh()
        let o = s.airport("DEN")!, d = s.airport("ORD")!
        let s0o = slotsFree(s, "DEN"), s0d = slotsFree(s, "ORD")
        let ac = s.buyAircraft(nb)!
        _ = s.openRoute(from: o, to: d, using: ac)
        check(s.playerRoutes.count == 1, "route opened")
        check(slotsFree(s, "DEN") == s0o - 1 && slotsFree(s, "ORD") == s0d - 1, "both slots consumed on open")
        check(!s.isEnRoute(ac), "fresh aircraft is at the gate, not airborne")

        let ok = s.parkAircraft(ac)
        check(ok, "parkAircraft returns true for a routed at-gate aircraft")
        check(ac.assignedRouteId == nil && ac.isIdleSpare, "aircraft is now an idle spare (kept)")
        check(s.playerRoutes.isEmpty && s.closedPlayerRoutes.count == 1, "route archived (history kept), not deleted")
        check(slotsFree(s, "DEN") == s0o && slotsFree(s, "ORD") == s0d, "both slots freed on park")
        check(s.ownedCount == 1, "the plane was NOT sold")
        check(s.cashInvariantResidual() == 0, "park moves no cash (invariant holds)")
        // Parking an idle spare is a no-op.
        check(s.parkAircraft(ac) == false, "parking an idle spare returns false (nothing to close)")
    }

    // ---- 2. Park an AIRBORNE aircraft: deferred until it lands. ----
    do {
        let (s, nb) = fresh()
        let o = s.airport("DEN")!, d = s.airport("ORD")!
        let ac = s.buyAircraft(nb)!
        _ = s.openRoute(from: o, to: d, using: ac)
        var guardTicks = 0
        while !s.isEnRoute(ac) && guardTicks < 5000 { s.advanceTick(); guardTicks += 1 }
        check(s.isEnRoute(ac), "aircraft reached the air")

        _ = s.parkAircraft(ac)
        check(ac.pendingPark, "airborne park is scheduled (pendingPark set)")
        check(ac.assignedRouteId != nil && s.playerRoutes.count == 1, "route stays OPEN while it finishes the leg")

        // Fly on until it lands and the deferred park fires.
        var g2 = 0
        while ac.assignedRouteId != nil && g2 < 20000 { s.advanceTick(); g2 += 1 }
        check(ac.assignedRouteId == nil && ac.isIdleSpare, "parks as an idle spare on arrival")
        check(!ac.pendingPark, "pendingPark cleared after it parks")
        check(s.closedPlayerRoutes.count == 1, "route archived on arrival")
        check(s.cashInvariantResidual() == 0, "invariant holds after deferred park")
    }

    // ---- 3. Park cancels a scheduled reassignment (tears down its paid route). ----
    do {
        let (s, nb) = fresh()
        let o = s.airport("DEN")!, d = s.airport("ORD")!
        let ac = s.buyAircraft(nb)!
        _ = s.openRoute(from: o, to: d, using: ac)
        var g = 0
        while !s.isEnRoute(ac) && g < 5000 { s.advanceTick(); g += 1 }
        // Reassign while airborne → creates + pays for a new route, sets pendingRouteId.
        let o2 = s.airport("LAX")!, d2 = s.airport("SFO")!
        _ = s.reassign(ac, from: o2, to: d2)
        check(ac.pendingRouteId != nil, "reassignment scheduled (pendingRouteId set)")
        check(s.playerRoutes.count == 2, "the new (pending) route exists")

        _ = s.parkAircraft(ac)
        check(ac.pendingRouteId == nil, "park cancels the scheduled reassignment")
        check(ac.pendingPark, "park is itself scheduled (still airborne)")
        // The pending LAX–SFO route is torn down; only the original DEN–ORD remains open.
        check(s.playerRoutes.count == 1 && s.playerRoutes.first?.originCode == "DEN", "pending reassignment route torn down")
        var g2 = 0
        while ac.assignedRouteId != nil && g2 < 20000 { s.advanceTick(); g2 += 1 }
        check(ac.isIdleSpare, "ends as an idle spare")
        check(s.cashInvariantResidual() == 0, "invariant holds (route opening costs sunk, no double-charge)")
    }

    // ---- 4. A scheduled (airborne) park survives save/reload. ----
    do {
        let (s, nb) = fresh()
        let o = s.airport("DEN")!, d = s.airport("ORD")!
        let ac = s.buyAircraft(nb)!
        _ = s.openRoute(from: o, to: d, using: ac)
        var g = 0
        while !s.isEnRoute(ac) && g < 5000 { s.advanceTick(); g += 1 }
        _ = s.parkAircraft(ac)
        check(ac.pendingPark, "pendingPark set before save")

        let snap = s.snapshot()
        guard let data = try? JSONEncoder().encode(snap),
              let decoded = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
            check(false, "snapshot round-trip failed"); print("\n\(pass)/\(pass+fail) — FAILED"); return
        }
        let r = Simulation(); r.configure(viewport: CGSize(width: 400, height: 800)); r.restore(from: decoded)
        let rac = r.aircraft.first { $0.purchased }!
        check(rac.pendingPark, "pendingPark survives save/reload (intent not stranded)")
        var g2 = 0
        while rac.assignedRouteId != nil && g2 < 20000 { r.advanceTick(); g2 += 1 }
        check(rac.isIdleSpare, "the restored aircraft still parks on arrival")
        check(r.cashInvariantResidual() == -500_000_000, "restored residual == -(un-persisted dev injection)")
    }

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}
MainActor.assumeIsolated { run() }
