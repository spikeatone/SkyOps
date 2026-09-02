import Foundation

// T2.2 preventive-maintenance budget balance probe.
// Runs the SAME well-crewed multi-family fleet under each of the 3 PM tiers and
// measures: AOG incidents, PM spend, AOG-repair spend (maintenanceSpend), and net
// worth — to confirm (a) the cash invariant holds with the new term, and (b) the
// tiers are a REAL trade-off (Premium grounds fewer but costs more; the right pick
// isn't obvious). Rename to main.swift to compile.
//
// This tune CHANGES the baseline economy (Standard now has a real PM cost), so we
// want a wider read than just AOG counts: does each tier stay solvent, and does
// net worth actually differ enough that the choice matters?

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    struct Result { var aog = 0; var pmSpend = 0; var repairSpend = 0; var netWorth = 0; var invOK = true; var bankrupt = false }

    func runTier(_ tier: Simulation.MaintenanceBudget, runs: Int) -> Result {
        var agg = Result()
        for _ in 0..<runs {
            let sim = Simulation()
            sim.configure(viewport: CGSize(width: 400, height: 800))
            sim.nameAirline("PM Air", tailCode: "PM")
            sim.devInjectCash(400_000_000)
            sim.setMaintenanceBudget(tier)

            let types = AircraftType.all
            func buyType(_ id: String, _ n: Int) {
                guard let t = types.first(where: { $0.id == id }) else { return }
                for _ in 0..<n {
                    guard sim.playerBalance >= t.purchasePrice, let ac = sim.buyAircraft(t) else { return }
                    if let o = sim.airport("DEN"), let d = sim.airport("ORD") { _ = sim.openRoute(from: o, to: d, using: ac) }
                }
            }
            buyType("B737800", 5); buyType("A320", 5); buyType("E175", 4)
            for fam in sim.ownedFamilies {
                let target = Int((Double(sim.ownedCount(family: fam)) * 2.2).rounded())
                var g = 0
                while sim.crewCount(family: fam) < target && sim.playerBalance > 5_000_000 && g < 40 { sim.hireCrew(family: fam); g += 1 }
            }

            var aogSeen = 0
            var prevMaint = false
            let days = 720   // 2 sim-years
            for _ in 0..<days {
                for _ in 0..<1440 { sim.advanceTick() }
                // Resolve AOG cards with the cheaper standard repair; keep crews going.
                for dec in sim.decisionQueue {
                    switch dec.kind {
                    case .aog:   sim.resolveAOGStandard(dec)
                    case .crew:  if let ac = dec.aircraft, sim.canAffordCrewHire(for: ac) { sim.resolveCrewHire(dec) } else { sim.resolveCrewWait(dec) }
                    case .training: sim.resolveTrainingNow(dec)
                    default: break
                    }
                }
                // Count AOG onsets: any owned aircraft newly in maint.
                let inMaint = sim.aircraft.filter { $0.purchased && $0.maint }.count
                if inMaint > 0 && !prevMaint { aogSeen += 1 }
                prevMaint = inMaint > 0
                if sim.cashInvariantResidual() != 0 { agg.invOK = false }
                if sim.isBankrupt { break }
            }
            agg.aog += aogSeen
            agg.pmSpend += sim.totalPreventiveMaintSpend
            agg.repairSpend += sim.maintenanceSpend
            agg.netWorth += sim.netWorth
            if sim.isBankrupt { agg.bankrupt = true }
        }
        return agg
    }

    let runs = 6
    let mn = runTier(.minimal, runs: runs)
    let st = runTier(.standard, runs: runs)
    let pm = runTier(.premium, runs: runs)

    func line(_ name: String, _ r: Result) {
        print(String(format: "%-9@  AOG~%3d  PMspend $%.0fM  repair $%.0fM  netWorth $%.0fM  inv=%@ bankrupt=%@",
                     name as NSString, r.aog, Double(r.pmSpend)/1e6, Double(r.repairSpend)/1e6,
                     Double(r.netWorth)/1e6, r.invOK ? "Y":"N", r.bankrupt ? "Y":"N"))
    }
    print("\n--- PM TIER SWEEP (\(runs) runs × 2 sim-years each, ~14-aircraft fleet) ---")
    line("Minimal",  mn)
    line("Standard", st)
    line("Premium",  pm)

    // REFRAMED lever: the differentiator is AOG REPAIR SPEND, not onset. Premium's
    // 0.5× repair-cost factor should make its repair spend visibly lower than
    // Minimal's 1.6×. (Onset barely differs by design — AOG is rare.)
    check(pm.repairSpend < mn.repairSpend, "Premium repair spend < Minimal (the cost lever works: \(pm.repairSpend/1_000_000)M vs \(mn.repairSpend/1_000_000)M)")
    check(mn.invOK && st.invOK && pm.invOK, "cash invariant held under all 3 tiers")
    check(!mn.bankrupt && !st.bankrupt && !pm.bankrupt, "no bankruptcy under any tier (competent play)")
    // Sanity: net worth shouldn't be wildly dominated by one tier — the choice is a
    // trade-off. Report the spread; assert it's within a sane band (no tier is >15%
    // better than another over 2 years, i.e. it's a real decision not a no-brainer).
    let nws = [mn.netWorth, st.netWorth, pm.netWorth].map { Double($0) }
    let spread = (nws.max()! - nws.min()!) / nws.max()!
    print(String(format: "net-worth spread across tiers: %.1f%%", spread * 100))
    check(spread < 0.15, "net worth within 15% across tiers (a real trade-off, not a dominant pick)")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
    print("READ: compare Premium's lower repair spend + higher net worth vs its PM cost — if net worth is")
    print("      close across tiers, the choice is a real trade-off (not a dominant pick).")
}

MainActor.assumeIsolated { main() }
