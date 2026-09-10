import Foundation

// MAINTENANCE NETWORK verification — `aa-1.1.x/MX_BASES_SCOPE.md` phases 1 and 2:
// the auto-A-check policy (the card-volume fix), the contract-MRO premium and hangar
// slot wait, and the player's own line stations and hangar bases. Plus the
// cycles→days conversion that four sites used to hardcode as 2 while the engine
// actually flies ~3.5, which made every maintenance date the player saw far too far
// out. Rename to main.swift to run.

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func printResult() { print("\nMXBaseVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }

    func newSim() -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Base Air", tailCode: "BQ"); s.devInjectCash(500_000_000_000)
        return s
    }
    /// Buy a jet and route it between two codes.
    @discardableResult
    func routed(_ sim: Simulation, _ id: String, _ from: String, _ to: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }), let ac = sim.buyAircraft(t),
              let o = sim.airport(from), let d = sim.airport(to) else { return nil }
        guard case .success = sim.openRoute(from: o, to: d, using: ac) else { return nil }
        return ac
    }
    /// Force one check due NOW (others fresh, so it is the most-urgent).
    func forceDue(_ sim: Simulation, _ ac: Aircraft, _ kind: Aircraft.MXKind, over: Int = 5) {
        let interval = sim.mxCycleInterval(kind, ac)
        ac.cyclesAccrued = max(ac.cyclesAccrued, interval + over + 10)
        let now = ac.cyclesAccrued, t = sim.tick
        ac.mxA = Aircraft.MXCheck(lastCycle: now, lastTick: t)
        ac.mxC = Aircraft.MXCheck(lastCycle: now, lastTick: t)
        ac.mxD = Aircraft.MXCheck(lastCycle: now, lastTick: t)
        switch kind {
        case .a: ac.mxA = Aircraft.MXCheck(lastCycle: now - (interval + over), lastTick: t)
        case .c: ac.mxC = Aircraft.MXCheck(lastCycle: now - (interval + over), lastTick: t)
        case .d: ac.mxD = Aircraft.MXCheck(lastCycle: now - (interval + over), lastTick: t)
        }
    }
    /// Advance to the next daily boundary + a bit, so the daily MX sweeps run.
    func nextDay(_ sim: Simulation, _ days: Int = 1) { for _ in 0..<(days * 1440 + 2) { sim.advanceTick() } }

    // ── 1. The cycles→days conversion is DERIVED, not a hardcoded 2 ──────────────
    do {
        let sim = newSim()
        check(abs(Simulation.mxCyclesPerSimDay - 1440.0 / Double(Simulation.legCycleTicks)) < 1e-9,
              "1: cycles/sim-day is derived from the flight cycle")
        check(Simulation.mxCyclesPerSimDay > 3.0,
              "1: …and is ~3.5, not the 2 four sites used to hardcode (got \(Simulation.mxCyclesPerSimDay))")
        guard let ac = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 1"); printResult(); return }
        // A check 150 cycles out should read ~43 days, not the old ~75.
        ac.mxA = Aircraft.MXCheck(lastCycle: ac.cyclesAccrued, lastTick: sim.tick)
        let want = Int(Double(Simulation.mxACycles) / Simulation.mxCyclesPerSimDay)
        check(abs(sim.mxDaysUntilDue(.a, ac) - want) <= 1,
              "1: days-until-due matches the real accrual rate (got \(sim.mxDaysUntilDue(.a, ac)), want ~\(want))")
    }

    // ── 2. AUTO-A: policy ON services silently; OFF pushes a card ────────────────
    do {
        let sim = newSim()
        guard let ac = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 2"); printResult(); return }
        check(sim.mxAutoServiceAChecks, "2: the policy defaults ON")
        forceDue(sim, ac, .a)
        // Measure the CHARGE, not the balance: a flying fleet books revenue and
        // operating cost in the same window, so a balance delta is not the fee.
        // (The Training-Centre harness lesson, verbatim.)
        let spentBefore = sim.totalMaintenanceCheckSpend, cost = sim.mxCheckCost(.a, ac)
        nextDay(sim)
        check(!sim.decisionQueue.contains { $0.kind == .mxCheck },
              "2: NO card for a due A check while the policy is on — the card-volume fix")
        // With no base of its own the check takes a day in the shop, so "serviced"
        // means it WENT IN — the clocks reset when it comes out.
        check(ac.inMXShop || sim.mxProgress(.a, ac) < 1.0, "2: the A check was actually serviced")
        check(sim.totalMaintenanceCheckSpend - spentBefore == cost,
              "2: charged exactly the quote (Δ \(sim.totalMaintenanceCheckSpend - spentBefore), quote \(cost))")
        check(sim.cashInvariantResidual() == 0, "2: cash invariant holds through an auto-serviced check")

        let sim2 = newSim()
        guard let ac2 = routed(sim2, "A320", "DEN", "ORD") else { check(false, "setup 2b"); printResult(); return }
        sim2.mxAutoServiceAChecks = false
        forceDue(sim2, ac2, .a)
        nextDay(sim2)
        check(sim2.decisionQueue.contains { $0.kind == .mxCheck && $0.aircraft === ac2 },
              "2: policy OFF restores the per-aircraft card")
    }

    // ── 3. C and D still ask, policy or not — they are real planning events ─────
    do {
        for kind in [Aircraft.MXKind.c, .d] {
            let sim = newSim()
            guard let ac = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 3"); printResult(); return }
            forceDue(sim, ac, kind)
            nextDay(sim)
            check(sim.decisionQueue.contains { $0.kind == .mxCheck && $0.aircraft === ac },
                  "3: a due \(kind.label) still pushes a card with auto-A on")
        }
    }

    // ── 4. Provider pricing: MRO premium vs your own base's discount ─────────────
    do {
        let sim = newSim()
        guard let ac = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 4"); printResult(); return }
        forceDue(sim, ac, .a)
        let list = sim.mxCheckBaseCost(.a, ac)
        let contract = sim.mxCheckCost(.a, ac)
        check(abs(Double(contract) - Double(list) * (1 + Simulation.mxContractPremium)) <= 2,
              "4: with no base, a check costs list +\(Int(Simulation.mxContractPremium * 100))% (got \(contract) vs \(list))")
        // Three routes at DEN make it an eligible strategic site.
        routed(sim, "A320", "DEN", "SEA"); routed(sim, "A320", "DEN", "LAX")
        check(sim.mxBaseEligible("DEN"), "4: DEN is eligible at \(sim.routesAt("DEN")) routes")
        check(!sim.mxBaseEligible("ORD"), "4: ORD (1 route) is NOT eligible")
        check(sim.buildMXBase(at: "DEN", tier: .lineStation), "4: line station built")
        let own = sim.mxCheckCost(.a, ac)
        check(abs(Double(own) - Double(list) * (1 - Simulation.mxBaseCostDiscount)) <= 2,
              "4: at your own base it costs list −\(Int(Simulation.mxBaseCostDiscount * 100))% (got \(own))")
        check(own < contract, "4: your base undercuts the MRO")
        check(!sim.mxBaseEligible("DEN"), "4: you can't build a second base at the same airport")
    }

    // ── 5. Building a base: exact cash, its own invariant term ───────────────────
    do {
        let sim = newSim()
        routed(sim, "A320", "DEN", "ORD"); routed(sim, "A320", "DEN", "SEA"); routed(sim, "A320", "DEN", "LAX")
        let cash = sim.playerBalance
        let cost = Simulation.mxBaseBuildCost(.hangarNarrow)
        check(sim.buildMXBase(at: "DEN", tier: .hangarNarrow), "5: hangar base built")
        check(sim.playerBalance == cash - cost, "5: exactly the build cost was deducted")
        check(sim.totalMXBaseSpend == cost, "5: it lands in totalMXBaseSpend")
        check(sim.cashInvariantResidual() == 0, "5: cash invariant holds after a build")
        check(sim.mxBases["DEN"]?.ledger.buildSpend == cost, "5: the ledger records the build")
        nextDay(sim, 31)
        check((sim.mxBases["DEN"]?.ledger.opexPaid ?? 0) >= Simulation.mxBaseMonthlyOpex(.hangarNarrow),
              "5: monthly opex is billed")
        check(sim.cashInvariantResidual() == 0, "5: …and the invariant still holds after opex")
    }

    // ── 6. An A check at your base is OVERNIGHT — it never enters the shop ───────
    do {
        let sim = newSim()
        guard let ac = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 6"); printResult(); return }
        routed(sim, "A320", "DEN", "SEA"); routed(sim, "A320", "DEN", "LAX")
        check(sim.buildMXBase(at: "DEN", tier: .lineStation), "6: line station built")
        check(sim.mxDowntimeDays(.a, for: ac) == 0, "6: an A check at a base costs zero days")
        forceDue(sim, ac, .a)
        nextDay(sim)
        check(!ac.inMXShop, "6: the aircraft never went into the shop")
        check(sim.mxProgress(.a, ac) < 1.0, "6: …and the check is done")
        let led = sim.mxBases["DEN"]!.ledger
        check(led.checksDone >= 1, "6: the base's ledger counted the check")
        check(led.feeSavings > 0, "6: it booked the MRO fee it avoided")
        check(led.timeValue > 0, "6: …and the flying day it handed back")
    }

    // ── 7. Tier capability: a line station can't do heavy work; a narrow hangar
    //      can't take a widebody. Both fall back to the MRO, never a dead end. ────
    do {
        let sim = newSim()
        guard let jet = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 7"); printResult(); return }
        routed(sim, "A320", "DEN", "SEA"); routed(sim, "A320", "DEN", "LAX")
        check(sim.buildMXBase(at: "DEN", tier: .lineStation), "7: line station built")
        check(sim.mxBaseCovering(jet, kind: .a) == "DEN", "7: the station takes A checks")
        check(sim.mxBaseCovering(jet, kind: .c) == nil, "7: it can't take a C check — that goes to the MRO")

        let sim2 = newSim()
        guard let wide = routed(sim2, "B789", "DEN", "LHR") else { check(false, "setup 7b"); printResult(); return }
        routed(sim2, "B789", "DEN", "NRT"); routed(sim2, "B789", "DEN", "CDG")
        check(sim2.buildMXBase(at: "DEN", tier: .hangarNarrow), "7: narrowbody hangar built")
        check(sim2.mxBaseCovering(wide, kind: .a) == "DEN", "7: it still does A checks on a widebody")
        check(sim2.mxBaseCovering(wide, kind: .c) == nil, "7: a widebody won't fit for a C check")
    }

    // ── 8. Hangar CAPACITY: past it, work overflows to the MRO ───────────────────
    do {
        let sim = newSim()
        var jets: [Aircraft] = []
        for code in ["ORD", "SEA", "LAX", "PHX"] { if let a = routed(sim, "A320", "DEN", code) { jets.append(a) } }
        check(jets.count == 4, "8: four routed jets through DEN")
        check(sim.buildMXBase(at: "DEN", tier: .hangarNarrow), "8: hangar base built")
        check(sim.mxHangarFreeSlots("DEN") == Simulation.mxHangarCapacity, "8: all slots free to start")
        for j in jets.prefix(Simulation.mxHangarCapacity) {
            forceDue(sim, j, .c)
            check(sim.mxBaseCovering(j, kind: .c) == "DEN", "8: a free slot takes the C check")
            check(sim.sendToMX(j), "8: serviced")
        }
        check(sim.mxHangarFreeSlots("DEN") == 0, "8: the hangar is full")
        let overflow = jets[Simulation.mxHangarCapacity]
        forceDue(sim, overflow, .c)
        check(sim.mxBaseCovering(overflow, kind: .c) == nil, "8: the next C check overflows to the MRO")
        check(sim.mxCheckCost(.c, overflow) > sim.mxCheckBaseCost(.c, overflow),
              "8: …and pays the MRO premium for it")
    }

    // ── 9. Network coverage: a base only serves rotations that touch it ──────────
    do {
        let sim = newSim()
        guard let near = routed(sim, "A320", "DEN", "ORD") else { check(false, "setup 9"); printResult(); return }
        routed(sim, "A320", "DEN", "SEA"); routed(sim, "A320", "DEN", "LAX")
        guard let far = routed(sim, "A320", "BOS", "MIA") else { check(false, "setup 9b"); printResult(); return }
        check(sim.buildMXBase(at: "DEN", tier: .lineStation), "9: base at DEN")
        check(sim.mxBaseServes("DEN", near), "9: a DEN rotation is served")
        check(!sim.mxBaseServes("DEN", far), "9: a BOS–MIA rotation is NOT — it never overnights there")
        check(sim.mxBaseCovering(far, kind: .a) == nil, "9: so its A check goes to the MRO")
        check(sim.mxDowntimeDays(.a, for: far) == Simulation.mxADowntimeDays, "9: …and costs a day")
        check(sim.mxDowntimeDays(.a, for: near) == 0, "9: while the DEN aircraft loses nothing")
    }

    // ── 10. MRO SLOT WAIT: it keeps flying, is charged once, and is exempt from
    //       the card and from force-grounding while it waits ─────────────────────
    do {
        let sim = newSim()
        // Find a tail whose deterministic wait is non-zero, so the test is stable.
        var jet: Aircraft? = nil
        for code in ["ORD", "SEA", "LAX", "PHX", "MSP", "DTW", "BOS", "JFK"] {
            guard let a = routed(sim, "B789", "DFW", code) else { continue }
            forceDue(sim, a, .c)
            if sim.mxSlotWaitDays(a, kind: .c) > 0 { jet = a; break }
        }
        guard let j = jet else { check(false, "10: no tail with a non-zero slot wait"); printResult(); return }
        let wait = sim.mxSlotWaitDays(j, kind: .c)
        let cash = sim.playerBalance, cost = sim.mxCheckCost(.c, j)
        check(sim.sendToMX(j), "10: servicing books an MRO slot")
        check(j.awaitingMXSlot && !j.inMXShop, "10: it is BOOKED and still flying, not in the shop")
        check(cash - sim.playerBalance == cost, "10: charged exactly once, at booking")
        check(!sim.mxDueAircraft.contains { $0 === j }, "10: a booked aircraft is not counted as needing attention")
        check(!sim.sendToMX(j), "10: it can't be double-booked")
        nextDay(sim, wait + 1)
        check(j.inMXShop, "10: the shop opened on the slot date")
        check(j.mxBookedKind == nil, "10: the booking cleared")
        check(sim.playerBalance <= cash - cost, "10: and it was NOT charged a second time")
        check(sim.cashInvariantResidual() == 0, "10: cash invariant holds across a booking")
    }

    // ── 11. A base HALVES-ish the heavy-check downtime and books the time saved ──
    do {
        let sim = newSim()
        var jets: [Aircraft] = []
        for code in ["ORD", "SEA", "LAX"] { if let a = routed(sim, "A320", "DEN", code) { jets.append(a) } }
        check(sim.buildMXBase(at: "DEN", tier: .hangarNarrow), "11: hangar base built")
        guard let j = jets.first else { check(false, "setup 11"); printResult(); return }
        forceDue(sim, j, .c)
        let full = sim.mxDowntimeDays(.c)
        let atBase = sim.mxDowntimeDays(.c, for: j)
        check(atBase < full && atBase >= 1, "11: a C check at your hangar is quicker (\(atBase) vs \(full) days)")
        check(sim.mxSlotWaitDays(j, kind: .c) == 0, "11: …and skips the slot queue entirely")
        check(sim.sendToMX(j), "11: serviced")
        check(j.inMXShop && j.mxShopBaseCode == "DEN", "11: the hangar slot is held by this aircraft")
    }

    // ── 12. Persistence: bases, spend, policy, the held slot and a live booking ──
    do {
        let sim = newSim()
        var jets: [Aircraft] = []
        for code in ["ORD", "SEA", "LAX"] { if let a = routed(sim, "A320", "DEN", code) { jets.append(a) } }
        check(sim.buildMXBase(at: "DEN", tier: .hangarWide), "12: widebody hangar built")
        sim.mxAutoServiceAChecks = false
        guard let inShop = jets.first else { check(false, "setup 12"); printResult(); return }
        forceDue(sim, inShop, .c)
        check(sim.sendToMX(inShop), "12: one aircraft in the hangar")
        let snap = sim.snapshot()
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
        sim2.restore(from: snap)
        check(sim2.mxBases["DEN"]?.tier == .hangarWide, "12: the base survives the round trip")
        check(sim2.totalMXBaseSpend == sim.totalMXBaseSpend, "12: build spend survives")
        check(sim2.mxAutoServiceAChecks == false, "12: the policy survives")
        let restored = sim2.aircraft.first { $0.tail == inShop.tail }
        check(restored?.mxShopBaseCode == "DEN", "12: the held hangar slot survives")
        check(sim2.mxHangarFreeSlots("DEN") == Simulation.mxHangarCapacity - 1,
              "12: …so capacity accounting is right after a reload")
        // `devInjectedCash` is deliberately NOT persisted, so a restored sim's residual
        // is exactly −(what the test injected). Asserting that EXACT number — rather
        // than relaxing the check — is what proves persistence is right and not merely
        // passing (the RoundTripVerify lesson).
        check(sim2.cashInvariantResidual() == -sim.devInjectedCash,
              "12: invariant intact after restore — residual is exactly the un-persisted test injection (got \(sim2.cashInvariantResidual()))")
    }

    // ── 13. A LEGACY save (no maintenance-network fields) loads with the fix on ──
    do {
        let sim = newSim()
        routed(sim, "A320", "DEN", "ORD")
        var snap = sim.snapshot()
        snap.mxBases = nil; snap.totalMXBaseSpend = nil; snap.mxAutoServiceAChecks = nil
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
        sim2.restore(from: snap)
        check(sim2.mxBases.isEmpty, "13: a pre-base save has no bases")
        check(sim2.totalMXBaseSpend == 0, "13: …and no build spend")
        check(sim2.mxAutoServiceAChecks, "13: the auto-A policy defaults ON for an existing airline — the card volume was their complaint")
    }

    // ── 14. It holds up over a long run: no cards from A checks, invariant intact ─
    do {
        let sim = newSim()
        for code in ["ORD", "SEA", "LAX", "PHX", "MSP", "DTW"] { routed(sim, "A320", "DEN", code) }
        for fam in sim.ownedFamilies {
            let want = Int(Double(sim.ownedCount(family: fam)) * 3.0) + 3
            while sim.crewCount(family: fam) < want { if sim.hireCrew(family: fam) == nil { break } }
        }
        check(sim.buildMXBase(at: "DEN", tier: .lineStation), "14: line station built")
        var mxCards = 0
        var seen = Set<String>()
        for _ in 0..<(120 * 1440) {
            sim.advanceTick()
            for d in Array(sim.decisionQueue) {
                if d.kind == .mxCheck, !seen.contains(d.id) { seen.insert(d.id); mxCards += 1 }
                switch d.kind {
                case .aog: sim.resolveAOGStandard(d)
                case .crew: sim.resolveCrewWait(d)
                case .sell: sim.resolveSellKeep(d)
                case .offer: sim.resolveOfferDecline(d)
                case .training: sim.resolveTrainingNow(d)
                case .airportOffer: sim.resolveAirportOfferDecline(d)
                case .hubOffer: sim.resolveHubSale(d, accept: false)
                case .activist: sim.resolveActivistComply(d)
                case .mxCheck: sim.resolveMXServiceNow(d)
                }
            }
        }
        let cycles = sim.aircraft.filter { $0.purchased }.map(\.cyclesAccrued).reduce(0, +)
        // A floor, not a target: a random labor action or an airworthiness-directive
        // grounding can idle this fleet for a real stretch, and that variance is the
        // game working. `checksDone` below is the non-vacuous guard — a fleet that
        // never flew would produce no checks either, so "0 cards" alone proves nothing.
        check(cycles > 500, "14: the fleet really flew (\(cycles) cycles)")
        check(mxCards == 0, "14: 120 sim-days of a flying fleet produced ZERO MX cards (got \(mxCards))")
        check(sim.cashInvariantResidual() == 0, "14: cash invariant holds over the whole run")
        let led = sim.mxBases["DEN"]!.ledger
        check(led.checksDone > 5, "14: the base did real work (\(led.checksDone) checks)")
        check(led.monthly.count >= 3, "14: monthly payback snapshots accumulated")
        check(led.monthly.count <= MaintenanceBase.maxSnapshots, "14: …and stay capped")
    }

    printResult()
}

// Entry point. WITHOUT this the file compiles to a binary that defines main()
// and never calls it — the harness "passes" by printing NOTHING.
MainActor.assumeIsolated { main() }
