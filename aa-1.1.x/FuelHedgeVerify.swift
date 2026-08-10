import Foundation

// Regression guard for the customer-reported bug: "I bought the 90-day fuel hedge,
// but when I closed out the app it disappeared ... it gives me the option to buy
// more." Root cause: `fuelHedgeExpiryTick` was never in GameSnapshot / snapshot() /
// restore(), so a PAID hedge was dropped on the autosave->relaunch round-trip.
// This drives the REAL save path (snapshot -> JSON -> decode -> restore) and proves
// the hedge survives, that re-buying is correctly refused after reload, that it
// still expires on schedule, and that a legacy save (no field) decodes gracefully.
@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func isSuccess(_ r: Simulation.FuelHedgeResult) -> Bool { if case .success = r { return true }; return false }
    func isAlreadyActive(_ r: Simulation.FuelHedgeResult) -> Bool { if case .alreadyActive = r { return true }; return false }

    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("Aster Air", tailCode: "MR")
    sim.devInjectCash(500_000_000)

    // A hedge premium requires an owned fleet (it's priced off holdCostPerTick).
    guard let nb = AircraftType.all.first(where: { $0.bodyType == .narrowbody }) else { print("setup failed"); return }
    guard sim.buyAircraft(nb) != nil else { print("buy failed"); return }

    // Buy the 90-day hedge (the customer's case).
    let buy = sim.buyFuelHedge(days: 90)
    check(isSuccess(buy), "90-day hedge purchase succeeds")
    check(sim.fuelHedgeActive, "hedge active pre-save")
    let days0 = sim.fuelHedgeDaysRemaining
    check(days0 == 90, "90 days remaining pre-save (got \(days0))")
    // Pre-save, a second buy must be refused (this is the guard the customer's
    // reloaded, wiped state was wrongly bypassing).
    check(isAlreadyActive(sim.buyFuelHedge(days: 60)), "re-buy refused while active (pre-save)")
    check(sim.cashInvariantResidual() == 0, "invariant holds after hedge buy (devInjectedCash tracked on live sim)")

    // THE REAL SAVE PATH: snapshot -> JSON -> decode -> restore into a fresh sim.
    let snap = sim.snapshot()
    guard let data = try? JSONEncoder().encode(snap),
          let decoded = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
        print("FAIL: snapshot did not round-trip"); print("\n\(pass)/\(pass+1) — FAILED"); return
    }
    let restored = Simulation()
    restored.configure(viewport: CGSize(width: 400, height: 800))
    restored.restore(from: decoded)

    // THE FIX: the hedge survives the reload (was false before — the bug).
    check(restored.fuelHedgeActive, "hedge STILL active after save/reload (the fix)")
    check(restored.fuelHedgeDaysRemaining == days0, "days remaining preserved (\(restored.fuelHedgeDaysRemaining) == \(days0))")
    // And the "buy more" option is correctly gone after reload.
    check(isAlreadyActive(restored.buyFuelHedge(days: 30)), "re-buy refused after reload (no phantom re-purchase)")

    // It still expires on schedule: advance just past 90 sim-days.
    for _ in 0..<(1440 * 90 + 10) { restored.advanceTick() }
    check(!restored.fuelHedgeActive, "hedge expires ~90 days after purchase")
    check(isSuccess(restored.buyFuelHedge(days: 30)), "a new hedge can be bought once the old one expires")

    // Legacy save (written before the fix has the field): strip the key, decode,
    // and confirm it loads gracefully with no hedge (decodeSafeOpt -> nil).
    if var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        obj.removeValue(forKey: "fuelHedgeExpiryTick")
        if let legacyData = try? JSONSerialization.data(withJSONObject: obj),
           let legacy = try? JSONDecoder().decode(GameSnapshot.self, from: legacyData) {
            let old = Simulation()
            old.configure(viewport: CGSize(width: 400, height: 800))
            old.restore(from: legacy)
            check(!old.fuelHedgeActive, "legacy save (no field) decodes with no active hedge")
        } else { check(false, "legacy save failed to decode") }
    } else { check(false, "could not build legacy JSON") }

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}
MainActor.assumeIsolated { run() }
