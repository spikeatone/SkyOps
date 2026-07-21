import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    let carib = Airline.roster(for: .caribbean)
    let caribNames = Set(carib.map(\.name))
    let mainland = Set(["Copa Airlines", "Avianca", "Volaris"])

    // 1. Roster shape
    check(carib.count == 6, "caribbean roster has 6 carriers (\(carib.count))")
    check(caribNames.contains("Caribbean Airlines") && caribNames.contains("Winair") && caribNames.contains("interCaribbean Airways"),
          "expected real Caribbean carriers present")
    check(caribNames.isDisjoint(with: mainland), "no Copa/Avianca/Volaris in the Caribbean roster")

    // 2. Region split
    check(Airline.region("NAS") == .caribbean && Airline.region("SBH") == .caribbean && Airline.region("BDA") == .caribbean,
          "Caribbean islands classify as .caribbean")
    check(Airline.region("PTY") == .centralAmerica && Airline.region("SJO") == .centralAmerica,
          "Central American mainland stays .centralAmerica")
    check(Airline.region("SJU") == .us && Airline.region("STT") == .us, "US territories SJU/STT stay .us")

    // 3. Weighted draw only yields Caribbean carriers (not mainland)
    var drawn = Set<String>()
    for _ in 0..<4000 { drawn.insert(Airline.weighted(carib).name) }
    check(drawn.isSubset(of: caribNames), "weighted caribbean draws never yield a non-Caribbean carrier")
    check(drawn.count >= 5, "most Caribbean carriers appear across draws (\(drawn.count)/6)")

    // 4. Domestic Caribbean leg (NAS-GCM) draws Caribbean carriers for their types
    var caribLegCarriers = Set<String>()
    for id in ["DH8B", "AT46", "B737800", "ERJ145"] {
        let a = Airline.pick(forType: id, originCode: "NAS", destCode: "GCM")
        caribLegCarriers.insert(a.name)
    }
    check(!caribLegCarriers.isEmpty && caribLegCarriers.allSatisfy { caribNames.contains($0) || $0 == "Independent Operator" },
          "NAS-GCM carriers are Caribbean (or fallback): \(caribLegCarriers)")

    // 5. Every game type resolves on a Caribbean leg (no crash, non-empty)
    var allResolve = true
    for t in AircraftType.all { if Airline.pick(forType: t.id, originCode: "NAS", destCode: "GCM").name.isEmpty { allResolve = false } }
    check(allResolve, "every type resolves to a carrier on a Caribbean leg")

    // 6. realCodes protects the Caribbean IATA codes (player can't collide)
    check(["BW","UP","KX","JY","WM","S6"].allSatisfy { Airline.realCodes[$0] != nil },
          "all 6 Caribbean codes are in realCodes (tail-code collision guard)")

    // 7. Player start "Central America & The Caribbean" spans BOTH regions
    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.setHomeRegion(.centralAmerica)
    let homeCodes = Set(sim.homeAirports.map(\.code))
    check(homeCodes.contains("NAS") && homeCodes.contains("PTY"),
          "CA start home airports include BOTH Caribbean (NAS) and mainland (PTY)")

    // 8. Background traffic actually flies Caribbean carriers on Caribbean airports
    sim.setFleetSize(500)
    let caribAC = sim.aircraft.filter { $0.homeRegion == .caribbean }
    check(!caribAC.isEmpty, "background traffic spawns Caribbean-region aircraft (\(caribAC.count))")
    let goodCarrier = caribAC.allSatisfy { caribNames.contains($0.airlineName ?? "") || $0.airlineName == "Independent Operator" }
    check(goodCarrier, "every Caribbean-region aircraft wears a Caribbean carrier (or fallback)")
    let touchesCarib = caribAC.allSatisfy { Airline.region($0.origin.code) == .caribbean || Airline.region($0.dest.code) == .caribbean }
    check(touchesCarib, "every Caribbean-region aircraft has a Caribbean endpoint")
    let realCaribSeen = caribAC.contains { caribNames.contains($0.airlineName ?? "") }
    check(realCaribSeen, "at least one real Caribbean carrier is actually flying")

    // 9. Market Intelligence includes the Caribbean carriers, deterministically
    let seed: UInt64 = 12345
    let p1 = CompetitorIntel.generateAll(seed: seed, airports: Airport.all)
    let p2 = CompetitorIntel.generateAll(seed: seed, airports: Airport.all)
    let names1 = Set(p1.map(\.name))
    check(names1.contains("Caribbean Airlines") && names1.contains("Bahamasair"),
          "competitor intel includes Caribbean carriers")
    check(p1.map(\.name) == p2.map(\.name), "competitor intel regenerates deterministically from seed")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
