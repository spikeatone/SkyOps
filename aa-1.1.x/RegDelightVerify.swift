import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    // ============ #1 REGISTRATION PREFIXES ============
    print("--- #1 registration prefixes ---")
    // Well-known carriers map to the right national prefix
    let expect: [String: String] = [
        "LH":"D","AF":"F","BA":"G","KL":"PH","IB":"EC","QF":"VH","NZ":"ZK","JL":"JA","NH":"JA",
        "CA":"B","CX":"B","KE":"HL","EK":"A6","QR":"A7","AC":"C","AM":"XA","CM":"HP","AV":"HK",
        "BW":"9Y","LA":"CC","AR":"LV","SU":"RA","TK":"TC","SQ":"9V","ET":"ET","MS":"SU",
        "AA":"N","DL":"N","UA":"N","WM":"PJ","KX":"VP","TN":"F",
    ]
    for (code, pfx) in expect.sorted(by: { $0.key < $1.key }) {
        check(Airline.registrationPrefix(code: code) == pfx, "prefix \(code) -> \(pfx) (got \(Airline.registrationPrefix(code: code)))")
    }
    // Every real roster carrier (non-empty code) has an explicit prefix mapping
    var missing: [String] = []
    for r in Airline.allRegions {
        for a in Airline.roster(for: r) where !a.code.isEmpty {
            if Airline.regPrefixByCode[a.code] == nil { missing.append("\(a.name)(\(a.code))") }
        }
    }
    check(missing.isEmpty, "every roster carrier has a prefix — missing: \(missing.prefix(8))")

    // Real spawn path: tails carry the national prefix, foreign carriers are NOT "N"
    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.setHomeRegion(.northAmerica)
    sim.nameAirline("Verify Air", tailCode: "MR")
    sim.setFleetSize(600)
    let bg = sim.aircraft.filter { !$0.purchased }
    var wellFormed = true, sawForeign = false
    var lhTail: String? = nil, qfTail: String? = nil
    for ac in bg {
        // tail is <prefix><number><code>; recover the code from the airline
        guard let name = ac.airlineName else { continue }
        let match = Airline.allRegions.flatMap { Airline.roster(for: $0) }.first { $0.name == name }
        let code = (match?.code.isEmpty == false) ? match!.code : String(ac.tail.suffix(2))
        let pfx = Airline.registrationPrefix(code: code, region: ac.homeRegion ?? .us)
        if !(ac.tail.hasPrefix(pfx) && ac.tail.hasSuffix(code)) { wellFormed = false }
        if !ac.tail.hasPrefix("N") { sawForeign = true }
        if name == "Lufthansa" { lhTail = ac.tail }
        if name == "Qantas" { qfTail = ac.tail }
    }
    check(wellFormed, "every background tail = <national prefix><n><code>")
    check(sawForeign, "foreign carriers get non-N tails (\(bg.count) background a/c)")
    if let t = lhTail { check(t.hasPrefix("D"), "a Lufthansa tail is D-registered: \(t)") }
    if let t = qfTail { check(t.hasPrefix("VH"), "a Qantas tail is VH-registered: \(t)") }
    // Player's own fleet stays N
    if let t = AircraftType.all.first(where: { $0.bodyType == .regionalJet }), let ac = sim.buyAircraft(t) {
        check(ac.tail.hasPrefix("N"), "player fleet stays N-registered: \(ac.tail)")
    }

    // ============ #5 MILESTONES ============
    print("--- #5 milestones ---")
    let g = Simulation()
    g.configure(viewport: CGSize(width: 400, height: 800))
    g.setHomeRegion(.northAmerica)
    g.nameAirline("Delight Air", tailCode: "MR")   // real $20M start (no inject yet)
    var seen = Set<String>()
    func collectTicks(_ n: Int) {
        for t in 0..<n {
            g.advanceTick()
            for c in g.celebrations { seen.insert(c.title) }   // capture before the 3-cap drops them
            if t % 1440 == 0 {
                for dec in Array(g.decisionQueue) {
                    switch dec.kind { case .aog: g.resolveAOGExpedite(dec); case .crew: g.resolveCrewHire(dec); case .sell: g.resolveSellKeep(dec); default: break }
                }
            }
        }
    }
    // Open one at a time with a tick between, so each first-milestone gets its own
    // tick (real play does this; the 3-slot toast queue would otherwise cap a burst).
    func open(_ o: String, _ d: String, _ typePred: (AircraftType) -> Bool) {
        guard let ty = AircraftType.all.filter(typePred).min(by: { $0.purchasePrice < $1.purchasePrice }),
              let oa = g.airport(o), let da = g.airport(d), let ac = g.buyAircraft(ty) else { print("  open \(o)-\(d) setup fail"); return }
        if case .success = g.openRoute(from: oa, to: da, using: ac) {} else { print("  open \(o)-\(d) failed") }
        collectTicks(3)
    }
    open("ATL","MIA") { $0.bodyType == .regionalJet }                 // domestic (on $20M) → first_aircraft + first_route, no net-worth flood
    g.devInjectCash(3_000_000_000)                                     // now fund the rest
    open("MIA","NAS") { $0.bodyType == .regionalJet }                 // us↔caribbean → first_intl
    open("SXM","SBH") { $0.id == "DH8B" }                             // iconic St. Barths
    open("JFK","LAX") { $0.bodyType == .widebody2Engine }             // widebody
    for fam in g.ownedFamilies { for _ in 0..<5 { _ = g.hireCrew(family: fam) } }
    collectTicks(Simulation.ticksPerMonth * 3)
    for want in ["First jet purchased!", "First route opened!", "First flight complete!",
                 "First international route!", "First widebody!", "You now serve St. Barths!"] {
        check(seen.contains(want), "milestone fired: \(want)")
    }
    print("  milestones seen (\(seen.count)): \(seen.sorted().joined(separator: " | "))")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
