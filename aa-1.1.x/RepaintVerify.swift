//  RepaintVerify.swift — FLEET REPAINT (30/30)
//
//  Covers: the per-airframe cost bands against the designer's real-world figures,
//  the itemized quote (grouping, per-line math, total, parallel downtime), the
//  charge + livery application, the whole fleet going into and coming out of the
//  shop, refusal paths (already running / unaffordable) being INERT, the cash
//  invariant at every step, and a save/load round-trip — a paid repaint vanishing
//  on reload is exactly the bug the fuel hedge shipped with.
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
//  NOTE: four "failures" during authoring were all WRONG ASSERTIONS, not bugs —
//  an A380 owner is not broke, buying more jets raises the bill as fast as it
//  drains cash, and a restored sim is off by exactly the un-persisted test
//  injection. Check a finding against the real contract before "fixing" the game.

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
    check("longest days = max, not sum", sim.repaintLongestDays == q.map(\.days).max())

    // ---- the repaint itself
    let before = sim.playerBalance
    let bill = sim.repaintTotal
    let ok = sim.repaintFleet(fontIndex: 2, paletteIndex: 3, tailArtIndex: 4, text: "REPAINTED")
    check("repaint succeeds", ok)
    check("charged exactly the quote", sim.playerBalance == before - bill,
          "\(before - sim.playerBalance) vs \(bill)")
    check("livery applied", sim.liveryPaletteIndex == 3 && sim.liveryTailArtIndex == 4 && sim.liveryText == "REPAINTED")
    check("whole fleet in the shop", sim.repaintingCount == sim.ownedCount)
    check("cash invariant holds", sim.cashInvariantResidual() == 0, "residual \(sim.cashInvariantResidual())")

    // ---- a second repaint is refused while one is running, and changes NOTHING
    let midBal = sim.playerBalance, midPal = sim.liveryPaletteIndex
    check("second repaint refused", !sim.repaintFleet(fontIndex: 0, paletteIndex: 9, tailArtIndex: 1, text: "NOPE"))
    check("refusal moved no cash", sim.playerBalance == midBal)
    check("refusal left livery alone", sim.liveryPaletteIndex == midPal)

    // ---- grounded aircraft don't fly, then come back
    let dh = sim.aircraft.first { $0.purchased && $0.type.id == "DH8B" }!
    let expected = Simulation.repaintDays(for: dh.type) * 1440
    check("DH8B downtime = its band", (dh.repaintUntilTick ?? 0) - sim.tick == expected,
          "\((dh.repaintUntilTick ?? 0) - sim.tick) vs \(expected)")
    for _ in 0..<(sim.repaintLongestDays * 1440 + 200) { sim.advanceTick() }
    check("fleet released after the longest job", sim.repaintingCount == 0,
          "still in shop: \(sim.repaintingCount)")
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
