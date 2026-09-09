//
//  CarrierHubVerify.swift — competitor hubs are the carrier's REAL hubs
//  (player-reported: "Air France hubbing out of LHR is very odd", 8 Sep 2026).
//
//  Before: CompetitorIntel gave every carrier its REGION's busiest airports, so
//  all European carriers shared LHR/IST/CDG and Air France could never reach CDG
//  in any seed. These hubs are not cosmetic — they base an acquired fleet, anchor
//  its inherited routes, and become real player hubs on acquisition.
//  Separately, the rival who bought a player hub came from a hardcoded US-only
//  pool, so "Southwest Airlines" could permanently own CDG.
//
//  Compile like the other harnesses (see aa-1.1.x/README.md); rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func printResult() { print("\nCarrierHubVerify: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED")) }

    let gameCodes = Set(Airport.all.map(\.code))
    let allCarriers = Airline.allRegions.flatMap { Airline.roster(for: $0) }

    // ── 1. The roster data itself ───────────────────────────────────────────────
    var withHubs = 0
    for a in allCarriers {
        for h in a.hubs {
            check(gameCodes.contains(h), "1: \(a.name) hub \(h) exists in the game")
        }
        if !a.hubs.isEmpty { withHubs += 1 }
    }
    check(withHubs >= 130, "1: the roster carries real hubs for most carriers (\(withHubs))")

    // ── 2. Known-real assignments (the ones a player would notice) ───────────────
    func hubs(_ name: String) -> [String] {
        allCarriers.first { $0.name == name }?.hubs ?? []
    }
    let expected: [(String, String)] = [
        ("Air France", "CDG"), ("Lufthansa", "FRA"), ("British Airways", "LHR"),
        ("Delta Air Lines", "ATL"), ("United Airlines", "ORD"), ("American Airlines", "DFW"),
        ("Emirates", "DXB"), ("Qantas", "SYD"), ("Copa Airlines", "PTY"),
        ("Air Canada", "YYZ"), ("Turkish Airlines", "IST"), ("KLM", "AMS"),
    ]
    for (carrier, hub) in expected where !hubs(carrier).isEmpty {
        check(hubs(carrier).contains(hub), "2: \(carrier) hubs at \(hub) (got \(hubs(carrier)))")
    }
    // THE reported bug: Air France must NOT hub at LHR.
    check(!hubs("Air France").contains("LHR"), "2: Air France does NOT hub at LHR")
    check(!hubs("Lufthansa").contains("LHR"), "2: Lufthansa does NOT hub at LHR")

    // ── 3. Generated profiles use them, and differ within a region ──────────────
    let sim = Simulation(); sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("Hub Air", tailCode: "HB")
    let profiles = sim.competitorProfiles
    check(!profiles.isEmpty, "3: profiles generated (\(profiles.count))")
    var mismatches: [String] = []
    for p in profiles {
        guard let a = allCarriers.first(where: { $0.name == p.name }), !a.hubs.isEmpty else { continue }
        // Every stated hub must be one of the carrier's REAL hubs.
        for h in p.hubCodes where !a.hubs.contains(h) { mismatches.append("\(p.name):\(h)") }
    }
    check(mismatches.isEmpty, "3: every profile hub is one of that carrier's real hubs (bad: \(mismatches.prefix(6)))")
    if let af = profiles.first(where: { $0.name == "Air France" }) {
        check(!af.hubCodes.contains("LHR"), "3: the Air France PROFILE does not hub at LHR (got \(af.hubCodes))")
        check(af.hubCodes.contains("CDG"), "3: the Air France profile hubs at CDG (got \(af.hubCodes))")
    }
    // Carriers in one region must no longer share an identical hub list.
    let euro = profiles.filter { p in Airline.europeRoster.contains { $0.name == p.name } }
    let distinct = Set(euro.map { $0.hubCodes.joined(separator: ",") })
    check(euro.count < 3 || distinct.count > 1,
          "3: European carriers no longer all share one hub list (\(distinct.count) distinct across \(euro.count))")

    // ── 4. Determinism is preserved (profiles regenerate from the seed) ─────────
    let sim2 = Simulation(); sim2.configure(viewport: CGSize(width: 400, height: 800))
    sim2.nameAirline("Hub Air", tailCode: "HB")
    sim2.restore(from: sim.snapshot())
    for p in sim2.competitorProfiles {
        guard let orig = profiles.first(where: { $0.id == p.id }) else { continue }
        check(p.hubCodes == orig.hubCodes, "4: \(p.name) hubs regenerate identically from the seed")
    }
    printResult()
}
MainActor.assumeIsolated { main() }
