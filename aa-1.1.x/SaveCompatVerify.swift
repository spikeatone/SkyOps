import Foundation

// Reproduces + guards the tester data-loss bug: an OLDER build's save (missing
// keys that later builds added) must still DECODE in the current build.
@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    // 1. A real modern snapshot with a route (history + assignment) + an aircraft.
    var snap = GameSnapshot()
    snap.playerAirlineName = "Aster Air"
    snap.playerTailCode = "MR"
    snap.playerBalance = 4_250_000
    snap.tick = 53_000
    snap.reputation = 82
    let fr = FlightRecordSave(id: 1, tick: 100, tail: "N1MR", revenue: 50000, fees: 8000,
                              operatingCost: 30000, leaseCostEstimate: 0, net: 12000,
                              pax: 120, seats: 150, loadFactor: 0.8, cumulativeNet: 12000)
    let asg = RouteAssignmentSave(id: 1, tail: "N1MR", typeName: "A320", assignedTick: 90)
    let route = RouteSave(id: 7, originCode: "DEN", destCode: "MCI", openedTick: 90, openingCost: 85000,
                          cumulativeNet: 12000, flights: 1, totalLeaseCost: 0, closedTick: nil,
                          competitionLevel: 1, competitors: ["Delta"], incentiveBonus: 0, incentiveWaived: 0,
                          fulfillByTick: nil, subsidiaryCode: nil, history: [fr], assignmentHistory: [asg],
                          revenueTotal: 50000, feesTotal: 8000, opCostTotal: 30000, loadFactorSum: 0.8)
    snap.routes = [route]
    let ac = AircraftSave(tail: "N1MR", typeId: "A320", originCode: "DEN", destCode: "MCI",
                          stateIndex: 3, stateTick: 12, cyclesAccrued: 40, assignedRouteId: 7, pendingRouteId: nil,
                          sellOfferDismissed: false, isLeased: true, leaseAccrued: 1234.5, maint: false,
                          aogAutoClearTick: nil, crewId: 5, subsidiaryCode: nil)
    snap.aircraft = [ac]
    snap.loans = [LoanSave(id: 1, originalPrincipal: 5_000_000, remainingPrincipal: 4_800_000,
                           monthlyRate: 0.006, monthlyPayment: 90000, termMonths: 60, takenTick: 1000)]
    snap.playerFareWarUntil = [7: 99999]
    snap.crewTrainingDue = ["A320_FAMILY": 120000]

    let data = try! JSONEncoder().encode(snap)

    // 2. Strip keys added by LATER builds → simulate an OLDER build's on-disk save.
    var obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    for k in ["playerFareWarUntil", "adCampaignUntil", "loyaltyPushUntil", "crewTrainingDue",
              "crewTrainingDeferred", "loans", "totalLoanProceeds", "totalDebtService", "reputation",
              "firedMilestones", "stressTestCount", "totalMarketingSpend", "totalFlightsFlown",
              "playerTailCode"] { obj.removeValue(forKey: k) }
    if var routes = obj["routes"] as? [[String: Any]], !routes.isEmpty {
        var r = routes[0]
        for k in ["competitionLevel", "competitors", "incentiveBonus", "incentiveWaived",
                  "revenueTotal", "feesTotal", "opCostTotal", "loadFactorSum"] { r.removeValue(forKey: k) }
        routes[0] = r; obj["routes"] = routes
    }
    if var acs = obj["aircraft"] as? [[String: Any]], !acs.isEmpty {
        var a = acs[0]; a.removeValue(forKey: "leaseAccrued"); acs[0] = a; obj["aircraft"] = acs
    }
    let legacy = try! JSONSerialization.data(withJSONObject: obj)

    // 3. The current build MUST still read the older save.
    let restored = try? JSONDecoder().decode(GameSnapshot.self, from: legacy)
    check(restored != nil, "older-build save still DECODES (the tester data-loss bug)")
    if let r = restored {
        check(r.playerAirlineName == "Aster Air", "airline name survived")
        check(r.playerBalance == 4_250_000, "balance survived")
        check(r.routes.count == 1 && r.routes.first?.id == 7, "route survived")
        check(r.aircraft.count == 1 && r.aircraft.first?.tail == "N1MR", "aircraft survived")
        check(r.routes.first?.competitionLevel == 0, "missing route field -> default 0")
        check(r.aircraft.first?.leaseAccrued == 0, "missing aircraft field -> default 0")
        check(r.playerTailCode == "ZQ", "missing tail code -> default ZQ")
        check(r.reputation == Simulation.reputationStart, "missing reputation -> default 70")
        check(r.playerFareWarUntil.isEmpty, "missing promo map -> empty")
    }

    // 4. A totally empty object decodes to defaults (maximum tolerance, no crash).
    let empty = try? JSONDecoder().decode(GameSnapshot.self, from: "{}".data(using: .utf8)!)
    check(empty != nil && empty?.playerAirlineName == nil, "empty {} decodes to defaults, no crash")

    // 5. Normal round-trip unaffected.
    let rt = try? JSONDecoder().decode(GameSnapshot.self, from: data)
    check(rt?.playerAirlineName == "Aster Air" && rt?.aircraft.first?.leaseAccrued == 1234.5,
          "normal full round-trip intact")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}
MainActor.assumeIsolated { run() }
