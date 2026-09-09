//
//  TrainingCenterABProbe.swift — the Training Center balance gate (crew-training
//  Phase 2). The scope's rule: a center must be a VALUE-SINK for a small fleet and
//  PAY BACK for a large one — a threshold, never dominant (the Hubs lesson).
//
//  METHOD: the center's own ledger IS the A/B. Every in-house course books
//  `savings = contract price − in-house price` (the contract price that would have
//  been charged), so `payback = savings − facility − opex` is EXACTLY the delta vs.
//  a contract-only twin with the same training volume — economic events, AOG,
//  weather all cancel because they don't touch the ledger. (Two separate sims
//  would let events poison the comparison — the FareVerify lesson.) Course volume
//  is the same in both arms: the center changes price/length/concurrency, not how
//  many courses a family needs.
//
//  Arms: one family per run, n aircraft on n routes out of a DEN hub, crewed to
//  ~2.1/aircraft with rated hires (same in both arms; no course), auto-recurrent
//  on, center + one bay built on day 0. Prints payback at 12/24/36/48/60 months.
//  Compile like the other harnesses; rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func buy(_ sim: Simulation, _ id: String) -> Aircraft? {
        guard let t = AircraftType.all.first(where: { $0.id == id }) else { return nil }
        return sim.buyAircraft(t)
    }
    func money(_ v: Int) -> String {
        let a = abs(v), s = v < 0 ? "−" : "+"
        return s + (a >= 1_000_000 ? String(format: "$%.2fM", Double(a) / 1_000_000) : String(format: "$%.0fk", Double(a) / 1_000))
    }
    struct Result { let type: String; let n: Int; let byMonth: [Int: Int]; let savings: Int; let opex: Int; let facility: Int; let crews: Int }
    func run(_ typeId: String, n: Int, months: Int) -> Result? {
        let sim = Simulation(); sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Probe Air", tailCode: "PB"); sim.devInjectCash(5_000_000_000)
        guard let den = sim.airport("DEN"), let type = AircraftType.all.first(where: { $0.id == typeId }) else { return nil }
        let maxNM = min(Double(type.rangeNM) * 0.8, 2_200)
        let dests = sim.airports.filter { $0.code != "DEN" && den.greatCircleNM(to: $0) < maxNM && den.greatCircleNM(to: $0) > 250 }
                                .sorted { den.greatCircleNM(to: $0) < den.greatCircleNM(to: $1) }
        for i in 0..<n {
            guard let ac = buy(sim, typeId), i < dests.count else { return nil }
            guard case .success = sim.openRoute(from: den, to: dests[i], using: ac) else { return nil }
        }
        guard sim.establishHub(at: "DEN"), sim.hubOperating("DEN") else { return nil }
        let fam = type.family
        // Crew to ~2.1 per aircraft with rated hires (no course either way).
        let target = Int((Double(n) * 2.1).rounded())
        while sim.crewCount(family: fam) < target { guard sim.hireCrew(family: fam, mode: .rated) != nil else { break } }
        guard sim.buildTrainingCenter(at: "DEN"), sim.addSimBay(family: fam) else { return nil }
        var byMonth: [Int: Int] = [:]
        for m in 1...months {
            for _ in 0..<Simulation.ticksPerMonth {
                sim.advanceTick()
                for d in sim.decisionQueue {
                    switch d.kind {
                    case .crew: sim.resolveCrewWait(d)
                    case .aog:  sim.resolveAOGStandard(d)
                    default:    break
                    }
                }
            }
            if m % 12 == 0 { byMonth[m] = sim.trainingCenter!.ledger.payback }
        }
        let l = sim.trainingCenter!.ledger
        return Result(type: typeId, n: n, byMonth: byMonth, savings: l.savings, opex: l.opexPaid, facility: l.facilitySpend, crews: sim.crewCount(family: fam))
    }

    let months = 60
    let arms: [(String, Int)] = [("A320", 6), ("A320", 8), ("A320", 12), ("A320", 16), ("A320", 24), ("B788", 8)]
    var results: [Result] = []
    print("TRAINING CENTER A/B — payback (savings vs contract − facility − opex), \(months) months")
    print(String(repeating: "-", count: 96))
    print(String(format: "%-6@ %4@ %6@ | %12@ %12@ %12@ %12@ %12@ | %10@ %10@ %10@", "type", "n", "crews", "12 mo", "24 mo", "36 mo", "48 mo", "60 mo", "savings", "opex", "facility"))
    for (t, n) in arms {
        guard let r = run(t, n: n, months: months) else { print("\(t) n=\(n): setup failed"); continue }
        results.append(r)
        let cols = [12, 24, 36, 48, 60].map { money(r.byMonth[$0] ?? 0) }
        print(String(format: "%-6@ %4d %6d | %12@ %12@ %12@ %12@ %12@ | %10@ %10@ %10@", t, n, r.crews, cols[0], cols[1], cols[2], cols[3], cols[4], money(r.savings), money(-r.opex), money(-r.facility)))
    }
    print(String(repeating: "-", count: 96))
    func payback(_ t: String, _ n: Int, _ m: Int) -> Int? { results.first { $0.type == t && $0.n == n }?.byMonth[m] }
    // The threshold shape (the gate).
    check((payback("A320", 6, 60) ?? 1) < 0, "small narrowbody family (6, the gate) is a value-sink even at 60 months")
    check((payback("A320", 16, 48) ?? -1) > 0, "16 narrowbodies pay back within 48 months")
    check((payback("A320", 24, 36) ?? -1) > 0, "24 narrowbodies pay back within 36 months")
    check((payback("B788", 8, 36) ?? -1) > 0, "8 widebodies pay back within 36 months (the expensive sim is the one worth owning)")
    if let a = payback("A320", 6, 60), let b = payback("A320", 16, 60) { check(b > a, "payback rises with fleet size") }
    print("\nTrainingCenterABProbe: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED"))
}
MainActor.assumeIsolated { main() }
