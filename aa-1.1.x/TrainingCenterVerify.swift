//
//  TrainingCenterVerify.swift — the Training Center (crew-training Phase 2,
//  8 Sep 2026; aa-1.1.x/CREW_TRAINING_SCOPE.md §3.5, designer decision 3).
//    • Gate: needs an OPERATING hub; one facility; a sim bay per family needs 6+
//      aircraft in that family. Build/bay charge exactly and land in the new
//      capital term (cash invariant).
//    • In-house: new-hire course 0.65× (0.25 recruit + 0.4 course) and 30 days
//      with NO class-slot wait; recurrent 0.4× and 2 days; 2× concurrency.
//    • Capacity: 4 crews per bay — the 5th overflows to the contractor at the
//      contract price and timeline; seats free as courses graduate.
//    • Monthly opex through the maintenance line + a ledger payback point.
//    • Contract new hires wait 0–10 days for a class slot.
//    • Persistence round-trip (center, bays, ledger, crew provider) + legacy.
//  Compile like the other harnesses (see aa-1.1.x/README.md — needs
//  RepaintVerifyStubs.swift); rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func printResult() { print("\nTrainingCenterVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }
    func newSim() -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Center Air", tailCode: "CN"); s.devInjectCash(5_000_000_000)
        return s
    }
    func buy(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { return nil }
        return sim.buyAircraft(t)
    }
    func days(_ sim: Simulation, _ n: Int) { for _ in 0..<(n * 1440) { sim.advanceTick() } }
    func pool(_ sim: Simulation, _ fam: String) -> [Crew] { sim.crewPoolsByFamily[fam] ?? [] }
    /// n aircraft of a type on n routes out of DEN, then DEN established as a hub.
    func hubSetup(_ sim: Simulation, _ typeId: String, n: Int) -> Bool {
        guard let den = sim.airport("DEN") else { return false }
        let dests = sim.airports.filter { $0.code != "DEN" && den.greatCircleNM(to: $0) < 1400 && den.greatCircleNM(to: $0) > 250 }
                                .sorted { den.greatCircleNM(to: $0) < den.greatCircleNM(to: $1) }
        for i in 0..<n {
            guard let ac = buy(sim, typeId), i < dests.count else { return false }
            guard case .success = sim.openRoute(from: den, to: dests[i], using: ac) else { return false }
        }
        return sim.establishHub(at: "DEN") && sim.hubOperating("DEN")
    }
    let FAM = "A320_FAMILY"

    // ── 1. Gate: no hub → no center ──────────────────────────────────────────────
    do {
        let sim = newSim()
        guard buy(sim, "A320") != nil else { check(false, "setup 1"); printResult(); return }
        check(sim.trainingCenterEligibleHubs.isEmpty, "1: no operating hub → no eligible site")
        check(!sim.canBuildTrainingCenter(at: "DEN"), "1: can't build without a hub")
        let before = sim.playerBalance
        check(!sim.buildTrainingCenter(at: "DEN") && sim.playerBalance == before && sim.trainingCenter == nil, "1: refused build moves no cash")
        check(sim.trainingProvider(for: FAM) == .contract, "1: contract is the provider without a center")
    }
    // ── 2. Build at an operating hub; one facility; the capital term ─────────────
    do {
        let sim = newSim()
        guard hubSetup(sim, "A320", n: Simulation.simBayMinAircraft) else { check(false, "setup 2 (hub)"); printResult(); return }
        check(sim.trainingCenterEligibleHubs == ["DEN"], "2: DEN is the eligible site")
        let before = sim.playerBalance
        check(sim.buildTrainingCenter(at: "DEN"), "2: build accepted")
        check(before - sim.playerBalance == Simulation.trainingCenterFacilityCost, "2: facility charged exactly")
        check(sim.totalTrainingCenterSpend == Simulation.trainingCenterFacilityCost, "2: capital term carries the facility")
        check(sim.trainingCenter?.hubCode == "DEN" && sim.trainingCenter?.ledger.facilitySpend == Simulation.trainingCenterFacilityCost, "2: center at DEN, ledger booked")
        check(!sim.buildTrainingCenter(at: "DEN"), "2: a second facility is refused")
        check(sim.cashInvariantResidual() == 0, "2: cash invariant after the build")
        // Bay gate + cost by class.
        check(sim.canAddSimBay(family: FAM), "2: a bay at the gate-size family is allowed")
        check(!sim.canAddSimBay(family: "B777"), "2: no bay for a family you don't fly")
        // ⚠️ DERIVED, not hardcoded. These were literals (18/22/12M) and went stale the
        // moment the bay prices were walked back to real device-plus-hall cost
        // (NB $17M / WB $21M / TP-RJ $13M) — which quietly turned FOUR checks red here
        // and in tests 2 and 6, while the handoff still recorded 75/75. Assert the
        // RELATIONSHIP (widebody > narrowbody > turboprop, and every bay inside the
        // real $12–22M device band plus its hall) so a future reprice can't do it again.
        let nbBay = sim.simBayCost(family: FAM)
        let wbBay = sim.simBayCost(family: "B787")
        let tpBay = sim.simBayCost(family: "DASH8_FAMILY")
        check(wbBay > nbBay && nbBay > tpBay, "2: bay cost rises by class (TP \(tpBay/1_000_000) < NB \(nbBay/1_000_000) < WB \(wbBay/1_000_000))")
        check(tpBay >= 12_000_000 && wbBay <= 25_000_000, "2: bay costs sit in the real device+hall band")
        let b2 = sim.playerBalance
        check(sim.addSimBay(family: FAM), "2: bay added")
        check(b2 - sim.playerBalance == nbBay && sim.hasSimBay(family: FAM), "2: bay charged exactly")
        check(sim.totalTrainingCenterSpend == Simulation.trainingCenterFacilityCost + nbBay, "2: capital term = facility + bay")
        check(!sim.addSimBay(family: FAM), "2: a second bay for the same family is refused")
        check(sim.trainingProvider(for: FAM) == .center, "2: the center now delivers this family's courses")
        check(sim.cashInvariantResidual() == 0, "2: cash invariant after the bay")

        // ── 3. In-house pricing + timeline, no class-slot wait ───────────────────
        let course = Double(sim.crewCourseCost(family: FAM))
        let inHouse = Int((course * (Simulation.newHireRecruitFraction + Simulation.centerCourseCostFactor)).rounded())
        let contract = Int((course * (Simulation.newHireRecruitFraction + 1.0)).rounded())
        check(sim.crewHireCost(family: FAM, mode: .newHire) == inHouse, "3: in-house new hire = 0.65× course")
        check(sim.crewHireDays(mode: .newHire, family: FAM) == Simulation.centerNewHireCourseDays, "3: in-house course is 30 days")
        check(sim.crewHireCost(family: FAM, mode: .rated) == Int((course * 2.0).rounded()), "3: rated hire price unchanged by the center")
        let b3 = sim.playerBalance
        guard let h1 = sim.hireCrew(family: FAM, mode: .newHire) else { check(false, "3: hire"); printResult(); return }
        let c1 = pool(sim, FAM).first { $0.id == h1 }!
        check(b3 - sim.playerBalance == inHouse, "3: charged the in-house price")
        check(c1.trainingProvider == .center && c1.readyTick == sim.tick + Simulation.centerNewHireCourseDays * 1440, "3: in-house, ready in exactly 30 days (no wait)")
        check(sim.centerLoad(family: FAM) == 1, "3: bay seat taken")
        check(sim.trainingCenter?.ledger.savings == contract - inHouse, "3: savings ledger = contract − in-house (\(sim.trainingCenter?.ledger.savings ?? -1) vs \(contract - inHouse))")

        // ── 4. Capacity: 4 seats, the 5th overflows to the contractor ───────────────
        for _ in 0..<3 { _ = sim.hireCrew(family: FAM, mode: .newHire) }
        check(sim.centerLoad(family: FAM) == Simulation.simBayCapacity, "4: bay full at 4")
        check(sim.trainingProvider(for: FAM) == .contract, "4: overflow → contractor")
        check(sim.crewHireCost(family: FAM, mode: .newHire) == contract, "4: overflow priced at the contract rate")
        let b4 = sim.playerBalance
        guard let h5 = sim.hireCrew(family: FAM, mode: .newHire) else { check(false, "4: overflow hire"); printResult(); return }
        let c5 = pool(sim, FAM).first { $0.id == h5 }!
        let lead = (c5.readyTick! - sim.tick) / 1440 - Simulation.newHireCourseDays
        check(b4 - sim.playerBalance == contract && c5.trainingProvider == .contract, "4: overflow hire is a contract course")
        check(lead >= 0 && lead <= Simulation.contractLeadDaysMax, "4: overflow waits 0–10 days for a class slot (got +\(lead))")
        check(sim.centerLoad(family: FAM) == 4, "4: overflow doesn't take a bay seat")
        days(sim, 31)
        // Graduated crews are line-ready — most go straight ON DUTY on a flying
        // fleet, so assert isLineReady, not `.available` (an early version of this
        // test asserted the latter and failed for the wrong reason).
        check(sim.centerLoad(family: FAM) == 0 && c1.isLineReady, "4: in-house graduates free the seats on day 30 (\(c1.status))")
        check(sim.trainingProvider(for: FAM) == .center, "4: seats free → in-house again")
        check(c5.status == .training, "4: the contract hire is still in its longer course")

        // ── 5. Recurrent in-house: 0.4× price, 2 days, bay-capacity concurrency ────
        // PARK the fleet first so crews aren't being consumed by flights — otherwise
        // how many sit `.available` on any given tick is a function of the flying
        // schedule and the concurrency assertion is non-deterministic.
        for ac in sim.aircraft where ac.purchased { _ = sim.parkAircraft(ac) }
        days(sim, 2)   // let airborne aircraft finish their leg and release their crew
        let crews = pool(sim, FAM).filter { $0.isLineReady }
        check(crews.count >= 8, "5: enough line-ready crews (\(crews.count))")
        for c in crews { c.currencyExpiresTick = sim.tick + 20 * 1440; c.status = .available }
        let poolN = pool(sim, FAM).count
        // With a bay the cap IS the bay capacity — scheduling past it would push the
        // surplus to the contractor at full price (the A/B caught that regression).
        let cap = Simulation.simBayCapacity
        let contractCap = max(1, Int(Double(poolN) * Simulation.recurrentConcurrencyFraction))
        check(cap > contractCap, "5: the bay raises the recurrent cap (\(cap) vs \(contractCap))")
        let savingsBefore = sim.trainingCenter!.ledger.savings
        // Measure the training charge in ISOLATION: playerBalance also moves with a
        // day of flight revenue/fees, so assert on maintenanceSpend (training + opex
        // only — no decisions are resolved here) and net the opex out via the ledger.
        let maint5 = sim.maintenanceSpend
        let opex5 = sim.trainingCenter!.ledger.opexPaid
        days(sim, 1)
        let inRec = pool(sim, FAM).filter { $0.status == .training && $0.trainingKind == .recurrent }
        check(inRec.count == cap, "5: \(cap) crews sent at once in-house (got \(inRec.count))")
        check(inRec.allSatisfy { $0.trainingProvider == .center }, "5: recurrent delivered in-house")
        let recIn = sim.crewRecurrentCost(family: FAM, provider: .center), recOut = sim.crewRecurrentCost(family: FAM, provider: .contract)
        check(recIn == Int((Double(sim.crewCourseCost(family: FAM, provider: .center)) * Simulation.recurrentCostFraction).rounded()) && recIn < recOut, "5: in-house recurrent is the 0.4× course rate")
        let opexBilled = sim.trainingCenter!.ledger.opexPaid - opex5
        let trainingCharged = sim.maintenanceSpend - maint5 - opexBilled
        check(trainingCharged == inRec.count * recIn,
              "5: charged the in-house recurrent price (\(trainingCharged) vs \(inRec.count * recIn))")
        check(inRec.allSatisfy { $0.readyTick! <= sim.tick + Simulation.centerRecurrentDays * 1440 }, "5: in-house recurrent lasts ≤ 2 days")
        check(sim.trainingCenter!.ledger.savings - savingsBefore == inRec.count * (recOut - recIn),
              "5: savings booked per in-house recurrent (\(sim.trainingCenter!.ledger.savings - savingsBefore) vs \(inRec.count * (recOut - recIn)))")
        check(sim.cashInvariantResidual() == 0, "5: cash invariant after recurrent")

        // ── 6. Monthly opex + ledger point ───────────────────────────────────────────
        let opexBefore = sim.trainingCenter!.ledger.opexPaid
        let maintBefore = sim.maintenanceSpend
        let monthsBefore = sim.trainingCenter!.ledger.monthly.count
        days(sim, 31)
        let opex = Simulation.trainingCenterFacilityOpexPerMonth + Simulation.simBayOpexPerMonth
        check(sim.trainingCenter!.ledger.opexPaid - opexBefore == opex, "6: one month of opex billed (facility + 1 bay)")
        check(sim.maintenanceSpend - maintBefore >= opex, "6: opex flows through the maintenance-&-crew line")
        check(sim.trainingCenter!.ledger.monthly.count == monthsBefore + 1, "6: a monthly payback point appended")
        check(sim.trainingCenter!.ledger.payback == sim.trainingCenter!.ledger.savings + (sim.trainingCenter!.ledger.timeValue ?? 0) - sim.trainingCenter!.ledger.facilitySpend - sim.trainingCenter!.ledger.opexPaid, "6: payback = fee savings + time value − facility − opex")
        check(sim.trainingCenterMonthlyOpex == opex, "6: monthly opex readout")
        check((sim.financeSnapshots.last?.trainingCenterSpend ?? -1) == Simulation.trainingCenterFacilityCost + sim.simBayCost(family: FAM), "6: the finance snapshot carries the capital term")
        check(sim.cashInvariantResidual() == 0, "6: cash invariant after billing")

        // ── 7. Persistence: round-trip + legacy ───────────────────────────────────
        let data = try! JSONEncoder().encode(sim.snapshot())
        let snap = try! JSONDecoder().decode(GameSnapshot.self, from: data)
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800)); sim2.restore(from: snap)
        check(sim2.trainingCenter?.hubCode == "DEN" && sim2.hasSimBay(family: FAM), "7: center + bay round-trip")
        check(sim2.trainingCenter?.ledger.savings == sim.trainingCenter?.ledger.savings
              && sim2.trainingCenter?.ledger.opexPaid == sim.trainingCenter?.ledger.opexPaid
              && sim2.trainingCenter?.ledger.facilitySpend == sim.trainingCenter?.ledger.facilitySpend
              && sim2.trainingCenter?.ledger.monthly.count == sim.trainingCenter?.ledger.monthly.count, "7: ledger round-trips")
        check(sim2.totalTrainingCenterSpend == sim.totalTrainingCenterSpend, "7: capital term round-trips")
        let p1 = pool(sim, FAM), p2 = pool(sim2, FAM)
        check(zip(p1, p2).allSatisfy { $0.trainingProvider == $1.trainingProvider && $0.status == $1.status }, "7: crew providers round-trip")
        check(sim2.centerLoad(family: FAM) == sim.centerLoad(family: FAM), "7: bay load identical after load")
        check(sim2.cashInvariantResidual() == -5_000_000_000, "7: invariant after restore = −(un-persisted dev injection)")
        var legacy = snap; legacy.trainingCenter = nil; legacy.totalTrainingCenterSpend = nil
        let sim3 = Simulation(); sim3.configure(viewport: CGSize(width: 400, height: 800)); sim3.restore(from: legacy)
        check(sim3.trainingCenter == nil && sim3.totalTrainingCenterSpend == 0 && sim3.trainingProvider(for: FAM) == .contract, "7: a pre-center save loads with no center")
    }
    // ── 8. Contract lead time without a center ─────────────────────────────────────
    do {
        let sim = newSim()
        guard buy(sim, "A320") != nil else { check(false, "setup 8"); printResult(); return }
        var leads: [Int] = []
        for _ in 0..<8 {
            guard let id = sim.hireCrew(family: FAM, mode: .newHire), let c = pool(sim, FAM).first(where: { $0.id == id }) else { continue }
            leads.append((c.readyTick! - sim.tick) / 1440 - Simulation.newHireCourseDays)
            check(c.trainingProvider == .contract, "8: contract provider")
        }
        check(leads.allSatisfy { $0 >= 0 && $0 <= Simulation.contractLeadDaysMax }, "8: every contract new hire waits 0–10 days (\(leads))")
        check(Set(leads).count > 1, "8: the wait varies (a real class-slot lottery)")
    }
    // ── 9. CREW-TIME VALUE (designer, 8 Sep 2026) ───────────────────────────────
    // At real simulator prices the course FEE saving alone can never repay a bay, so
    // the ledger also books the crew-DAYS a shorter in-house course returns to the
    // line — the actual reason airlines own simulators. Valued from the sim's own
    // dailyNet, and only while crew is the BINDING constraint.
    do {
        let sim = newSim()
        guard hubSetup(sim, "A320", n: Simulation.simBayMinAircraft) else { check(false, "setup 9"); printResult(); return }
        guard sim.buildTrainingCenter(at: "DEN"), sim.addSimBay(family: FAM) else { check(false, "setup 9 bay"); printResult(); return }
        // Crew the family DEEPLY: with plenty of cover a returning crew flies nothing
        // it wasn't already flying, so the time value must be ~zero.
        while sim.crewCount(family: FAM) < Simulation.simBayMinAircraft * 3 {
            if sim.hireCrew(family: FAM, mode: .rated) == nil { break }
        }
        days(sim, 12)   // let the rated hires reach the line
        let deepValue0 = sim.trainingCenter!.ledger.timeValue ?? 0
        _ = sim.hireCrew(family: FAM, mode: .newHire)
        let deepBooked = (sim.trainingCenter!.ledger.timeValue ?? 0) - deepValue0
        check(sim.crewDayValue(family: FAM) > 0, "9: a crew-day has a derived value while the family flies (\(sim.crewDayValue(family: FAM)))")
        check(deepBooked == 0, "9: deep cover books ~no time value (got \(deepBooked))")

        // Now make the family GENUINELY short: park most crews into lapsed state so
        // line-ready falls well under the continuous target.
        let pool = sim.crewPoolsByFamily[FAM] ?? []
        for c in pool.prefix(pool.count - 2) where c.isLineReady { c.status = .lapsed }
        let thinBefore = sim.trainingCenter!.ledger.timeValue ?? 0
        _ = sim.hireCrew(family: FAM, mode: .newHire)
        let thinBooked = (sim.trainingCenter!.ledger.timeValue ?? 0) - thinBefore
        check(thinBooked > 0, "9: a stretched family books real time value (got \(thinBooked))")
        check(thinBooked > deepBooked, "9: time value is worth MORE when short than when deep")
        // And it must show up in payback, alongside the fee savings.
        let l = sim.trainingCenter!.ledger
        check(l.payback == l.savings + (l.timeValue ?? 0) - l.facilitySpend - l.opexPaid,
              "9: payback = fee savings + time value − facility − opex")
        check(sim.cashInvariantResidual() == 0, "9: time value is BOOKKEEPING ONLY — no cash moved")
    }

    printResult()
}
MainActor.assumeIsolated { main() }
