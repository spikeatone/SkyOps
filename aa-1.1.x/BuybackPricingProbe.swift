//
//  BuybackPricingProbe.swift — the buyback repricing balance gate (player-reported,
//  8 Sep 2026: "why would I ever sell a highly profitable hub at 30% of my cost, or
//  give back a profitable slot for less than a month's profit?").
//
//  Offers now price off EARNING POWER (slot = months of trailing net; hub = what was
//  actually sunk incl. the club, sometimes at a premium) instead of sunk cost alone.
//  The hard rule from HUBS_AND_CLUBS_SPEC: a stronger offer must never make SELLING
//  strictly better than OPERATING. Both arms restore from ONE shared snapshot so
//  economic events cancel (the documented A/B lesson).
//
//  Rename to main.swift; compile like the other harnesses.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func money(_ v: Int) -> String {
        let a = abs(v), s = v < 0 ? "−" : ""
        return s + (a >= 1_000_000 ? String(format: "$%.2fM", Double(a)/1_000_000) : String(format: "$%.0fk", Double(a)/1_000))
    }
    func build() -> Simulation {
        let sim = Simulation(); sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Offer Air", tailCode: "OF"); sim.devInjectCash(3_000_000_000)
        guard let den = sim.airport("DEN") else { return sim }
        let dests = sim.airports.filter { $0.code != "DEN" && den.greatCircleNM(to: $0) < 1600 && den.greatCircleNM(to: $0) > 250 }
                                .sorted { ($1.info?.annualPassengers ?? 0) < ($0.info?.annualPassengers ?? 0) }
        for i in 0..<8 {
            guard let t = AircraftType.all.first(where: { $0.id == "A320" }), let ac = sim.buyAircraft(t), i < dests.count else { break }
            _ = sim.openRoute(from: den, to: dests[i], using: ac)
        }
        _ = sim.establishHub(at: "DEN")
        let fam = "A320_FAMILY"
        while sim.crewCount(family: fam) < 18 { if sim.hireCrew(family: fam, mode: .rated) == nil { break } }
        // Fly a year so routes have real history and the hub has a real ledger.
        for _ in 0..<(360 * 1440) {
            sim.advanceTick()
            for d in sim.decisionQueue {
                switch d.kind {
                case .crew: sim.resolveCrewWait(d)
                case .aog: sim.resolveAOGStandard(d)
                case .mxCheck: sim.resolveMXServiceNow(d)
                default: break
                }
            }
        }
        return sim
    }

    let seed = build()
    let routes = seed.playerRoutes.filter { $0.isOpen }
    check(!routes.isEmpty, "setup: routes open (\(routes.count))")
    guard let best = routes.max(by: { seed.trailingMonthlyNet($0) < seed.trailingMonthlyNet($1) }) else {
        print("no routes"); return
    }
    // ── 1. A profitable route now draws MONTHS of its profit, not days ──────────
    let monthly = seed.trailingMonthlyNet(best)
    print("Best route \(best.originCode)-\(best.destCode): trailing net \(money(monthly))/sim-month")
    check(monthly > 0, "1: the reference route is profitable (\(money(monthly)))")
    let sunkOnly = Int(Double(max(best.openingCost, best.incentiveWaived)) * 4.0)   // old formula, top of range
    let byEarnings = Int(Double(monthly) * Simulation.slotOfferMonthsMin)
    print("  old top-of-range offer \(money(sunkOnly))  ·  new floor \(money(byEarnings))")
    check(byEarnings > sunkOnly, "1: the new floor beats the OLD ceiling for a profitable route")
    let monthsOld = Double(sunkOnly) / Double(max(1, monthly))
    check(monthsOld < 1.0, "1: the old offer really was under a month of profit (\(String(format: "%.2f", monthsOld)) mo)")

    // ── 2. A hub bid now covers what was actually sunk, club included ───────────
    if let ap = seed.airport("DEN") {
        let sunkNoClub = seed.hubEstablishCost(ap)
        let withClub = sunkNoClub + seed.clubBuildCost(ap)
        let oldOffer = Int(Double(sunkNoClub) * 0.60)
        let newMin = Int(Double(sunkNoClub) * Simulation.hubSalePctHealthyMin)
        print("DEN hub: establish \(money(sunkNoClub)) · +club \(money(withClub)) · old bid \(money(oldOffer)) · new min bid \(money(newMin))")
        check(newMin > oldOffer, "2: a healthy hub bid is no longer a fraction of its cost")
        check(Simulation.hubSalePctUnderstaffed == 0.35, "2: the understaffed branch (which worked) is unchanged")
    }

    // ── 3. THE GATE: accepting every offer must not beat operating ──────────────
    let snap = seed.snapshot()
    func run(accept: Bool, months: Int) -> Int {
        let sim = Simulation(); sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.restore(from: snap)
        var taken = 0, proceeds = 0
        for _ in 0..<(months * Simulation.ticksPerMonth) {
            sim.advanceTick()
            for d in sim.decisionQueue {
                switch d.kind {
                case .crew: sim.resolveCrewWait(d)
                case .aog: sim.resolveAOGStandard(d)
                case .mxCheck: sim.resolveMXServiceNow(d)
                case .offer:
                    if accept, let o = d.offer { taken += 1; proceeds += o.amount; sim.resolveOfferAccept(d) }
                    else { sim.resolveOfferDecline(d) }
                case .hubOffer:
                    if accept, let h = d.hubOffer { taken += 1; proceeds += h.price; sim.resolveHubSale(d, accept: true) }
                    else { sim.resolveHubSale(d, accept: false) }
                default: break
                }
            }
        }
        let nw = sim.playerBalance + sim.fleetMarketValue
        print("  \(accept ? "ACCEPT-ALL" : "DECLINE-ALL"): net worth \(money(nw)) · offers taken \(taken) · proceeds \(money(proceeds))")
        return nw
    }
    let months = 24
    print("A/B over \(months) sim-months from one shared snapshot:")
    let acceptNW = run(accept: true, months: months)
    let declineNW = run(accept: false, months: months)
    let delta = acceptNW - declineNW
    print("  delta (accept − decline): \(money(delta))")
    check(acceptNW <= declineNW,
          "3: THE GATE — selling every asset does NOT beat operating them (delta \(money(delta)))")
    print("\nBuybackPricingProbe: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED"))
}
MainActor.assumeIsolated { main() }
