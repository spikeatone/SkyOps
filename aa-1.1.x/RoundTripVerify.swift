import Foundation

// End-to-end: a REAL Simulation → snapshot() → JSON encode → JSON decode →
// restore() into a fresh sim. Exercises the actual save path through the new
// custom Codable decoders, guarding against any round-trip regression.
@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("Aster Air", tailCode: "MR")
    sim.devInjectCash(500_000_000)   // fund a fleet + routes
    check(sim.cashInvariantResidual() == 0, "invariant after inject")

    // Build real state: two aircraft on two routes, a loan, and time flown.
    guard let nb = AircraftType.all.first(where: { $0.bodyType == .narrowbody }),
          let o1 = sim.airport("DEN"), let d1 = sim.airport("ORD"),
          let o2 = sim.airport("LAX"), let d2 = sim.airport("SFO") else { print("setup failed"); return }
    guard let a1 = sim.buyAircraft(nb) else { print("buy1 failed"); return }
    _ = sim.openRoute(from: o1, to: d1, using: a1)
    guard let a2 = sim.buyAircraft(nb) else { print("buy2 failed"); return }
    _ = sim.openRoute(from: o2, to: d2, using: a2)
    _ = sim.takeLoan(LoanOffer.all.first!)
    for _ in 0..<(1440 * 20) { sim.advanceTick() }   // ~20 sim-days of real activity
    check(sim.cashInvariantResidual() == 0, "invariant after 20 sim-days")

    // Capture ground truth.
    let name0 = sim.playerAirlineName, tail0 = sim.playerTailCode
    let bal0 = sim.playerBalance, tick0 = sim.tick
    let fleet0 = sim.ownedCount, routes0 = sim.playerRoutes.count
    let rep0 = sim.reputation, finSnaps0 = sim.financeSnapshots.count
    let loans0 = sim.loans.count

    // THE REAL SAVE PATH: snapshot -> JSON bytes -> JSON -> restore.
    let snap = sim.snapshot()
    guard let data = try? JSONEncoder().encode(snap) else { print("encode failed"); return }
    guard let decoded = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
        print("FAIL: real snapshot did not decode"); print("\n\(pass)/\(pass+1) — FAILED"); return
    }
    let restored = Simulation()
    restored.configure(viewport: CGSize(width: 400, height: 800))
    restored.restore(from: decoded)

    check(restored.playerAirlineName == name0, "name restored")
    check(restored.playerTailCode == tail0, "tail code restored")
    check(restored.playerBalance == bal0, "balance restored exactly (\(restored.playerBalance) == \(bal0))")
    check(restored.tick == tick0, "tick restored")
    check(restored.ownedCount == fleet0, "fleet size restored (\(restored.ownedCount) == \(fleet0))")
    check(restored.playerRoutes.count == routes0, "routes restored (\(restored.playerRoutes.count) == \(routes0))")
    check(restored.reputation == rep0, "reputation restored")
    check(restored.financeSnapshots.count == finSnaps0, "finance snapshots restored")
    check(restored.loans.count == loans0, "loans restored")
    // devInjectCash is a DEBUG test hook that is NOT persisted, so a restored sim's
    // residual equals exactly minus the injected amount — which PROVES the balance
    // (incl. the injected cash) restored exactly, rather than merely passing a
    // relaxed check. (Same lesson the Acquisition harness records in CLAUDE.md.)
    check(restored.cashInvariantResidual() == -500_000_000, "restored residual == -(un-persisted dev injection) (exact restore)")

    // And it keeps running cleanly (the constant injection offset stays constant).
    for _ in 0..<2000 { restored.advanceTick() }
    check(restored.cashInvariantResidual() == -500_000_000, "residual stays constant after restored sim runs")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}
MainActor.assumeIsolated { run() }
