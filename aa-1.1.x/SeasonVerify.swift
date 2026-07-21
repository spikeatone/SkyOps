import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func mean(_ a: [Double]) -> Double { a.reduce(0,+) / Double(a.count) }

    // ============ #2 SEASONAL WEATHER ============
    print("--- #2 seasonal weather ---")
    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    guard let mia = sim.airport("MIA"), let jfk = sim.airport("JFK"), let syd = sim.airport("SYD"),
          let bom = sim.airport("BOM"), let dxb = sim.airport("DXB") else { print("airport setup fail"); return }

    // Zone classification
    check(sim.weatherZone(mia) == .hurricane,   "MIA -> hurricane")
    check(sim.weatherZone(jfk) == .northWinter, "JFK -> northWinter")
    check(sim.weatherZone(syd) == .southWinter, "SYD -> southWinter")
    check(sim.weatherZone(bom) == .monsoon,     "BOM -> monsoon")
    check(sim.weatherZone(dxb) == .mild,        "DXB -> mild")

    // Seasonal factor by month + calibration (advance month-by-month, reading factor).
    var miaF: [Double] = [], jfkF: [Double] = [], sydF: [Double] = []
    var miaOnsetsByMonth = [Int](repeating: 0, count: 12)
    var prevStop = false
    for m in 0..<12 {
        check(sim.monthOfYear == m, "monthOfYear tracks (\(sim.monthOfYear) vs \(m))")
        miaF.append(sim.seasonalWeatherFactor(mia))
        jfkF.append(sim.seasonalWeatherFactor(jfk))
        sydF.append(sim.seasonalWeatherFactor(syd))
        for _ in 0..<Simulation.ticksPerMonth {
            sim.advanceTick()
            let s = mia.groundStop
            if s && !prevStop { miaOnsetsByMonth[sim.monthOfYear] += 1 }   // count onsets
            prevStop = s
        }
    }
    check(miaF.firstIndex(of: miaF.max()!) == 8, "MIA weather peaks in September (idx \(miaF.firstIndex(of: miaF.max()!)!))")
    check(miaF[8] > 2.0 && miaF[2] < 0.8, "MIA hurricane Sep high (\(miaF[8])) / spring low (\(miaF[2]))")
    check(jfkF[0] > 1.6 && jfkF[6] < 0.7, "JFK winter Jan high (\(jfkF[0])) / summer low (\(jfkF[6]))")
    check(sydF[6] > 1.6 && sydF[0] < 0.7, "SYD southern-winter Jul high (\(sydF[6])) / Jan low (\(sydF[0]))")
    check(abs(mean(miaF) - 1.0) < 0.06, "MIA curve averages ~1.0 (\(mean(miaF))) — annual calibration preserved")
    check(abs(mean(jfkF) - 1.0) < 0.06, "JFK curve averages ~1.0 (\(mean(jfkF)))")
    // Empirical: over the sim-year, hurricane-season onsets outnumber spring onsets.
    let peak = miaOnsetsByMonth[7] + miaOnsetsByMonth[8] + miaOnsetsByMonth[9]      // Aug-Oct
    let low  = miaOnsetsByMonth[1] + miaOnsetsByMonth[2] + miaOnsetsByMonth[3]      // Feb-Apr
    check(peak > low, "MIA onsets: hurricane season (\(peak)) > spring (\(low))")
    print("  MIA onsets by month (Jan..Dec): \(miaOnsetsByMonth)")

    // ============ #3 SEASONAL LEISURE DEMAND ============
    print("--- #3 seasonal leisure yield ---")
    check(abs(mean(Simulation.leisureSeasonCurve) - 1.0) < 0.03, "leisure curve averages ~1.0 (\(mean(Simulation.leisureSeasonCurve)))")
    check(Simulation.leisureSeasonCurve[11] > Simulation.leisureSeasonCurve[6], "leisure peaks in winter (Dec > Jul)")

    let g = Simulation()
    g.configure(viewport: CGSize(width: 400, height: 800))
    g.setHomeRegion(.northAmerica)
    g.nameAirline("Season Air", tailCode: "MR")
    g.devInjectCash(2_000_000_000)
    guard let ty = AircraftType.all.first(where: { $0.id == "ERJ145" }) else { print("no ERJ145"); return }
    func openRoute(_ o: String, _ d: String) {
        guard let oa = g.airport(o), let da = g.airport(d), let ac = g.buyAircraft(ty) else { return }
        _ = g.openRoute(from: oa, to: da, using: ac)
    }
    openRoute("MIA", "NAS")   // leisure (NAS is a leisure island)
    openRoute("MIA", "ATL")   // control (non-leisure)
    for fam in g.ownedFamilies { for _ in 0..<8 { _ = g.hireCrew(family: fam) } }
    // Capture each completed flight's revenue DURING the run (route.history caps at
    // 60, so reading it after a year only shows the final months). Bucket by month.
    var buckets: [String: [Int: (sum: Double, n: Int)]] = ["NAS": [:], "ATL": [:]]
    var lastFlights: [Int: Int] = [:]
    for t in 0..<(Simulation.ticksPerMonth * 12) {   // one sim-year
        g.advanceTick()
        for r in g.playerRoutes {
            if r.flights > (lastFlights[r.id] ?? 0), let rec = r.history.last {
                let mo = (rec.tick / Simulation.ticksPerMonth) % 12
                let key = (r.originCode == "NAS" || r.destCode == "NAS") ? "NAS" : "ATL"
                var b = buckets[key]![mo] ?? (0, 0); b.sum += Double(rec.revenue); b.n += 1; buckets[key]![mo] = b
            }
            lastFlights[r.id] = r.flights
        }
        if t % 1440 == 0 {
            for dec in Array(g.decisionQueue) {
                switch dec.kind { case .aog: g.resolveAOGExpedite(dec); case .crew: g.resolveCrewHire(dec); case .sell: g.resolveSellKeep(dec); default: break }
            }
        }
    }
    func seasonAvg(_ code: String, winter: Bool) -> Double {
        let months = winter ? [11, 0, 1] : [5, 6, 7]
        var sum = 0.0, n = 0
        for mo in months { if let b = buckets[code]?[mo] { sum += b.sum; n += b.n } }
        return n == 0 ? 0 : sum / Double(n)
    }
    let leiW = seasonAvg("NAS", winter: true), leiS = seasonAvg("NAS", winter: false)
    let ctlW = seasonAvg("ATL", winter: true), ctlS = seasonAvg("ATL", winter: false)
    print(String(format: "  leisure NAS: winter $%.0f vs summer $%.0f (ratio %.2f)", leiW, leiS, leiW/max(1,leiS)))
    print(String(format: "  control ATL: winter $%.0f vs summer $%.0f (ratio %.2f)", ctlW, ctlS, ctlW/max(1,ctlS)))
    check(leiW > leiS * 1.4, "leisure route earns markedly more in winter (\(String(format:"%.2f", leiW/max(1,leiS)))x)")
    check(abs(ctlW/max(1,ctlS) - 1.0) < 0.15, "control route revenue is ~flat across seasons (no leisure season)")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}

MainActor.assumeIsolated { run() }
