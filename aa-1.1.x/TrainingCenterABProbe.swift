//
//  TrainingCenterABProbe.swift — the Training Center balance probe (crew-training
//  Phase 2), REWRITTEN 8 Sep 2026 after the real-simulator repricing.
//
//  ⚠️ THIS IS NOW A MEASUREMENT TOOL, NOT A PASS/FAIL GATE. The original version
//  asserted a threshold shape (value-sink for a small family, payback for a large
//  one) against GAME-SCALED costs — facility $750k, bay $1.25–2.5M. The designer
//  then supplied real figures (a Level D full-flight sim costs as much as an
//  airplane; a 10-bay centre runs $160–260M), so the facility is $35M and a bay is
//  $12–22M. At those prices the old assertions are unreachable and the old arms
//  (6/8/12/16 aircraft) can't even BUILD a bay any more — the gate is 20. Asserting
//  a target nobody has set would be inventing one, so this prints the table and
//  asserts only what must hold regardless of tuning:
//
//    1. the ledger identity (payback == savings + timeValue − facility − opex),
//    2. payback improves with fleet size.
//
//  ⚠️ A "STRETCHED" ARM IS MEASURED BUT NOT ASSERTED, and the reason is a real
//  finding. `crewShortfallFactor` does raise the value of a crew-day when crew is
//  the binding constraint — `TrainingCenterVerify` test 9 proves that in isolation
//  — but on a LIVE fleet understaffing has two larger, opposite effects: aircraft
//  sit in rest holds so `dailyNet` (the thing a crew-day is valued against) falls,
//  and fewer crews means fewer courses to shorten. Measured: 45 A320s at 1.4
//  crews/aircraft book LESS total time value than the same fleet at 2.1, both in
//  total and per crew. So the scarcity premium is real but swamped by volume — do
//  not "fix" that by removing the shortfall factor; it's what stops a
//  deeply-covered airline booking value for crew it didn't need.
//
//  METHOD: the center's own ledger IS the A/B. Every in-house course books
//  `savings = contract price − in-house price` and every shortened course books the
//  crew-days it returned, so `payback` is exactly the delta vs. a contract-only twin
//  with the same training volume — economic events, AOG and weather all cancel
//  because they never touch the ledger. (Two separate sims would let events poison
//  the comparison — the FareVerify lesson.)
//
//  Arms: one family per run, n aircraft on n routes out of a DEN hub, auto-recurrent
//  on, center + one bay built on day 0. The "stretched" arm is crewed BELOW
//  `coverageContinuousRatio` so crew is the binding constraint and time value accrues.
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
        return s + (a >= 1_000_000 ? String(format: "$%.1fM", Double(a) / 1_000_000) : String(format: "$%.0fk", Double(a) / 1_000))
    }
    struct Result {
        let label: String; let type: String; let n: Int
        let byMonth: [Int: Int]
        let savings: Int; let timeValue: Int; let opex: Int; let facility: Int; let crews: Int
    }
    /// - Parameter crewRatio: crews per aircraft. Above `coverageContinuousRatio`
    ///   (1.9) crew is never the binding constraint, so the shortfall factor — and
    ///   with it the time value — is zero BY DESIGN. Below it, time counts.
    func run(_ label: String, _ typeId: String, n: Int, crewRatio: Double, months: Int) -> Result? {
        let sim = Simulation(); sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Probe Air", tailCode: "PB"); sim.devInjectCash(20_000_000_000)
        guard let den = sim.airport("DEN"), let type = AircraftType.all.first(where: { $0.id == typeId }) else { return nil }
        let maxNM = min(Double(type.rangeNM) * 0.8, 2_200)
        let dests = sim.airports.filter { $0.code != "DEN" && den.greatCircleNM(to: $0) < maxNM && den.greatCircleNM(to: $0) > 250 }
                                .sorted { den.greatCircleNM(to: $0) < den.greatCircleNM(to: $1) }
        var opened = 0
        for d in dests where opened < n {
            guard let ac = buy(sim, typeId) else { return nil }
            if case .success = sim.openRoute(from: den, to: d, using: ac) { opened += 1 }
        }
        guard opened == n else { print("\(label): only opened \(opened)/\(n) routes"); return nil }
        guard sim.establishHub(at: "DEN"), sim.hubOperating("DEN") else { return nil }
        let fam = type.family
        let target = Int((Double(n) * crewRatio).rounded())
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
        return Result(label: label, type: typeId, n: n, byMonth: byMonth,
                      savings: l.savings, timeValue: l.timeValue ?? 0,
                      opex: l.opexPaid, facility: l.facilitySpend, crews: sim.crewCount(family: fam))
    }

    let months = 60
    // Every arm is at or above `simBayMinAircraft` (20) — below it a bay can't be built.
    let arms: [(String, String, Int, Double)] = [
        ("gate",      "A320", 20, 2.1),
        ("large",     "A320", 45, 2.1),
        ("stretched", "A320", 45, 1.4),
        ("widebody",  "B788", 20, 2.1),
    ]
    var results: [Result] = []
    print("TRAINING CENTER — payback (course savings + crew time − facility − opex), \(months) months")
    print("costs are REAL simulator prices (facility $35M, bay $12–22M) — see CREW_TRAINING_SCOPE.md")
    print(String(repeating: "-", count: 110))
    print(String(format: "%-10@ %-5@ %3@ %6@ | %10@ %10@ %10@ %10@ %10@ | %9@ %9@ %9@ %9@",
                 "arm", "type", "n", "crews", "12 mo", "24 mo", "36 mo", "48 mo", "60 mo",
                 "fees", "time", "opex", "facility"))
    for (label, t, n, ratio) in arms {
        guard let r = run(label, t, n: n, crewRatio: ratio, months: months) else { print("\(label): setup failed"); continue }
        results.append(r)
        let cols = [12, 24, 36, 48, 60].map { money(r.byMonth[$0] ?? 0) }
        print(String(format: "%-10@ %-5@ %3d %6d | %10@ %10@ %10@ %10@ %10@ | %9@ %9@ %9@ %9@",
                     label, t, n, r.crews, cols[0], cols[1], cols[2], cols[3], cols[4],
                     money(r.savings), money(r.timeValue), money(-r.opex), money(-r.facility)))
    }
    print(String(repeating: "-", count: 110))
    func arm(_ l: String) -> Result? { results.first { $0.label == l } }

    // 1. The ledger identity — the thing every reading above depends on.
    for r in results {
        check(r.byMonth[months] == r.savings + r.timeValue - r.facility - r.opex,
              "\(r.label): payback == fees + time − facility − opex")
    }
    // 2. Scale helps (same crew ratio, bigger family).
    if let g = arm("gate")?.byMonth[months], let l = arm("large")?.byMonth[months] {
        check(l > g, "payback improves with fleet size")
    }
    // Report the headline the designer actually needs, without asserting a target.
    print("")
    for r in results {
        let p = r.byMonth[months] ?? 0
        let yrs = p > 0 ? "repaid inside \(months / 12) yr"
                        : String(format: "still %@ short at %d yr", money(-p), months / 12)
        let perCrew = r.crews > 0 ? r.timeValue / r.crews : 0
        print("  \(r.label) (\(r.n)× \(r.type), \(r.crews) crews): \(yrs) · time value \(money(perCrew))/crew")
    }
    print("\nTrainingCenterABProbe: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED"))
}
MainActor.assumeIsolated { main() }
