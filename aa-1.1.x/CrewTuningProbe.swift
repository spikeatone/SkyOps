import Foundation

// T1.2 / T1.3 balance probe (player-feedback crew tuning).
// Measures the crew-DISRUPTION load and financial stability over a multi-year
// run with a real, well-crewed fleet: labor-action count, crew-sideline
// pressure, and net-worth trajectory. Run against OLD constants (0.02 labor /
// 0.40 labor-fraction / 0.50 training-fraction) and NEW (0.008 / 0.25 / 0.25),
// diff the disruption load, and confirm the crew system stays stable + the cash
// invariant holds. Rename to main.swift to compile.
//
// The tune should make disruption STRICTLY LOWER (fewer/smaller labor hits, less
// training sideline) with no new instability — this quantifies "how much lower".

@MainActor
func main() {
    // Simulation has no seedable init (competitorSeed self-randomizes; labor/
    // training fire off Double.random, independent of it), so these are just run
    // indices for variety — the aggregate RATE across runs is the comparison.
    let runs = 10
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    // Aggregate disruption metrics across seeds.
    var totalLaborActions = 0
    var totalSidelinedCrewDays = 0      // Σ (crew sidelined at each daily observation)
    var peakSimultaneousSidelined = 0
    var bankruptcies = 0
    var invariantViolations = 0

    for seed in 1...runs {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Probe Air", tailCode: "PB")
        sim.devInjectCash(400_000_000)   // fund a real, well-crewed multi-family fleet

        // Build a genuine fleet across several crew families, well-crewed (~2.2
        // crew/aircraft) so labor/training actually has a pool to bite into and
        // the crew-shortage cascade is a real risk if the tune is wrong.
        let types = AircraftType.all
        func buyType(_ id: String, _ n: Int) {
            guard let t = types.first(where: { $0.id == id }) else { return }
            for _ in 0..<n {
                guard sim.playerBalance >= t.purchasePrice else { return }
                guard let ac = sim.buyAircraft(t) else { return }
                // open a route so it flies (pick two in-range CONUS airports)
                if let o = sim.airport("DEN"), let d = sim.airport("ORD") {
                    _ = sim.openRoute(from: o, to: d, using: ac)
                }
            }
        }
        buyType("B737800", 4)   // B737 family
        buyType("A320", 4)      // A320 family
        buyType("E175", 3)      // E170 family
        buyType("CRJ900", 3)    // CRJ family
        // Hire up to ~2.2 crew/aircraft per owned family so ops are sustainable.
        for fam in sim.ownedFamilies {
            let target = Int((Double(sim.ownedCount(family: fam)) * 2.2).rounded())
            var guardN = 0
            while sim.crewCount(family: fam) < target && sim.playerBalance > 5_000_000 && guardN < 40 {
                sim.hireCrew(family: fam); guardN += 1
            }
        }

        var seedLaborActions = 0
        var seedInvOK = true
        var lastLoggedLabor = 0

        // ~2 sim-years/seed. Observe once per sim-day.
        let days = 720
        for _ in 0..<days {
            for _ in 0..<1440 { sim.advanceTick() }

            // Drain the decision queue plausibly (hire on crew holds, keep flying)
            // so a shortage doesn't just freeze everything artificially.
            for dec in sim.decisionQueue {
                switch dec.kind {
                case .crew:
                    if let ac = dec.aircraft, sim.canAffordCrewHire(for: ac) { sim.resolveCrewHire(dec) }
                    else { sim.resolveCrewWait(dec) }
                case .training: sim.resolveTrainingNow(dec)   // train now (exercises the sideline)
                default: break
                }
            }

            // Count labor actions via the Ops log (disruption entries titled "Labor action").
            let laborNow = sim.opsEventLog.filter { $0.title == L("Labor action") }.count
            if laborNow > lastLoggedLabor { seedLaborActions += (laborNow - lastLoggedLabor); lastLoggedLabor = laborNow }

            // Crew sidelined right now (labor + training downtime both use .sidelined).
            var sidelinedNow = 0
            for (_, pool) in sim.crewPoolsByFamily {
                sidelinedNow += pool.filter { $0.status == .sidelined }.count
            }
            totalSidelinedCrewDays += sidelinedNow
            peakSimultaneousSidelined = max(peakSimultaneousSidelined, sidelinedNow)

            // Cash invariant every day. cashInvariantResidual() already folds
            // devInjectedCash into `expected`, so a sound economy reads 0.
            if sim.cashInvariantResidual() != 0 { seedInvOK = false }
            if sim.isBankrupt { break }
        }

        totalLaborActions += seedLaborActions
        if !seedInvOK { invariantViolations += 1 }
        if sim.isBankrupt { bankruptcies += 1 }
        print(String(format: "seed %2d: laborActions=%d, netWorth=$%.0fM, invOK=%@, bankrupt=%@",
                     seed, seedLaborActions, Double(sim.netWorth)/1_000_000,
                     seedInvOK ? "Y" : "N", sim.isBankrupt ? "Y" : "N"))
    }

    let years = Double(runs) * 2.0
    print("\n--- AGGREGATE (\(runs) runs × 2 sim-years) ---")
    print(String(format: "labor actions: %d total  (%.2f per sim-year across the fleet)",
                 totalLaborActions, Double(totalLaborActions) / years))
    print(String(format: "peak simultaneous sidelined crew: %d", peakSimultaneousSidelined))
    print(String(format: "sideline-crew-days (Σ daily sidelined): %d", totalSidelinedCrewDays))
    print("invariant violations: \(invariantViolations)  |  bankruptcies: \(bankruptcies)")

    // Assertions: the crew system stays sound regardless of the tune.
    check(invariantViolations == 0, "cash invariant held across all seeds")
    check(bankruptcies == 0, "no bankruptcy under competent play with the tune")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
    print("NOTE: run this on OLD constants (0.02/0.40/0.50) and NEW (0.008/0.25/0.25) and DIFF the")
    print("      labor-action count + sideline-crew-days — the tune should cut both substantially.")
}

MainActor.assumeIsolated { main() }
