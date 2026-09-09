//
//  CrewPipelineVerify.swift — the crew-training pipeline (Phase 1, 8 Sep 2026;
//  aa-1.1.x/CREW_TRAINING_SCOPE.md, designer decisions 1–5).
//    • The bundled crew is LINE-READY (a starter's first aircraft flies on day one).
//    • Two hire doors: RATED (2× course, line-ready in 10d) / NEW HIRE (1.25× course,
//      45d). A crew in training can't be assigned and doesn't count for coverage.
//    • Per-crew CURRENCY (180d): the auto-scheduler sends the soonest-expiring crews
//      to a 4-day recurrent a few at a time (≤10%, min 1; a crew about to lapse goes
//      regardless); policy OFF → the crew LAPSES (can't fly) → a per-family card →
//      requalify at 1.6× the recurrent rate.
//    • A crew whose currency runs out mid-trip finishes the trip, then lapses.
//    • Coverage readout: ratio + verdict from the sim's own thresholds.
//    • Persistence: training/lapsed state round-trips; a PRE-pipeline save gets
//      staggered currency (no lapse wave on load); the cash invariant holds.
//    • Early-game guard: a $20M starter with one Beech 1900 survives the first 45
//      days and its rated hire is line-ready by day 11.
//  Compile like the other harnesses (see aa-1.1.x/README.md — needs
//  RepaintVerifyStubs.swift); rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func printResult() { print("\nCrewPipelineVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }
    func newSim(inject: Int = 5_000_000_000) -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Pipeline Air", tailCode: "PL")
        if inject > 0 { s.devInjectCash(inject) }
        return s
    }
    func buy(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { return nil }
        return sim.buyAircraft(t)
    }
    func days(_ sim: Simulation, _ n: Int) { for _ in 0..<(n * 1440) { sim.advanceTick() } }
    func ticks(_ sim: Simulation, _ n: Int) { for _ in 0..<n { sim.advanceTick() } }
    func pool(_ sim: Simulation, _ fam: String) -> [Crew] { sim.crewPoolsByFamily[fam] ?? [] }
    let FAM = "A320_FAMILY"

    // ── 1. Bundled crew: line-ready, currency set, the aircraft flies on day one ──
    do {
        let sim = newSim()
        guard let ac = buy(sim, "A320"), let den = sim.airport("DEN"), let ord = sim.airport("ORD") else { check(false, "setup 1"); printResult(); return }
        let c = pool(sim, FAM).first!
        check(c.status == .available && c.isLineReady, "1: bundled crew is line-ready")
        check(c.currencyExpiresTick > sim.tick && c.currencyExpiresTick <= sim.tick + Crew.currencyDays * 1440, "1: bundled crew has currency ≤180d")
        _ = sim.openRoute(from: den, to: ord, using: ac)
        ticks(sim, 1500)
        check(ac.cyclesAccrued >= 1, "1: first aircraft flew a leg on day one (cycles \(ac.cyclesAccrued))")
    }
    // ── 2. Hire doors: cost, timeline, not assignable while training ─────────────
    do {
        let sim = newSim()
        guard buy(sim, "A320") != nil else { check(false, "setup 2"); printResult(); return }
        let course = sim.crewCourseCost(family: FAM)
        check(sim.crewHireCost(family: FAM, mode: .rated) == Int((Double(course) * 2.0).rounded()), "2: rated hire = 2× course")
        check(sim.crewHireCost(family: FAM, mode: .newHire) == Int((Double(course) * 1.25).rounded()), "2: new hire = 1.25× course")
        check(sim.crewHireCost(family: FAM) == sim.crewHireCost(family: FAM, mode: .rated), "2: old hireCost signature = rated")
        let before = sim.playerBalance
        guard let rid = sim.hireCrew(family: FAM, mode: .rated) else { check(false, "2: rated hire"); printResult(); return }
        check(before - sim.playerBalance == sim.crewHireCost(family: FAM, mode: .rated), "2: rated hire charged exactly")
        let r = pool(sim, FAM).first { $0.id == rid }!
        check(r.status == .training && r.trainingKind == .initial, "2: rated hire is IN TRAINING")
        check(r.readyTick == sim.tick + Simulation.ratedHireDays * 1440, "2: rated hire ready in 10 days")
        check(!r.isLineReady && sim.crewCoverage(family: FAM).lineReady == 1, "2: a training crew doesn't count for coverage")
        guard let nid = sim.hireCrew(family: FAM, mode: .newHire) else { check(false, "2: new hire"); printResult(); return }
        let n = pool(sim, FAM).first { $0.id == nid }!
        // A contract new hire also waits 0–10 days for a class slot (Phase 2).
        let lead = (n.readyTick! - sim.tick) / 1440 - Simulation.newHireCourseDays
        check(lead >= 0 && lead <= Simulation.contractLeadDaysMax, "2: new hire ready in 45 days + a 0–10 day class-slot wait (got +\(lead))")
        check(sim.hireCrew(family: FAM) != nil, "2: old hireCrew(family:) signature still works")
        days(sim, 11)
        check(r.status == .available && r.readyTick == nil && r.trainingKind == nil, "2: rated hire graduated on schedule")
        check(r.currencyExpiresTick > sim.tick + (Crew.currencyDays - 2) * 1440, "2: graduate gets fresh ~180d currency")
        check(n.status == .training, "2: new hire still in the course at day 11")
        days(sim, 46)
        check(n.status == .available, "2: new hire graduated by day 57 (45 + up to 10 wait)")
        check(sim.cashInvariantResidual() == 0, "2: cash invariant after hires")
    }
    // ── 3. Rolling auto-recurrent: window, cap, urgency override, cost ───────────
    do {
        let sim = newSim()
        guard buy(sim, "A320") != nil, buy(sim, "A321") != nil, buy(sim, "A319") != nil else { check(false, "setup 3"); printResult(); return }
        let crews = pool(sim, FAM)
        check(crews.count == 3, "3: three bundled crews")
        // All three inside the 30-day window, 20 days out → cap = max(1, 0) = 1 → one goes.
        for c in crews { c.currencyExpiresTick = sim.tick + 20 * 1440 }
        let before = sim.playerBalance
        days(sim, 1)
        let inRec = crews.filter { $0.status == .training && $0.trainingKind == .recurrent }
        check(inRec.count == 1, "3: soft cap — only 1 of 3 sent at once (got \(inRec.count))")
        check(before - sim.playerBalance == sim.crewRecurrentCost(family: FAM), "3: recurrent charged 15% of course per crew")
        check(inRec.first!.readyTick! <= sim.tick + Simulation.recurrentDays * 1440, "3: recurrent lasts ≤ 4 days")
        // A crew about to lapse goes regardless of the cap.
        let urgent = crews.first { $0.status == .available }!
        urgent.currencyExpiresTick = sim.tick + 2 * 1440
        days(sim, 1)
        check(urgent.status == .training && urgent.trainingKind == .recurrent, "3: an about-to-lapse crew is sent despite the cap")
        days(sim, 5)
        let back = crews.filter { $0.status == .available && $0.currencyExpiresTick > sim.tick + 170 * 1440 }
        check(back.count >= 2, "3: recurrent graduates return with fresh currency (\(back.count))")
        check(crews.allSatisfy { $0.status != .lapsed }, "3: nobody lapsed under auto-scheduling")
        check(!sim.decisionQueue.contains { $0.kind == .training }, "3: no training card under auto-scheduling")
        check(sim.cashInvariantResidual() == 0, "3: cash invariant after recurrent")
    }
    // ── 4. Policy OFF → lapse → card → requalify at the premium ──────────────────
    do {
        let sim = newSim()
        guard let ac = buy(sim, "A320"), let den = sim.airport("DEN"), let ord = sim.airport("ORD") else { check(false, "setup 4"); printResult(); return }
        sim.setCrewAutoRecurrent(false, family: FAM)
        check(!sim.crewAutoRecurrentOn(FAM), "4: policy off")
        let c = pool(sim, FAM).first!
        c.currencyExpiresTick = sim.tick + 1
        days(sim, 1)
        check(c.status == .lapsed, "4: currency ran out → LAPSED")
        check(sim.decisionQueue.contains { $0.kind == .training && $0.trainingFamily == FAM }, "4: a lapsed card for the family")
        _ = sim.openRoute(from: den, to: ord, using: ac)
        ticks(sim, 300)
        check(ac.crewId == nil && ac.cyclesAccrued == 0, "4: a lapsed crew is never assigned (aircraft holds)")
        let expected = sim.crewRequalCost(family: FAM)
        check(expected == Int((Double(sim.crewRecurrentCost(family: FAM)) * 1.6).rounded()), "4: requal = 1.6× the recurrent rate")
        let before = sim.playerBalance
        check(sim.retrainLapsed(family: FAM), "4: requalify accepted")
        check(before - sim.playerBalance == expected, "4: requal charged exactly")
        check(c.status == .training && c.trainingKind == .requal, "4: crew is requalifying")
        check(!sim.decisionQueue.contains { $0.kind == .training }, "4: card cleared on requalify")
        days(sim, 5)
        check(c.status == .available || c.status == .onDuty, "4: back on the line after the requal (\(c.status))")
        // NOTE: a random labor action (0.003/day/family) can sideline the only crew,
        // which would stall the aircraft through no fault of the requal path — so
        // give it room and skip the check outright if one is active. An earlier
        // version asserted a fixed window and failed ~1 run in 4 for that reason.
        ticks(sim, 6000)
        let laborActive = (sim.laborActionExpiryByFamily[FAM] ?? 0) > sim.tick
        if !laborActive {
            check(ac.cyclesAccrued >= 1, "4: the aircraft flies again")
        } else {
            check(true, "4: (skipped — a labor action is sidelining this family)")
        }
        check(sim.cashInvariantResidual() == 0, "4: cash invariant after requal")
    }
    // ── 5. Mid-trip lapse: finish the trip, then lapse on release ─────────────────
    do {
        let sim = newSim()
        guard let ac = buy(sim, "A320"), let den = sim.airport("DEN"), let ord = sim.airport("ORD") else { check(false, "setup 5"); printResult(); return }
        sim.setCrewAutoRecurrent(false, family: FAM)
        _ = sim.openRoute(from: den, to: ord, using: ac)
        ticks(sim, 60)   // airborne-ish: crew assigned
        let c = pool(sim, FAM).first!
        check(c.status == .onDuty, "5: crew on duty")
        c.currencyExpiresTick = sim.tick   // expires now, mid-trip
        var n = 0
        while ac.cyclesAccrued < 1 && n < 3000 { sim.advanceTick(); n += 1 }
        check(ac.cyclesAccrued == 1, "5: the trip completed")
        check(c.status == .lapsed && ac.crewId == nil, "5: lapsed on release, not mid-air (\(c.status))")
    }
    // ── 6. Coverage verdicts ────────────────────────────────────────────────────────
    do {
        let sim = newSim()
        guard buy(sim, "A320") != nil else { check(false, "setup 6"); printResult(); return }
        var cov = sim.crewCoverage(family: FAM)
        check(cov.lineReady == 1 && cov.aircraft == 1 && cov.verdict == .under, "6: 1 crew / 1 aircraft = under-crewed")
        _ = sim.hireCrew(family: FAM, mode: .rated)
        check(sim.crewCoverage(family: FAM).lineReady == 1, "6: training crew not counted yet")
        days(sim, 11)
        cov = sim.crewCoverage(family: FAM)
        check(cov.lineReady == 2 && cov.verdict == .continuous, "6: 2.0/aircraft = continuous (\(cov.ratio))")
        guard buy(sim, "A321") != nil else { check(false, "setup 6b"); printResult(); return }
        cov = sim.crewCoverage(family: FAM)
        check(cov.lineReady == 3 && cov.aircraft == 2 && cov.verdict == .thin, "6: 1.5/aircraft = thin (\(cov.ratio))")
        check(sim.crewCoverage(family: "B777").verdict == .none, "6: no aircraft → none")
    }
    // ── 7. Persistence: round-trip + legacy stagger ──────────────────────────────
    do {
        let sim = newSim()
        guard buy(sim, "A320") != nil, buy(sim, "A321") != nil else { check(false, "setup 7"); printResult(); return }
        _ = sim.hireCrew(family: FAM, mode: .newHire)
        sim.setCrewAutoRecurrent(false, family: FAM)
        let lapsed = pool(sim, FAM)[0]; lapsed.currencyExpiresTick = sim.tick + 1
        days(sim, 1)
        check(lapsed.status == .lapsed, "7: one crew lapsed before save")
        let data = try! JSONEncoder().encode(sim.snapshot())
        let snap = try! JSONDecoder().decode(GameSnapshot.self, from: data)
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800)); sim2.restore(from: snap)
        let p1 = pool(sim, FAM), p2 = pool(sim2, FAM)
        check(p1.count == p2.count, "7: pool size round-trips")
        for (a, b) in zip(p1, p2) {
            // `.sidelined` intentionally restores as `.available` — the labor action
            // that caused it isn't persisted (CrewStatus.saveCode maps both to 0).
            let statusOK = a.status == b.status || (a.status == .sidelined && b.status == .available)
            check(statusOK && a.readyTick == b.readyTick && a.currencyExpiresTick == b.currencyExpiresTick && a.trainingKind == b.trainingKind,
                  "7: crew \(a.id) state round-trips (\(a.status)/\(b.status))")
        }
        check(!sim2.crewAutoRecurrentOn(FAM), "7: auto-recurrent policy round-trips")
        // Legacy: strip the new fields → staggered currency in [30d, 180d], nothing lapses on load.
        var legacy = snap
        legacy.crewPools = legacy.crewPools.mapValues { $0.map { cs in
            var l = cs; l.readyTick = nil; l.currencyExpires = nil; l.trainingKind = nil
            if l.status >= 3 { l.status = 0 }
            return l
        } }
        legacy.crewAutoRecurrent = nil
        let sim3 = Simulation(); sim3.configure(viewport: CGSize(width: 400, height: 800)); sim3.restore(from: legacy)
        let p3 = pool(sim3, FAM)
        check(p3.allSatisfy { $0.status != .lapsed && $0.status != .training }, "7: legacy crews load line-ready")
        check(p3.allSatisfy { $0.currencyExpiresTick >= legacy.tick + 30 * 1440 && $0.currencyExpiresTick <= legacy.tick + 180 * 1440 }, "7: legacy currency staggered into [30d, 180d]")
        check(Set(p3.map(\.currencyExpiresTick)).count == p3.count, "7: legacy currency is staggered, not one wave")
        check(sim3.crewAutoRecurrentOn(FAM), "7: legacy policy defaults ON")
        days(sim3, 1)
        check(!sim3.decisionQueue.contains { $0.kind == .training }, "7: no lapse wave on a legacy load")
    }
    // ── 8. Early-game guard: a $20M starter survives the pipeline ────────────────
    do {
        let sim = newSim(inject: 0)
        let start = sim.playerBalance
        guard let ac = buy(sim, "B1900"), let sea = sim.airport("SEA"), let pdx = sim.airport("PDX") else { check(false, "setup 8"); printResult(); return }
        _ = sim.openRoute(from: sea, to: pdx, using: ac)
        let fam = ac.type.family
        check(sim.hireCrew(family: fam, mode: .rated) != nil, "8: starter can afford a rated hire")
        var flights = 0, lastCycles = 0
        for d in 0..<45 {
            for _ in 0..<1440 {
                sim.advanceTick()
                // Answer the cards a real player would: Wait on crew holds (the rest
                // clock clears them), Standard repair on an AOG — an unanswered AOG
                // grounds the aircraft for good (the headless-harness trap).
                for dec in sim.decisionQueue {
                    switch dec.kind {
                    case .crew: sim.resolveCrewWait(dec)
                    case .aog:  sim.resolveAOGStandard(dec)
                    default:    break
                    }
                }
            }
            if ac.cyclesAccrued > lastCycles { flights += ac.cyclesAccrued - lastCycles; lastCycles = ac.cyclesAccrued }
            if d == 11 { check(sim.crewCoverage(family: fam).lineReady == 2, "8: rated hire line-ready by day 11") }
        }
        check(!sim.isBankrupt, "8: not bankrupt after 45 days")
        check(flights >= 20, "8: kept flying (\(flights) legs in 45 days)")
        check(sim.playerBalance > start / 2, "8: cash still above half the starting stake (\(sim.playerBalance))")
        check(sim.cashInvariantResidual() == 0, "8: cash invariant on the starter")
    }
    printResult()
}
MainActor.assumeIsolated { main() }
