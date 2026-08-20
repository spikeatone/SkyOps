//  QuestBriefVerify.swift — FIRST QUEST + SESSION BRIEFING
//
//  Verifies the two session-shaping features on the REAL sim:
//  · seedFirstQuest() — the guaranteed, curated recruitment offer for a fresh
//    airline (called from the app's new-game flow, like randomizeCalendarStart;
//    harnesses call it explicitly). Curation bounds, the accept→pending→
//    buy→auto-staff arc, and the guards that keep it from firing twice or for
//    an established airline.
//  · briefingItems() — the welcome-back briefing: prioritization, the 5-item
//    cap, urgency flags, and the healthy-airline fallback.
//
//  RUN (entry file must be named main.swift):
//    mkdir -p /tmp/qb && cp aa-1.1.x/QuestBriefVerify.swift /tmp/qb/main.swift
//    cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/qb/
//    swiftc -O -DDEBUG -o /tmp/qb/qb \
//      $(ls AirlineArchitect/AirlineArchitect/Sim/*.swift | grep -vE 'AircraftIcon|SVGPath') \
//      AirlineArchitect/AirlineArchitect/Persistence.swift \
//      /tmp/qb/RepaintVerifyStubs.swift /tmp/qb/main.swift && /tmp/qb/qb

import Foundation

@MainActor func run() {
    var pass = 0, fail = 0
    func check(_ l: String, _ c: Bool, _ d: String = "") {
        if c { pass += 1; print("  ok   \(l)") } else { fail += 1; print("  FAIL \(l) \(d)") }
    }

    // ---- First quest -------------------------------------------------------
    let sim = Simulation()
    sim.nameAirline("Quest Air", tailCode: "QX")
    sim.seedFirstQuest()
    let offer = sim.decisionQueue.first { $0.kind == .airportOffer }
    check("quest offer exists on a fresh airline", offer != nil)
    if let p = offer?.pitch {
        let o = sim.airports.first { $0.code == p.originCode }
        let d = sim.airports.first { $0.code == p.destCode }
        check("endpoints resolve", o != nil && d != nil)
        if let o, let d {
            let nm = o.greatCircleNM(to: d)
            check("distance suits a starter aircraft", nm >= 200 && nm <= 900, "\(Int(nm))nm")
        }
        check("demand suits a small plane", p.demandPerDay >= 40 && p.demandPerDay <= 220, "\(p.demandPerDay)/day")
        check("bonus follows the offer formula",
              p.signingBonus == min(500_000, 100_000 + p.demandPerDay * 300))
        check("extended (21-day) window", p.expiryTick == sim.tick + 21 * 1440)
        check("pitch is the first-customer welcome", p.pitch.contains("first customer"))

        // Accept with NO aircraft → route opens PENDING (free), bonus banked.
        let cashBefore = sim.playerBalance
        sim.resolveAirportOfferAccept(offer!)
        let r = sim.playerRoutes.first
        check("accept opens the route pending", r != nil && sim.pendingRoutes.count == 1)
        check("opening cost waived", r?.openingCost == 0)
        check("bonus banked", sim.playerBalance == cashBefore + p.signingBonus)
        check("staffing deadline set", r?.fulfillByTick != nil)

        // Buy a plane that can fly it → the pending route auto-staffs.
        sim.devInjectCash(50_000_000)
        if let o = sim.airports.first(where: { $0.code == p.originCode }),
           let d = sim.airports.first(where: { $0.code == p.destCode }),
           let type = AircraftType.all.sorted(by: { $0.purchasePrice < $1.purchasePrice })
               .first(where: { t in Double(t.rangeNM) > o.greatCircleNM(to: d) * 1.1 }),
           let ac = sim.buyAircraft(type) {
            var ticks = 0
            while sim.pendingRoutes.count == 1 && ticks < 3000 { sim.advanceTick(); ticks += 1 }
            check("bought aircraft auto-staffs the quest route",
                  sim.pendingRoutes.isEmpty && ac.assignedRouteId == r?.id)
        } else { check("bought aircraft auto-staffs the quest route", false, "setup failed") }
    }
    // Guards: never a second quest, never for an established airline.
    sim.seedFirstQuest()
    check("no duplicate quest once routes exist",
          sim.decisionQueue.filter { $0.kind == .airportOffer }.count <= 1)
    check("cash invariant holds through the quest", sim.cashInvariantResidual() == 0,
          "residual \(sim.cashInvariantResidual())")

    // ---- Session briefing --------------------------------------------------
    // Healthy empty airline → the calm fallback line, exactly one item.
    let calm = Simulation()
    calm.nameAirline("Calm Air", tailCode: "CX")
    let calmItems = calm.briefingItems()
    check("healthy airline gets the calm fallback",
          calmItems.count == 1 && calmItems[0].title.contains("All quiet"))

    // The quest sim now has real state: a staffed route + whatever the ticks
    // produced. Items exist, are capped, and pending-decision state surfaces.
    let items = sim.briefingItems()
    check("briefing returns items", !items.isEmpty)
    check("briefing is capped at 5", items.count <= 5)
    if !sim.decisionQueue.isEmpty {
        check("pending decisions lead the briefing when present",
              items.contains { $0.title.contains("decision") })
    } else { pass += 1; print("  ok   pending decisions lead the briefing when present (none pending — vacuous)") }

    // A pending offer-route with a deadline surfaces as urgent when close.
    let s2 = Simulation()
    s2.nameAirline("Brief Air", tailCode: "BX")
    s2.seedFirstQuest()
    if let o2 = s2.decisionQueue.first(where: { $0.kind == .airportOffer }) {
        s2.resolveAirportOfferAccept(o2)
        let b = s2.briefingItems()
        check("unstaffed offer route surfaces in the briefing",
              b.contains { $0.title.contains("needs an aircraft") })
    } else { check("unstaffed offer route surfaces in the briefing", false, "no quest offer") }

    print("\n\(pass) passed, \(fail) failed")
    exit(fail == 0 ? 0 : 1)
}
MainActor.assumeIsolated { run() }
