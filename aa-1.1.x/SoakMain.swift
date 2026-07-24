import Foundation

// ============================================================================
// SoakMain — the "played end-to-end" soak harness.
//
// Every OTHER harness in aa-1.1.x verifies ONE system in isolation. This one
// drives a SINGLE Simulation through a long, multi-year game with randomised-
// but-plausible player behaviour — buying across the whole fleet, opening and
// closing routes, hiring crew across families, taking and repaying loans,
// weathering economic events, establishing hubs, going public and pulling its
// levers, and draining the decision queue as cards arrive — while asserting a
// battery of cross-system INVARIANTS on every check. The point is to surface
// bugs that only emerge from systems INTERACTING over a long horizon, which the
// isolated unit harnesses structurally cannot.
//
// It targets the class of bug CLAUDE.md's "never played end-to-end" concern is
// about — the six that shipped THROUGH passing verification:
//   • operatingCost / any untracked cash flow  → INV: cash residual == 0
//   • lease-proration (leasing dominant)        → INV: cash residual + fleet sanity
//   • phantom-crew-family                       → INV: crewId resolves in its family pool
//   • ownership-scoping (bg traffic → decisions)→ INV: every decision aircraft is purchased
//   • crew duty/rest reset (flies forever)      → INV: a lone busy crew must eventually rest
//   • decision-panel/dropdown/buy-panel FLICKER → NOT CATCHABLE HERE (pure UI re-render).
//     Honestly out of reach of a headless soak; it needs the simulator + eyes.
//
// Determinism: the ACTION stream is seeded (SplitMix64) so a given seed replays
// the same playthrough shape and a failure is reproducible from its seed. The
// sim's OWN internal rolls (AOG/revenue/events) may not be seeded, so the exact
// tick of a violation can shift on rerun — but the invariant CLASS reproduces,
// and every failure prints seed + tick + a rich state dump to investigate from.
//
// Run (from the repo root):
//   cd AirlineArchitect/AirlineArchitect
//   cp ../../aa-1.1.x/SoakMain.swift /tmp/main.swift
//   swiftc -O -DDEBUG \
//     $(ls Sim/*.swift | grep -vE 'AircraftIcon.swift|SVGPath.swift') \
//     Persistence.swift /tmp/main.swift -o /tmp/soak
//   /tmp/soak              # defaults: 6 seeds × 2 sim-years
//   /tmp/soak 12 3         # 12 seeds × 3 sim-years
// ============================================================================

// MARK: - Deterministic RNG (so a failing seed reproduces its playthrough)

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// A curated pool of real airport codes spanning regions, so route attempts land
// on real geography (out-of-range / short-runway attempts just no-op, which is
// itself fine to exercise — a failed open must move no cash).
let AIRPORT_POOL = [
    "JFK","LAX","ORD","DEN","SFO","SEA","ATL","BOS","MIA","DFW","LAS","PHX",
    "LHR","CDG","FRA","AMS","MAD","LGW",
    "NRT","HND","SIN","HKG","SYD","MEL","YYZ","YVR","GRU","MEX","DXB","JNB",
]

// ---------------------------------------------------------------------------

@MainActor
final class SoakRunner {
    let seed: UInt64
    let simDays: Int
    var rng: SplitMix64
    let sim = Simulation()

    // Findings for this seed.
    var violations: [String] = []
    var actionsTaken = 0
    // Liveness signal for the crew duty/rest system (the "flies forever" bug is
    // duty NOT accumulating). We track the peak duty seen and whether any crew
    // ever reached the rest cycle; a busy seed where duty never climbs would be
    // the regression. Reported, not hard-failed (a low-activity seed legitimately
    // may not stress a crew to the cap).
    var peakDutyTicks = 0
    var sawCrewReachCap = false
    // A short rolling log of the last few actions, dumped on the first violation
    // so a failure comes with the context that produced it.
    var recentActions: [String] = []

    init(seed: UInt64, simDays: Int) {
        self.seed = seed
        self.simDays = simDays
        self.rng = SplitMix64(seed: seed)
    }

    func logAction(_ s: String) {
        actionsTaken += 1
        recentActions.append("t=\(sim.tick) \(s)")
        if recentActions.count > 12 { recentActions.removeFirst() }
    }

    // MARK: Setup

    func setup() {
        sim.configure(viewport: CGSize(width: 400, height: 800))
        let regions = Airline.PlayerRegion.allCases
        let region = regions.randomElement(using: &rng) ?? .northAmerica
        sim.setHomeRegion(region)
        sim.nameAirline("Soak \(seed)", tailCode: "SK")
        // A generous bank so the soak reaches the MID/LATE game (hubs, IPO,
        // large fleet) instead of dying at turn one — the interactions we want
        // to stress live there. Injection is TRACKED, so the residual stays 0.
        sim.devInjectCash(2_000_000_000)
    }

    // MARK: The action menu — each is guarded so an unmet precondition no-ops.

    func buySomeAircraft() {
        guard let type = AircraftType.all.randomElement(using: &rng) else { return }
        // Occasionally lease instead of buy, to exercise the lease path (the
        // lease-proration bug lived here).
        if Bool.random(using: &rng), sim.leaseAircraft(type) != nil {
            logAction("lease \(type.id)")
        } else if sim.buyAircraft(type) != nil {
            logAction("buy \(type.id)")
        }
    }

    func buyUsed() {
        let listings = sim.usedListings
        guard let listing = listings.randomElement(using: &rng) else { return }
        if sim.buyUsedAircraft(listing) != nil { logAction("buyUsed \(listing.typeId)") }
    }

    func openARoute() {
        // Need an idle spare to fly it.
        guard let spare = sim.aircraft.first(where: { $0.isIdleSpare }) else { return }
        guard let oc = AIRPORT_POOL.randomElement(using: &rng),
              let dc = AIRPORT_POOL.randomElement(using: &rng), oc != dc,
              let o = sim.airport(oc), let d = sim.airport(dc) else { return }
        if case .success = sim.openRoute(from: o, to: d, using: spare) {
            logAction("openRoute \(oc)-\(dc)")
        }
    }

    func closeARoute() {
        // Closing under activist pressure is the only public close path; the
        // player's own teardown is via the slot-offer card. Sell an on-route
        // aircraft's route indirectly by selling a spare instead (safe close is
        // exercised via decision cards). Here: sell an idle spare to churn fleet.
        guard let spare = sim.aircraft.first(where: { $0.isIdleSpare && !$0.isLeased }) else { return }
        sim.sellAircraft(spare)
        logAction("sell spare \(spare.type.id)")
    }

    func hireSomeCrew() {
        guard let fam = sim.ownedFamilies.randomElement(using: &rng) else { return }
        if sim.hireCrew(family: fam) != nil { logAction("hireCrew \(fam)") }
    }

    func manageLoans() {
        // Repay a random loan sometimes; otherwise take one.
        if !sim.loans.isEmpty, Bool.random(using: &rng) {
            let loan = sim.loans.randomElement(using: &rng)!
            if sim.payOffLoan(loan.id) { logAction("payOffLoan \(loan.id)") }
        } else if let offer = LoanOffer.all.randomElement(using: &rng) {
            if sim.takeLoan(offer) { logAction("takeLoan") }
        }
    }

    func tryHub() {
        // Establish a hub at a code the player already touches with routes; the
        // sim gates it on route count, so an ineligible attempt just no-ops.
        guard let code = AIRPORT_POOL.randomElement(using: &rng) else { return }
        if sim.establishHub(at: code) {
            logAction("establishHub \(code)")
            if Bool.random(using: &rng), sim.buildClub(at: code) { logAction("buildClub \(code)") }
        }
    }

    func tryGoPublicAndLevers() {
        if sim.publicCompany == nil {
            if sim.canGoPublic {
                let float = [0.15, 0.25, 0.35].randomElement(using: &rng)!
                if sim.goPublic(ticker: "SOAK", floatFraction: float) { logAction("goPublic \(float)") }
            }
            return
        }
        // Already public — pull a random lever.
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: if sim.payDividend(yield: 0.05) { logAction("dividend") }
        case 1: if sim.buyBackShares(floatFraction: 0.10) { logAction("buyback") }
        default: if sim.secondaryOffering(fraction: 0.05) { logAction("secondary") }
        }
    }

    /// Drain the decision queue with a randomised but always-valid response, so
    /// cards don't pile up and every resolver path gets exercised.
    func drainDecisions() {
        for dec in Array(sim.decisionQueue) {
            let coin = Bool.random(using: &rng)
            switch dec.kind {
            case .aog:         coin ? sim.resolveAOGExpedite(dec) : sim.resolveAOGStandard(dec)
            case .crew:        coin ? sim.resolveCrewHire(dec) : sim.resolveCrewWait(dec)
            case .sell:        sim.resolveSellKeep(dec)          // keep — churn is via explicit sell
            case .offer:       coin ? sim.resolveOfferAccept(dec) : sim.resolveOfferDecline(dec)
            case .training:    coin ? sim.resolveTrainingNow(dec) : sim.resolveTrainingDefer(dec)
            case .airportOffer: coin ? sim.resolveAirportOfferAccept(dec) : sim.resolveAirportOfferDecline(dec)
            case .hubOffer:    sim.resolveHubSale(dec, accept: coin)
            case .activist:    coin ? sim.resolveActivistComply(dec) : sim.resolveActivistRefuse(dec)
            }
        }
    }

    // A soft fleet cap keeps the soak in a REALISTIC, bounded regime: past the
    // cap, buy-actions flip to sell-actions. Without it the buy-heavy mix balloons
    // to 400+ aircraft over multi-year runs, which is both unrealistic and makes
    // each tick (which advances every aircraft) pathologically slow. The cap is
    // high enough to still stress a large network.
    static let fleetCap = 60

    func takeRandomAction() {
        let overCap = sim.ownedCount >= SoakRunner.fleetCap
        switch Int.random(in: 0..<9, using: &rng) {
        case 0, 1: overCap ? closeARoute() : buySomeAircraft()   // fleet growth vs. churn
        case 2:    overCap ? closeARoute() : buyUsed()
        case 3, 4: openARoute()
        case 5:    closeARoute()
        case 6:    hireSomeCrew()
        case 7:    manageLoans()
        default:
            // Rarer strategic moves.
            switch Int.random(in: 0..<3, using: &rng) {
            case 0: tryHub()
            default: tryGoPublicAndLevers()
            }
        }
    }

    // MARK: Invariants — the actual value of the soak.

    /// Record a violation ONCE per seed (first is the most diagnosable), with a
    /// full state dump + the recent-action tail.
    func fail(_ what: String) {
        guard violations.isEmpty else { violations.append("[t=\(sim.tick)] \(what)"); return }
        violations.append("[t=\(sim.tick)] \(what)")
    }

    func checkInvariants() {
        // 1. THE MASTER: cash reconciles. Catches operatingCost, lease-proration,
        //    and any untracked cash flow. devInjectCash is a tracked term, so 0.
        let residual = sim.cashInvariantResidual()
        if residual != 0 { fail("CASH INVARIANT residual=\(residual) (bal=\(sim.playerBalance))") }

        // 2. tick monotonic + reputation / board pressure in range.
        if sim.reputation < 0 || sim.reputation > 100 { fail("reputation out of [0,100]: \(sim.reputation)") }
        if sim.boardPressure < 0 || sim.boardPressure > 1 { fail("boardPressure out of [0,1]: \(sim.boardPressure)") }

        // 3. ownedCount matches the purchased set.
        let purchased = sim.aircraft.filter { $0.purchased }
        if sim.ownedCount != purchased.count { fail("ownedCount \(sim.ownedCount) != purchased \(purchased.count)") }

        // 4. CREW INTEGRITY (phantom-crew-family): every assigned crewId must
        //    resolve to a real crew in THAT aircraft's family pool, and no crew
        //    may be assigned to two aircraft at once. crewId is minted per-family
        //    (hireCrew: id = pool.count), so id 0 exists in EVERY family and the
        //    real code always looks a crew up scoped to the aircraft's family —
        //    the double-booking key must therefore be (family, id), not id alone.
        var seenCrew: [String: String] = [:]   // "family#id" -> aircraft desc
        for ac in purchased {
            guard let cid = ac.crewId else { continue }
            let fam = ac.type.family
            let pool = sim.crewPoolsByFamily[fam] ?? []
            if !pool.contains(where: { $0.id == cid }) {
                fail("PHANTOM CREW: \(ac.type.id) (fam \(fam)) holds crewId \(cid) absent from its pool")
            }
            let key = "\(fam)#\(cid)"
            if let other = seenCrew[key] {
                fail("CREW DOUBLE-BOOKED: \(fam) crew \(cid) on both \(other) and \(ac.type.id)")
            }
            seenCrew[key] = ac.type.id
        }

        // 5. DUTY/REST bounds. dutyTicks does NOT hard-cap at maxDutyTicks: the
        //    cap-and-rest check runs in releaseCrew at the END of a flight span
        //    (a crew can't leave mid-flight — realistic Part 117), so duty
        //    legitimately overshoots the cap by the remainder of the in-progress
        //    span. The upper bound here is therefore GENEROUS — it only trips on
        //    genuine RUNAWAY (duty never resetting), which is the "flies forever"
        //    bug. A single continuous span can't exceed the longest flight (well
        //    under a sim-day), so maxDutyTicks + 2 sim-days is a safe ceiling.
        let dutyCeiling = Crew.maxDutyTicks + 2 * 1440
        for (fam, pool) in sim.crewPoolsByFamily {
            for c in pool {
                peakDutyTicks = max(peakDutyTicks, c.dutyTicks)
                if c.dutyTicks >= Crew.maxDutyTicks || c.status == .resting { sawCrewReachCap = true }
                if c.dutyTicks < 0 || c.dutyTicks > dutyCeiling {
                    fail("CREW DUTY RUNAWAY: fam \(fam) crew \(c.id) dutyTicks=\(c.dutyTicks) (ceiling \(dutyCeiling))")
                }
                if c.restTicksLeft < 0 || c.restTicksLeft > Crew.restTicks {
                    fail("CREW REST out of range: fam \(fam) crew \(c.id) restTicksLeft=\(c.restTicksLeft)")
                }
            }
        }

        // 6. OWNERSHIP SCOPING (bg traffic → real decisions): every decision that
        //    names an aircraft must name a PURCHASED one.
        for dec in sim.decisionQueue {
            if let ac = dec.aircraft, !ac.purchased {
                fail("UNOWNED-AIRCRAFT DECISION: \(dec.kind) card references a non-purchased \(ac.type.id)")
            }
        }

        // 7. ROUTE/FLEET consistency: every purchased aircraft's assignedRouteId
        //    must reference an OPEN player route.
        let openRouteIds = Set(sim.playerRoutes.map { $0.id })
        for ac in purchased {
            if let rid = ac.assignedRouteId, !openRouteIds.contains(rid) {
                fail("DANGLING ROUTE REF: \(ac.type.id) assignedRouteId \(rid) not in open routes")
            }
        }
    }

    // MARK: The run

    func run() {
        setup()
        let totalTicks = simDays * 1440
        for t in 0..<totalTicks {
            sim.advanceTick()
            if sim.isBankrupt { break }                 // a legit game-over ends this seed cleanly
            if t % 720 == 0 { drainDecisions() }        // twice a sim-day
            if t % 500 == 0 { takeRandomAction() }      // ~3 actions/sim-day
            if t % 240 == 0 { checkInvariants() }       // 6×/sim-day
            if !violations.isEmpty { break }            // stop at the first (most diagnosable) failure
        }
        // Final sweep + a save/load round-trip: the whole soaked state must
        // survive the real persistence path, and the restored sim must keep its
        // invariants (offset by the un-persisted injection, exactly).
        checkInvariants()
        roundTripCheck()
    }

    func roundTripCheck() {
        let snap = sim.snapshot()
        guard let data = try? JSONEncoder().encode(snap),
              let decoded = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
            fail("SNAPSHOT round-trip failed to encode/decode"); return
        }
        let restored = Simulation()
        restored.configure(viewport: CGSize(width: 400, height: 800))
        restored.restore(from: decoded)
        if restored.playerBalance != sim.playerBalance { fail("restore balance drift \(restored.playerBalance) != \(sim.playerBalance)") }
        if restored.ownedCount != sim.ownedCount { fail("restore fleet drift \(restored.ownedCount) != \(sim.ownedCount)") }
        if restored.playerRoutes.count != sim.playerRoutes.count { fail("restore routes drift") }
        // The restored residual is exactly minus the un-persisted dev injection
        // (proves an EXACT balance restore, per the RoundTrip harness lesson).
        if restored.cashInvariantResidual() != -2_000_000_000 {
            fail("restore residual != -(injection): \(restored.cashInvariantResidual())")
        }
    }

    func report() -> Bool {
        let ok = violations.isEmpty
        let tag = ok ? "PASS" : "FAIL"
        print("  seed \(seed): \(tag) — \(actionsTaken) actions, \(sim.tick) ticks, "
              + "fleet \(sim.ownedCount), routes \(sim.playerRoutes.count), "
              + "netWorth \(compact(sim.netWorth)), peakDuty \(peakDutyTicks)\(sawCrewReachCap ? "✓rest" : "")"
              + "\(sim.isBankrupt ? ", BANKRUPT" : "")\(sim.publicCompany != nil ? ", PUBLIC" : "")")
        if !ok {
            for v in violations.prefix(5) { print("      ✗ \(v)") }
            print("      recent actions: \(recentActions.joined(separator: " | "))")
        }
        return ok
    }

    func compact(_ v: Int) -> String {
        v >= 1_000_000_000 ? String(format: "$%.2fB", Double(v)/1e9)
        : v >= 1_000_000 ? String(format: "$%.0fM", Double(v)/1e6) : "$\(v)"
    }
}

// MARK: - Driver

@MainActor
func main() {
    setbuf(stdout, nil)   // unbuffered, so per-seed lines appear live when piped to a file
    let args = CommandLine.arguments
    let seeds = args.count > 1 ? Int(args[1]) ?? 6 : 6
    let simDays = args.count > 2 ? (Int(args[2]) ?? 2) * 365 : 2 * 365

    print("SOAK — \(seeds) seeds × \(simDays / 365) sim-years (\(simDays) sim-days each)")
    print(String(repeating: "-", count: 60))

    var passed = 0
    let start = Date()
    for s in 0..<seeds {
        let runner = SoakRunner(seed: UInt64(s) &* 0x100000001B3 &+ 0xCBF29CE484222325, simDays: simDays)
        runner.run()
        if runner.report() { passed += 1 }
    }
    let secs = Date().timeIntervalSince(start)
    print(String(repeating: "-", count: 60))
    print("\(passed)/\(seeds) seeds clean — \(String(format: "%.1f", secs))s"
          + (passed == seeds ? " — ALL GREEN" : " — \(seeds - passed) with violations"))
    print("NOTE: the panel/flicker class of bug is a UI re-render and is NOT covered here — needs the simulator + eyes.")
}

MainActor.assumeIsolated { main() }
