import Foundation

// Route plans (the "Plans" shelf) + route-research math.
//  1. Saving a plan moves NO money (cash invariant untouched).
//  2. Plans round-trip through the REAL save path (snapshot → JSON → restore).
//  3. A pre-plans save (no `plans` key) decodes to an empty shelf.
//  4. `typeCanFly` mirrors `routeBlock` for every type × a sample of pairs.
//  5. `projectedDailyNet` matches a flown route's realised average (research == reality).
@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    // ── 1. Save moves no money; the shelf grows; delete removes ─────────────────
    do {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Plan Air", tailCode: "PL")
        sim.devInjectCash(50_000_000)
        check(sim.cashInvariantResidual() == 0, "1: invariant clean at start")
        let bal0 = sim.playerBalance
        sim.savePlan(stops: ["DEN", "ORD"])
        sim.savePlan(stops: ["LAX", "SFO", "SEA"])   // a loop
        check(sim.plans.count == 2, "1: two plans on the shelf")
        check(sim.playerBalance == bal0, "1: saving a plan cost nothing")
        check(sim.cashInvariantResidual() == 0, "1: invariant still clean after saving plans")
        check(sim.plans[0].stops == ["DEN", "ORD"] && !sim.plans[0].isMultiStop, "1: pair recorded")
        check(sim.plans[1].isMultiStop && sim.plans[1].stops.count == 3, "1: loop recorded")
        let id0 = sim.plans[0].id
        sim.deletePlan(id: id0)
        check(sim.plans.count == 1 && sim.plans[0].stops.first == "LAX", "1: delete removed the right plan")
        // Ids don't recycle.
        sim.savePlan(stops: ["JFK", "BOS"])
        check(Set(sim.plans.map(\.id)).count == sim.plans.count, "1: plan ids are unique")
    }

    // ── 2. Round-trip through the real save path ────────────────────────────────
    do {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Plan Air", tailCode: "PL")
        sim.devInjectCash(50_000_000)
        sim.savePlan(stops: ["DEN", "ORD"])
        sim.savePlan(stops: ["LAX", "SFO", "SEA"])
        let count0 = sim.plans.count, stops0 = sim.plans.map(\.stops)
        let snap = sim.snapshot()
        guard let data = try? JSONEncoder().encode(snap),
              let decoded = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
            check(false, "2: snapshot encode/decode"); printResult(pass, fail); return
        }
        let restored = Simulation()
        restored.configure(viewport: CGSize(width: 400, height: 800))
        restored.restore(from: decoded)
        check(restored.plans.count == count0, "2: plan count survives (\(restored.plans.count) == \(count0))")
        check(restored.plans.map(\.stops) == stops0, "2: plan stops survive in order")
        check(restored.cashInvariantResidual() == -sim.devInjectedCash,
              "2: invariant intact after restore (residual == un-persisted injection)")
        // A NEW plan after restore gets a fresh, non-colliding id.
        restored.savePlan(stops: ["MIA", "ATL"])
        check(Set(restored.plans.map(\.id)).count == restored.plans.count, "2: nextPlanId survived — no id collision")
    }

    // ── 3. A pre-plans save decodes to an empty shelf ───────────────────────────
    do {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Plan Air", tailCode: "PL")
        var snap = sim.snapshot()
        snap.plans = nil; snap.nextPlanId = nil
        let restored = Simulation()
        restored.configure(viewport: CGSize(width: 400, height: 800))
        restored.restore(from: snap)
        check(restored.plans.isEmpty, "3: pre-plans save → empty shelf")
        restored.savePlan(stops: ["DEN", "ORD"])
        check(restored.plans.count == 1 && restored.plans[0].id >= 1, "3: can still save after a legacy restore")
    }

    // ── 4. typeCanFly mirrors routeBlock exactly ────────────────────────────────
    do {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Plan Air", tailCode: "PL")
        sim.devInjectCash(1_000_000_000)
        // A spread of pairs: short domestic, long transcon, a short-runway airport (LGA),
        // an ultra-long haul that only widebodies reach.
        let pairs = [("DEN","ORD"), ("JFK","LAX"), ("LGA","ORD"), ("SFO","JFK"), ("LAX","MIA")]
        var mismatches = 0, checkedTypes = 0
        for (oc, dc) in pairs {
            guard let o = sim.airport(oc), let d = sim.airport(dc) else { continue }
            for t in AircraftType.all {
                checkedTypes += 1
                // Build a throwaway aircraft of this type to drive routeBlock.
                guard let ac = sim.buyAircraft(t) else { continue }
                let blocked = sim.routeBlock(for: ac, from: o, to: d) != nil
                let canFly = sim.typeCanFly(t, from: o, to: d)
                if blocked == canFly { mismatches += 1 }   // must be OPPOSITE
                sim.sellAircraft(ac)
            }
        }
        check(checkedTypes > 100, "4: really iterated types × pairs (\(checkedTypes))")
        check(mismatches == 0, "4: typeCanFly is the exact inverse of routeBlock (\(mismatches) mismatches)")
    }

    // ── 5. projectedDailyNet ≈ a flown route's realised average ─────────────────
    do {
        let sim = Simulation()
        sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Plan Air", tailCode: "PL")
        sim.devInjectCash(1_000_000_000)
        guard let o = sim.airport("DEN"), let d = sim.airport("ORD"),
              let t = sim.bestFitType(from: o, to: d) else {
            check(false, "5: setup — no best-fit type"); printResult(pass, fail); return
        }
        let projected = sim.projectedDailyNet(t, from: o, to: d)
        check(projected > 0, "5: DEN→ORD projects a positive daily net for its best-fit type (\(t.name), $\(projected))")
        // Fly it for real with that exact type, well-crewed, and compare over a SHORT
        // window (30 sim-days) BEFORE rivals enter and split demand — the projection is
        // a fresh-route (no-competition) estimate, so comparing it to a 120-day contested
        // route just measures the competition maturity gap, not the projection's accuracy.
        // Drain the decision queue so a stray AOG doesn't idle the tail and skew the average.
        guard let ac = sim.buyAircraft(t) else { check(false, "5: buy"); printResult(pass, fail); return }
        _ = sim.openRoute(from: o, to: d, using: ac)
        let fam = t.family
        let want = Int(Double(sim.ownedCount(family: fam)) * 3.0) + 3
        while sim.crewCount(family: fam) < want { if sim.hireCrew(family: fam) == nil { break } }
        for _ in 0..<(1440 * 30) {
            sim.advanceTick()
            for dcard in Array(sim.decisionQueue) where dcard.kind == .aog { sim.resolveAOGStandard(dcard) }
        }
        guard let r = sim.playerRoutes.first(where: { $0.id == ac.assignedRouteId }), r.flights > 0 else {
            check(false, "5: the route never flew"); printResult(pass, fail); return
        }
        // Realised per-leg net × legs/day, the same shape the projection uses.
        let realisedDaily = (r.cumulativeNet / r.flights) * Int((1440.0 / Double(Simulation.legCycleTicks)).rounded())
        check(realisedDaily > 0, "5: the flown route actually earned (realised $\(realisedDaily)/day over \(r.flights) flights)")
        // Fresh, uncontested, well-crewed — projection should land close. Allow a band
        // for the ±10% per-flight spread and a few early holds.
        let lo = Double(realisedDaily) * 0.6, hi = Double(realisedDaily) * 1.6
        check(Double(projected) >= lo && Double(projected) <= hi,
              "5: projected $\(projected)/day is within 0.6–1.6× of realised $\(realisedDaily)/day")
    }

    printResult(pass, fail)
}

@MainActor
func printResult(_ pass: Int, _ fail: Int) {
    print("\nRoutePlanVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED"))
}

// Entry point — WITHOUT this the file compiles to a binary that never runs.
MainActor.assumeIsolated { run() }
