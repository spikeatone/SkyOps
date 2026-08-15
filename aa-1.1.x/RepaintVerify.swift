//  RepaintVerify.swift — FLEET REPAINT (36/36)
//
//  Covers: per-airframe cost bands against the designer's real-world figures, the
//  itemized quote, the SHOP QUEUE (only `repaintShopSlots` in at once, longest job
//  first, program length scaling with fleet size rather than one job), stage +
//  progress reporting, the whole program draining, refusal paths being INERT, the
//  cash invariant at every step, and a save/load round-trip.
//
//  RUN (entry file must be named main.swift):
//    mkdir -p /tmp/rpv && cp aa-1.1.x/RepaintVerify.swift /tmp/rpv/main.swift
//    cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/rpv/
//    swiftc -O -DDEBUG -o /tmp/rpv/rpv \
//      AirlineArchitect/AirlineArchitect/Sim/*.swift \
//      AirlineArchitect/AirlineArchitect/Persistence.swift \
//      /tmp/rpv/RepaintVerifyStubs.swift /tmp/rpv/main.swift && /tmp/rpv/rpv
//
//  The stubs exist because Livery.swift imports SwiftUI and so can't be compiled
//  into a headless harness; they mirror its catalog sizes only.
//
//  NOTE: FIVE "failures" during authoring were all WRONG ASSERTIONS, not bugs — an
//  A380 owner is not broke, buying more jets raises the bill as fast as it drains
//  cash, a restored sim is off by exactly the un-persisted test injection, and on a
//  4-aircraft fleet the two longest jobs are 14d and 10d (not both >= 12d). Check a
//  finding against the real contract before "fixing" the game.

import Foundation

@MainActor func run() {
    var pass = 0, fail = 0
    func check(_ label: String, _ cond: Bool, _ detail: String = "") {
        if cond { pass += 1; print("  ok   \(label)") }
        else { fail += 1; print("  FAIL \(label) \(detail)") }
    }

    // ---- cost bands match the designer's real-world guidance
    let bands: [(String, Int, Int)] = [   // typeID, min, max acceptable
        ("A320",  50_000, 150_000),      // narrowbody band
        ("B789", 150_000, 300_000),      // widebody band
        ("A380", 300_000, 500_000),      // jumbo band
    ]
    for (id, lo, hi) in bands {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { continue }
        let c = Simulation.repaintCost(for: t)
        check("\(id) repaint \(c) within $\(lo)-\(hi)", c >= lo && c <= hi, "got \(c)")
    }
    // turboprop/RJ below the narrowbody floor
    if let t = AircraftType.all.first(where: { $0.id == "DH8B" }) {
        check("turboprop below narrowbody band", Simulation.repaintCost(for: t) < 50_000)
    }

    // ---- itemized quote
    let sim = Simulation()
    sim.nameAirline("Test Air", tailCode: "TN")
    sim.devInjectCash(500_000_000)
    for id in ["A320", "A320", "B789", "DH8B"] {
        if let t = AircraftType.all.first(where: { $0.id == id }) { _ = sim.buyAircraft(t) }
    }
    let q = sim.repaintQuote
    check("quote groups by type (3 lines for 4 aircraft)", q.count == 3, "got \(q.count)")
    let a320 = q.first { $0.typeID == "A320" }
    check("A320 line counts 2", a320?.count == 2, "got \(String(describing: a320?.count))")
    check("A320 line cost = 2 x each", a320.map { $0.lineCost == $0.eachCost * 2 } ?? false)
    let manual = sim.aircraft.filter(\.purchased).reduce(0) { $0 + Simulation.repaintCost(for: $1.type) }
    check("total == sum over airframes", sim.repaintTotal == manual, "\(sim.repaintTotal) vs \(manual)")
    // Program length must reflect the SHOP QUEUE, not one job: with 2 slots and
    // 4 aircraft it has to exceed the longest single job.
    let longestJob = q.map(\.days).max() ?? 0
    check("program length exceeds the longest single job",
          sim.repaintProgramDays > longestJob, "\(sim.repaintProgramDays) vs \(longestJob)")

    // ---- the repaint itself
    let before = sim.playerBalance
    let bill = sim.repaintTotal
    let ok = sim.repaintFleet(fontIndex: 2, paletteIndex: 3, tailArtIndex: 4, text: "REPAINTED")
    check("repaint succeeds", ok)
    check("charged exactly the quote", sim.playerBalance == before - bill,
          "\(before - sim.playerBalance) vs \(bill)")
    check("livery applied", sim.liveryPaletteIndex == 3 && sim.liveryTailArtIndex == 4 && sim.liveryText == "REPAINTED")
    check("only the shop slots are occupied", sim.repaintingCount == Simulation.repaintShopSlots,
          "in shop \(sim.repaintingCount)")
    check("the rest are queued, still flying",
          sim.repaintQueuedCount == sim.ownedCount - Simulation.repaintShopSlots,
          "queued \(sim.repaintQueuedCount)")
    check("program covers the whole fleet", sim.repaintProgramTotal == sim.ownedCount)
    check("cash invariant holds", sim.cashInvariantResidual() == 0, "residual \(sim.cashInvariantResidual())")

    // ---- a second repaint is refused while one is running, and changes NOTHING
    let midBal = sim.playerBalance, midPal = sim.liveryPaletteIndex
    check("second repaint refused", !sim.repaintFleet(fontIndex: 0, paletteIndex: 9, tailArtIndex: 1, text: "NOPE"))
    check("refusal moved no cash", sim.playerBalance == midBal)
    check("refusal left livery alone", sim.liveryPaletteIndex == midPal)

    // ---- grounded aircraft don't fly, then come back
    // The biggest jets go in FIRST (longest-job-first keeps the program short).
    let inShop = sim.aircraft.filter { $0.purchased && $0.inPaintShop }
    // Longest-job-first: nothing still QUEUED may be longer than what's in the shop.
    let shopMin = inShop.map { Simulation.repaintDays(for: $0.type) }.min() ?? 0
    let queuedMax = sim.aircraft.filter { $0.purchased && $0.repaintQueued }
        .map { Simulation.repaintDays(for: $0.type) }.max() ?? 0
    check("longest jobs scheduled first", shopMin >= queuedMax,
          "shop min \(shopMin) < queued max \(queuedMax); in shop: \(inShop.map { $0.type.id })")
    if let big = inShop.first {
        let expected = Simulation.repaintDays(for: big.type) * 1440
        check("shop duration = its band", (big.repaintUntilTick ?? 0) - (big.repaintStartTick ?? 0) == expected)
        check("stage is reported", big.repaintStage(at: sim.tick) != nil)
        check("progress starts near 0", (big.repaintProgress(at: sim.tick) ?? 1) < 0.05)
    }
    // Run the WHOLE program out: every aircraft must pass through the shop.
    for _ in 0..<(sim.repaintProgramDays * 1440 + 5000) { sim.advanceTick() }
    check("program finishes — nothing in the shop", sim.repaintingCount == 0,
          "still in shop: \(sim.repaintingCount)")
    check("program finishes — nothing queued", sim.repaintQueuedCount == 0,
          "still queued: \(sim.repaintQueuedCount)")
    check("invariant still holds after release", sim.cashInvariantResidual() == 0)

    // ---- unaffordable repaint is inert
    // Buy an A380 with just enough cash that the airframe is owned but the
    // repaint bill can no longer be covered.
    // A single A380 ($400k bill) with only a sliver of cash left. Buying the jet
    // itself drains the balance, so the shortfall is created by the purchase.
    let poor = Simulation()
    poor.nameAirline("Broke Air", tailCode: "BK")
    if let t = AircraftType.all.first(where: { $0.id == "A380" }) {
        // The sim already starts with `startingCapital`, so inject only the
        // difference needed to leave ~100k against a 400k bill.
        poor.devInjectCash(max(0, t.purchasePrice + 100_000 - poor.playerBalance))
        _ = poor.buyAircraft(t)
    }
    check("poor airline really is short", !poor.canAffordRepaint,
          "bal \(poor.playerBalance) bill \(poor.repaintTotal)")
    let pb = poor.playerBalance, pp = poor.liveryPaletteIndex
    check("unaffordable repaint refused", !poor.repaintFleet(fontIndex: 0, paletteIndex: 5, tailArtIndex: 2, text: "X"))
    check("unaffordable moved no cash", poor.playerBalance == pb)
    check("unaffordable left livery alone", poor.liveryPaletteIndex == pp)

    // ---- PERSISTENCE: a paid repaint must survive save/load. This is the exact
    // class of bug the fuel hedge shipped with (paid asset dropped on reload).
    let ps = Simulation()
    ps.nameAirline("Save Air", tailCode: "SV")
    ps.devInjectCash(400_000_000)
    for id in ["B789", "DH8B"] {
        if let t = AircraftType.all.first(where: { $0.id == id }) { _ = ps.buyAircraft(t) }
    }
    _ = ps.repaintFleet(fontIndex: 3, paletteIndex: 7, tailArtIndex: 5, text: "SAVED")
    let spentBefore = ps.totalRepaintSpend
    let shopBefore = ps.repaintingCount
    let untilBefore = ps.aircraft.first { $0.purchased && $0.type.id == "B789" }?.repaintUntilTick

    let snap = ps.snapshot()
    let data = try! JSONEncoder().encode(snap)
    let back = try! JSONDecoder().decode(GameSnapshot.self, from: data)
    let ps2 = Simulation()
    ps2.restore(from: back)
    check("repaint spend survives reload", ps2.totalRepaintSpend == spentBefore,
          "\(ps2.totalRepaintSpend) vs \(spentBefore)")
    check("aircraft still in the shop after reload", ps2.repaintingCount == shopBefore,
          "\(ps2.repaintingCount) vs \(shopBefore)")
    check("shop end tick survives reload",
          ps2.aircraft.first { $0.purchased && $0.type.id == "B789" }?.repaintUntilTick == untilBefore)
    check("livery survives reload",
          ps2.liveryPaletteIndex == 7 && ps2.liveryTailArtIndex == 5 && ps2.liveryText == "SAVED")
    // devInjectedCash is deliberately NOT persisted, so a restored sim's residual
    // is exactly minus the test injection — assert that, rather than relaxing the
    // check (which is what proves persistence is right instead of merely passing).
    check("invariant off by exactly the un-persisted test injection",
          ps2.cashInvariantResidual() == -400_000_000,
          "residual \(ps2.cashInvariantResidual())")
    // A legacy save (no repaint fields) must decode with defaults, not throw.
    var legacy = ps.snapshot()
    legacy.totalRepaintSpend = nil
    let ld = try! JSONEncoder().encode(legacy)
    let lback = try! JSONDecoder().decode(GameSnapshot.self, from: ld)
    check("legacy save decodes with repaint default", (lback.totalRepaintSpend ?? 0) == 0)

    print("\n\(pass) passed, \(fail) failed")
    exit(fail == 0 ? 0 : 1)
}
MainActor.assumeIsolated { run() }
