//
//  TickCostProbe.swift — measures the MAIN-THREAD cost of one `advanceTick()`
//  as a function of fleet and route count, and reports it against the drain
//  budget that decides whether the sim stays responsive at high speed.
//
//  WHY THIS EXISTS (8 Sep 2026). TelemetryDeck reported `hang.under3s` ×43 and a
//  RunningBoard watchdog SIGKILL on the shipping app. Root cause was a pair:
//    1. `assignSpareToPendingRoutes()` ran an O(routes × fleet) scan on EVERY
//       tick, guarded only on "a spare exists" — and 1.7's MX program creates
//       spares by design, so on a large fleet the scan was permanently on.
//    2. `run()`'s catch-up drain was capped at 50 TICKS, which is unreachable up
//       to 25× but at the 100× added in 1.7 is only 125ms of SIM time — under the
//       250ms input clamp. So once per-tick cost exceeded ~2.34ms the accumulator
//       refilled faster than it drained and the loop pinned at the cap forever.
//
//  The two interact: (1) sets the per-tick cost `c`, and `c` decides whether (2)
//  collapses. So this probe measures `c` and prints the speed at which the drain
//  budget (`Simulation.maxDrainMs`) starts to bite.
//
//  This is a MEASUREMENT tool, not a pass/fail gate — absolute milliseconds are
//  machine-specific. It asserts only the two things that must hold on any machine:
//  that cost grows sub-quadratically with the route×fleet product, and that a
//  fleet with idle spares and fully-staffed routes is not dramatically more
//  expensive than the same fleet with none (which is what the old scan did).
//
//  Compile like the other harnesses; rename to main.swift.
//
import Foundation

@MainActor
func main() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }

    /// Median of `runs` timed batches of `batch` ticks, in ms per tick.
    func tickCost(_ sim: Simulation, batch: Int = 400, runs: Int = 7) -> Double {
        var samples: [Double] = []
        for _ in 0..<runs {
            let t0 = ContinuousClock.now
            for _ in 0..<batch { sim.advanceTick() }
            let dt = ContinuousClock.now - t0
            let ms = Double(dt.components.seconds) * 1000
                   + Double(dt.components.attoseconds) / 1e15
            samples.append(ms / Double(batch))
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    /// Build an airline of `n` routes out of DEN, plus `spares` idle aircraft.
    /// Every route is STAFFED — the common late-game case, and the one the old
    /// O(routes × fleet) scan walked in full on every tick for nothing.
    func build(routes n: Int, spares: Int, typeId: String = "A320") -> Simulation? {
        let sim = Simulation(); sim.configure(viewport: CGSize(width: 400, height: 800))
        sim.nameAirline("Perf Air", tailCode: "PF"); sim.devInjectCash(500_000_000_000)
        guard let type = AircraftType.all.first(where: { $0.id == typeId }) else { return nil }
        // MULTI-ORIGIN on purpose. A single hub runs out of SLOTS around ~113
        // routes, so a one-hub build cannot reach the network size at which the
        // O(routes × fleet) term actually dominates. Spread across the busiest
        // airports, which is also what a real late-game network looks like.
        let maxNM = Double(type.rangeNM) * 0.8
        let hubs = sim.airports
            .sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
            .prefix(24)
        var opened = 0
        var used = Set<String>()                       // one route per unordered pair
        outer: for o in hubs {
            let dests = sim.airports.filter {
                $0.code != o.code && o.greatCircleNM(to: $0) < maxNM && o.greatCircleNM(to: $0) > 250
            }.sorted { o.greatCircleNM(to: $0) < o.greatCircleNM(to: $1) }
            for d in dests {
                if opened >= n { break outer }
                let key = [o.code, d.code].sorted().joined(separator: "-")
                if used.contains(key) { continue }
                guard let ac = sim.buyAircraft(type) else { return nil }
                if case .success = sim.openRoute(from: o, to: d, using: ac) {
                    opened += 1; used.insert(key)
                }
            }
        }
        guard opened == n else { print("  (only opened \(opened)/\(n) routes)"); return nil }
        // Crew it so aircraft actually fly rather than sitting in rest holds.
        let target = Int(Double(opened) * 2.1)
        while sim.crewCount(family: type.family) < target {
            guard sim.hireCrew(family: type.family, mode: .rated) != nil else { break }
        }
        for _ in 0..<spares { _ = sim.buyAircraft(type) }   // idle: never routed
        // Settle in, and drain the queue so blocked aircraft don't skew the cost.
        for _ in 0..<2_000 {
            sim.advanceTick()
            for d in sim.decisionQueue {
                switch d.kind {
                case .crew: sim.resolveCrewWait(d)
                case .aog:  sim.resolveAOGStandard(d)
                default:    break
                }
            }
        }
        return sim
    }

    print("TICK COST — main-thread ms per advanceTick()")
    print("drain budget \(Simulation.maxDrainMs)ms/wake · speeds \(Simulation.speedOptions.map { String(format: "%g", $0) }.joined(separator: "/"))")
    print(String(repeating: "-", count: 92))
    print(String(format: "%8@ %8@ %8@ | %10@ | %@", "routes", "fleet", "spares", "ms/tick", "at what speed does the drain budget bite"))

    struct Row { let routes: Int; let fleet: Int; let spares: Int; let cost: Double }
    var rows: [Row] = []
    // The last two arms use a WIDEBODY on purpose: the O(routes × fleet) term only
    // dominates on a big network, and DEN has nowhere near 250 destinations inside
    // an A320's range. A 787 opens the whole map, which is the scale at which the
    // original scan was measured at ~55% of the tick.
    let arms: [(Int, Int, String)] = [
        (20, 0, "A320"), (20, 8, "A320"),
        (60, 0, "A320"), (60, 20, "A320"),
        (120, 0, "A320"), (120, 40, "A320"),
        (250, 0, "B788"), (250, 80, "B788"),
    ]
    for (n, spares, typeId) in arms {
        guard let sim = build(routes: n, spares: spares, typeId: typeId) else { continue }
        let c = tickCost(sim)
        rows.append(Row(routes: n, fleet: sim.aircraft.count, spares: spares, cost: c))
        // The drain runs until it exceeds maxDrainMs; the interesting number is the
        // speed at which one wake's worth of ticks costs more than the budget.
        // ticks per wake at speed s ≈ 8ms / (baseTickMs / s)
        var bites = "never (all speeds fit)"
        for s in Simulation.speedOptions {
            let interval = Simulation.baseTickMs / s
            let ticksPerWake = 8.0 / interval
            if ticksPerWake * c > Simulation.maxDrainMs { bites = String(format: "%g×", s); break }
        }
        print(String(format: "%8d %8d %8d | %10.4f | %@", n, sim.aircraft.count, spares, c, bites))
    }
    print(String(repeating: "-", count: 92))

    // 1. Sub-quadratic growth. The old scan made cost track routes×fleet; with the
    //    set rewrite the per-tick work is dominated by the per-aircraft advance,
    //    so a 6× bigger product must NOT cost 6× more per tick.
    if let small = rows.first(where: { $0.routes == 20 && $0.spares == 0 }),
       let big = rows.last(where: { $0.spares == 0 }) {
        let productRatio = Double(big.routes * big.fleet) / Double(small.routes * small.fleet)
        let costRatio = big.cost / small.cost
        print(String(format: "growth: route×fleet product ×%.1f → cost ×%.1f", productRatio, costRatio))
        check(costRatio < productRatio,
              "per-tick cost grows SLOWER than the routes×fleet product (the O(routes×fleet) scan is gone)")
    }

    // 2. THE REGRESSION GUARD FOR THE ACTUAL BUG. Holding idle spares while every
    //    route is staffed used to flip on a full O(routes × fleet) scan every tick.
    //    With the corrected guard (nothing pending → return) it must be ~free.
    for n in [20, 60, 120, 250] {
        guard let none = rows.first(where: { $0.routes == n && $0.spares == 0 }),
              let some = rows.first(where: { $0.routes == n && $0.spares > 0 }) else { continue }
        // Spares add real per-aircraft work of their own, so allow headroom; the
        // old behaviour was a large multiple, not a few percent.
        let ratio = some.cost / none.cost
        print(String(format: "spares@%d routes: %.4f → %.4f ms (×%.2f)", n, none.cost, some.cost, ratio))
        check(ratio < 1.8, "idle spares at \(n) routes don't re-enable a full per-tick scan")
    }

    print("\nTickCostProbe: \(pass)/\(pass + fail) passed" + (fail == 0 ? "  ✅" : "  ❌ \(fail) FAILED"))
}
MainActor.assumeIsolated { main() }
