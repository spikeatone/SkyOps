//
//  OpsTweaksVerify.swift — the 8 Sep 2026 Ops tweaks:
//    • SPEED RESTORE: the auto-slow (new card at >1× → 1×) gives the player's speed
//      BACK once every card that arrived while slowed is cleared — unless they picked
//      a speed themselves; a card that pre-dates the slow never holds it hostage.
//    • OPS DRAWERS: collapsed sections live on the sim, persist through save/load
//      (legacy saves → all open), and an alert re-opens its box.
//    • MX LIST ORDER: nearest date first; the row's shown check == the sort's check.
//  Compile like the other harnesses (see aa-1.1.x/README.md — needs
//  RepaintVerifyStubs.swift); rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func printResult() { print("\nOpsTweaksVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }
    func newSim() -> Simulation {
        let s = Simulation(); s.configure(viewport: CGSize(width: 400, height: 800))
        s.nameAirline("Tweak Air", tailCode: "TW"); s.devInjectCash(5_000_000_000)
        return s
    }
    func buy(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { return nil }
        return sim.buyAircraft(t)
    }
    /// Tick until a CREW card exists for `tail` (a 1-crew aircraft rests after ~2 legs).
    @discardableResult
    func tickUntilCrewCard(_ sim: Simulation, tail: String, limit: Int = 40_000) -> Bool {
        var n = 0
        while n < limit && !sim.decisionQueue.contains(where: { $0.kind == .crew && $0.aircraft?.tail == tail }) {
            sim.advanceTick(); n += 1
        }
        return n < limit
    }
    func tick(_ sim: Simulation, _ n: Int) { for _ in 0..<n { sim.advanceTick() } }
    /// Tick until a condition holds (or give up). The generic sibling of
    /// `tickUntilCrewCard`, for tests that wait on a different card kind.
    func tickUntil(_ sim: Simulation, limit: Int = 40_000, _ cond: (Simulation) -> Bool) -> Bool {
        var n = 0
        while n < limit && !cond(sim) { sim.advanceTick(); n += 1 }
        return n < limit
    }

    // ── 1. Speed restore: slow on the card, restore on clear ────────────────────
    do {
        let sim = newSim()
        guard let ac = buy(sim, "A320"), let den = sim.airport("DEN"), let ord = sim.airport("ORD") else { check(false, "setup 1"); printResult(); return }
        _ = sim.openRoute(from: den, to: ord, using: ac)
        sim.requestSpeed(25)
        check(sim.speed == 25, "1: player at 25×")
        check(tickUntilCrewCard(sim, tail: ac.tail), "1: a CREW card arrives")
        check(sim.speed == 1, "1: auto-slowed to 1×")
        check(sim.autoSlowRestoreSpeed == 25, "1: remembers 25× (got \(String(describing: sim.autoSlowRestoreSpeed)))")
        check(sim.decisionQueue.count == 1, "1: one card")
        if let d = sim.decisionQueue.first(where: { $0.kind == .crew }) { sim.resolveCrewHire(d) }
        tick(sim, 5)
        check(sim.decisionQueue.isEmpty, "1: card cleared by hiring")
        check(sim.speed == 25, "1: speed RESTORED to 25× (got \(sim.speed))")
        check(sim.autoSlowRestoreSpeed == nil, "1: restore intent consumed")
    }
    // ── 2. Player override: a deliberate speed pick is never overridden ─────────
    do {
        let sim = newSim()
        guard let ac = buy(sim, "A320"), let den = sim.airport("DEN"), let ord = sim.airport("ORD") else { check(false, "setup 2"); printResult(); return }
        _ = sim.openRoute(from: den, to: ord, using: ac)
        sim.requestSpeed(25)
        check(tickUntilCrewCard(sim, tail: ac.tail), "2: CREW card arrives")
        check(sim.speed == 1, "2: auto-slowed")
        sim.requestSpeed(5)            // the player takes over while slowed
        check(sim.autoSlowRestoreSpeed == nil, "2: player pick drops the restore intent")
        if let d = sim.decisionQueue.first(where: { $0.kind == .crew }) { sim.resolveCrewHire(d) }
        tick(sim, 5)
        check(sim.decisionQueue.isEmpty, "2: card cleared")
        check(sim.speed == 5, "2: stays at the player's 5× (got \(sim.speed))")
    }
    // ── 3. A card that PRE-DATES the slow doesn't hold the speed hostage ─────────
    do {
        let sim = newSim()
        // ⚠️ The two aircraft must be in DIFFERENT CREW FAMILIES. Both were A320s,
        // and since the crew-training pipeline made a bundled crew line-ready on
        // arrival, buying two A320s put TWO ready crews in one pool — so the single
        // routed aircraft could always rotate onto the spare crew and the shortage
        // this test needs never happened. (That silently turned 4 checks red at
        // HEAD; the failures pre-date the maintenance work.) Separate families give
        // each aircraft its own pool, so neither can bail the other out.
        guard let a = buy(sim, "A320"), let b = buy(sim, "B737800"),
              let den = sim.airport("DEN"), let ord = sim.airport("ORD"), let sea = sim.airport("SEA"), let sfo = sim.airport("SFO")
        else { check(false, "setup 3"); printResult(); return }
        sim.requestSpeed(1)
        _ = sim.openRoute(from: den, to: ord, using: a)
        // The OLDER card must be one that does NOT heal itself while we wait for the
        // newer one, or the test races its own setup: a CREW hold clears the moment
        // that crew finishes its 600-tick rest, which is inside the window it takes
        // the second aircraft to run its own crew down. An AOG card sits until it is
        // answered, which is what "a card that pre-dates the slow" needs to mean.
        a.maint = true
        check(tickUntil(sim) { $0.decisionQueue.contains { $0.kind == .aog && $0.aircraft?.tail == a.tail } },
              "3: first card (at 1×, no auto-slow)")
        check(sim.autoSlowRestoreSpeed == nil, "3: no restore intent at 1×")
        _ = sim.openRoute(from: sea, to: sfo, using: b)
        sim.requestSpeed(25)
        check(tickUntilCrewCard(sim, tail: b.tail), "3: second card arrives while at 25×")
        check(sim.speed == 1 && sim.autoSlowRestoreSpeed == 25, "3: slowed by the second card")
        // Random offer cards (slot buyback / airport recruitment) can arrive during the
        // 1× stretch — they PRE-DATE the slow, which is exactly the case under test.
        check(sim.decisionQueue.count >= 2, "3: both cards pending (got \(sim.decisionQueue.count))")
        check(sim.decisionQueue.contains(where: { $0.kind == .crew && $0.aircraft?.tail == b.tail }), "3: the second crew card is the pending one")
        if let d = sim.decisionQueue.first(where: { $0.kind == .crew && $0.aircraft?.tail == b.tail }) { sim.resolveCrewHire(d) }
        tick(sim, 3)
        check(sim.decisionQueue.contains(where: { $0.aircraft?.tail == a.tail }), "3: the older card is still there")
        check(sim.speed == 25, "3: speed restored anyway — the older card didn't hold it (got \(sim.speed))")
    }
    // ── 4. Drawers: persistence + legacy + auto-open + kind mapping ──────────────
    do {
        let sim = newSim()
        check(sim.opsCollapsedSections.isEmpty, "4: fresh sim = everything open")
        sim.toggleOpsSection(.maintenance); sim.toggleOpsSection(.events)
        check(sim.opsCollapsedSections == [.maintenance, .events], "4: toggle collapses")
        sim.toggleOpsSection(.events)
        check(sim.opsCollapsedSections == [.maintenance], "4: toggle again re-opens")
        sim.toggleOpsSection(.competition)
        let data = try! JSONEncoder().encode(sim.snapshot())
        let snap = try! JSONDecoder().decode(GameSnapshot.self, from: data)
        check(snap.opsCollapsedSections == ["competition", "maintenance"], "4: persisted as sorted raw values (got \(String(describing: snap.opsCollapsedSections)))")
        let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800)); sim2.restore(from: snap)
        check(sim2.opsCollapsedSections == [.maintenance, .competition], "4: restored collapsed set")
        var legacy = snap; legacy.opsCollapsedSections = nil
        let sim3 = Simulation(); sim3.configure(viewport: CGSize(width: 400, height: 800)); sim3.restore(from: legacy)
        check(sim3.opsCollapsedSections.isEmpty, "4: legacy save (no field) = all open")
        // Auto-open: an alert re-opens Needs Attention; unrelated boxes stay collapsed.
        let sim4 = newSim()
        guard let ac = buy(sim4, "A320"), let den = sim4.airport("DEN"), let ord = sim4.airport("ORD") else { check(false, "setup 4"); printResult(); return }
        _ = sim4.openRoute(from: den, to: ord, using: ac)
        sim4.toggleOpsSection(.needsAttention); sim4.toggleOpsSection(.competition)
        check(tickUntilCrewCard(sim4, tail: ac.tail), "4: CREW card arrives")
        check(!sim4.opsCollapsedSections.contains(.needsAttention), "4: Needs Attention auto-opened on the alert")
        check(sim4.opsCollapsedSections.contains(.competition), "4: an unrelated box stays collapsed")
        check(Simulation.Decision.Kind.mxCheck.opsSection == .maintenance, "4: mxCheck → Maintenance box")
        check(Simulation.Decision.Kind.hubOffer.opsSection == .hubs, "4: hubOffer → Hubs box")
        check(Simulation.Decision.Kind.aog.opsSection == nil, "4: aog → no dedicated box")
        sim4.opsAutoOpen(.competition)
        check(!sim4.opsCollapsedSections.contains(.competition), "4: opsAutoOpen re-opens")
    }
    // ── 5. MX list: nearest date first, row check == sort check ──────────────────
    do {
        let sim = newSim()
        guard let a = buy(sim, "A320"), let b = buy(sim, "B788"), let c = buy(sim, "AT46"),
              let den = sim.airport("DEN"), let ord = sim.airport("ORD"), let sea = sim.airport("SEA"), let sfo = sim.airport("SFO"),
              let lax = sim.airport("LAX"), let phx = sim.airport("PHX")
        else { check(false, "setup 5"); printResult(); return }
        _ = sim.openRoute(from: den, to: ord, using: a)
        _ = sim.openRoute(from: sea, to: sfo, using: b)
        _ = sim.openRoute(from: lax, to: phx, using: c)
        // Fly a while, draining CREW cards so the fleet actually accrues cycles.
        for _ in 0..<60_000 {
            sim.advanceTick()
            for d in sim.decisionQueue where d.kind == .crew { sim.resolveCrewHire(d) }
        }
        let fleet = sim.mxFleet
        check(fleet.count == 3, "5: three owned aircraft in the MX list")
        func key(_ ac: Aircraft) -> Int {
            if ac.inMXShop { return 1_000_000 + (sim.mxShopDaysLeft(ac) ?? 0) }
            return sim.mxNearestCheck(ac)?.days ?? 999_999
        }
        let keys = fleet.map(key)
        check(keys == keys.sorted(), "5: list is nearest-date-first (keys \(keys))")
        for ac in fleet where !ac.inMXShop {
            check(sim.mxNextCheckETA(ac)?.kind == sim.mxNearestCheck(ac)?.kind, "5: \(ac.tail) shows the check it sorts by")
            check(sim.mxNearestCheck(ac)!.days <= sim.mxDaysUntilDue(.d, ac), "5: \(ac.tail) nearest ≤ D on the time axis")
        }
        // devInjectCash is TRACKED (devInjectedCash is an invariant term), so a LIVE sim
        // residual is 0; only a save/load round-trip leaves the −injected residual.
        check(sim.cashInvariantResidual() == 0, "5: cash invariant holds (residual \(sim.cashInvariantResidual()))")
    }
    printResult()
}
MainActor.assumeIsolated { main() }
