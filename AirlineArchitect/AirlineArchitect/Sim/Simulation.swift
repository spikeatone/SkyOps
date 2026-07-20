//
//  Simulation.swift
//  Airline Architect — Phase 1–2
//
//  Owns the world (airports + aircraft) and the tick clock. The tick loop is a
//  Swift-Concurrency async task, decoupled from the render frame rate exactly
//  like the prototype's requestAnimationFrame accumulator: 1 tick = BASE_TICK_MS
//  of real time at 1× speed, divided by the speed multiplier, capped at 50
//  catch-up ticks per wake so a stall can't spiral. The view re-renders on each
//  tick (MapView takes `tick` as a value input) and reads current positions.
//

import Foundation
import Observation
import CoreGraphics

@MainActor
@Observable
final class Simulation {

    /// Real-time milliseconds per tick at 1× speed (prototype BASE_TICK_MS).
    static let baseTickMs: Double = 250

    private(set) var tick: Int = 0
    /// Throttled UI heartbeat: mirrors `tick` but only advances a few times a
    /// second regardless of sim speed. List/HUD views (Ops/Fleet/Finance/Crews)
    /// observe THIS instead of `tick`, so scrolling a long list doesn't fight a
    /// per-frame full-body re-eval when the sim is running at 10×/25×. The map
    /// keeps reading `tick` for smooth per-tick aircraft motion.
    private(set) var displayTick: Int = 0
    private(set) var airports: [Airport] = []
    private(set) var aircraft: [Aircraft] = []

    /// Prototype: passenger-demand model (load factor = route demand vs. aircraft
    /// capacity). ON by default; a DEV toggle can flip it OFF to A/B against the
    /// old flat-load-factor economy. See `Demand` in Economics.swift.
    var useDemandModel = true

    /// The most recently opened route (endpoint codes + the tick it opened) —
    /// drives a brief expanding-ring "ripple" on the map at both airports.
    struct RoutePulse { let a: String; let b: String; let tick: Int }
    private(set) var routeOpenPulse: RoutePulse?

    /// Network / hub effect: a route through an airport where you already run
    /// OTHER routes carries connecting passengers, boosting its demand. Each other
    /// player route touching an endpoint adds `hubBonusRate`; capped. So a coherent
    /// hub-and-spoke network beats scattered point-to-point — building up a hub
    /// lifts every route through it.
    static let hubBonusRate = 0.08
    static let hubBonusCap = 0.80

    /// Demand multiplier from the hub effect for a city pair. `excludingRouteId`
    /// omits a route's own id when it's already open (so it doesn't count itself).
    func hubDemandMultiplier(originCode: String, destCode: String, excludingRouteId: Int? = nil) -> Double {
        func others(_ code: String) -> Int {
            playerRoutes.filter { ($0.originCode == code || $0.destCode == code) && $0.id != excludingRouteId }.count
        }
        // A declared, OPERATING hub amplifies the per-spoke connection bonus at
        // its endpoint (8% → 12%); the +80% cap deliberately does NOT rise
        // (anti-money-printer, see HUBS_AND_CLUBS_SPEC.md).
        func bonus(_ code: String) -> Double {
            (hubOperating(code) ? Simulation.hubBonusRateHub : Simulation.hubBonusRate) * Double(others(code))
        }
        return 1 + min(Simulation.hubBonusCap, bonus(originCode) + bonus(destCode))
    }
    /// The hub bonus a PROSPECTIVE new route would get, as a whole percent (UI).
    func hubBonusPercent(originCode: String, destCode: String) -> Int {
        Int(((hubDemandMultiplier(originCode: originCode, destCode: destCode) - 1) * 100).rounded())
    }

    /// Convenience for the UI: this route's estimated daily one-way demand (incl.
    /// the hub bonus), and the load factor a given aircraft would fly it at.
    func routeDailyDemand(_ a: Airport, _ b: Airport) -> Int {
        Int((Demand.dailyOneWay(a, b) * hubDemandMultiplier(originCode: a.code, destCode: b.code)).rounded())
    }
    func projectedLoadFactor(seats: Int, from a: Airport, to b: Airport) -> Double {
        Demand.loadFactor(seats: seats, dailyOneWay: Demand.dailyOneWay(a, b) * hubDemandMultiplier(originCode: a.code, destCode: b.code))
    }

    // MARK: - Route opportunities (the Ops "underserved markets" finder)

    /// A high-demand city pair the player does NOT currently serve. In this sim
    /// the demand model is the truth of profitability (no competitor saturation
    /// modeled), so highest-demand-unserved == best opportunity.
    struct RouteOpportunity: Identifiable {
        let id: String
        let originCode, destCode, originCity, destCity: String
        let demandPerDay, distanceNM: Int
        let suggested: String
    }

    private func pairKey(_ a: String, _ b: String) -> String { a < b ? "\(a)|\(b)" : "\(b)|\(a)" }
    private func suggestedClass(demand: Int, distanceNM: Int = 0) -> String {
        // Demand sizes the tier; distance can only bump it UP — a suggested class
        // must actually be able to FLY the route (a playtest shot showed EWR↔Hilo
        // at 4,235nm tagged "Regional jet", which nothing in that tier can fly).
        let byDemand: String
        switch demand { case ..<180: byDemand = "Regional jet"; case ..<560: byDemand = "Narrowbody"; default: byDemand = "Widebody" }
        if byDemand == "Regional jet", distanceNM > Self.tierMaxRange["Regional jet", default: .max] {
            return distanceNM > Self.tierMaxRange["Narrowbody", default: .max] ? "Widebody" : "Narrowbody"
        }
        if byDemand == "Narrowbody", distanceNM > Self.tierMaxRange["Narrowbody", default: .max] { return "Widebody" }
        return byDemand
    }
    /// Longest range available in each suggestion tier, from the real fleet data.
    private static let tierMaxRange: [String: Int] = {
        func maxRange(_ types: [BodyType]) -> Int {
            AircraftType.all.filter { types.contains($0.bodyType) }.map(\.rangeNM).max() ?? .max
        }
        return ["Regional jet": maxRange([.regionalJet]),
                "Narrowbody": maxRange([.narrowbody]),
                "Widebody": maxRange([.widebody2Engine, .widebody4Engine])]
    }()

    /// Top unserved city pairs, within the player's home region (CONUS). Returns
    /// a SPREAD across fleet tiers (top `perClass` regional / narrowbody /
    /// widebody markets) rather than a raw demand ranking — otherwise the list is
    /// always the same handful of mega-hub widebody pairs a starting player can't
    /// touch. The regional tier naturally surfaces smaller, off-radar airports.
    /// Candidates are all CONUS airports with info; already-flown pairs excluded.
    func topRouteOpportunities(perClass: Int = 2) -> [RouteOpportunity] {
        let cands = homeAirports.filter { $0.info != nil }
        let served = Set(playerRoutes.map { pairKey($0.originCode, $0.destCode) })
        var all: [RouteOpportunity] = []
        for i in 0..<cands.count {
            for j in (i + 1)..<cands.count {
                let a = cands[i], b = cands[j]
                if served.contains(pairKey(a.code, b.code)) { continue }
                let demand = routeDailyDemand(a, b)
                let nm = Int(a.greatCircleNM(to: b).rounded())
                all.append(RouteOpportunity(
                    id: "\(a.code)-\(b.code)", originCode: a.code, destCode: b.code,
                    originCity: a.info?.city ?? a.code, destCity: b.info?.city ?? b.code,
                    demandPerDay: demand, distanceNM: nm,
                    suggested: suggestedClass(demand: demand, distanceNM: nm)))
            }
        }
        // A few of each tier, actionable-first (regional → narrowbody → widebody).
        // SAMPLED from each tier's top pool rather than always the absolute best —
        // the demand model is static, so a deterministic top-2 showed the exact
        // same markets in every new game (designer-reported). Every pick is still
        // a genuinely strong market; games just stop looking identical.
        var out: [RouteOpportunity] = []
        for tier in ["Regional jet", "Narrowbody", "Widebody"] {
            let pool = all.filter { $0.suggested == tier }
                .sorted { $0.demandPerDay > $1.demandPerDay }
                .prefix(8)
            out += pool.shuffled().prefix(perClass)
                .sorted { $0.demandPerDay > $1.demandPerDay }
        }
        return out
    }

    // MARK: - Reputation (service quality → demand)

    /// Airline service-quality reputation, 0–100. Falls when the operation fails
    /// passengers (an aircraft grounded, a flight held for want of crew) and
    /// recovers slowly through flights completed cleanly. Feeds back into demand,
    /// and helps the airline defend market share against competitors.
    private(set) var reputation: Double = Simulation.reputationStart
    static let reputationStart = 70.0
    private static let repHitAOG = 4.0
    private static let repHitCrew = 2.0
    private static let repRecoverPerFlight = 0.15

    /// Demand multiplier from reputation: 0.85 (rep 0) · 1.0 (rep 50) · 1.15 (rep 100).
    var reputationDemandMultiplier: Double { 0.85 + 0.30 * (reputation / 100) }
    /// Signed passenger-demand impact for the Ops box.
    var reputationDemandPercent: Int { Int(((reputationDemandMultiplier - 1) * 100).rounded()) }
    /// Reputation tier label (for the Ops box).
    var reputationTier: String {
        switch reputation {
        case ..<40: return "Poor"
        case ..<60: return "Fair"
        case ..<80: return "Good"
        default:    return "Excellent"
        }
    }

    /// Clubs raise the reputation FLOOR (loyal flyers forgive) — they never ADD
    /// points, so ops stay the only thing that moves the score up. 40 + 5/club,
    /// capped at 60. No clubs = no floor.
    var reputationFloor: Double {
        let clubs = operatingClubCount
        return clubs > 0 ? min(60, 40 + 5 * Double(clubs)) : 0
    }
    private func dingReputation(_ amount: Double) { reputation = max(reputationFloor, reputation - amount) }
    private func recoverReputation(_ amount: Double) { reputation = min(100, reputation + amount) }

    // MARK: - Hubs & Clubs (designer-reviewed spec: HUBS_AND_CLUBS_SPEC.md)

    struct Hub: Codable {
        var establishedTick: Int
        var hasClub = false
        var clubOpenedTick: Int? = nil
    }

    /// Player hubs by airport code. Status (operating vs UNDERSTAFFED) is
    /// COMPUTED from live route count — drop below 5 routes and benefits
    /// suspend while the labor bill keeps running (the overextension trap).
    private(set) var hubs: [String: Hub] = [:]
    /// Airports where the player SOLD a hub to a rival — permanent for the
    /// save: +50% competitor entry pressure there and the player can never
    /// re-hub it (the rival holds the gates). code → rival airline name.
    private(set) var rivalHubs: [String: String] = [:]
    private(set) var totalHubSpend = 0    // hub establishment + club build-out (capital-out)
    private(set) var totalHubLabor = 0    // hub ground-staff bills (overhead)
    private(set) var totalClubRent = 0    // club rent bills (overhead)
    private var nextHubBillTick = 0

    // All DESIGNED pacing (spec'd, tunable).
    static let hubMinRoutes = 5
    static let hubBonusRateHub = 0.15          // amplified per-spoke demand rate (base 0.08)
    static let hubGateFeeDiscount = 0.65       // −35% gate fees at the hub
    static let hubLandingFeeDiscount = 0.80    // −20% landing fees at the hub
    static let hubRepairTimeFactor = 0.75      // MX base: standard AOG repair 25% faster
    static let hubRepairCostFactor = 0.80      // MX base: repairs 20% cheaper
    static let hubCrewRestFactor = 0.80        // crew base: rest completes 20% faster
    static let hubFortressEntryFactor = 0.5    // fortress: −50% competitor entry on hub routes
    static let rivalHubEntryFactor = 1.5       // sold hub: +50% competitor entry there
    static let hubFareMultiplier = 1.03        // +3% yield on hub routes (connection revenue)
    static let clubFareMultiplier = 1.04       // +4% further yield at the club (premium loyalty)
    static let clubCompetitionShareFloor = 0.35 // loyal flyers don't defect (base floor 0.2)
    static let clubFFRFareHit = 0.02           // FFR surge bites +2%/club (redemption liability)
    static let hubOfferDailyProbHealthy = 0.015
    static let hubOfferDailyProbUnderstaffed = 0.08   // vultures circle a struggling hub
    static let hubSalePctHealthy = 0.60
    static let hubSalePctUnderstaffed = 0.35

    /// Player routes anchored at this airport (either endpoint).
    func routesAt(_ code: String) -> Int {
        playerRoutes.filter { $0.originCode == code || $0.destCode == code }.count
    }
    /// CREATE A HUB unlocks at 5 routes; a rival-held airport can never be re-hubbed.
    func hubEligible(_ code: String) -> Bool {
        hubs[code] == nil && rivalHubs[code] == nil && routesAt(code) >= Simulation.hubMinRoutes
    }
    func hubOperating(_ code: String) -> Bool {
        hubs[code] != nil && routesAt(code) >= Simulation.hubMinRoutes
    }
    func hubUnderstaffed(_ code: String) -> Bool {
        hubs[code] != nil && routesAt(code) < Simulation.hubMinRoutes
    }
    /// Club benefits require the hub to be OPERATING (suspend with it).
    func clubOperating(_ code: String) -> Bool {
        (hubs[code]?.hasClub ?? false) && hubOperating(code)
    }
    var operatingClubCount: Int { hubs.keys.filter { clubOperating($0) }.count }
    /// Auto-named per designer: "{Airline name} Club".
    var clubName: String { "\(playerAirlineName ?? "Airline") Club" }
    private func routeTouchesOperatingHub(_ a: String, _ b: String) -> Bool {
        hubOperating(a) || hubOperating(b)
    }

    // Costs — anchored to the airport's real size (annual passengers).
    // Costs retuned after the mandatory balance A/B (see HUBS_AND_CLUBS_SPEC.md
    // status): the original spec numbers made the hub a pure value-sink — on an
    // identical network, establishing one cost −41% net worth over 3 sim-years
    // (capital crowd-out compounds). The hub is identity infrastructure + the
    // club's prerequisite, priced accordingly; the club is the earner.
    func hubEstablishCost(_ ap: Airport) -> Int {
        let paxM = Double(ap.info?.annualPassengers ?? 1_000_000) / 1_000_000
        return min(8_000_000, max(2_000_000, Int((1_500_000 + 60_000 * paxM).rounded())))
    }
    func hubMonthlyLabor(_ code: String) -> Int { 25_000 + 8_000 * routesAt(code) }
    func clubBuildCost(_ ap: Airport) -> Int {
        let paxM = Double(ap.info?.annualPassengers ?? 1_000_000) / 1_000_000
        return min(5_000_000, Int((1_000_000 + 40_000 * paxM).rounded()))
    }
    func clubMonthlyRent(_ ap: Airport) -> Int {
        let paxM = Double(ap.info?.annualPassengers ?? 1_000_000) / 1_000_000
        return Int((20_000 + 800 * paxM).rounded())
    }

    @discardableResult
    func establishHub(at code: String) -> Bool {
        guard hubEligible(code), let ap = airport(code) else { return false }
        let cost = hubEstablishCost(ap)
        guard playerBalance >= cost else { return false }
        if hubs.isEmpty { nextHubBillTick = tick + Simulation.ticksPerMonth }
        playerBalance -= cost
        totalHubSpend += cost
        hubs[code] = Hub(establishedTick: tick)
        logOps(.structural, "Hub established at \(code)",
               "\(playerAirlineName ?? "Your airline") invested \(dollars(cost)) in a new hub", airportCode: code)
        return true
    }

    @discardableResult
    func buildClub(at code: String) -> Bool {
        guard var hub = hubs[code], !hub.hasClub, hubOperating(code), let ap = airport(code) else { return false }
        let cost = clubBuildCost(ap)
        guard playerBalance >= cost else { return false }
        playerBalance -= cost
        totalHubSpend += cost
        hub.hasClub = true
        hub.clubOpenedTick = tick
        hubs[code] = hub
        logOps(.structural, "\(clubName) opens at \(code)",
               "Premium lounge built for \(dollars(cost)) — loyalty starts here", airportCode: code)
        return true
    }

    /// Walking away recovers NOTHING (designer decision) — the only way to
    /// recoup a hub is a rival's buyout offer.
    func decommissionHub(at code: String) {
        guard hubs[code] != nil else { return }
        hubs[code] = nil
        logOps(.structural, "Hub decommissioned", "\(code) hub closed — the build-out is written off", airportCode: code)
    }

    /// Monthly hub labor + club rent, on the same recurring-billing cadence as
    /// insurance/leases. Bills even when UNDERSTAFFED (deliberate).
    private func tickHubBilling() {
        guard !hubs.isEmpty, tick >= nextHubBillTick else { return }
        nextHubBillTick = tick + Simulation.ticksPerMonth
        for (code, hub) in hubs {
            let labor = hubMonthlyLabor(code)
            playerBalance -= labor
            totalHubLabor += labor
            if hub.hasClub, let ap = airport(code) {
                let rent = clubMonthlyRent(ap)
                playerBalance -= rent
                totalClubRent += rent
            }
        }
    }

    /// A rival occasionally bids for a player hub (blue Offer card). Noticeably
    /// more often when the hub is UNDERSTAFFED — exactly when the cash tempts.
    private func tickHubOffers() {
        guard !hubs.isEmpty,
              !decisionQueue.contains(where: { $0.kind == .hubOffer }) else { return }
        for code in hubs.keys.shuffled() {
            let p = hubUnderstaffed(code) ? Simulation.hubOfferDailyProbUnderstaffed
                                          : Simulation.hubOfferDailyProbHealthy
            guard Double.random(in: 0..<1) < p, let ap = airport(code) else { continue }
            let pct = hubUnderstaffed(code) ? Simulation.hubSalePctUnderstaffed
                                            : Simulation.hubSalePctHealthy
            let price = Int((Double(hubEstablishCost(ap)) * pct).rounded())
            let rival = competitorName(excluding: [])
            decisionQueue.append(Decision(id: "hubOffer_\(code)_\(tick)", kind: .hubOffer, aircraft: nil,
                                          hubOffer: HubOffer(airportCode: code, rival: rival, price: price)))
            break
        }
    }

    /// Accepting arms the rival PERMANENTLY at that airport (+50% entry
    /// pressure, purple hub badge, no re-hubbing) and closes any club with it.
    func resolveHubSale(_ decision: Decision, accept: Bool) {
        defer { decisionQueue.removeAll { $0.id == decision.id } }
        guard accept, let offer = decision.hubOffer, hubs[offer.airportCode] != nil else {
            if let o = decision.hubOffer {
                logOps(.market, "Hub offer declined", "\(o.rival)'s bid for the \(o.airportCode) hub was turned down")
            }
            return
        }
        playerBalance += offer.price
        totalOfferIncome += offer.price
        hubs[offer.airportCode] = nil          // club (if any) closes with the sale
        rivalHubs[offer.airportCode] = offer.rival
        logOps(.structural, "Hub SOLD to \(offer.rival)",
               "\(offer.airportCode) is now a \(offer.rival) hub — \(dollars(offer.price)) banked, gates gone for good",
               airportCode: offer.airportCode)
    }

    private func dollars(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }

    // MARK: - Route competition (rival carriers reacting to the player)

    private static let competitionCap = 3
    private static let competitorEntryDailyProbability = 0.06   // per eligible route
    private static let competitorExitDailyProbability = 0.02
    private static let competitionMinRouteAgeDays = 8

    // MARK: Consolidation pressure
    //
    // ACQUISITIONS_SPEC.md's hardest guardrail: winning must NOT empty the map.
    // Acquiring a competitor removes it from every player route (demand recovers
    // — the reward), which HALVES rivals-on-routes. Left alone that quiets the
    // endgame exactly when it should intensify. So each completed acquisition
    // makes the SURVIVORS more aggressive: fewer players chasing the same
    // routes, a bigger prize each, and a market that reads the consolidation as
    // an invitation. This is the INVERSE of the Hubs & Clubs guardrail, which
    // wanted rivals halved as a success — here that same halving is the failure.

    /// Per-acquisition lift on the daily entry rate. Deliberately SMALL: the
    /// point is to keep rival DENSITY comparable, not to swarm the map. A first
    /// sizing of 0.5 overshot ~7× (16.7 → 114 rivals) — because an acquired
    /// network multiplies the ROUTE count too, and the entry rate is per-route,
    /// so a modest per-route lift compounds hard across a big inherited network.
    /// 0.12 keeps per-route entry roughly flat while nudging survivors up.
    private static let consolidationEntryPerAcquisition = 0.12
    /// Per-acquisition lift on how many rivals a single route can hold — a
    /// consolidated market supports incumbents stacking one deeper, capped so it
    /// can't run away.
    private static let consolidationCapPerAcquisition = 1
    private static let consolidationCapMax = 5
    /// Per-acquisition damping on the exit rate — survivors have more to gain, so
    /// they dig in rather than churning out (floored so they never become
    /// permanent).
    private static let consolidationStickiness = 0.15

    var consolidationEntryMultiplier: Double {
        1.0 + Double(subsidiaries.count) * Simulation.consolidationEntryPerAcquisition
    }
    var effectiveCompetitionCap: Int {
        min(Simulation.consolidationCapMax,
            Simulation.competitionCap + subsidiaries.count * Simulation.consolidationCapPerAcquisition)
    }
    var effectiveCompetitorExitProbability: Double {
        Simulation.competitorExitDailyProbability
            * max(0.55, 1.0 - Double(subsidiaries.count) * Simulation.consolidationStickiness)
    }

    /// Every open player route with a competitor on it (for the Ops box).
    var contestedRoutes: [Route] { playerRoutes.filter { $0.competitionLevel > 0 } }

    /// Once/day: rivals ENTER the player's profitable, established routes (chasing
    /// the traffic) up to a cap, and occasionally EXIT (churn). A strong
    /// reputation makes the player a harder target — fewer entrants.
    private func tickCompetition() {
        for r in playerRoutes {
            let ageDays = (tick - r.openedTick) / 1440
            // Must be actually flown + genuinely profitable (a subsidized route's
            // $0 opening cost makes isProfitable true from tick 0 — flights>0 guards it).
            if r.competitionLevel < effectiveCompetitionCap, r.flights > 0, r.isProfitable,
               ageDays >= Simulation.competitionMinRouteAgeDays {
                // High reputation deters entrants (a well-liked incumbent is hard
                // to unseat): rep 100 → half the base rate, rep 0 → full rate.
                let deter = 0.5 + 0.5 * (reputation / 100)
                var entryRate = Simulation.competitorEntryDailyProbability * (1.5 - deter)
                // Fortress hub: −50% entry on routes touching the player's
                // operating hub. A SOLD hub is the mirror: +50% entry there.
                if routeTouchesOperatingHub(r.originCode, r.destCode) { entryRate *= Simulation.hubFortressEntryFactor }
                if rivalHubs[r.originCode] != nil || rivalHubs[r.destCode] != nil { entryRate *= Simulation.rivalHubEntryFactor }
                // Consolidation: each acquisition makes the survivors hungrier,
                // so taking a competitor out of the market doesn't quiet it.
                entryRate *= consolidationEntryMultiplier
                if Double.random(in: 0..<1) < entryRate {
                    let name = competitorName(excluding: r.competitors)
                    r.competitionLevel += 1
                    r.competitors.append(name)
                    let why = subsidiaries.isEmpty ? "" : " as the market consolidates"
                    logOps(.market, "Competitor entered your market",
                           "\(name) now flies \(r.originCode) ↔\u{FE0E} \(r.destCode)\(why)")
                }
            }
            if r.competitionLevel > 0, Double.random(in: 0..<1) < effectiveCompetitorExitProbability {
                let name = r.competitors.popLast() ?? "A rival"
                r.competitionLevel -= 1
                logOps(.market, "Competitor exited",
                       "\(name) pulled out of \(r.originCode) ↔\u{FE0E} \(r.destCode)")
            }
        }
    }

    /// A plausible rival carrier (avoids duplicating one already on the route,
    /// and never names a carrier the player now OWNS — a subsidiary can't enter
    /// as your competitor).
    private func competitorName(excluding used: [String]) -> String {
        let owned = Set(subsidiaries.map(\.name))
        let pool = ["American Airlines", "Delta Air Lines", "United Airlines", "Southwest Airlines",
                    "JetBlue", "Alaska Airlines", "Spirit", "Frontier"]
        return pool.filter { !used.contains($0) && !owned.contains($0) }.randomElement() ?? "A new entrant"
    }

    /// Speed multiplier. Prototype default is 5× (feels smooth; at 1× the
    /// aircraft visibly steps every 250 ms, which is expected, not a bug).
    private(set) var speed: Double = 5
    /// Hard pause (QUIT-to-menu, app backgrounded). Not persisted — transient UI
    /// state. Distinct from the design's "no player-facing pause DURING play":
    /// this only stops the world while the player isn't looking at it.
    var isPaused = false

    /// Selectable speeds (¼×/½× are the slow-mo tiers; ¼× is rate-limited).
    static let speedOptions: [Double] = [0.25, 0.5, 1, 5, 10, 25]

    // ¼× is rate-limited: 3 uses per FIXED sim-calendar-day (resets when the
    // day-of-sim number changes, NOT a rolling 24h window). Exhausting it snaps
    // speed to 1× (not back to the previous speed). Ported from the prototype.
    static let quarterSpeedDailyLimit = 3
    private(set) var quarterSpeedUsesToday = 0
    private var quarterSpeedDay = 0

    /// Uses of ¼× left today (the UI shows/greys the ¼× control by this).
    var quarterSpeedUsesRemaining: Int {
        let day = tick / 1440
        return day == quarterSpeedDay ? max(0, Simulation.quarterSpeedDailyLimit - quarterSpeedUsesToday)
                                      : Simulation.quarterSpeedDailyLimit
    }

    /// Set the speed, enforcing the ¼× daily rate limit. Requesting ¼× when
    /// it's exhausted snaps to 1× instead. Non-¼× speeds set directly.
    func requestSpeed(_ s: Double) {
        if s == 0.25 {
            let day = tick / 1440
            if day != quarterSpeedDay { quarterSpeedDay = day; quarterSpeedUsesToday = 0 }
            guard quarterSpeedUsesToday < Simulation.quarterSpeedDailyLimit else { speed = 1; return }
            quarterSpeedUsesToday += 1
        }
        speed = s
    }

    private var nextTailNum = 1

    // MARK: - Camera (pan / zoom), ported from the prototype's camera model.
    // Everything on the map lives in resolution-independent "unit" space; the
    // camera maps unit→screen each frame. Default view frames the continental
    // US (resetCameraToConus); zoom clamps to [0.4×, 28×].

    static let cameraMinZoom: CGFloat = 0.4    // out enough to see AK+HI+CONUS
    static let cameraMaxZoom: CGFloat = 60     // in close enough to separate tight clusters (SFO/OAK) for tapping (was 28)
    private static let elementZoomGrowthMax: CGFloat = 0.15  // icon growth cap

    /// Horizontal wrap period in unit space = one full 360° of longitude. The map
    /// wraps around the world: panning east past the last airport rolls seamlessly
    /// back into the Americas (and vice versa). The rendered content actually spans
    /// ~390° (Alaska → Tahiti, because Tahiti is stored across the antimeridian), so
    /// there's a ~30° overlap of (near-empty) mid-Pacific at the seam — Anchorage
    /// and Tahiti are at the same real longitude and coincide there, which is why
    /// this tiling is correct rather than an error.
    static let wrapWidthUnits: CGFloat = 360 * GeoProjection.lonCorrection

    /// Zoom multiplier (× the whole-world fit). Observable → drives redraw.
    var cameraZoom: CGFloat = 1
    /// Unit-space point shown at screen centre. Observable → drives redraw.
    var cameraCenter: CGPoint = .zero

    private var viewport: CGSize = .zero
    private var worldScale: CGFloat = 1     // px per unit at zoom = 1 (whole world fits)
    private(set) var defaultZoom: CGFloat = 1
    /// Set once the user pans/zooms. Until then the view auto-frames CONUS on
    /// every size change, so a transient launch/rotation size can't lock the
    /// camera to the wrong framing.
    private var userAdjustedCamera = false

    // World and CONUS-frame extents in unit space (computed once).
    private static let worldUnitSize: CGSize = {
        let br = GeoProjection.unit(lat: GeoProjection.latMin, lon: GeoProjection.lonMax)
        return CGSize(width: br.x, height: br.y)   // top-left projects to (0,0)
    }()
    private static let conusFrame: (origin: CGPoint, size: CGSize, center: CGPoint) = {
        let tl = GeoProjection.unit(lat: 49.5, lon: -125)
        let br = GeoProjection.unit(lat: 24.5, lon: -66.5)
        let size = CGSize(width: br.x - tl.x, height: br.y - tl.y)
        return (tl, size, CGPoint(x: (tl.x + br.x) / 2, y: (tl.y + br.y) / 2))
    }()

    // MARK: Home region (player's start-region choice)

    /// Chosen on the naming screen; persisted. Drives the default map framing
    /// and the home-scoped pools (spare bases, route opportunities, airport
    /// recruitment offers). The player can still fly anywhere — this is focus,
    /// not a fence.
    private(set) var homeRegion: Airline.PlayerRegion = .northAmerica
    /// The default camera frame for the home region (CONUS for North America).
    private var homeFrame: (origin: CGPoint, size: CGSize, center: CGPoint) = Simulation.conusFrame

    /// Unit-space frame for a start region: North America keeps the proven CONUS
    /// frame (Hawaii/Alaska outliers deliberately excluded from the fit);
    /// everything else is the padded bounding box of the region's airports.
    static func frame(for region: Airline.PlayerRegion, airports: [Airport])
        -> (origin: CGPoint, size: CGSize, center: CGPoint) {
        if region == .northAmerica { return conusFrame }
        let regs = Set(region.gameRegions)
        let pts = airports.filter { regs.contains(Airline.region($0.code)) }.map(\.unit)
        guard pts.count >= 2 else { return conusFrame }
        var minX = pts[0].x, maxX = pts[0].x, minY = pts[0].y, maxY = pts[0].y
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let padX = (maxX - minX) * 0.08, padY = (maxY - minY) * 0.08
        let o = CGPoint(x: minX - padX, y: minY - padY)
        let s = CGSize(width: (maxX - minX) + 2 * padX, height: (maxY - minY) + 2 * padY)
        return (o, s, CGPoint(x: o.x + s.width / 2, y: o.y + s.height / 2))
    }

    /// Set (or restore) the player's start region and re-frame the map on it.
    func setHomeRegion(_ region: Airline.PlayerRegion) {
        homeRegion = region
        homeFrame = Simulation.frame(for: region, airports: airports)
        userAdjustedCamera = false
        applyHomeFraming()
    }

    /// Fit `homeFrame` in the current viewport → defaultZoom, and re-center on
    /// it unless the user has taken manual camera control.
    private func applyHomeFraming() {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let fit = min(viewport.width / (homeFrame.size.width * worldScale),
                      viewport.height / (homeFrame.size.height * worldScale)) * 0.92
        defaultZoom = min(Simulation.cameraMaxZoom, max(Simulation.cameraMinZoom, fit))
        if !userAdjustedCamera {
            cameraZoom = defaultZoom
            cameraCenter = homeFrame.center
        }
    }

    /// Ensure the camera is configured for the current viewport. Recomputes the
    /// whole-world scale and the home-region-fit default zoom on size change;
    /// frames the home region on first configure (CONUS until a region is set).
    func configure(viewport size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if size != viewport {
            viewport = size
            let w = Simulation.worldUnitSize
            worldScale = min(size.width / w.width, size.height / w.height)
            applyHomeFraming()
        }
    }

    private var pixelsPerUnit: CGFloat { worldScale * cameraZoom }
    private var viewportCentre: CGPoint { CGPoint(x: viewport.width / 2, y: viewport.height / 2) }

    /// One wrap period in screen pixels at the current zoom.
    var wrapWidthPx: CGFloat { Simulation.wrapWidthUnits * pixelsPerUnit }

    /// Pixel x-offsets at which the whole world should be redrawn so it tiles
    /// across the viewport for the wrap-around effect. Always includes 0; adds
    /// the ±copies whose content actually intersects the viewport. Falls back to
    /// [0] if anything's degenerate.
    func wrapDrawOffsetsPx() -> [CGFloat] {
        let wpx = wrapWidthPx
        guard wpx > 1, viewport.width > 0 else { return [0] }
        let minX = project(.zero).x                                        // world left edge
        let maxX = project(CGPoint(x: Simulation.worldUnitSize.width, y: 0)).x  // world right edge
        let kMin = Int((-maxX / wpx).rounded(.up))
        let kMax = Int(((viewport.width - minX) / wpx).rounded(.down))
        guard kMin <= kMax, (kMax - kMin) <= 12 else { return [0] }        // sanity cap
        return (kMin...kMax).map { CGFloat($0) * wpx }
    }

    /// Minimal horizontal screen delta between two x's, accounting for the wrap
    /// (so a tap on any tiled copy of an airport still registers as that airport).
    private func wrappedDX(_ ax: CGFloat, _ px: CGFloat) -> CGFloat {
        let w = wrapWidthPx
        guard w > 1 else { return ax - px }
        var d = (ax - px).truncatingRemainder(dividingBy: w)
        if d > w / 2 { d -= w } else if d < -w / 2 { d += w }
        return d
    }

    /// Keep cameraCenter.x in [0, wrapWidthUnits) so it never drifts unbounded
    /// over a long session. A shift of exactly one period is visually invisible
    /// (the scene is periodic — the tiled copies fill in), so this can't jump.
    private func wrapCameraX() {
        let w = Simulation.wrapWidthUnits
        guard w > 0 else { return }
        cameraCenter.x = cameraCenter.x.truncatingRemainder(dividingBy: w)
        if cameraCenter.x < 0 { cameraCenter.x += w }
    }

    /// Unit → screen for the current camera. Airports and basemap both use this.
    func project(_ u: CGPoint) -> CGPoint {
        let ppu = pixelsPerUnit
        return CGPoint(x: (u.x - cameraCenter.x) * ppu + viewportCentre.x,
                       y: (u.y - cameraCenter.y) * ppu + viewportCentre.y)
    }

    /// Screen → unit (inverse), for gesture anchoring.
    func unit(fromScreen s: CGPoint) -> CGPoint {
        let ppu = pixelsPerUnit
        return CGPoint(x: (s.x - viewportCentre.x) / ppu + cameraCenter.x,
                       y: (s.y - viewportCentre.y) / ppu + cameraCenter.y)
    }

    /// Damped element-scale curve: airports/aircraft stay constant size up to
    /// the default zoom, then grow modestly to +15% and hold there. The growth
    /// range is anchored to a FIXED zoom span (not cameraMaxZoom) so raising
    /// the max zoom doesn't change how icons feel at the zoom levels the
    /// designer already tuned — extra zoom just keeps icons at the +15% cap.
    private var elementGrowthEnd: CGFloat { defaultZoom * 2.5 }

    var elementScale: CGFloat {
        guard cameraZoom > defaultZoom else { return 1 }
        let t = min(1, (cameraZoom - defaultZoom) / (elementGrowthEnd - defaultZoom))
        return 1 + Simulation.elementZoomGrowthMax * t
    }

    /// Airport labels grow like other elements, PLUS an extra +15% that ramps
    /// in between the element cap and the max zoom — so labels read 15% larger
    /// than everything else at the highest zoom (designer request), where
    /// there's room for it and legibility matters most.
    var labelScale: CGFloat {
        let extra = min(1, max(0, (cameraZoom - elementGrowthEnd) / (Simulation.cameraMaxZoom - elementGrowthEnd)))
        return elementScale * (1 + Simulation.elementZoomGrowthMax * extra)
    }

    /// Recompute every airport's screen position (call each frame after
    /// configure, since the camera can change between frames).
    func projectAirports() {
        for ap in airports { ap.screen = project(ap.unit) }
    }

    /// Nearest aircraft within `tolerance` screen points of a tap, or nil.
    /// Lives in the sim layer (not the view) so the headless harness can
    /// verify hit-testing without driving real touches.
    /// Nearest airport within `tolerance` of a tap (for the route picker).
    /// 44pt ≈ a fingertip; nearest-wins keeps dense clusters unambiguous.
    func airport(atScreenPoint p: CGPoint, tolerance: CGFloat = 44) -> Airport? {
        var best: (ap: Airport, d: CGFloat)?
        for ap in airports {
            let d = hypot(wrappedDX(ap.screen.x, p.x), ap.screen.y - p.y)
            if d <= tolerance && d < (best?.d ?? .infinity) { best = (ap, d) }
        }
        return best?.ap
    }

    func aircraft(atScreenPoint p: CGPoint, tolerance: CGFloat = 24) -> Aircraft? {
        var best: (ac: Aircraft, d: CGFloat)?
        for ac in aircraft {
            let pos = ac.position(tick: tick).point
            let d = hypot(wrappedDX(pos.x, p.x), pos.y - p.y)
            if d <= tolerance && d < (best?.d ?? .infinity) { best = (ac, d) }
        }
        return best?.ac
    }

    // MARK: - Camera controls (driven by gestures / buttons)

    func pan(by delta: CGSize) {
        userAdjustedCamera = true
        let ppu = pixelsPerUnit
        cameraCenter.x -= delta.width / ppu
        cameraCenter.y -= delta.height / ppu
        wrapCameraX()   // keep x bounded; the map wraps around the world
    }

    /// Multiply zoom by `factor`, keeping the unit point under `anchor` fixed.
    func zoom(by factor: CGFloat, anchor: CGPoint) {
        userAdjustedCamera = true
        let anchorUnit = unit(fromScreen: anchor)
        cameraZoom = min(Simulation.cameraMaxZoom, max(Simulation.cameraMinZoom, cameraZoom * factor))
        // keep anchorUnit projecting back to `anchor`
        let ppu = pixelsPerUnit
        cameraCenter = CGPoint(x: anchorUnit.x - (anchor.x - viewportCentre.x) / ppu,
                               y: anchorUnit.y - (anchor.y - viewportCentre.y) / ppu)
    }

    func resetCamera() {
        userAdjustedCamera = false
        cameraZoom = defaultZoom
        cameraCenter = homeFrame.center
    }

    /// Center the map on an airport and zoom in enough to see it clearly — the
    /// target of "show me where this airport is" from the Ops feed.
    func focusCamera(on code: String) {
        guard let ap = airport(code) else { return }
        userAdjustedCamera = true
        cameraZoom = min(Simulation.cameraMaxZoom, max(defaultZoom * 8, 10))
        cameraCenter = ap.unit
        wrapCameraX()
    }

    // MARK: - Route suggestion preview (Ops "Route Opportunities" → tap → map)

    /// A suggested city pair the player tapped in Ops, previewed on the map with
    /// a dashed line + pulsing endpoints and an Open This Route / Don't Open
    /// panel. Purely a UI-intent flag (not persisted); the map + NetworkView
    /// read it. Survives the Ops→Network tab switch because it lives on the sim.
    struct RouteSuggestion: Equatable { let origin: String; let dest: String }
    private(set) var pendingSuggestion: RouteSuggestion?

    /// Preview a suggested route: flag the pair and frame the camera so both
    /// endpoints sit comfortably on screen.
    func suggestRoute(from o: String, to d: String) {
        guard let a = airport(o), let b = airport(d) else { return }
        pendingSuggestion = RouteSuggestion(origin: o, dest: d)
        frameRoute(a, b)
    }
    func clearSuggestion() { pendingSuggestion = nil }

    /// Center on the two airports' midpoint and zoom so both fit with generous
    /// padding (so the dashed line reads as a route across open map, not edge
    /// to edge). Same fit math as applyHomeFraming.
    private func frameRoute(_ a: Airport, _ b: Airport) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        userAdjustedCamera = true
        let minX = min(a.unit.x, b.unit.x), maxX = max(a.unit.x, b.unit.x)
        let minY = min(a.unit.y, b.unit.y), maxY = max(a.unit.y, b.unit.y)
        let w = max(maxX - minX, 0.001), h = max(maxY - minY, 0.001)
        // Pad so the pair occupies the middle ~45% of the frame.
        let boxW = w * 2.2 + 0.03, boxH = h * 2.2 + 0.03
        let fit = min(viewport.width / (boxW * worldScale),
                      viewport.height / (boxH * worldScale))
        cameraZoom = min(Simulation.cameraMaxZoom, max(Simulation.cameraMinZoom, fit))
        cameraCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        wrapCameraX()
    }

    init() {
        // Phase 2: the full 48-airport network and a stress-test fleet flying
        // real routes between them. These are stress-test aircraft (no
        // ownership/economy yet — that's Phase 5); each gets a weighted-random
        // type, a random city pair it flies back and forth, and a staggered
        // start so the fleet isn't synchronized.
        airports = Airport.all
        provisionSlots()
        // Crew pools start EMPTY — the player-driven model fills them as aircraft
        // are bought/leased (grantBundledCrew), not by any startup ratio.
        initializeUsedInventory()   // 1–2 pre-owned listings per type at start
        // Full-shift start: $20M, zero aircraft, zero routes. The FLEET buttons
        // are a DEV stress-test control (spawn background/non-owned traffic).
        financeSnapshots = [financeSnapshotNow()]   // launch baseline (tick 0, $20M)
        competitorSeed = UInt64.random(in: 1...UInt64.max)
        rebuildCompetitorIntel()
    }

    // MARK: - Competitor acquisition (step 2: transaction + inheritance)
    //
    // Types, gate, and pricing live in Acquisition.swift; the mutating work is
    // here because the state it touches is private(set) to this file.
    //
    // ⚠️ NOT SHIPPABLE WITHOUT STEP 3 (the integration burden). As it stands an
    // acquisition is pure upside, which is the design the spec rejects.

    // MARK: - Public company (IPO) — step 1: model + transaction + ticker
    //
    // Types, gate, and valuation live in GoPublic.swift; the mutating work is here
    // because it touches private(set) state.

    /// The listed airline, or nil while private.
    private(set) var publicCompany: PublicCompany?
    /// The market's mood, ∈ [floor, ceiling]. Updated monthly toward a
    /// fundamentals-driven target; persisted so the ticker doesn't jump on load.
    private(set) var marketSentiment: Double = 1.0
    /// The displayed share price, eased toward `targetSharePrice` each tick so the
    /// ticker animates instead of snapping.
    private(set) var displaySharePrice: Double = 0
    /// Capital-in accumulator for the Finance cash invariant.
    private(set) var totalEquityRaised = 0
    /// Cash returned to public shareholders as dividends (Finance cash-out).
    private(set) var totalDividendsPaid = 0
    /// Cash spent repurchasing float shares (Finance cash-out).
    private(set) var totalBuybackSpend = 0
    /// Tick of the most recent dividend (seeded to the IPO tick) — drives the
    /// dividend-drought sentiment penalty (the "income" half of the string).
    private var lastDividendTick = 0
    private var nextSentimentTick = 0

    /// Take the airline public. Player picks a ticker and how much to sell.
    /// Returns false if ungated, already public, or the ticker is invalid.
    @discardableResult
    func goPublic(ticker rawTicker: String, floatFraction: Double) -> Bool {
        guard canGoPublic else { return false }
        let ticker = Simulation.sanitizeTicker(rawTicker)
        guard !ticker.isEmpty else { return false }
        let fraction = max(0.01, min(0.99, floatFraction))

        // Value the company as-is, THEN sell a slice. Share count is FIXED (not
        // derived to hit a flat price), so a bigger airline lists at a higher
        // per-share price — the price reflects the size of the entity.
        let preMoneyCap = marketCap
        let shares = Simulation.ipoShares
        let ipoPrice = preMoneyCap / shares
        let proceeds = Int((preMoneyCap * fraction).rounded())

        publicCompany = PublicCompany(ticker: ticker, ipoTick: tick, ipoPrice: ipoPrice,
                                      sharesOutstanding: shares,
                                      playerShares: shares * (1 - fraction))
        displaySharePrice = ipoPrice
        playerBalance += proceeds
        totalEquityRaised += proceeds
        lastDividendTick = tick   // the income clock starts at listing
        nextSentimentTick = tick + Simulation.ticksPerMonth

        logOps(.market, "\(ticker) is public",
               "Listed at \(compactMoneySim(Int(ipoPrice)))/share. Raised \(compactMoneySim(proceeds)) selling \(Int((fraction*100).rounded()))%.")
        celebrate("ipo", "chart.line.uptrend.xyaxis", "\(ticker) went public",
                  "Raised \(compactMoneySim(proceeds))")
        return true
    }

    /// Per-tick: ease the displayed price toward its target, and refresh sentiment
    /// once per sim-month. Called from the tick loop.
    private func tickStockPrice() {
        guard isPublic else { return }
        if tick >= nextSentimentTick {
            marketSentiment = nextSentiment()
            nextSentimentTick += Simulation.ticksPerMonth
        }
        // Ease per sim-day (the target moves as net worth/sentiment move).
        if tick % 1440 == 0 {
            let target = targetSharePrice
            displaySharePrice += (target - displaySharePrice) * Simulation.sharePriceEasing
        }
    }

    /// Next month's sentiment from the fundamentals the game already tracks:
    /// reputation, the recent net-worth trend, and the active economic event —
    /// plus a small mean-reverting wiggle so the ticker feels alive. Momentum
    /// carried (80/20) so it drifts rather than teleports.
    private func nextSentiment() -> Double {
        // New-issue turbulence: 1.0 at listing → 0 by `ipoVolatilityMonths`. It
        // amplifies the random swings AND the sensitivity to performance, and
        // loosens the smoothing — so the first year is volatile and unforgiving,
        // then settles into a seasoned stock (designer).
        var ipo = 0.0
        if let pc = publicCompany {
            let monthsPublic = Double(tick - pc.ipoTick) / Double(Simulation.ticksPerMonth)
            ipo = max(0, 1 - monthsPublic / Simulation.ipoVolatilityMonths)
        }

        var target = 1.0
        // Reputation vs the anchor: ±0.4 across the full 0–100 range.
        target += 0.4 * ((reputation - Simulation.sentimentReputationAnchor) / 50)
        // Net-worth trend — the pressure to perform hits HARDER in the IPO year.
        if financeSnapshots.count >= 2 {
            let recent = financeSnapshots.suffix(3)
            if let first = recent.first, let last = recent.last, first.netWorth > 0 {
                let growth = Double(last.netWorth - first.netWorth) / Double(first.netWorth)
                let clamp = 0.35 * (1 + ipo)
                target += max(-clamp, min(clamp, growth * 2.0 * (1 + ipo)))
            }
        }
        // Airline stocks move with the macro: a fuel spike / recession drags, a
        // boom lifts. costMultiplier > 1 is harmful, < 1 favourable.
        if !currentEvent.isNormal {
            target += (1.0 - currentEvent.costMultiplier) * 0.5
        }
        // The income half of the string: shareholders sour the longer they go
        // without a dividend. A grace period, then a growing drag a special
        // dividend resets. The growth half is the net-worth-trend term above.
        let monthsSinceDividend = Double(tick - lastDividendTick) / Double(Simulation.ticksPerMonth)
        if monthsSinceDividend > 6 {
            target -= min(0.25, (monthsSinceDividend - 6) * 0.03)
        }
        // Random swings: up to 3× normal in the first month of trading.
        target += Double.random(in: -0.06...0.06) * (1 + 2 * ipo)

        // Momentum: less smoothing early (more reactive → more visibly volatile),
        // easing to the normal 0.8 as the issue seasons.
        let momentum = 0.8 - 0.3 * ipo
        let blended = momentum * marketSentiment + (1 - momentum) * target
        return max(Simulation.sentimentFloor, min(Simulation.sentimentCeiling, blended))
    }

    /// Ticker validation shared by the sim and the naming UI.
    static func sanitizeTicker(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter }.prefix(4))
    }

    // MARK: - Public company: levers (step 2 — dividends, buybacks, secondary)

    /// Pay a special dividend at `yield` of the share price on the public float.
    /// Costs cash, lifts sentiment immediately, resets the dividend-drought clock,
    /// and (step 3) is the fastest way to end an activist campaign. Returns false
    /// if private or unaffordable.
    @discardableResult
    func payDividend(yield: Double) -> Bool {
        guard let pc = publicCompany else { return false }
        let cost = dividendCost(yield: yield)
        guard cost > 0, playerBalance >= cost else { return false }
        playerBalance -= cost
        totalDividendsPaid += cost
        lastDividendTick = tick
        marketSentiment = min(Simulation.sentimentCeiling, marketSentiment + min(0.15, max(0, yield) * 2.0))
        logOps(.market, "\(pc.ticker) paid a dividend",
               "Special dividend of \(compactMoneySim(cost)) to shareholders.")
        return true
    }

    /// Repurchase `floatFraction` of the public float at the current price and
    /// retire the shares: the player's stake rises (fewer shares outstanding) and
    /// the float that fuels activists shrinks. Expensive when the price is high.
    @discardableResult
    func buyBackShares(floatFraction: Double) -> Bool {
        guard let pc = publicCompany else { return false }
        let shares = pc.floatShares * max(0, min(1, floatFraction))
        guard shares > 0 else { return false }
        let cost = Int((shares * currentSharePrice).rounded())
        guard cost > 0, playerBalance >= cost else { return false }
        playerBalance -= cost
        totalBuybackSpend += cost
        publicCompany?.sharesOutstanding = pc.sharesOutstanding - shares
        if let updated = publicCompany {
            logOps(.market, "\(updated.ticker) bought back stock",
                   "Repurchased \(compactMoneySim(cost)) of shares; your stake is now \(Int((updated.playerStake*100).rounded()))%.")
        }
        return true
    }

    /// Issue new shares equal to `fraction` × current shares outstanding at the
    /// current price: raises cash now, dilutes the player's stake (raising board
    /// risk, step 4). Raises little when the price is depressed — the realistic
    /// penalty for needing cash in a downturn.
    @discardableResult
    func secondaryOffering(fraction: Double) -> Bool {
        guard let pc = publicCompany else { return false }
        let newShares = pc.sharesOutstanding * max(0, fraction)
        guard newShares > 0 else { return false }
        let proceeds = Int((newShares * currentSharePrice).rounded())
        guard proceeds > 0 else { return false }
        publicCompany?.sharesOutstanding = pc.sharesOutstanding + newShares
        playerBalance += proceeds
        totalEquityRaised += proceeds
        if let updated = publicCompany {
            logOps(.market, "\(updated.ticker) secondary offering",
                   "Raised \(compactMoneySim(proceeds)); your stake is now \(Int((updated.playerStake*100).rounded()))%.")
        }
        return true
    }

    #if DEBUG
    /// TEST HOOK — reaching the $1B acquisition gate through the real economy
    /// takes sim-years, which no headless suite can afford. Injections are
    /// TRACKED so the Finance cash invariant can account for them explicitly
    /// rather than being quietly excused. DEBUG-only: absent from Release.
    private(set) var devInjectedCash = 0
    func devInjectCash(_ amount: Int) {
        playerBalance += amount
        devInjectedCash += amount
    }
    #endif

    /// Airlines the player has bought. Each keeps flying under its own flag.
    private(set) var subsidiaries: [Subsidiary] = []
    /// Capital-out accumulator for the Finance cash invariant.
    private(set) var totalAcquisitionPrice = 0
    /// Carriers whose books the player has opened (stage-2 due diligence).
    /// Persisted — paying to diligence a target shouldn't evaporate on reload.
    private(set) var diligencedCarriers: Set<String> = []

    private func compactMoneySim(_ v: Int) -> String {
        v >= 1_000_000 ? String(format: "$%.1fM", Double(v)/1e6) : "$\(v)"
    }

    /// Cost to open a carrier's books: scales with the size of the business, so
    /// diligencing every target is deliberately not free.
    func diligenceCost(for p: CompetitorProfile) -> Int {
        max(250_000, Int(p.estimatedValue * 0.004))
    }
    func hasDiligenced(_ id: String) -> Bool { diligencedCarriers.contains(id) }
    func diligenceStage(_ id: String) -> Int { diligencedCarriers.contains(id) ? 2 : 1 }

    /// Pay to open the books. One-off, permanent for that carrier.
    @discardableResult
    func openBooks(on p: CompetitorProfile) -> Bool {
        let cost = diligenceCost(for: p)
        guard !diligencedCarriers.contains(p.id), playerBalance >= cost else { return false }
        playerBalance -= cost
        totalDiligenceSpend += cost
        diligencedCarriers.insert(p.id)
        logOps(.market, "Due diligence: \(p.name)", "Books opened for \(compactMoneySim(cost)).")
        return true
    }
    private(set) var totalDiligenceSpend = 0

    /// The live integration, if any. THIS is the feature — see Acquisition.swift.
    private(set) var activeIntegration: Integration?
    /// Overhead accumulators for the Finance cash invariant.
    private(set) var totalIntegrationSpend = 0
    private(set) var totalSenioritySpend = 0

    // MARK: Integration lifecycle

    /// Start the merger integration: monthly bills, a seniority dispute across
    /// the families both airlines fly, and a reputation hit passengers feel.
    private func beginIntegration(_ p: CompetitorProfile, price: Int) {
        let months = Simulation.integrationMonths
        // Families flown by BOTH airlines — the ones with two seniority lists to
        // merge. A type only the subsidiary flies has nobody to argue with.
        let mine = Set(aircraft.filter { $0.purchased && $0.subsidiaryCode == nil }.map(\.type.family))
        let theirs = Set(p.fleetByType.keys.compactMap { id in
            AircraftType.all.first { $0.id == id }?.family })
        let disputed = mine.intersection(theirs).sorted()

        var ig = Integration(
            subsidiaryCode: p.id, subsidiaryName: p.name,
            startTick: tick, endTick: tick + months * Simulation.ticksPerMonth,
            monthlyBill: Int(Double(price) * Simulation.integrationBillRate),
            seniorityExpiryTick: tick + Simulation.seniorityDisputeMonths * Simulation.ticksPerMonth,
            senioritySettlementCost: Int(Double(price) * Simulation.senioritySettlementRate),
            disputedFamilies: disputed,
            nextBillTick: tick + Simulation.ticksPerMonth)
        if disputed.isEmpty {
            // Nothing to dispute — no overlapping type ratings.
            ig.senioritySettlementCost = nil
            ig.seniorityExpiryTick = tick
        }
        activeIntegration = ig
        applySeniorityDispute()

        reputation = max(0, reputation - Simulation.acquisitionReputationHit)
        logOps(.disruption, "Integration underway",
               "\(p.name) integration runs \(months) months. \(disputed.isEmpty ? "No overlapping type ratings." : "Seniority dispute across \(disputed.count) crew families.")")
    }

    /// Sideline a fraction of each disputed family's crew. Reuses the labor-action
    /// mechanism, but runs for MONTHS rather than days — merging two seniority
    /// lists is the most contested part of a real airline merger.
    private func applySeniorityDispute() {
        guard let ig = activeIntegration, !ig.isSettled else { return }
        for family in ig.disputedFamilies {
            guard var pool = crewPoolsByFamily[family], !pool.isEmpty else { continue }
            let target = Int((Double(pool.count) * Simulation.senioritySidelinedFraction).rounded())
            var sidelined = pool.filter { $0.status == .sidelined }.count
            for i in pool.indices where sidelined < target {
                // Never yank a crew mid-flight — same rule as the labor action.
                if pool[i].status == .available || pool[i].status == .resting {
                    pool[i].status = .sidelined
                    sidelined += 1
                }
            }
            crewPoolsByFamily[family] = pool
        }
    }

    /// Return sidelined crew once the dispute ends (settled or expired).
    private func endSeniorityDispute(settled: Bool) {
        guard var ig = activeIntegration else { return }
        for family in ig.disputedFamilies {
            guard var pool = crewPoolsByFamily[family] else { continue }
            for i in pool.indices where pool[i].status == .sidelined { pool[i].status = .available }
            crewPoolsByFamily[family] = pool
        }
        ig.senioritySettlementCost = nil
        ig.seniorityExpiryTick = tick
        activeIntegration = ig
        logOps(.structural, settled ? "Seniority agreement signed" : "Seniority dispute resolved",
               "\(ig.subsidiaryName) crews are back on the line.")
    }

    /// Pay to end the seniority dispute now — the clearest "manage it well" lever
    /// in the feature, and expensive enough to be a real decision.
    @discardableResult
    func settleSeniority() -> Bool {
        guard let ig = activeIntegration, let cost = ig.senioritySettlementCost,
              playerBalance >= cost else { return false }
        playerBalance -= cost
        totalSenioritySpend += cost
        endSeniorityDispute(settled: true)
        return true
    }

    /// Monthly bill + dispute expiry + completion. Called from the tick loop.
    private func tickIntegration() {
        guard var ig = activeIntegration else { return }

        if !ig.isSettled, tick >= ig.seniorityExpiryTick {
            endSeniorityDispute(settled: false)
            return
        }
        // Re-apply sidelining: crew released from a flight return as .available,
        // so the dispute has to keep its grip rather than draining away.
        if !ig.isSettled { applySeniorityDispute() }

        if tick >= ig.nextBillTick, tick < ig.endTick {
            playerBalance -= ig.monthlyBill
            totalIntegrationSpend += ig.monthlyBill
            ig.billsPaid += 1
            ig.nextBillTick += Simulation.ticksPerMonth
            activeIntegration = ig
        }
        if tick >= ig.endTick {
            if !ig.isSettled { endSeniorityDispute(settled: false) }
            logOps(.structural, "Integration complete",
                   "\(ig.subsidiaryName) is fully integrated after \(Simulation.integrationMonths) months.")
            celebrate("integ_\(ig.subsidiaryCode)", "checkmark.seal.fill",
                      "\(ig.subsidiaryName) integrated", "The merger is complete")
            activeIntegration = nil
        }
    }

    @discardableResult
    func acquire(_ p: CompetitorProfile) -> Bool {
        guard acquisitionBlock(for: p) == nil else { return false }
        let price = askingPrice(for: p)

        playerBalance -= price
        totalAcquisitionPrice += price

        let fleet = inheritFleet(from: p)
        let routes = inheritRoutes(from: p, using: fleet)
        inheritHubs(from: p)
        removeAsRival(p)
        blendReputation(with: p)

        subsidiaries.append(Subsidiary(code: p.id, name: p.name, region: p.region,
                                       acquiredTick: tick, pricePaid: price,
                                       serviceScoreAtAcquisition: p.serviceScore,
                                       fleetInherited: fleet.count, routesInherited: routes))

        beginIntegration(p, price: price)
        logOps(.structural, "Acquired \(p.name)",
               "\(fleet.count) aircraft and \(routes) routes join your group — \(p.name) keeps flying under its own flag.")
        celebrate("acq_\(p.id)", "building.2.fill", "\(p.name) acquired",
                  "\(fleet.count) aircraft · \(routes) routes")
        return true
    }

    /// Inherited aircraft KEEP THE CARRIER'S OWN TAIL CODE (a Delta jet stays
    /// N…DL, not renumbered to the player's) — the subsidiary model made visible
    /// in the Fleet list. They carry that carrier's real age too, so a chunk of
    /// what you buy is genuinely near end-of-life.
    private func inheritFleet(from p: CompetitorProfile) -> [Aircraft] {
        var made: [Aircraft] = []
        let bases = airports.filter { p.hubCodes.contains($0.code) }
        // The DETERMINISTIC manifest — the same airframes stage-2 due diligence
        // showed. Ages are no longer rolled here, so the books the player paid to
        // open are exactly the fleet they receive.
        for entry in p.fleetManifest(seed: competitorSeed) {
            let type = entry.type
            do {
                guard let base = bases.randomElement() ?? homeBaseAirports.randomElement() else { continue }
                let tail = "N\(nextTailNum)\(p.code.isEmpty ? playerTailCode : p.code)"
                nextTailNum += 1
                let cycles = Int(Double(type.expectedLifespanCycles) * entry.ageFraction)
                let ac = Aircraft(tail: tail, type: type, origin: base, dest: base,
                                  stateIndex: FlightState.parked.rawValue,
                                  cyclesAccrued: max(0, min(cycles, type.expectedLifespanCycles)),
                                  purchased: true)
                ac.subsidiaryCode = p.id
                ac.airlineName = p.name
                rollRevenue(for: ac)
                aircraft.append(ac)
                made.append(ac)
                // You acquire the airline's PEOPLE too. The spec's original "no
                // crew for unfamiliar types" was wrong on realism — a merger's
                // pain is the SENIORITY fight (step 3), not an absence of crew.
                // Inheriting crew also avoids an alert flood the moment it closes.
                grantBundledCrew(type.family)
            }
        }
        return made
    }

    /// Build the carrier's network as real player routes in its region,
    /// hub-anchored. Routes cost nothing (they came with the company) but DO
    /// consume slots — which is what makes an acquisition a genuine land-grab.
    private func inheritRoutes(from p: CompetitorProfile, using fleet: [Aircraft]) -> Int {
        let pool = airports.filter { CompetitorIntel.regionLabel(Airline.region($0.code)) == p.region }
        let hubs = airports.filter { p.hubCodes.contains($0.code) }
        guard pool.count >= 2, !hubs.isEmpty else { return 0 }

        var opened = 0
        var spares = fleet
        // Capped at the aircraft actually inherited: a route with nobody to fly
        // it is a pending route, and inheriting dozens of those is noise.
        let target = min(p.routeCount, fleet.count)
        var attempts = 0
        while opened < target, attempts < target * 12, !spares.isEmpty {
            attempts += 1
            guard let hub = hubs.randomElement() else { continue }
            // You buy a competitor BECAUSE they fly where you fly. Bias their
            // network toward airports the player already serves, so double
            // coverage is a real, expected consequence of the deal rather than a
            // rare accident — without this the whole integration burden is inert
            // for most targets and a player can cherry-pick frictionless ones.
            // (Caught by the step-3 harness: the first target produced ZERO
            // overlapping pairs and ZERO disputed crew families.)
            let contested = pool.filter { ap in
                playerRoutes.contains { $0.subsidiaryCode == nil &&
                    ($0.originCode == ap.code || $0.destCode == ap.code) } }
            let useContested = !contested.isEmpty && Double.random(in: 0..<1) < 0.45
            // A real airline flies where the demand is. Draw the spoke weighted
            // by airport traffic rather than uniformly — uniform selection gave
            // the inherited network a tail of dead markets and made every
            // acquisition value-destructive regardless of tuning.
            let candidates = (useContested ? contested : pool).filter { $0.code != hub.code }
            guard let spoke = weightedByTraffic(candidates) else { continue }
            // Overlap with the player's existing network is ALLOWED and is the
            // point (step 3's double-coverage problem) — but only once per pair,
            // so an inherited network can't stack three deep on one city pair.
            if playerRoutes.contains(where: { $0.subsidiaryCode == p.id &&
                (($0.originCode == hub.code && $0.destCode == spoke.code) ||
                 ($0.originCode == spoke.code && $0.destCode == hub.code)) }) { continue }
            // Match aircraft to route ECONOMICALLY, not merely physically. Taking
            // the first aircraft that *can* fly a leg puts widebodies on short
            // domestic hops, where they lose enormous money (an A380 is −$63k at
            // 300nm — see CLAUDE.md), which made every inherited network
            // structurally loss-making no matter how the integration was tuned.
            // A real airline flies each type at the stage length it's built for.
            let nm = hub.greatCircleNM(to: spoke)
            guard let idx = spares.indices
                .filter({ routeBlock(for: spares[$0], from: hub, to: spoke) == nil })
                .min(by: { stageMismatch(spares[$0], nm) < stageMismatch(spares[$1], nm) })
            else { continue }
            // Refuse a badly-mismatched pairing outright rather than book a
            // guaranteed loss-maker; another spoke will suit this aircraft.
            guard stageMismatch(spares[idx], nm) < 2.2 else { continue }
            let ac = spares.remove(at: idx)

            if hub.slotsAvailable > 0 { hub.slotsAvailable -= 1 }
            if spoke.slotsAvailable > 0 { spoke.slotsAvailable -= 1 }
            let r = Route(id: nextRouteId, originCode: hub.code, destCode: spoke.code,
                          openedTick: tick, openingCost: 0)
            r.subsidiaryCode = p.id
            nextRouteId += 1
            playerRoutes.append(r)
            r.assignmentHistory.append(RouteAssignment(id: 0, tail: ac.tail,
                                                       typeName: ac.type.name, assignedTick: tick))
            ac.assignedRouteId = r.id
            ac.origin = hub
            ac.dest = spoke
            rollRevenue(for: ac)
            opened += 1
        }
        return opened
    }

    /// How badly a leg length suits an aircraft type, as a ratio around the
    /// stage length that type is built for (1.0 = perfect). Used to keep
    /// inherited widebodies off short domestic hops.
    private func stageMismatch(_ ac: Aircraft, _ nm: Double) -> Double {
        let ideal: Double
        switch ac.type.bodyType {
        case .turboprop:       ideal = 250
        case .regionalJet:     ideal = 450
        case .narrowbody:      ideal = 900
        case .widebody2Engine: ideal = 3_400
        case .widebody4Engine: ideal = 4_200
        }
        return max(nm, 1) / ideal > 1 ? max(nm, 1) / ideal : ideal / max(nm, 1)
    }

    /// Pick an airport with probability proportional to its annual passengers.
    private func weightedByTraffic(_ pool: [Airport]) -> Airport? {
        guard !pool.isEmpty else { return nil }
        let weights = pool.map { max(1.0, Double($0.info?.annualPassengers ?? 1_000_000)) }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            roll -= w
            if roll < 0 { return pool[i] }
        }
        return pool.last
    }

    /// Their hubs become yours — unless you already hub there, in which case
    /// yours stands.
    private func inheritHubs(from p: CompetitorProfile) {
        for code in p.hubCodes where hubs[code] == nil {
            hubs[code] = Hub(establishedTick: tick)
            rivalHubs[code] = nil   // no longer a rival's — it's in the group now
        }
    }

    /// The instant, legible reward: they stop competing with you everywhere.
    private func removeAsRival(_ p: CompetitorProfile) {
        for r in playerRoutes {
            let before = r.competitors.count
            r.competitors.removeAll { $0 == p.name }
            r.competitionLevel = max(0, r.competitionLevel - (before - r.competitors.count))
        }
    }

    /// PARTIAL blend, weighted by relative size and capped so a subsidiary can
    /// never swing the mainline score by more than half. Buying a well-run
    /// carrier helps a little; buying a badly-run one hurts a little and gives
    /// you something to fix.
    private func blendReputation(with p: CompetitorProfile) {
        let mine = Double(max(1, ownedCount - p.fleetSize))
        let theirs = Double(p.fleetSize)
        let weight = min(0.5, theirs / (mine + theirs))
        reputation = reputation * (1 - weight) + p.serviceScore * weight
    }

    // MARK: - Competitor intelligence (scouting)

    /// Per-game seed for competitor profiles. Persisted; the profiles themselves
    /// are NOT (they regenerate exactly from this, keeping saves small and
    /// stopping a player re-rolling a carrier's books by quitting).
    private(set) var competitorSeed: UInt64 = 1
    private(set) var competitorProfiles: [CompetitorProfile] = []

    func rebuildCompetitorIntel() {
        competitorProfiles = CompetitorIntel.generateAll(seed: competitorSeed, airports: airports)
    }

    /// Carriers in regions the player actually touches — their home region plus
    /// anywhere they've opened a route. Scouting is intentionally scoped to the
    /// market the player competes in rather than all 140+ carriers.
    var relevantCompetitors: [CompetitorProfile] {
        var regions = Set(homeRegion.gameRegions.map { CompetitorIntel.regionLabel($0) })
        for r in playerRoutes + closedPlayerRoutes {
            regions.insert(CompetitorIntel.regionLabel(Airline.region(r.originCode)))
            regions.insert(CompetitorIntel.regionLabel(Airline.region(r.destCode)))
        }
        return competitorProfiles.filter { regions.contains($0.region) }
    }

    /// Carriers currently contesting one of the player's open routes — the ones
    /// a player has a live reason to study.
    var rivalsOnMyRoutes: Set<String> {
        Set(playerRoutes.flatMap(\.competitors))
    }

    // MARK: - Ownership economy (Phase 5)

    static let startingCapital = 20_000_000

    /// A held aircraft (AOG/crew) still costs money at the gate, but a PARKED
    /// aircraft doesn't burn full in-flight block-hour cost — only idle cost
    /// (crew standby, gate, opportunity). So hold burn is a FRACTION of the flight
    /// operating rate. Early-game tuning: at the full rate, an under-crewed
    /// starter regional lost ~$5k/held-leg (ruinous, ~3 profitable legs); at 0.4
    /// it's a recoverable setback that still signals "hire crew" (you also lose
    /// the flights themselves while held). The AOG expedite-vs-standard tradeoff
    /// still holds — the standard repair's timed burn is smaller now, so expedite
    /// stays a premium reserved for expensive aircraft / lost high-value revenue.
    static let holdBurnRate = 0.4

    /// The player's airline name. nil until the first-launch naming screen is
    /// completed (which blocks the game until then). Defaults to "New Airline".
    private(set) var playerAirlineName: String?
    /// The 2-letter code stamped into every owned aircraft's tail (e.g. "ZQ" →
    /// "N1ZQ"). Chosen on the naming screen; can't match a real airline code
    /// (validated there). Defaults to a safe fictional code if left blank.
    private(set) var playerTailCode = "ZQ"
    func nameAirline(_ name: String, tailCode: String = "") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        playerAirlineName = trimmed.isEmpty ? "New Airline" : trimmed
        let code = tailCode.uppercased().filter { $0.isLetter }
        // Ignore an invalid/blank/colliding code and keep the safe default.
        if code.count == 2 && Airline.realCodes[code] == nil { playerTailCode = code }
    }

    private(set) var playerBalance = startingCapital
    private(set) var playerRoutes: [Route] = []
    /// Routes archived (not deleted) when their aircraft was sold — full
    /// history preserved so a closed route stays reviewable.
    private(set) var closedPlayerRoutes: [Route] = []
    private var nextRouteId = 1

    /// Open + closed routes, newest first (for the ROUTES panel).
    var allRoutes: [Route] { (playerRoutes + closedPlayerRoutes).sorted { $0.openedTick > $1.openedTick } }

    /// "Day N · HH:MM" from a tick (1 tick = 1 sim-minute).
    static func simDate(fromTick t: Int) -> String {
        let day = t / 1440 + 1
        let mins = t % 1440
        return String(format: "Day %d · %02d:%02d", day, mins / 60, mins % 60)
    }

    var ownedCount: Int { aircraft.lazy.filter { $0.purchased }.count }
    /// Aircraft owned OUTRIGHT (bought, not leased) — the ones that are real,
    /// sellable assets. A leased aircraft isn't yours to sell, so it isn't a
    /// balance-sheet asset (its lease is an ongoing expense, not equity).
    var ownedOutrightCount: Int { aircraft.lazy.filter { $0.purchased && !$0.isLeased }.count }
    var leasedCount: Int { aircraft.lazy.filter { $0.purchased && $0.isLeased }.count }
    /// Current resale value of owned-outright aircraft (each at its depreciated
    /// sell value) — the "assets" side of the Finance net-worth view. Leased
    /// aircraft are deliberately excluded (see ownedOutrightCount).
    var fleetMarketValue: Int { aircraft.lazy.filter { $0.purchased && !$0.isLeased }.reduce(0) { $0 + sellValue(of: $1) } }
    var stressTestCount: Int { aircraft.lazy.filter { !$0.purchased }.count }
    /// Purchased aircraft with no route yet — available to assign to a new one.
    var idleSpares: [Aircraft] { aircraft.filter { $0.isIdleSpare } }

    /// Slot scarcity: busier/more-expensive airports get fewer slots (3–13),
    /// starting 30–70% available. Ported from the setup pass around AIRPORTS.
    private func provisionSlots() {
        let sorted = airports.sorted { $0.landingFeePerKlb < $1.landingFeePerKlb }
        let n = max(1, sorted.count - 1)
        for (i, ap) in sorted.enumerated() {
            // cheapest (i=0) → ~13 slots, most expensive → floor of 3
            ap.slotsTotal = max(3, 13 - Int((Double(i) / Double(n) * 10).rounded()))
            ap.slotsAvailable = max(1, Int((Double(ap.slotsTotal) * (0.3 + Double.random(in: 0..<0.4))).rounded()))
        }
    }

    /// Slots slowly free up (abstract background churn). ~5%/day per airport
    /// under capacity. Ported from tickSlotAvailability().
    private func tickSlotAvailability() {
        guard tick % 1440 == 0 else { return }   // once per sim-day
        for ap in airports where ap.slotsAvailable < ap.slotsTotal {
            if Double.random(in: 0..<1) < 0.05 { ap.slotsAvailable += 1 }
        }
    }

    // MARK: Buying

    // CONUS bounds (matches the default camera frame). A fresh spare spawns at
    // a CONUS airport so it's VISIBLE in the default view — spawning at an
    // off-screen AK/HI base (ANC lat 61 / HNL lat 21) made a new spare
    // invisible and untappable until it was routed. The base is cosmetic
    // (openRoute reassigns origin), so restricting it purely improves
    // visibility; background traffic is unaffected (it can fly AK/HI freely).
    /// Airports in the player's home region (falls back to all if somehow empty).
    var homeAirports: [Airport] {
        let regs = Set(homeRegion.gameRegions)
        let inside = airports.filter { regs.contains(Airline.region($0.code)) }
        return inside.isEmpty ? airports : inside
    }

    /// Home-region airports inside the default frame — spare bases come from
    /// here so a fresh purchase is always VISIBLE in the starting view (for
    /// North America this excludes ANC/HNL, same rule as the old CONUS pool).
    private var homeBaseAirports: [Airport] {
        let f = homeFrame
        let inside = homeAirports.filter {
            $0.unit.x >= f.origin.x && $0.unit.x <= f.origin.x + f.size.width
                && $0.unit.y >= f.origin.y && $0.unit.y <= f.origin.y + f.size.height
        }
        return inside.isEmpty ? homeAirports : inside
    }

    /// A genuinely fresh purchase — 0 cycles, PARKED at a random home-region
    /// base, no route (a spare). Separate from makeAircraft (stress-test).
    private func makePurchasedAircraft(_ type: AircraftType, startingCycles: Int = 0) -> Aircraft {
        let base = homeBaseAirports.randomElement()!
        let tail = "N\(nextTailNum)\(playerTailCode)"
        nextTailNum += 1
        let ac = Aircraft(tail: tail, type: type, origin: base, dest: base,
                          stateIndex: FlightState.parked.rawValue,
                          cyclesAccrued: startingCycles, purchased: true)
        rollRevenue(for: ac)
        return ac
    }

    /// Buy an aircraft if affordable. Returns the new spare (to auto-assign to a
    /// pending route) or nil.
    @discardableResult
    func buyAircraft(_ type: AircraftType) -> Aircraft? {
        guard playerBalance >= type.purchasePrice else { return nil }
        playerBalance -= type.purchasePrice
        totalAcquisitionSpend += type.purchasePrice
        let ac = makePurchasedAircraft(type)
        aircraft.append(ac)
        grantBundledCrew(type.family)   // 1 crew bundled; the player hires more
        return ac
    }

    // MARK: Leasing

    /// Upfront cost to lease instead of buy: 15% of purchase price
    /// (LEASE_UPFRONT_RATE). Lower capital now, but the fixed monthly bill
    /// (type.monthlyLeaseCost, tickLeaseBilling) makes a leased aircraft cost
    /// more over time — a genuine tradeoff, not a strictly-better option.
    static let leaseUpfrontRate = 0.15

    func leaseUpfront(_ type: AircraftType) -> Int {
        Int((Double(type.purchasePrice) * Simulation.leaseUpfrontRate).rounded())
    }

    /// Running total of all fixed lease bills paid (a separate line from
    /// operating cost at the data layer, per the prototype's design).
    private(set) var totalLeaseCost = 0

    /// Lease an aircraft if the upfront cost is affordable. Returns the new
    /// spare (to auto-assign to a pending route) or nil. Ported from
    /// leaseAircraft().
    @discardableResult
    func leaseAircraft(_ type: AircraftType) -> Aircraft? {
        let upfront = leaseUpfront(type)
        guard playerBalance >= upfront else { return nil }
        playerBalance -= upfront
        totalAcquisitionSpend += upfront
        let ac = makePurchasedAircraft(type)
        ac.isLeased = true
        aircraft.append(ac)
        grantBundledCrew(type.family)   // 1 crew bundled; the player hires more
        return ac
    }

    /// Charge every leased aircraft its fixed monthly obligation, ACCRUED
    /// CONTINUOUSLY per tick (monthlyLeaseCost / ticksPerMonth) rather than as a
    /// monthly lump. This means a leased aircraft's cost shows up immediately in
    /// its route P&L and the running lease total (a lump-sum model left a leased
    /// route reading $0 lease for its whole first sim-month, then a big jump).
    /// The charge lands regardless of whether the aircraft is flying, held, or
    /// an idle spare, so leasing stays a real fixed obligation (NOT the earlier
    /// per-leg proration bug, which made idle leases free). Sub-dollar remainders
    /// carry in ac.leaseAccrued so nothing is lost to rounding. playerBalance is
    /// allowed to go negative (no bankruptcy mechanic yet).
    /// Committed once per sim-HOUR (not per tick). The obligation is unchanged —
    /// the same monthly total drains — but it's applied in hourly steps so the
    /// displayed lease total updates at a readable cadence instead of flickering
    /// "multiple times a second" at high game speed.
    private static let leaseBillIntervalTicks = 60   // 1 sim-hour
    private func tickLeaseBilling() {
        guard tick % Simulation.leaseBillIntervalTicks == 0 else { return }
        let perInterval: (AircraftType) -> Double = {
            Double($0.monthlyLeaseCost) / Double(Simulation.ticksPerMonth) * Double(Simulation.leaseBillIntervalTicks)
        }
        for ac in aircraft where ac.isLeased {
            ac.leaseAccrued += perInterval(ac.type)
            let bill = Int(ac.leaseAccrued)   // whole dollars due this hour
            guard bill > 0 else { continue }
            ac.leaseAccrued -= Double(bill)
            playerBalance -= bill
            totalLeaseCost += bill
            if let id = ac.assignedRouteId, let r = playerRoutes.first(where: { $0.id == id }) {
                r.totalLeaseCost += bill
                r.cumulativeNet -= bill   // a real cost against this route's P&L
            }
        }
    }

    // MARK: Routes

    static let routeBaseCost = 50_000
    static let routeCostPerGateFeeUnit = 50
    static let routeSlotPurchasePremium = 75_000

    func route(between a: String, _ b: String) -> Route? {
        playerRoutes.first { ($0.originCode == a && $0.destCode == b) || ($0.originCode == b && $0.destCode == a) }
    }

    /// Real opening cost: base + both endpoints' gate fees, plus a premium per
    /// endpoint with no free slot. Ported from computeRouteOpeningCost().
    /// Leisure economics (designer-specified pair, deliberately opposed): island
    /// fares run a PREMIUM (+15%), but ESTABLISHING an island route costs more
    /// (×1.75 — "labor, setup costs, materials all cost more in a leisure
    /// destination"). Bigger buy-in, richer payback curve. DESIGNED pacing.
    static let leisureFareMultiplier = 1.15
    static let leisureOpeningCostMultiplier = 1.75

    func routeOpeningCost(_ origin: Airport, _ dest: Airport) -> Int {
        var cost = Double(Simulation.routeBaseCost)
                 + Double(origin.gateFeeNarrowbody + dest.gateFeeNarrowbody) * Double(Simulation.routeCostPerGateFeeUnit)
        // Slot-buyout premium is WAIVED at the player's own operating hub
        // (you hold the gates there).
        if origin.slotsAvailable <= 0, !hubOperating(origin.code) { cost += Double(Simulation.routeSlotPurchasePremium) }
        if dest.slotsAvailable <= 0, !hubOperating(dest.code) { cost += Double(Simulation.routeSlotPurchasePremium) }
        if Airport.isLeisure(origin.code) || Airport.isLeisure(dest.code) {
            cost *= Simulation.leisureOpeningCostMultiplier
        }
        return Int(cost.rounded())
    }

    enum OpenRouteResult { case success, sameAirport, alreadyOpen, noSpare, insufficientFunds(Int), outOfRange, runwayTooShort(String) }

    /// A physical reason `ac` can't fly `origin`→`dest`: the leg exceeds its
    /// range, or an endpoint's longest runway is too short for the type. nil = OK.
    /// (Airports with no runway data don't block — data-gap tolerant.)
    enum RouteBlock { case range(Int), runway(String) }
    func routeBlock(for ac: Aircraft, from origin: Airport, to dest: Airport) -> RouteBlock? {
        let nm = Int(origin.greatCircleNM(to: dest).rounded())
        if nm > ac.type.rangeNM { return .range(nm) }
        let minRw = ac.type.minRunwayFt   // per-type (Dash 8 STOL override) or tier default
        if let rw = origin.info?.longestRunwayFt, rw < minRw { return .runway(origin.code) }
        if let rw = dest.info?.longestRunwayFt, rw < minRw { return .runway(dest.code) }
        return nil
    }

    /// Create the Route (charge cost, consume slots, log). Shared by openRoute
    /// (staffed now) and the airport-offer accept path (may open PENDING — no
    /// aircraft yet). Does NOT assign an aircraft.
    @discardableResult
    private func createRoute(from origin: Airport, to dest: Airport, cost: Int,
                             incentiveBonus: Int = 0, waived: Int = 0) -> Route {
        playerBalance -= cost
        totalRouteSpend += cost
        if origin.slotsAvailable > 0 { origin.slotsAvailable -= 1 }
        if dest.slotsAvailable > 0 { dest.slotsAvailable -= 1 }
        let r = Route(id: nextRouteId, originCode: origin.code, destCode: dest.code,
                      openedTick: tick, openingCost: cost)
        r.incentiveBonus = incentiveBonus
        r.incentiveWaived = waived
        nextRouteId += 1
        playerRoutes.append(r)
        routeOpenPulse = RoutePulse(a: origin.code, b: dest.code, tick: tick)   // map ripple
        logOps(.structural, "Route opened", "\(origin.code) ↔︎ \(dest.code)")
        return r
    }

    /// Assign an idle spare to fly a route (range/runway assumed already checked).
    private func assign(_ ac: Aircraft, to r: Route, origin: Airport, dest: Airport) {
        r.assignmentHistory.append(RouteAssignment(id: r.assignmentHistory.count, tail: ac.tail,
                                                   typeName: ac.type.name, assignedTick: tick))
        ac.assignedRouteId = r.id
        ac.origin = origin
        ac.dest = dest
        ac.stateIndex = FlightState.parked.rawValue
        ac.stateTick = 0
        rollRevenue(for: ac)
    }

    /// Open a route and assign a spare to fly it. `subsidized` (an airport
    /// incentive) waives the opening cost entirely. Ported from openRoute().
    @discardableResult
    func openRoute(from origin: Airport, to dest: Airport, using ac: Aircraft, subsidized: Bool = false) -> OpenRouteResult {
        guard ac.purchased, ac.assignedRouteId == nil else { return .noSpare }
        return openRouteCore(from: origin, to: dest, using: ac, subsidized: subsidized)
    }

    /// Move an owned aircraft onto a BRAND-NEW route, whether it is currently an
    /// idle spare or already flying something. If it is already on a route, that
    /// route is archived first (full P&L history preserved, slots freed) — the
    /// same teardown selling uses — so the player is trading one route for
    /// another, not silently accumulating an unstaffed one.
    ///
    /// Detaching happens BEFORE the new route is created, so a reassignment that
    /// reuses one of the old endpoints gets that slot back rather than being
    /// blocked by its own aircraft.
    @discardableResult
    func reassign(_ ac: Aircraft, from origin: Airport, to dest: Airport) -> OpenRouteResult {
        guard ac.purchased else { return .noSpare }
        return openRouteCore(from: origin, to: dest, using: ac, subsidized: false, detaching: true)
    }

    /// True if `ac` is airborne / mid-turn rather than sitting at a gate, i.e. a
    /// reassignment must wait for it to finish the leg it's flying.
    func isEnRoute(_ ac: Aircraft) -> Bool {
        ac.assignedRouteId != nil && ac.stateIndex != FlightState.parked.rawValue
    }

    /// The route an aircraft is moving to once it lands (for the Fleet card).
    func pendingRoute(for ac: Aircraft) -> Route? {
        guard let id = ac.pendingRouteId else { return nil }
        return playerRoutes.first { $0.id == id }
    }

    /// Complete a deferred reassignment: called when the aircraft reaches a gate.
    /// Archives the route it just left and puts it on the one the player chose.
    private func completePendingReassignment(_ ac: Aircraft) {
        guard let id = ac.pendingRouteId else { return }
        guard let r = playerRoutes.first(where: { $0.id == id }),
              let o = airport(r.originCode), let d = airport(r.destCode) else {
            ac.pendingRouteId = nil   // route vanished (e.g. slot buyback) — drop it
            return
        }
        ac.pendingRouteId = nil
        detachFromRoute(ac)
        assign(ac, to: r, origin: o, dest: d)
        logOps(.structural, "Aircraft reassigned", "\(ac.tail) → \(r.originCode) ↔\u{FE0E} \(r.destCode)")
    }

    /// Archive the aircraft's current route (if any) and free it up. Mirrors the
    /// route half of `liquidate` — the aircraft itself is kept.
    private func detachFromRoute(_ ac: Aircraft) {
        guard let id = ac.assignedRouteId,
              let idx = playerRoutes.firstIndex(where: { $0.id == id }) else { return }
        ac.assignedRouteId = nil
        let r = playerRoutes.remove(at: idx)
        r.closedTick = tick
        closedPlayerRoutes.append(r)
        decisionQueue.removeAll { $0.kind == .offer && $0.offer?.routeId == id }
        airports.first { $0.code == r.originCode }?.slotsAvailable += 1
        airports.first { $0.code == r.destCode }?.slotsAvailable += 1
        logOps(.structural, "Route closed", "\(r.originCode) ↔︎ \(r.destCode) — \(ac.tail) reassigned")
    }

    private func openRouteCore(from origin: Airport, to dest: Airport, using ac: Aircraft,
                               subsidized: Bool, detaching: Bool = false) -> OpenRouteResult {
        if origin === dest { return .sameAirport }
        if route(between: origin.code, dest.code) != nil { return .alreadyOpen }
        switch routeBlock(for: ac, from: origin, to: dest) {
        case .range:  return .outOfRange
        case .runway(let code): return .runwayTooShort(code)
        case nil: break
        }
        let cost = subsidized ? 0 : routeOpeningCost(origin, dest)
        guard playerBalance >= cost else { return .insufficientFunds(cost) }
        // An aircraft that's already airborne finishes its leg first (real-world
        // behaviour): create + pay for the new route now, but leave the old one
        // flying until it lands, then swap in completePendingReassignment().
        let defer_ = detaching && isEnRoute(ac)
        if detaching && !defer_ { detachFromRoute(ac) }
        let r = createRoute(from: origin, to: dest, cost: cost)
        // Surfacing: the moment an airport reaches hub eligibility, say so.
        for code in [origin.code, dest.code]
        where routesAt(code) == Simulation.hubMinRoutes && hubs[code] == nil && rivalHubs[code] == nil {
            logOps(.structural, "\(code) reached hub eligibility",
                   "\(Simulation.hubMinRoutes) routes now use \(code) — you can establish a hub (tap the airport)",
                   airportCode: code)
        }
        if defer_ {
            ac.pendingRouteId = r.id
            logOps(.structural, "Reassignment scheduled",
                   "\(ac.tail) moves to \(origin.code) ↔\u{FE0E} \(dest.code) after it lands at \(ac.dest.code)")
        } else {
            assign(ac, to: r, origin: origin, dest: dest)
        }
        return .success
    }

    // MARK: Pending routes (opened by an accepted offer, awaiting an aircraft)

    /// True if some owned aircraft is flying this route.
    func routeStaffed(_ r: Route) -> Bool { aircraft.contains { $0.purchased && $0.assignedRouteId == r.id } }
    /// Open routes with no aircraft yet (accepted an offer, still need a plane).
    var pendingRoutes: [Route] { playerRoutes.filter { !routeStaffed($0) } }

    // MARK: Assignment intent (Fleet → "ASSIGN TO NEW ROUTE")

    /// The aircraft the player tapped ASSIGN TO NEW ROUTE on, carried across the
    /// tab switch into the Network route-pick flow so the route they draw is
    /// flown by THAT aircraft — not by whichever spare happens to be first.
    /// Transient (not persisted); cleared when the flow ends.
    var pendingAssignment: Aircraft?
    func beginAssignment(_ ac: Aircraft) { pendingAssignment = ac }
    func clearAssignment() { pendingAssignment = nil }

    /// Why a pending route hasn't been auto-staffed yet, in one short player-
    /// facing phrase (nil once staffed). `assignSpareToPendingRoutes` assigns
    /// the first idle spare that clears the route every tick — so a route that's
    /// STILL pending means either there's no idle spare, or every spare is
    /// physically blocked (range, then runway). Surfaced in the Ops incentive
    /// box so "Awaiting aircraft" isn't a mystery.
    func pendingStaffingReason(_ r: Route) -> String? {
        guard !routeStaffed(r), let o = airport(r.originCode), let d = airport(r.destCode) else { return nil }
        let nm = Int(o.greatCircleNM(to: d).rounded())
        let spares = idleSpares
        if spares.isEmpty { return "No idle aircraft — buy or free one" }
        // A spare exists but none could be assigned → all are blocked. If none
        // even has the range, that's the wall; otherwise a runway is too short.
        if (spares.map { $0.type.rangeNM }.max() ?? 0) < nm {
            return "No spare has the range — needs ~\(nm.formatted()) nm"
        }
        for s in spares {
            if case .runway(let code) = routeBlock(for: s, from: o, to: d) {
                return "\(code) runway too short for your spare"
            }
        }
        return "No spare can fly this route"
    }
    /// Open routes that received an airport incentive (for the Ops box).
    var incentedRoutes: [Route] { playerRoutes.filter { $0.hasIncentive } }

    /// Auto-staff pending routes with an idle spare that can fly them (oldest
    /// pending first). So after accepting an offer, buying an aircraft in range
    /// puts it on that route. Runs per tick, early-returning when no spare exists.
    private func assignSpareToPendingRoutes() {
        guard !idleSpares.isEmpty else { return }
        // Skip routes already reserved by a deferred reassignment — that route
        // belongs to an aircraft still finishing its current leg.
        for r in playerRoutes where !routeStaffed(r)
            && !aircraft.contains(where: { $0.pendingRouteId == r.id }) {
            guard let o = airport(r.originCode), let d = airport(r.destCode) else { continue }
            if let spare = idleSpares.first(where: { routeBlock(for: $0, from: o, to: d) == nil }) {
                assign(spare, to: r, origin: o, dest: d)
                logOps(.structural, "Aircraft assigned", "\(spare.tail) → \(r.originCode) ↔\u{FE0E} \(r.destCode)")
            }
        }
    }

    // MARK: Selling

    /// Linear depreciation from purchase price, floored at 5%. Ported from
    /// computeSellValue().
    func sellValue(of ac: Aircraft) -> Int {
        let used = Double(ac.cyclesAccrued) / Double(max(1, ac.type.expectedLifespanCycles))
        let remaining = max(0.05, 1 - used)
        return Int((Double(ac.type.purchasePrice) * remaining).rounded())
    }

    // MARK: - Used-aircraft market (buy-only, persistent inventory)

    /// One pre-owned listing: a specific airframe at a real cycle count and its
    /// depreciated price. Persists in `usedInventory` until bought or replaced.
    struct UsedListing: Identifiable {
        let id: Int
        let typeId: String
        let cyclesAccrued: Int
        let price: Int
    }

    /// Listings per type id. Generated at game start, removed on purchase,
    /// slowly replenished (so a long session doesn't permanently deplete it).
    private(set) var usedInventory: [String: [UsedListing]] = [:]
    private var nextUsedListingId = 1

    /// Pricing reuses the EXACT SAME linear depreciation as sellValue() — a
    /// deliberate consistency with the sell mechanic, not a new formula.
    private func usedPrice(_ type: AircraftType, cyclesAccrued: Int) -> Int {
        let usedFraction = Double(cyclesAccrued) / Double(max(1, type.expectedLifespanCycles))
        return Int((Double(type.purchasePrice) * max(0.05, 1 - usedFraction)).rounded())
    }

    /// A listing at 15–75% of expected life — meaningfully used, not
    /// near-new or near-scrap, so the market has real variety.
    private func generateUsedListing(_ type: AircraftType) -> UsedListing {
        let cycles = Int((Double(type.expectedLifespanCycles) * (0.15 + Double.random(in: 0..<0.6))).rounded())
        defer { nextUsedListingId += 1 }
        return UsedListing(id: nextUsedListingId, typeId: type.id,
                           cyclesAccrued: cycles, price: usedPrice(type, cyclesAccrued: cycles))
    }

    /// 1–2 listings per type at game start (called once from init).
    private func initializeUsedInventory() {
        for type in AircraftType.all {
            let count = 1 + Int.random(in: 0...1)
            usedInventory[type.id] = (0..<count).map { _ in generateUsedListing(type) }
        }
    }

    /// Slowly refill toward 2 listings/type (another airline selling, a lessor's
    /// aircraft coming off lease). Once per sim-day, 10% chance per under-stocked
    /// type. Ported from tickUsedMarketReplenishment().
    private func tickUsedMarketReplenishment() {
        guard tick % 1440 == 0 else { return }
        for type in AircraftType.all {
            let listings = usedInventory[type.id] ?? []
            if listings.count < 2, Double.random(in: 0..<1) < 0.1 {
                usedInventory[type.id, default: []].append(generateUsedListing(type))
            }
        }
    }

    /// All current listings flattened, cheapest first (for the USED panel).
    var usedListings: [UsedListing] {
        usedInventory.values.flatMap { $0 }.sorted { $0.price < $1.price }
    }

    /// Buy a specific used listing. A purchased used aircraft inherits the
    /// listing's real cycle count (NOT 0). Returns the new spare or nil.
    @discardableResult
    func buyUsedAircraft(_ listing: UsedListing) -> Aircraft? {
        guard let type = AircraftType.all.first(where: { $0.id == listing.typeId }),
              var listings = usedInventory[listing.typeId],
              let idx = listings.firstIndex(where: { $0.id == listing.id }),
              playerBalance >= listing.price else { return nil }
        playerBalance -= listing.price
        totalAcquisitionSpend += listing.price
        let ac = makePurchasedAircraft(type, startingCycles: listing.cyclesAccrued)
        aircraft.append(ac)
        grantBundledCrew(type.family)   // 1 crew bundled; the player hires more
        listings.remove(at: idx)          // sold — gone until replenishment
        usedInventory[listing.typeId] = listings
        return ac
    }

    // MARK: - Fleet

    /// Spawn one stress-test aircraft — weighted type, random route, staggered
    /// start. Ported from makeAircraft().
    // MARK: Background-traffic geography (airline-first, region-constrained)

    /// Airports grouped by carrier region (computed once from Airport.all).
    @ObservationIgnored private lazy var airportsByRegion: [Airline.Region: [Airport]] = {
        var m: [Airline.Region: [Airport]] = [:]
        for ap in airports { m[Airline.region(ap.code), default: []].append(ap) }
        return m
    }()

    /// Per-region international GATEWAYS = the busiest ~35% of that region's
    /// airports (min 2) by annual passengers. Only a gateway can be the endpoint
    /// of a cross-region international leg, so a small airport (Oklahoma City,
    /// Bozeman) stays domestic-only and never gets a foreign carrier flying in.
    @ObservationIgnored private lazy var gatewaysByRegion: [Airline.Region: Set<String>] = {
        var m: [Airline.Region: Set<String>] = [:]
        for (region, aps) in airportsByRegion {
            let sorted = aps.sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
            let n = max(2, Int((Double(sorted.count) * 0.35).rounded()))
            m[region] = Set(sorted.prefix(n).map { $0.code })
        }
        return m
    }()

    /// Region spawn weights ∝ each region's airport count (a simple, self-adjusting
    /// proxy for its share of air traffic — the US, with the most airports, spawns
    /// the most traffic).
    @ObservationIgnored private lazy var backgroundRegionPool: [(Airline.Region, Int)] = {
        Airline.allRegions.compactMap { r in
            let c = airportsByRegion[r]?.count ?? 0
            return c > 0 ? (r, c) : nil
        }
    }()

    private func pickBackgroundRegion() -> Airline.Region {
        let total = backgroundRegionPool.reduce(0) { $0 + $1.1 }
        var r = Int.random(in: 0..<max(1, total))
        for (region, w) in backgroundRegionPool { r -= w; if r < 0 { return region } }
        return .us
    }

    /// A plausible leg for a carrier whose home region is `region`: mostly a
    /// domestic leg within the region; occasionally (from a gateway only) an
    /// international leg to a plausible neighbour region's gateway. This is what
    /// keeps a carrier inside its real sphere — no more "EgyptAir to OKC".
    /// A leg the carrier plausibly flies, RANGE-GATED to the aircraft type — a
    /// narrowbody won't be handed a transatlantic corridor (the "American A320
    /// FLL→BCN" bug), only widebodies with the legs to reach get long ones. Short
    /// international corridors (US↔Mexico/Canada) stay open to narrowbodies, which
    /// is realistic.
    func backgroundLeg(for region: Airline.Region, type: AircraftType) -> (Airport, Airport) {
        let range = Double(type.rangeNM)
        let pool = airportsByRegion[region] ?? airports
        guard let origin = pool.randomElement() else { return Airport.randomPair() }
        // International: from a gateway only, ~25% of the time, to a neighbour
        // gateway that's actually WITHIN this aircraft's range.
        if (gatewaysByRegion[region]?.contains(origin.code) ?? false), Int.random(in: 0..<100) < 25,
           let neighbours = Airline.corridors[region] {
            let viable = neighbours.filter { !(gatewaysByRegion[$0]?.isEmpty ?? true) }
            if let nr = viable.randomElement(), let gws = gatewaysByRegion[nr] {
                let dests = (airportsByRegion[nr] ?? []).filter { gws.contains($0.code) && origin.greatCircleNM(to: $0) <= range }
                if let dest = dests.randomElement() { return (origin, dest) }
                // No in-range international dest → fall through to a domestic leg.
            }
        }
        // Domestic: another in-region airport within range.
        guard pool.count > 1 else { return (origin, origin) }
        let inRange = pool.filter { $0 !== origin && origin.greatCircleNM(to: $0) <= range }
        if let dest = inRange.randomElement() { return (origin, dest) }
        // Origin too remote for this type — use the nearest airport (minimizes any
        // residual over-range; a rare, purely-cosmetic edge for background traffic).
        let nearest = pool.filter { $0 !== origin }
            .min { origin.greatCircleNM(to: $0) < origin.greatCircleNM(to: $1) }
        return (origin, nearest ?? origin)
    }

    /// A type the carrier actually flies, weighted by that type's global commonness.
    private func pickBackgroundType(for airline: Airline) -> AircraftType {
        let types = airline.types.compactMap { AircraftType.byId[$0] }
        guard !types.isEmpty else { return AircraftType.pickWeighted() }
        let total = types.reduce(0) { $0 + $1.weight }
        var r = Int.random(in: 0..<max(1, total))
        for t in types { r -= t.weight; if r < 0 { return t } }
        return types.last!
    }

    private func makeAircraft() -> Aircraft {
        // Airline-FIRST: pick a region (weighted by traffic) → a carrier in it →
        // a type it flies → a route in its geographic sphere. Each background
        // aircraft is thus ONE coherent airline that never flies outside its real
        // reach. (The old model picked a random GLOBAL airport pair every leg while
        // keeping the spawn carrier — that's how "EgyptAir to Oklahoma City" happened.)
        let region = pickBackgroundRegion()
        let airline = Airline.weighted(Airline.roster(for: region))
        let type = pickBackgroundType(for: airline)
        let (origin, dest) = backgroundLeg(for: region, type: type)
        // Tail carries the carrier's real IATA code (Delta → "N123DL"); the
        // generic fallback gets a random non-real code so they aren't uniform.
        let code = airline.code.isEmpty ? Airline.randomTailCode() : airline.code
        let tail = "N\(nextTailNum)\(code)"
        nextTailNum += 1
        let ac = Aircraft(tail: tail,
                          type: type,
                          origin: origin,
                          dest: dest,
                          stateIndex: Int.random(in: 0..<FlightState.allCases.count),
                          cyclesAccrued: Int.random(in: 0..<Int(Double(type.expectedLifespanCycles) * 0.9)))
        ac.airlineName = airline.name
        ac.homeRegion = region
        rollRevenue(for: ac)   // seed this leg's revenue before its first arrival
        return ac
    }

    /// Grow or shrink the fleet to `n` (stress-test control; all aircraft are
    /// non-owned so a plain trim is fine — the purchased-vs-spawn distinction
    /// arrives with the Phase 5 economy).
    /// DEV stress-test control — sets the count of NON-OWNED background
    /// aircraft, never touching the player's purchased fleet.
    func setFleetSize(_ n: Int) {
        let target = max(0, n)
        let current = stressTestCount
        if target < current {
            var toRemove = current - target
            let removed = aircraft.filter { !$0.purchased }.suffix(toRemove)
            aircraft.removeAll { ac in
                if !ac.purchased && toRemove > 0 { toRemove -= 1; return true }
                return false
            }
            decisionQueue.removeAll { d in removed.contains(where: { $0 === d.aircraft }) }
        } else {
            while stressTestCount < target { aircraft.append(makeAircraft()) }
        }
        resizeCrewPools()   // cleanup only (background traffic uses no crew)
    }

    var fleetCount: Int { aircraft.count }

    // MARK: - Tick

    /// Ticks in a 30-day sim-month (1 tick = 1 sim-minute). Used for
    /// converting real per-month event rates into per-tick probabilities.
    static let ticksPerMonth = 30 * 24 * 60   // 43,200

    // MARK: - AOG (unscheduled maintenance), ported from tickAOGOnset()

    /// Real anchor: ~2 incidents/month for a 100-aircraft airline, as a
    /// continuous per-aircraft per-tick probability (NOT bracketed tiers).
    static let aogRatePerAircraftPerMonth = 2.0 / 100.0
    static let aogProbPerTick = aogRatePerAircraftPerMonth / Double(ticksPerMonth)
    /// One incident temporarily triples AOG risk for the SAME family only
    /// (real-world analog: type-wide ADs / bad parts batches), decaying
    /// linearly over 3 sim-days. Families never cross-contaminate.
    static let aogClusterMultiplier = 3.0
    static let aogClusterDecayTicks = 4320   // 3 sim-days

    private var familyPressureTicksLeft: [String: Int] = [:]

    /// NOTE (ownership scoping): the prototype gates AOG on `ac.purchased` —
    /// background traffic never experiences it. Ownership doesn't exist until
    /// Phase 5, so for now the whole stress-test fleet is eligible. Re-scope
    /// this when `purchased` lands (see TASKS.md / CLAUDE.md — the prototype
    /// had a real reported bug from missing exactly this retrofit).
    private func tickAOGOnset() {
        for (f, left) in familyPressureTicksLeft where left > 0 {
            familyPressureTicksLeft[f] = left - 1
        }
        for ac in aircraft where ac.purchased && !ac.maint {
            let pressure = Double(familyPressureTicksLeft[ac.type.family] ?? 0)
                         / Double(Simulation.aogClusterDecayTicks)
            let multiplier = 1 + (Simulation.aogClusterMultiplier - 1) * pressure
            if Double.random(in: 0..<1) < Simulation.aogProbPerTick * multiplier * ac.aogAgeMultiplier {
                ac.maint = true
                // this incident (re)opens the elevated window for the family
                familyPressureTicksLeft[ac.type.family] = Simulation.aogClusterDecayTicks
            }
        }
    }

    // MARK: - Crew (per-family pools, FAA Part 117 duty/rest)

    // PLAYER-DRIVEN crew model (ported from the prototype, replacing the native
    // app's auto-ratio stand-in). Buying/leasing an aircraft bundles exactly 1
    // crew — deliberately NOT enough for continuous operation once duty/rest
    // limits kick in (a crew flies ~55% of the time), which is the real pressure
    // toward hiring more via the ADD CREW panel. A family's FIRST aircraft also
    // seeds 1 reserve (1 bundled + 1 reserve = 2 crew total on the first tail —
    // the corrected count, was 2 reserves). `crewsPerTail` (6 short / 11 long
    // haul) is now purely a REFERENCE figure the player reasons about — no code
    // consumes it, so the old cascade-prone auto-ratio is gone entirely.
    private static let reservesPerFamily = 1
    /// Crew hire cost = 0.2% of a representative aircraft's price (scales with
    /// complexity: ~$28K regional-jet crew … ~$578K widebody crew). A DESIGNED
    /// estimate, not deeply sourced.
    private static let crewHireCostRate = 0.002

    private(set) var crewPoolsByFamily: [String: [Crew]] = [:]
    private(set) var reserveCrewsByFamily: [String: Int] = [:]

    /// Families the player currently owns aircraft in (for the ADD CREW panel —
    /// never the full 15). Insertion-ordered by first-owned.
    var ownedFamilies: [String] {
        var seen = Set<String>(), out = [String]()
        for ac in aircraft where ac.purchased && !seen.contains(ac.type.family) {
            seen.insert(ac.type.family); out.append(ac.type.family)
        }
        return out
    }
    func crewCount(family: String) -> Int { crewPoolsByFamily[family]?.count ?? 0 }
    func ownedCount(family: String) -> Int { aircraft.lazy.filter { $0.purchased && $0.type.family == family }.count }

    /// Bundle exactly 1 crew with a bought/leased aircraft; seed 1 reserve if
    /// this is the family's first aircraft. Ported from grantBundledCrew().
    private func grantBundledCrew(_ family: String) {
        if crewPoolsByFamily[family]?.isEmpty ?? true {
            reserveCrewsByFamily[family] = Simulation.reservesPerFamily
        }
        let id = crewPoolsByFamily[family]?.count ?? 0
        crewPoolsByFamily[family, default: []].append(Crew(id: id))
    }

    /// Cleanup pass ONLY — clears a family's pool/reserves to 0 once its owned
    /// count hits zero (last one sold). Never grows or shrinks by any ratio
    /// (that's the player's job now). Ported from the rewritten resizeCrewPools().
    private func resizeCrewPools() {
        for family in Array(crewPoolsByFamily.keys) where ownedCount(family: family) == 0 {
            crewPoolsByFamily[family] = nil
            reserveCrewsByFamily[family] = nil
            crewTrainingDueByFamily[family] = nil
            crewTrainingDeferredByFamily[family] = nil
            crewTrainingExpiryByFamily[family] = nil
            decisionQueue.removeAll { $0.kind == .training && $0.trainingFamily == family }
        }
    }

    /// Cost to hire one crew in a family (0.2% of a representative aircraft's
    /// price). Same function the ADD CREW panel and the CREW card's hire option
    /// both use.
    func crewHireCost(family: String) -> Int {
        let price = AircraftType.all.first { $0.family == family }?.purchasePrice ?? 0
        return Int((Double(price) * Simulation.crewHireCostRate).rounded())
    }

    // MARK: - Recurrent crew training (a recurring decision, real regulatory analog)

    // Crews need periodic recurrent training (real FAA requirement). It comes due
    // per owned family on a recurring cycle; the player can train NOW (a real
    // cost + some crew sidelined for the training window) or DEFER 30 days at a
    // higher cost (a rush/premium later). Pacing is designed, not sourced.
    private static let crewTrainingIntervalDays = 150
    private static let crewTrainingDeferDays = 30
    private static let crewTrainingDowntimeDays = 4
    private static let crewTrainingDeferCostMultiplier = 1.6
    private static let crewTrainingSidelineFraction = 0.5

    /// Next tick each owned family is due for recurrent training.
    private(set) var crewTrainingDueByFamily: [String: Int] = [:]
    /// Tick a deferred training will auto-execute (at the higher cost).
    private(set) var crewTrainingDeferredByFamily: [String: Int] = [:]
    /// Tick a family's training downtime ends (its sidelined crew return).
    private var crewTrainingExpiryByFamily: [String: Int] = [:]

    /// Cost of a training cycle for a family — reuses the hire-cost basis (a
    /// representative recurring expense). Deferring pays the higher multiple.
    func crewTrainingCost(family: String, deferred: Bool = false) -> Int {
        let base = crewHireCost(family: family)
        return deferred ? Int((Double(base) * Simulation.crewTrainingDeferCostMultiplier).rounded()) : base
    }

    /// Put a family's crews into training: sideline ~half its ready/resting crew
    /// for the downtime window (operations degrade but don't fully stop) and
    /// schedule the next cycle.
    private func runTraining(_ family: String) {
        let pool = crewPoolsByFamily[family] ?? []
        let candidates = pool.filter { $0.status == .available || $0.status == .resting }
        let n = min(candidates.count, max(1, Int((Double(pool.count) * Simulation.crewTrainingSidelineFraction).rounded())))
        for c in candidates.shuffled().prefix(n) { c.status = .sidelined }
        if n > 0 { crewTrainingExpiryByFamily[family] = tick + Simulation.crewTrainingDowntimeDays * 1440 }
        crewTrainingDueByFamily[family] = tick + Simulation.crewTrainingIntervalDays * 1440
        crewTrainingDeferredByFamily[family] = nil
        logOps(.structural, "Crew training", "\(CREW_FAMILY_INFO[family]?.name ?? family): \(n) crew in recurrent training")
    }

    /// Per-day: return crews whose training window ended, execute any deferred
    /// training that's come due, and push a card for any family newly due.
    private func tickCrewTraining() {
        // Return crews whose training window ended.
        for (fam, expiry) in crewTrainingExpiryByFamily where tick >= expiry {
            for c in crewPoolsByFamily[fam] ?? [] where c.status == .sidelined { c.status = .available }
            crewTrainingExpiryByFamily[fam] = nil
        }
        // Execute deferred trainings that have come due (charge the higher cost).
        for (fam, dtick) in crewTrainingDeferredByFamily where tick >= dtick {
            chargeDecisionCost(crewTrainingCost(family: fam, deferred: true))
            runTraining(fam)
        }
        // Seed / push due trainings for owned families.
        for fam in ownedFamilies {
            if crewTrainingDueByFamily[fam] == nil {          // seed on first sight (new/restored game)
                crewTrainingDueByFamily[fam] = tick + Simulation.crewTrainingIntervalDays * 1440
                continue
            }
            guard tick >= crewTrainingDueByFamily[fam]!, crewTrainingDeferredByFamily[fam] == nil,
                  !decisionQueue.contains(where: { $0.kind == .training && $0.trainingFamily == fam }) else { continue }
            decisionQueue.append(Decision(id: "training_\(fam)_\(tick)", kind: .training,
                                          aircraft: nil, trainingFamily: fam))
        }
    }

    /// TRAINING card: train now — pay the base cost, sideline crews, reset cycle.
    func resolveTrainingNow(_ decision: Decision) {
        defer { decisionQueue.removeAll { $0.id == decision.id } }
        guard let fam = decision.trainingFamily else { return }
        chargeDecisionCost(crewTrainingCost(family: fam))
        runTraining(fam)
    }

    /// TRAINING card: defer 30 days — no downtime now, but it auto-runs then at
    /// the higher cost. Pushing the due date out stops the card re-prompting.
    func resolveTrainingDefer(_ decision: Decision) {
        defer { decisionQueue.removeAll { $0.id == decision.id } }
        guard let fam = decision.trainingFamily else { return }
        crewTrainingDeferredByFamily[fam] = tick + Simulation.crewTrainingDeferDays * 1440
        crewTrainingDueByFamily[fam] = tick + (Simulation.crewTrainingDeferDays + Simulation.crewTrainingIntervalDays) * 1440
        logOps(.structural, "Crew training deferred", "\(CREW_FAMILY_INFO[fam]?.name ?? fam): scheduled in 30 days")
    }

    /// Hire one crew into a family if affordable (real playerBalance cost).
    /// Returns the new crew's id, or nil if unaffordable.
    @discardableResult
    func hireCrew(family: String) -> Int? {
        let cost = crewHireCost(family: family)
        guard playerBalance >= cost else { return nil }
        playerBalance -= cost
        maintenanceSpend += cost
        let id = crewPoolsByFamily[family]?.count ?? 0
        crewPoolsByFamily[family, default: []].append(Crew(id: id))
        return id
    }

    /// Duty/rest clock. Ported from tickCrewPool(): on-duty accrues duty time;
    /// a completed rest period is the ONLY place dutyTicks resets (Part 117).
    private func tickCrewPool() {
        for pool in crewPoolsByFamily.values {
            for c in pool {
                switch c.status {
                case .onDuty:
                    c.dutyTicks += 1
                case .resting:
                    c.restTicksLeft -= 1
                    if c.restTicksLeft <= 0 { c.status = .available; c.dutyTicks = 0 }
                case .available, .sidelined:
                    break   // sidelined crew return via the labor-action expiry
                }
            }
        }
    }

    /// Injected into Aircraft.advance — take an available crew (keeping its
    /// duty clock), or fail.
    private func assignCrew(_ ac: Aircraft) -> Bool {
        guard let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.status == .available }) else { return false }
        crew.status = .onDuty
        ac.crewId = crew.id   // dutyTicks NOT reset — the Part 117 fix
        return true
    }

    /// Injected into Aircraft.advance — release the crew to rest (if it hit the
    /// duty limit) or back to the pool, and clear the assignment.
    private func releaseCrew(_ ac: Aircraft) {
        if let id = ac.crewId, let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == id }) {
            if crew.dutyTicks >= Crew.maxDutyTicks {
                crew.status = .resting
                // Crew base: rest at the player's operating hub completes 20%
                // faster (crew facilities live there).
                let atHub = routeTouchesOperatingHub(ac.origin.code, ac.dest.code)
                crew.restTicksLeft = atHub ? Int((Double(Crew.restTicks) * Simulation.hubCrewRestFactor).rounded())
                                           : Crew.restTicks
            } else {
                crew.status = .available
            }
        }
        ac.crewId = nil
    }

    /// Assigned crew's duty hours for the tooltip, or nil if none / held.
    func crewDuty(for ac: Aircraft) -> (used: Double, max: Double)? {
        guard let id = ac.crewId,
              let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == id }) else { return nil }
        return (Double(crew.dutyTicks) / 60.0, Double(Crew.maxDutyTicks) / 60.0)
    }

    // MARK: - Decisions (AOG + CREW cards; SELL arrives with the economy)

    struct Decision: Identifiable {
        enum Kind { case aog, crew, sell, offer, training, airportOffer, hubOffer }
        let id: String
        let kind: Kind
        /// The subject aircraft (aog / crew / sell). nil for the others.
        let aircraft: Aircraft?
        /// The slot-buyback details (`.offer` only).
        var offer: SlotOffer? = nil
        /// The crew family due for recurrent training (`.training` only).
        var trainingFamily: String? = nil
        /// An airport recruiting the player to open a route (`.airportOffer` only).
        var pitch: AirportPitch? = nil
        /// A rival bidding to buy one of the player's hubs (`.hubOffer` only).
        var hubOffer: HubOffer? = nil
    }

    /// A rival's bid for a player hub — the ONLY way to recoup hub capital.
    struct HubOffer {
        let airportCode: String
        let rival: String
        let price: Int
    }

    /// An airport recruiting the player to open a new route to it — waived
    /// opening cost + a signing bonus, plus a human pitch from the airport's
    /// officials. Designed to put a smaller, off-radar airport on the player's
    /// radar. Regenerates each session (lives only in the decision queue).
    struct AirportPitch {
        let originCode, destCode, originCity, destCity: String
        let signingBonus, demandPerDay, expiryTick: Int
        let pitch: String
    }

    /// A slot-value buyback: an airport (the destination) offers to buy back a
    /// route's slot. Accepting closes the route for cash; declining keeps it.
    struct SlotOffer {
        let routeId: Int
        let originCode: String
        let destCode: String
        let amount: Int
    }

    private(set) var decisionQueue: [Decision] = []
    /// Running maintenance spend (expedite/standard repair costs). The full
    /// fee/economy system is Phase 5; this keeps the costs real until then.
    private(set) var maintenanceSpend: Int = 0

    private func pushDecision(_ kind: Decision.Kind, for ac: Aircraft) {
        guard !decisionQueue.contains(where: { $0.aircraft === ac && $0.kind == kind }) else { return }
        decisionQueue.append(Decision(id: "\(kind)_\(ac.tail)_\(tick)", kind: kind, aircraft: ac))
    }

    /// Remove a card whose condition resolved through a path OTHER than its
    /// own buttons (e.g. the timed standard repair completing). Ported from
    /// clearDecisionForAircraft() — a real reported prototype bug.
    private func clearDecision(_ kind: Decision.Kind, for ac: Aircraft) {
        decisionQueue.removeAll { $0.aircraft === ac && $0.kind == kind }
    }

    /// Charge a real decision cost against the balance (and track the running
    /// maintenance stat). Previously `maintenanceSpend` accumulated but never
    /// touched `playerBalance` — decisions were silently free; now they cost.
    private func chargeDecisionCost(_ amount: Int) {
        playerBalance -= amount
        maintenanceSpend += amount
    }

    /// AOG card option 1: pay to have the aircraft ready now. Cost is scaled by
    /// any active #12 maintenance-cost inflation (repair costs only).
    func resolveAOGExpedite(_ decision: Decision) {
        let age = decision.aircraft?.maintenanceAgeMultiplier ?? 1
        let atHubX = decision.aircraft.map { routeTouchesOperatingHub($0.origin.code, $0.dest.code) } ?? false
        chargeDecisionCost(Int((15_000 * maintCostMultiplier * age * (atHubX ? Simulation.hubRepairCostFactor : 1)).rounded()))
        decision.aircraft?.maint = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// AOG card option 2: cheaper repair on a ~3 sim-hour timer; the aircraft
    /// stays held until it completes. Cost scaled by #12 maintenance inflation.
    func resolveAOGStandard(_ decision: Decision) {
        let age = decision.aircraft?.maintenanceAgeMultiplier ?? 1
        // MX base: repairs at/near the player's operating hub run 25% faster
        // and 20% cheaper (the hub hosts your maintenance facilities).
        let atHub = decision.aircraft.map { routeTouchesOperatingHub($0.origin.code, $0.dest.code) } ?? false
        let costFactor = atHub ? Simulation.hubRepairCostFactor : 1
        let timer = atHub ? Int((180 * Simulation.hubRepairTimeFactor).rounded()) : 180
        chargeDecisionCost(Int((3_000 * maintCostMultiplier * age * costFactor).rounded()))
        decision.aircraft?.aogAutoClearTick = tick + timer
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// True if a family still has a reserve crew to call in.
    func hasReserve(for ac: Aircraft) -> Bool { (reserveCrewsByFamily[ac.type.family] ?? 0) > 0 }

    /// CREW card option 1: call in a reserve crew ($5,000), assigned now so the
    /// aircraft boards this cycle. Disabled when the family is out of reserves.
    func resolveCrewReserve(_ decision: Decision) {
        guard let ac = decision.aircraft else { return }
        let family = ac.type.family
        guard (reserveCrewsByFamily[family] ?? 0) > 0 else { return }
        reserveCrewsByFamily[family]! -= 1
        chargeDecisionCost(5_000)
        let crew = Crew(id: crewPoolsByFamily[family]?.count ?? 0)
        crew.status = .onDuty
        crewPoolsByFamily[family, default: []].append(crew)
        ac.crewId = crew.id
        ac.holdReason = nil
        ac.holdLogged = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// True if the player can afford to hire a crew for this aircraft's family.
    func canAffordCrewHire(for ac: Aircraft) -> Bool {
        playerBalance >= crewHireCost(family: ac.type.family)
    }

    /// CREW card option 2: hire a NEW crew (real cost) and assign it to this
    /// held aircraft immediately, resolving the hold this cycle. Reuses
    /// hireCrew() — same cost/pool logic as the ADD CREW panel.
    func resolveCrewHire(_ decision: Decision) {
        guard let ac = decision.aircraft else { return }
        guard let id = hireCrew(family: ac.type.family) else { return }
        // Put the freshly-hired crew straight on this aircraft.
        crewPoolsByFamily[ac.type.family]?.first { $0.id == id }?.status = .onDuty
        ac.crewId = id
        ac.holdReason = nil
        ac.holdLogged = false
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// CREW card option 3: dismiss and let the aircraft keep waiting on the
    /// pool — the boarding gate assigns a crew the moment one frees up.
    func resolveCrewWait(_ decision: Decision) {
        decisionQueue.removeAll { $0.id == decision.id }
    }

    // MARK: - Economics (per-flight revenue / cost / fees)

    /// Active economic condition and how many ticks it has left.
    private(set) var currentEvent = EconomicEvent.normal
    private(set) var economicEventTicksLeft = 0

    // MARK: - Ops event log (the Ops tab's Events feed)
    private(set) var opsEventLog: [OpsEvent] = []
    private var nextOpsEventId = 1

    /// Highest ops-event id the player has already seen (Ops tab viewed). Drives
    /// the Ops tab-bar activity badge.
    private(set) var lastSeenOpsEventId = 0
    /// New ops events since the player last looked at the Ops feed.
    var unseenOpsEventCount: Int {
        opsEventLog.reduce(0) { $0 + ($1.id > lastSeenOpsEventId ? 1 : 0) }
    }
    /// Mark the Ops feed as seen — called when the Ops tab is on screen. The
    /// newest event is always at index 0 (highest id), so that's the high-water mark.
    func markOpsEventsSeen() {
        lastSeenOpsEventId = max(lastSeenOpsEventId, opsEventLog.first?.id ?? lastSeenOpsEventId)
    }

    /// Record an event to the (capped, newest-first) Ops feed.
    private func logOps(_ category: OpsEvent.Category, _ title: String, _ subtitle: String, airportCode: String? = nil) {
        opsEventLog.insert(OpsEvent(id: nextOpsEventId, category: category,
                                    title: title, subtitle: subtitle, tick: tick, airportCode: airportCode), at: 0)
        nextOpsEventId += 1
        if opsEventLog.count > 40 { opsEventLog.removeLast(opsEventLog.count - 40) }
    }

    /// Airport codes on the player's open routes (weather there is worth logging).
    private var playerRouteCodes: Set<String> {
        Set(playerRoutes.flatMap { [$0.originCode, $0.destCode] })
    }

    private func opsEventSubtitle(_ e: EconomicEvent) -> String {
        switch e.id {
        case "OIL_SPIKE": return "Fuel costs surge \(Int(((e.costMultiplier - 1) * 100).rounded()))%"
        case "FUEL_GLUT": return "Fuel costs drop \(Int(((1 - e.costMultiplier) * 100).rounded()))%"
        case "ECON_BOOM": return "Demand up — fares +\(Int(((e.fareMultiplier - 1) * 100).rounded()))%"
        case "RECESSION": return "Fares down \(Int(((1 - e.fareMultiplier) * 100).rounded()))%"
        case "FFR_SURGE": return "Seats fill (+\(Int(((e.loadMultiplier - 1) * 100).rounded()))%), less cash per seat"
        default:          return e.label
        }
    }

    // MARK: - World disruption / structural events (Phase 1 of the event system)
    // Regional ATC shortages and single-airport security incidents both reuse
    // the SAME ground-stop mechanism as weather (distinguished only by cause /
    // scope / duration). Airport expansion is the one DURABLE event (a permanent
    // slot increase). Daily probabilities are designed pacing, not sourced.
    private static let atcDailyProbability = 0.04
    private static let securityDailyProbability = 0.03
    private static let expansionDailyProbability = 0.025
    private static let slotOfferDailyProbability = 0.06
    private static let laborActionDailyProbability = 0.02
    private static let recallDailyProbability = 0.015

    /// Tick a family's labor action ends (its sidelined crew return). Days
    /// boundaries only, so it's safe to expire inside the daily tickWorldEvents.
    private(set) var laborActionExpiryByFamily: [String: Int] = [:]

    // MARK: Phase-4 cost/revenue events (all passive multipliers/bills).
    // #11 Insurance — a recurring MONTHLY bill vs current fleet value, with an
    // occasional "hard market" period that raises the premium.
    static let insuranceRateMonthly = 0.0008    // 0.08%/mo of fleet value (designed)
    static let insuranceHardMarketMultiplier = 1.8
    private var nextInsuranceBillTick = Simulation.ticksPerMonth
    private var insuranceHardMarketExpiryTick = 0
    private(set) var totalInsuranceSpent = 0
    var insuranceHardMarketActive: Bool { tick < insuranceHardMarketExpiryTick }
    // #12 Maintenance cost inflation — spikes AOG REPAIR cost only (not fuel).
    static let maintInflationMultiplier = 1.6
    private var maintInflationExpiryTick = 0
    var maintCostMultiplier: Double { tick < maintInflationExpiryTick ? Simulation.maintInflationMultiplier : 1 }
    // #13 FX shock — widebody fare only (honest adaptation: no real intl routes).
    static let fxFareMultiplier = 0.85
    private var fxShockExpiryTick = 0
    var fxShockActive: Bool { tick < fxShockExpiryTick }
    // #14 Competitor fare war — depresses ONE existing player route's fare.
    static let fareWarMultiplier = 0.75
    private(set) var fareWarRouteId: Int?
    private var fareWarExpiryTick = 0
    private static let insuranceHardMarketDailyProbability = 0.02
    private static let maintInflationDailyProbability = 0.025
    private static let fxShockDailyProbability = 0.02
    private static let fareWarDailyProbability = 0.03

    private func tickWorldEvents() {
        guard tick % 1440 == 0 else { return }   // once per sim-day

        // Recurrent crew training (return trainees, run deferred, push due cards).
        tickCrewTraining()
        // Airport recruitment offers (an airport pitches you to open a route).
        tickAirportOffers()
        // Deadline on accepted offers — forfeit + claw back if not staffed in time.
        tickOfferFulfillment()
        // Rival carriers entering / leaving the player's markets.
        tickCompetition()
        // A rival occasionally bids to buy one of the player's hubs.
        tickHubOffers()

        // Clear an expired fare war so a new one can start.
        if fareWarRouteId != nil, tick >= fareWarExpiryTick { fareWarRouteId = nil }

        // Expire any finished labor action FIRST (return the sidelined crew).
        for (fam, expiry) in laborActionExpiryByFamily where tick >= expiry {
            for c in crewPoolsByFamily[fam] ?? [] where c.status == .sidelined { c.status = .available }
            laborActionExpiryByFamily[fam] = nil
            logOps(.disruption, "Labor action resolved", CREW_FAMILY_INFO[fam]?.name ?? fam)
        }

        // #9 Labor Action — sideline a real fraction (~40%) of ONE crew family's
        // pool (from the ready/resting crew, not mid-flight), for 3–8 sim-days.
        if Double.random(in: 0..<1) < Simulation.laborActionDailyProbability,
           let fam = ownedFamilies.filter({ (laborActionExpiryByFamily[$0] ?? 0) <= tick }).randomElement() {
            let pool = crewPoolsByFamily[fam] ?? []
            let candidates = pool.filter { $0.status == .available || $0.status == .resting }
            let n = min(candidates.count, max(1, Int((Double(pool.count) * 0.4).rounded())))
            let sidelined = Array(candidates.shuffled().prefix(n))
            for c in sidelined { c.status = .sidelined }
            if !sidelined.isEmpty {
                laborActionExpiryByFamily[fam] = tick + (3 + Int.random(in: 0...5)) * 1440
                logOps(.disruption, "Labor action", "\(CREW_FAMILY_INFO[fam]?.name ?? fam): \(sidelined.count) crew sidelined")
            }
        }

        // #10 Aircraft Recall / Airworthiness Directive — ground EVERY owned
        // aircraft of one type at once (reuses the AOG mechanism: maint = true →
        // each aircraft AOGs at its next gate, pushing an AOG card per tail).
        if Double.random(in: 0..<1) < Simulation.recallDailyProbability {
            let ownedTypes = Set(aircraft.filter { $0.purchased && !$0.maint }.map { $0.type.id })
            if let typeId = ownedTypes.randomElement() {
                let affected = aircraft.filter { $0.purchased && $0.type.id == typeId && !$0.maint }
                for ac in affected { ac.maint = true }
                if let name = affected.first?.type.name {
                    logOps(.disruption, "Airworthiness Directive", "\(name): \(affected.count) grounded")
                }
            }
        }
        // ATC staffing shortage — regional, 2–4 airports grounded at once,
        // moderate duration (2.5–5 sim-hours).
        if Double.random(in: 0..<1) < Simulation.atcDailyProbability {
            let hit = Array(airports.shuffled().prefix(Int.random(in: 2...4)))
            for ap in hit { ap.groundStop = true; ap.groundStopTicksLeft = 150 + Int.random(in: 0...150); ap.groundStopReason = "ATC staffing shortage" }
            logOps(.disruption, "ATC staffing shortage", "Ground stops: \(hit.map { $0.code }.joined(separator: ", "))")
        }
        // Security incident — single airport, sharper & SHORTER than weather
        // (0.75–2 sim-hours vs weather's 1.5–5.5).
        if Double.random(in: 0..<1) < Simulation.securityDailyProbability, let ap = airports.randomElement() {
            ap.groundStop = true; ap.groundStopTicksLeft = 45 + Int.random(in: 0...75); ap.groundStopReason = "Security incident"
            logOps(.disruption, "Security incident", "Ground stop at \(ap.code)", airportCode: ap.code)
        }
        // Airport expansion — PERMANENT slot capacity increase (durable).
        if Double.random(in: 0..<1) < Simulation.expansionDailyProbability, let ap = airports.randomElement() {
            let added = Int.random(in: 2...3)
            ap.slotsTotal += added; ap.slotsAvailable += added
            logOps(.structural, "\(ap.code) capacity expansion", "\(added) new slots available", airportCode: ap.code)
        }
        // Slot-value buyback — an airport offers to buy back one route's slot.
        // The one event that's a real player CHOICE (Accept/Decline card), not a
        // passive effect. Only one open at a time; only when the player has a route.
        if !decisionQueue.contains(where: { $0.kind == .offer }),
           Double.random(in: 0..<1) < Simulation.slotOfferDailyProbability {
            // The slot's market value = its real establishment cost. A SUBSIDIZED
            // route (opened via an airport offer) has openingCost 0 but records the
            // waived cost in `incentiveWaived` — use that so the buyback isn't $0.
            let candidates = playerRoutes.filter { max($0.openingCost, $0.incentiveWaived) > 0 }
            if let r = candidates.randomElement() {
                let base = max(r.openingCost, r.incentiveWaived)
                let amount = Int((Double(base) * Double.random(in: 2.0...4.0)).rounded())
                decisionQueue.append(Decision(id: "offer_\(r.id)_\(tick)", kind: .offer, aircraft: nil,
                    offer: SlotOffer(routeId: r.id, originCode: r.originCode, destCode: r.destCode, amount: amount)))
            }
        }

        // #11 Insurance hard market — a temporary spike in the recurring premium.
        if !insuranceHardMarketActive, Double.random(in: 0..<1) < Simulation.insuranceHardMarketDailyProbability {
            insuranceHardMarketExpiryTick = tick + (15 + Int.random(in: 0...20)) * 1440
            logOps(.market, "Insurance hard market", "Premiums up \(Int((Simulation.insuranceHardMarketMultiplier - 1) * 100))%")
        }
        // #12 Maintenance cost inflation — parts/MRO spike (AOG repair cost only).
        if tick >= maintInflationExpiryTick, Double.random(in: 0..<1) < Simulation.maintInflationDailyProbability {
            maintInflationExpiryTick = tick + (5 + Int.random(in: 0...8)) * 1440
            logOps(.market, "Maintenance cost inflation", "Repair costs +\(Int((Simulation.maintInflationMultiplier - 1) * 100))%")
        }
        // #13 FX shock — widebody fares only (needs at least one owned widebody).
        if !fxShockActive, Double.random(in: 0..<1) < Simulation.fxShockDailyProbability,
           aircraft.contains(where: { $0.purchased && $0.type.bodyType.usesWidebodyGateFee }) {
            fxShockExpiryTick = tick + (5 + Int.random(in: 0...10)) * 1440
            logOps(.market, "FX shock", "Widebody fares −\(Int((1 - Simulation.fxFareMultiplier) * 100))%")
        }
        // #14 Competitor fare war — depresses ONE existing player route's fare.
        if fareWarRouteId == nil, Double.random(in: 0..<1) < Simulation.fareWarDailyProbability,
           let r = playerRoutes.randomElement() {
            fareWarRouteId = r.id
            fareWarExpiryTick = tick + (4 + Int.random(in: 0...8)) * 1440
            let comp = ["American Airlines", "Delta Air Lines", "Southwest Airlines", "United Airlines"].randomElement()!
            logOps(.market, "Fare war", "\(comp) dumps capacity \(r.originCode)-\(r.destCode)")
        }
    }

    /// #11 Insurance — bill the recurring MONTHLY premium (current fleet value ×
    /// rate, × the hard-market multiplier when active). Silent routine cost
    /// (tracked in totalInsuranceSpent for the Finance tab); the hard-market
    /// ONSET is what surfaces in the Ops feed.
    private func tickInsuranceBilling() {
        guard tick >= nextInsuranceBillTick else { return }
        nextInsuranceBillTick += Simulation.ticksPerMonth
        let owned = aircraft.filter { $0.purchased }
        guard !owned.isEmpty else { return }
        let fleetValue = owned.reduce(0) { $0 + sellValue(of: $1) }
        let mult = insuranceHardMarketActive ? Simulation.insuranceHardMarketMultiplier : 1
        let bill = Int((Double(fleetValue) * Simulation.insuranceRateMonthly * mult).rounded())
        playerBalance -= bill
        totalInsuranceSpent += bill
    }

    /// OFFER card: accept the slot buyback — credit the cash and close the route
    /// (its aircraft becomes an idle spare, crew released; the SLOT is sold, not
    /// the plane). The route is archived, keeping its P&L history reviewable.
    func resolveOfferAccept(_ decision: Decision) {
        defer { decisionQueue.removeAll { $0.id == decision.id } }
        guard let offer = decision.offer,
              let idx = playerRoutes.firstIndex(where: { $0.id == offer.routeId }) else { return }
        playerBalance += offer.amount
        totalOfferIncome += offer.amount
        let r = playerRoutes.remove(at: idx)
        r.closedTick = tick
        closedPlayerRoutes.append(r)
        for ac in aircraft where ac.assignedRouteId == offer.routeId {
            ac.assignedRouteId = nil
            if let cid = ac.crewId, let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == cid }) {
                crew.status = .available
            }
            ac.crewId = nil
            ac.holdReason = nil
        }
        logOps(.structural, "Slot sold", "\(offer.originCode) ↔\u{FE0E} \(offer.destCode): $\(offer.amount.formatted())")
    }

    /// OFFER card: decline — keep the route.
    func resolveOfferDecline(_ decision: Decision) {
        decisionQueue.removeAll { $0.id == decision.id }
    }

    // MARK: - Airport recruitment offers (an airport pitches YOU to open a route)

    private static let airportOfferDailyProbability = 0.08
    private static let airportOfferDurationDays = 12

    func airport(_ code: String) -> Airport? { airports.first { $0.code == code } }

    /// An idle spare (owned, unassigned) that can physically fly this pitched
    /// route — the accept option only appears when one exists.
    func eligibleSpareForOffer(_ p: AirportPitch) -> Aircraft? {
        guard let o = airport(p.originCode), let d = airport(p.destCode) else { return nil }
        return idleSpares.first { routeBlock(for: $0, from: o, to: d) == nil }
    }

    /// Once/day: expire a stale offer, then maybe push a new one (one at a time).
    /// Origin is a smaller, off-radar CONUS airport the player doesn't serve (to
    /// put it on their radar); dest prefers a hub already in their network.
    private func tickAirportOffers() {
        decisionQueue.removeAll { $0.kind == .airportOffer && ($0.pitch?.expiryTick ?? 0) <= tick }
        guard !decisionQueue.contains(where: { $0.kind == .airportOffer }),
              Double.random(in: 0..<1) < Simulation.airportOfferDailyProbability else { return }

        let servedCodes = Set(playerRoutes.flatMap { [$0.originCode, $0.destCode] })
        let servedPairs = Set(playerRoutes.map { pairKey($0.originCode, $0.destCode) })
        let conus = homeAirports.filter { $0.info != nil }
        let bySize = conus.sorted { ($0.info?.annualPassengers ?? 0) < ($1.info?.annualPassengers ?? 0) }
        let smaller = Array(bySize.prefix(max(1, bySize.count * 2 / 3)))   // bottom ~2/3 by traffic
        guard let origin = smaller.filter({ !servedCodes.contains($0.code) }).randomElement() else { return }
        let hubs = conus.sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
        let dest = hubs.first(where: { servedCodes.contains($0.code) && $0.code != origin.code
                                       && !servedPairs.contains(pairKey(origin.code, $0.code)) })
            ?? hubs.first(where: { $0.code != origin.code && !servedPairs.contains(pairKey(origin.code, $0.code)) })
        guard let dest else { return }

        let demand = routeDailyDemand(origin, dest)
        let bonus = min(500_000, 100_000 + demand * 300)
        let oCity = origin.info?.city ?? origin.code, dCity = dest.info?.city ?? dest.code
        let pitchText = airportPitchText(originCity: oCity, destCity: dCity,
                                         originCode: origin.code, destCode: dest.code, demand: demand, bonus: bonus)
        decisionQueue.append(Decision(id: "airport_\(origin.code)_\(tick)", kind: .airportOffer, aircraft: nil,
            pitch: AirportPitch(originCode: origin.code, destCode: dest.code, originCity: oCity, destCity: dCity,
                                signingBonus: bonus, demandPerDay: demand,
                                expiryTick: tick + Simulation.airportOfferDurationDays * 1440, pitch: pitchText)))
        logOps(.structural, "Route offer", "\(oCity) is courting you for \(origin.code) ↔\u{FE0E} \(dest.code)")
    }

    private func airportPitchText(originCity: String, destCity: String, originCode: String,
                                  destCode: String, demand: Int, bonus: Int) -> String {
        let b = "$\(bonus.formatted())"
        let templates = [
            "\(originCity)'s airport authority is courting you: fly \(originCode) ↔ \(destCode) and we'll waive every opening fee, plus a \(b) marketing package. ~\(demand) travelers a day, and no direct link to your network yet.",
            "\(originCity) wants your airline. Launch \(originCode) ↔ \(destCode), pocket a \(b) signing incentive, and we cover your setup costs. This market's been overlooked too long.",
            "Straight talk from \(originCity): ~\(demand) passengers a day are driving hours to the nearest hub. Open \(originCode) ↔ \(destCode) on us — zero opening cost, plus \(b) to get started.",
        ]
        return templates[abs(tick) % templates.count]
    }

    /// AIRPORT OFFER card: accept — ALWAYS opens the route free (subsidized) and
    /// banks the signing bonus. If an eligible spare exists it's assigned now;
    /// otherwise the route opens PENDING (awaiting an aircraft) and is auto-staffed
    /// once the player acquires/frees an in-range spare. No more spare-required
    /// dead-end.
    func resolveAirportOfferAccept(_ decision: Decision) {
        defer { decisionQueue.removeAll { $0.id == decision.id } }
        guard let p = decision.pitch, let o = airport(p.originCode), let d = airport(p.destCode),
              route(between: o.code, d.code) == nil else { return }
        let waived = routeOpeningCost(o, d)   // what it WOULD have cost — for the Ops incentive box
        let r = createRoute(from: o, to: d, cost: 0, incentiveBonus: p.signingBonus, waived: waived)
        playerBalance += p.signingBonus
        totalOfferIncome += p.signingBonus
        if let spare = eligibleSpareForOffer(p) {
            assign(spare, to: r, origin: o, dest: d)
            logOps(.structural, "Route offer accepted",
                   "\(o.code) ↔\u{FE0E} \(d.code): \(spare.tail) assigned · +$\(p.signingBonus.formatted()) bonus")
        } else {
            // Pending: the player has a deadline to staff it or forfeit the bonus.
            r.fulfillByTick = tick + Simulation.offerFulfillmentDays * 1440
            logOps(.structural, "Route offer accepted",
                   "\(o.code) ↔\u{FE0E} \(d.code): staff within \(Simulation.offerFulfillmentDays) days · +$\(p.signingBonus.formatted()) bonus")
        }
    }

    /// Days to put an aircraft on an offer-opened route before it's forfeited.
    static let offerFulfillmentDays = 14

    /// Once/day: fulfilled pending routes clear their deadline; unfulfilled ones
    /// past the deadline are FORFEITED — the route closes and the marketing bonus
    /// is clawed back (the obligation had teeth).
    private func tickOfferFulfillment() {
        for r in playerRoutes where r.fulfillByTick != nil {
            if routeStaffed(r) {
                r.fulfillByTick = nil   // obligation met
            } else if tick >= r.fulfillByTick! {
                playerBalance -= r.incentiveBonus
                totalOfferIncome -= r.incentiveBonus   // reverse the banked bonus
                airport(r.originCode)?.slotsAvailable += 1
                airport(r.destCode)?.slotsAvailable += 1
                r.closedTick = tick
                logOps(.structural, "Route offer forfeited",
                       "\(r.originCode) ↔\u{FE0E} \(r.destCode): not staffed in time — $\(r.incentiveBonus.formatted()) bonus clawed back")
                closedPlayerRoutes.append(r)
            }
        }
        playerRoutes.removeAll { $0.closedTick != nil }
    }

    /// AIRPORT OFFER card: decline.
    func resolveAirportOfferDecline(_ decision: Decision) {
        decisionQueue.removeAll { $0.id == decision.id }
    }

    private static let economicEventCheckInterval = 1440   // once per sim-day
    private static let economicEventDailyProbability = 0.15
    private static let economicEventMinDurationDays = 3
    private static let economicEventMaxDurationDays = 10

    /// Sim-days remaining on the active event (for the HUD banner).
    var eventDaysLeft: Int { max(0, Int((Double(economicEventTicksLeft) / (24 * 60)).rounded(.up))) }

    /// Randomly start / end economic events. Ported from tickEconomicEvents():
    /// checked once per sim-day, 15% chance to start when normal, 3–10 days.
    /// After an economic event ends, the SAME event can't recur for this long —
    /// so you don't get two "Fuel Price Drop"s a few days apart (unrealistic).
    private static let economicEventCooldownDays = 30
    private var eventCooldownUntil: [String: Int] = [:]

    private func tickEconomicEvents() {
        if !currentEvent.isNormal {
            economicEventTicksLeft -= 1
            if economicEventTicksLeft <= 0 { currentEvent = .normal }
            return
        }
        guard tick % Simulation.economicEventCheckInterval == 0 else { return }
        if Double.random(in: 0..<1) < Simulation.economicEventDailyProbability {
            // Pick only from event types not on cooldown (fall back to all if every
            // type is cooling down, which shouldn't happen with 5 types + 30 days).
            let eligible = EconomicEvent.all.filter { (eventCooldownUntil[$0.id] ?? 0) <= tick }
            currentEvent = (eligible.isEmpty ? EconomicEvent.all : eligible).randomElement()!
            // Cooldown from ONSET: guarantees the same event can't recur within
            // `economicEventCooldownDays` regardless of how long this one lasts.
            eventCooldownUntil[currentEvent.id] = tick + Simulation.economicEventCooldownDays * 1440
            let days = Double(Simulation.economicEventMinDurationDays)
                     + Double.random(in: 0..<1) * Double(Simulation.economicEventMaxDurationDays - Simulation.economicEventMinDurationDays)
            economicEventTicksLeft = Int((days * 24 * 60).rounded())
            logOps(.market, currentEvent.label, opsEventSubtitle(currentEvent))
        }
    }

    // MARK: - Fuel hedging (a real call option on fuel cost)

    // A fuel hedge is a CALL OPTION: pay a premium now for the right to buy at
    // a locked price if the market spikes. The ASYMMETRY is the whole point —
    // it caps the player's cost multiplier at the ceiling ONLY when a spike
    // would push above it, and does NOT force costs up during a genuine price
    // drop (a real call option doesn't erase the benefit of prices falling).
    // If no spike ever happens, the premium is a genuine sunk cost — the same
    // "real downside risk" as leasing's fixed obligation, not free insurance.
    static let fuelHedgePremiumRate = 0.10     // real: Carter/Rogers/Simkins 2006 (≤10%)
    static let fuelHedgeCeiling = 1.0          // caps a spike's cost multiplier here
    static let fuelHedgeUtilization = 0.35     // designed: share of ticks an owned aircraft accrues op cost
    static let fuelHedgeDurations = [30, 60, 90]

    /// Tick the active hedge expires (nil = no hedge).
    private(set) var fuelHedgeExpiryTick: Int?
    var fuelHedgeActive: Bool { if let e = fuelHedgeExpiryTick { return tick < e } else { return false } }
    var fuelHedgeDaysRemaining: Int {
        guard let e = fuelHedgeExpiryTick, tick < e else { return 0 }
        return Int((Double(e - tick) / 1440).rounded(.up))
    }

    /// The asymmetric call-option cap, as a pure function (so it's testable
    /// without forcing an economic event): a spike is capped at the ceiling
    /// ONLY when hedged; a price drop (raw ≤ ceiling) always passes through.
    static func effectiveMultiplier(raw: Double, hedged: Bool) -> Double {
        (hedged && raw > fuelHedgeCeiling) ? fuelHedgeCeiling : raw
    }

    /// The multiplier the PLAYER actually pays. With an active hedge a spike is
    /// capped at the ceiling; a price drop passes through unchanged. The global
    /// economic banner deliberately shows the RAW `currentEvent.costMultiplier`
    /// (the market's true state), NOT this hedged view.
    /// Fuel is ~this share of direct operating cost at baseline; a fuel-price
    /// event scales only this portion (the rest — crew, capital, maintenance —
    /// doesn't move with fuel).
    static let fuelShareBase = 0.35

    /// The operating-cost multiplier for a SPECIFIC aircraft under the current
    /// fuel-price event. The event moves fuel price; only the fuel share of cost
    /// responds, and by the aircraft's `fuelIntensity` (a thirsty 4-engine jet is
    /// hammered by an oil spike; a modern neo/787 barely feels it — and a fuel
    /// hedge caps the spike entirely). Normal conditions → 1.0 for everyone, so
    /// the real `costPerHour` stays the truth when fuel price is normal.
    func effectiveCostMultiplier(for ac: Aircraft) -> Double {
        let hedgedFuel = Simulation.effectiveMultiplier(raw: currentEvent.costMultiplier, hedged: fuelHedgeActive)
        return 1 + (hedgedFuel - 1) * Simulation.fuelShareBase * ac.type.fuelIntensity
    }

    /// Premium for a `days`-length hedge, priced against the player's ACTUAL
    /// owned fleet's expected operating cost over that window (not a flat fee) —
    /// real hedges are priced against expected consumption the same way. Scales
    /// linearly with duration. Empty fleet → $0 (there's nothing to hedge).
    func fuelHedgePremium(days: Int) -> Int {
        let durationTicks = Double(days * 1440)
        let expectedOpCost = aircraft.lazy.filter { $0.purchased }.reduce(0.0) {
            $0 + Double($1.type.holdCostPerTick) * durationTicks * Simulation.fuelHedgeUtilization
        }
        return Int((expectedOpCost * Simulation.fuelHedgePremiumRate).rounded())
    }

    enum FuelHedgeResult { case success, noFleet, alreadyActive, insufficientFunds(Int) }

    /// Buy a hedge (only when none is active and the player owns aircraft).
    @discardableResult
    func buyFuelHedge(days: Int) -> FuelHedgeResult {
        guard ownedCount > 0 else { return .noFleet }
        guard !fuelHedgeActive else { return .alreadyActive }
        let premium = fuelHedgePremium(days: days)
        guard playerBalance >= premium else { return .insufficientFunds(premium) }
        playerBalance -= premium
        totalHedgeSpend += premium
        fuelHedgeExpiryTick = tick + days * 1440
        return .success
    }

    // Running financial totals (a fresh session's ledger). playerBalance and
    // the ownership economy arrive in a later slice; for now this is the sim's
    // net result.
    private(set) var totalRevenue = 0
    private(set) var totalFees = 0
    private(set) var totalOperatingCost = 0
    var netRevenue: Int { totalRevenue - totalFees - totalOperatingCost }

    // Capital-account totals (for the Finance tab). Together with the operating
    // totals above, the recurring totals (lease/insurance/maintenance), and
    // startingCapital, these RECONCILE exactly to playerBalance — every place
    // that moves cash also books into one of these. Keep that invariant if you
    // add a new cash flow.
    private(set) var totalAcquisitionSpend = 0   // buy + used-buy + lease upfront
    private(set) var totalRouteSpend = 0         // route opening costs
    private(set) var totalHedgeSpend = 0         // fuel-hedge premiums
    private(set) var totalSaleProceeds = 0       // aircraft sales
    private(set) var totalOfferIncome = 0        // slot-buyback offers accepted
    private(set) var totalLoanProceeds = 0       // cash drawn from loans
    private(set) var totalDebtService = 0        // loan payments (principal + interest)
    private(set) var totalFlightsFlown = 0       // owned-aircraft legs settled

    // MARK: - Loans / financing

    private(set) var loans: [Loan] = []
    private var nextLoanId = 1
    private var nextLoanBillTick = Simulation.ticksPerMonth

    /// Sum of all remaining loan balances.
    var totalDebtOutstanding: Int { Int(loans.reduce(0.0) { $0 + $1.remainingPrincipal }.rounded()) }
    /// Combined monthly debt-service obligation across active loans.
    var monthlyDebtService: Int { loans.reduce(0) { $0 + $1.monthlyPayment } }
    /// Collateral-based borrowing limit: a base credit line + the fleet's resale value.
    var borrowingLimit: Int { max(30_000_000, fleetMarketValue) }
    func canBorrow(_ offer: LoanOffer) -> Bool { totalDebtOutstanding + offer.principal <= borrowingLimit }

    /// Draw a loan: credit the cash now, owe a fixed monthly payment until repaid.
    @discardableResult
    func takeLoan(_ offer: LoanOffer) -> Bool {
        guard canBorrow(offer) else { return false }
        playerBalance += offer.principal
        totalLoanProceeds += offer.principal
        loans.append(Loan(id: nextLoanId, originalPrincipal: offer.principal,
                          remainingPrincipal: Double(offer.principal), monthlyRate: offer.monthlyRate,
                          monthlyPayment: offer.monthlyPayment, termMonths: offer.termMonths, takenTick: tick))
        nextLoanId += 1
        logOps(.structural, "Loan drawn",
               "$\(offer.principal.formatted()) at \(Int((offer.apr * 100).rounded()))% · $\(offer.monthlyPayment.formatted())/mo")
        return true
    }

    /// Cost to retire a loan today: its full remaining balance (no future
    /// interest — paying early saves every remaining interest payment).
    func earlyPayoffCost(_ loan: Loan) -> Int { Int(loan.remainingPrincipal.rounded()) }

    /// True only when the player has the cash on hand to settle this loan in
    /// full right now — the pay-off action only surfaces when this is true.
    func canPayOffLoan(_ loan: Loan) -> Bool {
        let cost = earlyPayoffCost(loan)
        return cost > 0 && playerBalance >= cost
    }

    /// Pay off a loan early: settle the outstanding balance now, saving all
    /// future interest. Counts as debt service so the Finance cash invariant
    /// (…− debtService…) holds exactly.
    @discardableResult
    func payOffLoan(_ loanId: Int) -> Bool {
        guard let idx = loans.firstIndex(where: { $0.id == loanId }) else { return false }
        let cost = earlyPayoffCost(loans[idx])
        guard cost > 0, playerBalance >= cost else { return false }
        playerBalance -= cost
        totalDebtService += cost
        loans.remove(at: idx)
        logOps(.structural, "Loan paid off early",
               "$\(cost.formatted()) settled in full · no more interest")
        return true
    }

    /// Monthly debt service: interest on the remaining balance + a slice of
    /// principal; a final short payment retires the loan.
    private func tickLoanBilling() {
        guard tick >= nextLoanBillTick else { return }
        nextLoanBillTick += Simulation.ticksPerMonth
        for i in loans.indices {
            let interest = loans[i].remainingPrincipal * loans[i].monthlyRate
            let due = min(Double(loans[i].monthlyPayment), loans[i].remainingPrincipal + interest)
            loans[i].remainingPrincipal -= (due - interest)
            let payment = Int(due.rounded())
            playerBalance -= payment
            totalDebtService += payment
        }
        loans.removeAll { $0.remainingPrincipal <= 0.5 }
    }

    // MARK: Per-period finance history (for the Finance tab's period views)

    /// A frozen copy of every cumulative total (plus cash / net worth) at one
    /// instant. One is captured at launch (tick 0) and at each sim-month
    /// boundary; a period's activity is the difference between two snapshots,
    /// which reconciles the same way the cumulative ledger does.
    struct FinanceSnapshot {
        let tick, revenue, fees, operatingCost: Int
        let leaseCost, insurance, maintenance: Int
        let acquisition, routeSpend, hedgeSpend: Int
        let saleProceeds, offerIncome, flights: Int
        let loanProceeds, debtService: Int
        var hubSpend = 0, hubLabor = 0, clubRent = 0
        /// Airline acquisitions (buying a competitor outright).
        var airlineAcquisition = 0
        /// Merger integration bills + seniority settlement (overhead).
        var integrationSpend = 0
        /// Equity raised via IPO / secondary offerings (capital-in).
        var equityRaised = 0
        /// Dividends paid + buybacks — cash returned to shareholders (capital-out).
        var dividendsPaid = 0, buybackSpend = 0
        let cash, netWorth: Int
    }
    private(set) var financeSnapshots: [FinanceSnapshot] = []
    private func financeSnapshotNow() -> FinanceSnapshot {
        FinanceSnapshot(tick: tick, revenue: totalRevenue, fees: totalFees,
                        operatingCost: totalOperatingCost, leaseCost: totalLeaseCost,
                        insurance: totalInsuranceSpent, maintenance: maintenanceSpend,
                        acquisition: totalAcquisitionSpend, routeSpend: totalRouteSpend,
                        hedgeSpend: totalHedgeSpend, saleProceeds: totalSaleProceeds,
                        offerIncome: totalOfferIncome, flights: totalFlightsFlown,
                        loanProceeds: totalLoanProceeds, debtService: totalDebtService,
                        hubSpend: totalHubSpend, hubLabor: totalHubLabor, clubRent: totalClubRent,
                        airlineAcquisition: totalAcquisitionPrice,
                        integrationSpend: totalIntegrationSpend + totalSenioritySpend + totalDiligenceSpend,
                        equityRaised: totalEquityRaised,
                        dividendsPaid: totalDividendsPaid, buybackSpend: totalBuybackSpend,
                        cash: playerBalance, netWorth: playerBalance + fleetMarketValue)
    }

    /// Roll a leg's revenue at scheduling time — pax-first so displayed pax and
    /// revenue always agree. Ported from rollRevenue(). Stored on the aircraft.
    private func rollRevenue(for ac: Aircraft) {
        // Distance-based fare: depends on the ROUTE's stage length, not the
        // aircraft's bodyType (see FareModel). Longer routes yield more per seat.
        let avgFare = FareModel.farePerSeat(distanceNM: ac.origin.greatCircleNM(to: ac.dest))
        // Event fare modifiers: #13 FX shock (widebody only) and #14 fare war
        // (this specific route only) stack on top of the economic condition.
        var fareMult = currentEvent.fareMultiplier
        if fxShockActive, ac.type.bodyType.usesWidebodyGateFee { fareMult *= Simulation.fxFareMultiplier }
        if let fw = fareWarRouteId, ac.assignedRouteId == fw, tick < fareWarExpiryTick { fareMult *= Simulation.fareWarMultiplier }
        // Leisure destinations command premium fares (designer: island/beach
        // markets run a premium, as in the real world).
        if Airport.isLeisure(ac.origin.code) || Airport.isLeisure(ac.dest.code) {
            fareMult *= Simulation.leisureFareMultiplier
        }
        // Hub yield: connecting itineraries through an operating hub earn a
        // small fare premium (+3%, player only, once per leg) — the hub's one
        // scaling revenue benefit, sized by the balance A/B so the hub roughly
        // pays for itself without printing.
        if ac.purchased, routeTouchesOperatingHub(ac.origin.code, ac.dest.code) {
            fareMult *= Simulation.hubFareMultiplier
        }
        // Club yield: business travelers pay up for the lounge (+4% on top of
        // the hub's +3%, player only, no double-dip — a route touching two club
        // airports gets it once).
        if ac.purchased, clubOperating(ac.origin.code) || clubOperating(ac.dest.code) {
            fareMult *= Simulation.clubFareMultiplier
            // Loyalty's liability: an FFR Redemption Surge bites harder per club.
            if currentEvent.id == "FFR_SURGE" {
                fareMult *= (1 - Simulation.clubFFRFareHit * Double(operatingClubCount))
            }
        }
        let farePerSeat = avgFare * fareMult * (0.9 + Double.random(in: 0..<0.2))  // ±10%
        // Load factor: with the demand model ON (prototype), it's an OUTCOME of
        // this route's passenger demand vs. this aircraft's seats — so a widebody
        // on a thin route flies half-empty. With it OFF (dev A/B toggle), the old
        // flat industry baseline. Event/random modifiers apply on top of both.
        let load: Double
        if useDemandModel {
            // The player's own routes get the hub/network bonus (connecting pax);
            // background traffic doesn't (it's not part of the player's network).
            let hub = ac.purchased
                ? hubDemandMultiplier(originCode: ac.origin.code, destCode: ac.dest.code, excludingRouteId: ac.assignedRouteId)
                : 1.0
            var effDemand = Demand.dailyOneWay(ac.origin, ac.dest) * hub
            if ac.purchased {
                // Reputation lifts/depresses demand overall; competitors on this
                // specific route split what's left of the market.
                effDemand *= reputationDemandMultiplier
                if let rid = ac.assignedRouteId, let r = playerRoutes.first(where: { $0.id == rid }) {
                    let floor = clubOperating(r.originCode) || clubOperating(r.destCode)
                        ? Simulation.clubCompetitionShareFloor : 0.2
                    effDemand *= r.competitionShare(reputation: reputation, shareFloor: floor)
                    // Double coverage: you compete with YOURSELF on a pair you
                    // serve twice. Eases over the integration, never to 1.0 —
                    // only closing/reassigning one of the pair clears it.
                    effDemand *= overlapDemandMultiplier(for: r)
                }
            }
            let base = Demand.loadFactor(seats: ac.type.seats, dailyOneWay: effDemand)
            load = min(Demand.maxLoadFactor, base * currentEvent.loadMultiplier * (0.9 + Double.random(in: 0..<0.2)))
        } else {
            load = min(1, baseLoadFactor * currentEvent.loadMultiplier * (0.95 + Double.random(in: 0..<0.1)))  // ±5%, capped
        }
        let pax = Int((Double(ac.type.seats) * load).rounded())
        ac.currentLoadFactor = load
        ac.currentPax = pax
        ac.projectedRevenue = Int((Double(pax) * farePerSeat).rounded())
        ac.holdBurn = 0   // fresh leg — no hold cost accrued yet
    }

    /// Real economics for a leg (projected while flying, settled at arrival).
    /// Ported from computeLegEconomics(): weight-based landing fee, body-type
    /// gate fee, per-bodyType stage-length operating cost × event multiplier.
    func legEconomics(for ac: Aircraft) -> LegEconomics {
        // Negotiated volume rates at the player's own OPERATING hub: −10%
        // landing / −20% gate (the real signatory-rate analog). Player only —
        // background traffic keeps full-rate fees (they're not displayed anyway).
        let hubFees = ac.purchased && hubOperating(ac.dest.code)
        let landingDiscount = hubFees ? Simulation.hubLandingFeeDiscount : 1
        let gateDiscount = hubFees ? Simulation.hubGateFeeDiscount : 1
        let landingFee = Int((ac.dest.landingFeePerKlb * (Double(ac.type.mlwLbs) / 1000) * landingDiscount).rounded())
        let gateFee = Int((Double(ac.type.bodyType.usesWidebodyGateFee ? ac.dest.gateFeeWidebody : ac.dest.gateFeeNarrowbody) * gateDiscount).rounded())
        // Base stage-length operating cost + any accrued hold burn (a held
        // flight keeps burning money at the gate — booked as cost, so revenue
        // stays = pax × fare and never goes negative). Net is identical to the
        // old "erode revenue" model, just correctly attributed.
        // Operating cost scales with the ACTUAL route distance (block minutes) —
        // the companion to distance-based fares — AND with airframe age (an old
        // jet costs more to keep flying, `maintenanceAgeMultiplier`). + hold burn.
        let blockMin = ac.type.bodyType.blockMinutes(forNM: ac.origin.greatCircleNM(to: ac.dest))
        let opCost = Int((blockMin * Double(ac.type.holdCostPerTick)
                          * effectiveCostMultiplier(for: ac) * ac.maintenanceAgeMultiplier).rounded())
                     + ac.holdBurn
        // DISPLAY-ONLY: a smoothed lease-per-leg figure for the tooltip. Does
        // not affect net/settlement — real lease is billed monthly. Ported
        // from computeLegEconomics: blockMinutes × (monthlyLeaseCost / month).
        let leaseEst = ac.isLeased
            ? Int((Double(ac.type.bodyType.operatingCostBlockMinutes)
                   * Double(ac.type.monthlyLeaseCost) / Double(Simulation.ticksPerMonth)).rounded())
            : 0
        return LegEconomics(revenue: ac.projectedRevenue, landingFee: landingFee,
                            gateFee: gateFee, operatingCost: opCost, leaseCostEstimate: leaseEst)
    }

    /// Settle a completed leg. Only OWNED aircraft move the player's money /
    /// route P&L; stress-test traffic is pure flavor.
    private func settleLeg(_ ac: Aircraft) {
        let econ = legEconomics(for: ac)
        guard ac.purchased else { return }
        recoverReputation(Simulation.repRecoverPerFlight)   // a clean completed flight rebuilds trust
        totalFlightsFlown += 1
        totalRevenue += econ.revenue
        totalFees += econ.fees
        totalOperatingCost += econ.operatingCost
        playerBalance += econ.net
        if let id = ac.assignedRouteId, let r = playerRoutes.first(where: { $0.id == id }) {
            let wasShort = r.cumulativeNet < r.openingCost
            r.cumulativeNet += econ.net
            if wasShort && r.cumulativeNet >= r.openingCost { celebrateRecoup(r) }
            r.flights += 1
            r.history.append(FlightRecord(
                id: r.history.count, tick: tick, tail: ac.tail,
                revenue: econ.revenue, fees: econ.fees, operatingCost: econ.operatingCost,
                leaseCostEstimate: econ.leaseCostEstimate, net: econ.net,
                pax: ac.currentPax, seats: ac.type.seats, loadFactor: ac.currentLoadFactor,
                cumulativeNet: r.cumulativeNet))
        }
        // At 80% of expected lifespan, offer a one-time sell decision.
        if !ac.sellOfferDismissed && ac.cyclesAccrued >= Int(Double(ac.type.expectedLifespanCycles) * 0.8) {
            pushDecision(.sell, for: ac)
        }
    }

    /// SELL card option: sell at linear-depreciated value, close its route.
    func resolveSell(_ decision: Decision) {
        // A leased aircraft can't be sold — it's handed back (with the penalty).
        if let ac = decision.aircraft { ac.isLeased ? terminateLease(ac) : sellAircraft(ac) }
    }

    /// Sell an aircraft (from the SELL card OR the Fleet detail screen): credit
    /// its depreciated value, release its crew, archive its route, remove it,
    /// and clear any pending decision cards for it.
    func sellAircraft(_ ac: Aircraft) {
        let proceeds = sellValue(of: ac)
        totalSaleProceeds += proceeds
        liquidate(ac, proceeds: proceeds)
    }

    /// Early lease-termination penalty — you don't own a leased jet, so you can't
    /// sell it; ending the lease early costs a fee. Real leases charge a few
    /// months' rent (or forfeit reserves) to break early; modeled here as 3
    /// months of the monthly lease payment. $0 for a non-leased aircraft.
    static let leaseTerminationMonths = 3
    func leaseTerminationPenalty(_ ac: Aircraft) -> Int {
        ac.isLeased ? Simulation.leaseTerminationMonths * ac.type.monthlyLeaseCost : 0
    }

    /// Terminate a lease early: hand the jet back (no proceeds — you never owned
    /// it) and pay the early-termination penalty. Charged to the lease-cost
    /// bucket so the Finance ledger stays consistent.
    func terminateLease(_ ac: Aircraft) {
        let penalty = leaseTerminationPenalty(ac)
        playerBalance -= penalty
        totalLeaseCost += penalty
        liquidate(ac, proceeds: 0)
    }

    /// Remove an aircraft from the fleet — crediting `proceeds` (a real sale) or
    /// $0 (a leased jet handed back in a forced liquidation). Releases crew,
    /// archives the route, frees slots, clears pending cards. The shared teardown.
    private func liquidate(_ ac: Aircraft, proceeds: Int) {
        playerBalance += proceeds
        // Release the sold aircraft's crew back to the pool (it isn't sold with
        // the aircraft) before the cleanup pass.
        if let cid = ac.crewId, let crew = crewPoolsByFamily[ac.type.family]?.first(where: { $0.id == cid }) {
            crew.status = .available
        }
        ac.crewId = nil
        if let id = ac.assignedRouteId, let idx = playerRoutes.firstIndex(where: { $0.id == id }) {
            // Archive, don't discard — the route's full P&L history stays
            // reviewable (including one that never recouped its cost).
            let r = playerRoutes.remove(at: idx)
            r.closedTick = tick
            closedPlayerRoutes.append(r)
            logOps(.structural, "Route closed", "\(r.originCode) ↔︎ \(r.destCode)")
            decisionQueue.removeAll { $0.kind == .offer && $0.offer?.routeId == id }
            airports.first { $0.code == r.originCode }?.slotsAvailable += 1
            airports.first { $0.code == r.destCode }?.slotsAvailable += 1
        }
        aircraft.removeAll { $0 === ac }
        decisionQueue.removeAll { $0.aircraft === ac }
        resizeCrewPools()   // clears the family's pool only if this was its last aircraft
    }

    // MARK: - Solvency / bankruptcy (the failure state)

    private(set) var isBankrupt = false
    /// Tick the balance first went negative (nil = solvent) — drives the grace
    /// countdown before a forced liquidation.
    private(set) var insolventSinceTick: Int?
    static let bankruptcyGraceTicks = 14 * 1440   // 14 sim-days to recover

    /// Sim-days left before forced liquidation (for the UI warning); nil = solvent.
    var insolvencyDaysLeft: Int? {
        guard let since = insolventSinceTick else { return nil }
        return max(0, (Simulation.bankruptcyGraceTicks - (tick - since)) / 1440)
    }

    /// Once per tick: negative cash starts a 14-day grace countdown; when it
    /// expires, force-liquidate to recover — and if that can't, it's game over.
    private func tickSolvency() {
        guard playerAirlineName != nil, !isBankrupt else { return }
        if playerBalance < 0 {
            if insolventSinceTick == nil {
                insolventSinceTick = tick
                logOps(.structural, "Cash on hand is negative",
                       "Recover within 14 days or assets will be liquidated")
            } else if tick - insolventSinceTick! >= Simulation.bankruptcyGraceTicks {
                forcedLiquidation()
            }
        } else {
            insolventSinceTick = nil
        }
    }

    /// Grace expired: sell owned aircraft (most valuable first) until solvent; if
    /// that isn't enough, hand back leased jets (no proceeds, but stops the
    /// bills); if the fleet empties and cash is still negative → bankruptcy.
    private func forcedLiquidation() {
        for ac in aircraft.filter({ $0.purchased && !$0.isLeased })
                          .sorted(by: { sellValue(of: $0) > sellValue(of: $1) }) where playerBalance < 0 {
            logOps(.structural, "Forced sale", "\(ac.tail) liquidated to cover debt")
            sellAircraft(ac)
        }
        if playerBalance < 0 {
            for ac in aircraft.filter({ $0.purchased && $0.isLeased }) {
                logOps(.structural, "Lease returned", "\(ac.tail) handed back to the lessor")
                liquidate(ac, proceeds: 0)
            }
        }
        if playerBalance < 0 && !aircraft.contains(where: { $0.purchased }) {
            isBankrupt = true
            insolventSinceTick = nil
            logOps(.structural, "BANKRUPTCY", "The airline is insolvent — game over")
        } else {
            insolventSinceTick = nil   // recovered; reset the clock
        }
    }

    // MARK: - Milestones / celebrations (surprise & delight)

    struct Celebration: Identifiable, Equatable {
        let id: Int
        let symbol: String          // SF Symbol name (app-aesthetic, not emoji)
        let title: String
        let subtitle: String
        /// Route milestone: the toast renders the pair with a ⇄ icon between them.
        var originCode: String? = nil
        var destCode: String? = nil
    }
    private(set) var celebrations: [Celebration] = []
    private var celebrationSeq = 0
    private var firedMilestones: Set<String> = []

    /// Queue a one-time celebration for `key` (deduped — fires once, ever).
    private func celebrate(_ key: String, _ symbol: String, _ title: String, _ subtitle: String,
                           originCode: String? = nil, destCode: String? = nil) {
        guard playerAirlineName != nil, !isBankrupt, firedMilestones.insert(key).inserted else { return }
        celebrationSeq += 1
        celebrations.append(Celebration(id: celebrationSeq, symbol: symbol, title: title, subtitle: subtitle,
                                        originCode: originCode, destCode: destCode))
        if celebrations.count > 3 { celebrations.removeFirst() }   // never back up too far
    }
    func dismissCelebration(_ id: Int) { celebrations.removeAll { $0.id == id } }
    /// Route recoup is celebrated from settleLeg; expose the trigger.
    fileprivate func celebrateRecoup(_ r: Route) {
        celebrate("recoup_\(r.id)", "chart.line.uptrend.xyaxis", "Route is profitable!",
                  "Recouped its opening cost.", originCode: r.originCode, destCode: r.destCode)
    }

    /// Checked once per tick — net-worth thresholds, fleet size, flight counts.
    private func checkMilestones() {
        guard playerAirlineName != nil, !isBankrupt else { return }
        if ownedCount >= 1 { celebrate("first_aircraft", "airplane", "First jet purchased!", "Your fleet has its first aircraft.") }
        if totalFlightsFlown >= 1 { celebrate("first_flight", "airplane.departure", "First flight complete!", "Wheels up — welcome to the skies.") }
        if totalFlightsFlown >= 1000 { celebrate("flights_1k", "trophy.fill", "1,000 flights flown", "The network is humming.") }
        if !hubs.isEmpty { celebrate("first_hub", "building.2.crop.circle", "First hub established!", "Your fortress takes shape.") }
        if hubs.values.contains(where: { $0.hasClub }) { celebrate("first_club", "cup.and.saucer.fill", "First club opened!", "Loyalty has a lounge now.") }
        // Net-worth ladder. Gated on owning at least one aircraft so nothing
        // fires before the player has deployed any capital (net worth == the $20M
        // starting stake). The lowest tier ($30M) is real growth above the start.
        let nw = playerBalance + fleetMarketValue
        let owned = ownedCount
        if owned >= 1 {
            for (t, label) in [(30_000_000, "$30M"), (50_000_000, "$50M"), (100_000_000, "$100M"),
                               (250_000_000, "$250M"), (500_000_000, "$500M"), (1_000_000_000, "$1B")] where nw >= t {
                celebrate("nw_\(t)", "chart.line.uptrend.xyaxis", "\(label) net worth", "The airline is really taking off.")
            }
        }
        for (n, sub) in [(5, "A real fleet now."), (10, "Double digits!"),
                         (25, "A major carrier."), (50, "A powerhouse of the skies.")] where owned >= n {
            celebrate("fleet_\(n)", "airplane.circle.fill", "\(n) aircraft in the fleet", sub)
        }
    }

    // MARK: - Persistence (save / restore)

    /// Export the persistent game state. Background traffic, live event effects,
    /// and the used market are NOT saved — they regenerate on load.
    func snapshot() -> GameSnapshot {
        var s = GameSnapshot()
        s.savedAtTick = tick
        s.playerAirlineName = playerAirlineName
        s.playerTailCode = playerTailCode
        s.playerBalance = playerBalance
        s.tick = tick
        s.nextTailNum = nextTailNum
        s.nextRouteId = nextRouteId
        s.totalRevenue = totalRevenue; s.totalFees = totalFees
        s.totalOperatingCost = totalOperatingCost; s.totalLeaseCost = totalLeaseCost
        s.totalInsuranceSpent = totalInsuranceSpent; s.maintenanceSpend = maintenanceSpend
        s.totalAcquisitionSpend = totalAcquisitionSpend; s.totalRouteSpend = totalRouteSpend
        s.totalHedgeSpend = totalHedgeSpend; s.totalSaleProceeds = totalSaleProceeds
        s.totalOfferIncome = totalOfferIncome; s.totalFlightsFlown = totalFlightsFlown
        s.totalLoanProceeds = totalLoanProceeds; s.totalDebtService = totalDebtService
        s.loans = loans.map { LoanSave(id: $0.id, originalPrincipal: $0.originalPrincipal,
                                       remainingPrincipal: $0.remainingPrincipal, monthlyRate: $0.monthlyRate,
                                       monthlyPayment: $0.monthlyPayment, termMonths: $0.termMonths, takenTick: $0.takenTick) }
        s.isBankrupt = isBankrupt; s.insolventSinceTick = insolventSinceTick
        s.useDemandModel = useDemandModel
        s.reputation = reputation
        s.firedMilestones = Array(firedMilestones)
        s.stressTestCount = stressTestCount
        s.cameraZoom = cameraZoom; s.cameraCenterX = cameraCenter.x; s.cameraCenterY = cameraCenter.y
        s.homeRegion = homeRegion.rawValue
        s.competitorSeed = competitorSeed
        s.subsidiaries = subsidiaries
        s.totalAcquisitionPrice = totalAcquisitionPrice
        s.activeIntegration = activeIntegration
        s.diligencedCarriers = Array(diligencedCarriers)
        s.totalDiligenceSpend = totalDiligenceSpend
        s.publicCompany = publicCompany
        s.marketSentiment = marketSentiment
        s.displaySharePrice = displaySharePrice
        s.totalEquityRaised = totalEquityRaised
        s.totalDividendsPaid = totalDividendsPaid
        s.totalBuybackSpend = totalBuybackSpend
        s.totalIntegrationSpend = totalIntegrationSpend
        s.totalSenioritySpend = totalSenioritySpend
        s.hubs = hubs
        s.rivalHubs = rivalHubs
        s.totalHubSpend = totalHubSpend
        s.totalHubLabor = totalHubLabor
        s.totalClubRent = totalClubRent
        s.aircraft = aircraft.filter { $0.purchased }.map { ac in
            AircraftSave(tail: ac.tail, typeId: ac.type.id, originCode: ac.origin.code, destCode: ac.dest.code,
                         stateIndex: ac.stateIndex, stateTick: ac.stateTick, cyclesAccrued: ac.cyclesAccrued,
                         assignedRouteId: ac.assignedRouteId, pendingRouteId: ac.pendingRouteId,
                         sellOfferDismissed: ac.sellOfferDismissed,
                         isLeased: ac.isLeased, leaseAccrued: ac.leaseAccrued, maint: ac.maint,
                         aogAutoClearTick: ac.aogAutoClearTick, crewId: ac.crewId,
                         subsidiaryCode: ac.subsidiaryCode)
        }
        s.routes = playerRoutes.map(routeSave)
        s.closedRoutes = closedPlayerRoutes.map(routeSave)
        s.crewPools = crewPoolsByFamily.mapValues { $0.map { CrewSave(id: $0.id, status: $0.status.saveCode, dutyTicks: $0.dutyTicks, restTicksLeft: $0.restTicksLeft) } }
        s.reserveCrews = reserveCrewsByFamily
        s.crewTrainingDue = crewTrainingDueByFamily
        s.crewTrainingDeferred = crewTrainingDeferredByFamily
        s.financeSnapshots = financeSnapshots.map { f in
            FinanceSave(tick: f.tick, revenue: f.revenue, fees: f.fees, operatingCost: f.operatingCost,
                        leaseCost: f.leaseCost, insurance: f.insurance, maintenance: f.maintenance,
                        acquisition: f.acquisition, routeSpend: f.routeSpend, hedgeSpend: f.hedgeSpend,
                        saleProceeds: f.saleProceeds, offerIncome: f.offerIncome, flights: f.flights,
                        cash: f.cash, netWorth: f.netWorth,
                        loanProceeds: f.loanProceeds, debtService: f.debtService,
                        hubSpend: f.hubSpend, hubLabor: f.hubLabor, clubRent: f.clubRent,
                        airlineAcquisition: f.airlineAcquisition,
                        integrationSpend: f.integrationSpend,
                        equityRaised: f.equityRaised,
                        dividendsPaid: f.dividendsPaid, buybackSpend: f.buybackSpend)
        }
        return s
    }

    private func routeSave(_ r: Route) -> RouteSave {
        RouteSave(id: r.id, originCode: r.originCode, destCode: r.destCode, openedTick: r.openedTick,
                  openingCost: r.openingCost, cumulativeNet: r.cumulativeNet, flights: r.flights,
                  totalLeaseCost: r.totalLeaseCost, closedTick: r.closedTick,
                  competitionLevel: r.competitionLevel, competitors: r.competitors,
                  incentiveBonus: r.incentiveBonus, incentiveWaived: r.incentiveWaived, fulfillByTick: r.fulfillByTick,
                  subsidiaryCode: r.subsidiaryCode,
                  history: r.history.map { FlightRecordSave(id: $0.id, tick: $0.tick, tail: $0.tail, revenue: $0.revenue, fees: $0.fees, operatingCost: $0.operatingCost, leaseCostEstimate: $0.leaseCostEstimate, net: $0.net, pax: $0.pax, seats: $0.seats, loadFactor: $0.loadFactor, cumulativeNet: $0.cumulativeNet) },
                  assignmentHistory: r.assignmentHistory.map { RouteAssignmentSave(id: $0.id, tail: $0.tail, typeName: $0.typeName, assignedTick: $0.assignedTick) })
    }
    private func restoreRoute(_ s: RouteSave) -> Route {
        let r = Route(id: s.id, originCode: s.originCode, destCode: s.destCode, openedTick: s.openedTick, openingCost: s.openingCost)
        r.cumulativeNet = s.cumulativeNet; r.flights = s.flights; r.totalLeaseCost = s.totalLeaseCost; r.closedTick = s.closedTick
        r.subsidiaryCode = s.subsidiaryCode
        r.competitionLevel = s.competitionLevel; r.competitors = s.competitors
        r.incentiveBonus = s.incentiveBonus; r.incentiveWaived = s.incentiveWaived; r.fulfillByTick = s.fulfillByTick
        r.history = s.history.map { FlightRecord(id: $0.id, tick: $0.tick, tail: $0.tail, revenue: $0.revenue, fees: $0.fees, operatingCost: $0.operatingCost, leaseCostEstimate: $0.leaseCostEstimate, net: $0.net, pax: $0.pax, seats: $0.seats, loadFactor: $0.loadFactor, cumulativeNet: $0.cumulativeNet) }
        r.assignmentHistory = s.assignmentHistory.map { RouteAssignment(id: $0.id, tail: $0.tail, typeName: $0.typeName, assignedTick: $0.assignedTick) }
        return r
    }

    /// Load a saved game into this (fresh) Simulation instance.
    func restore(from s: GameSnapshot) {
        playerAirlineName = s.playerAirlineName
        playerTailCode = s.playerTailCode
        playerBalance = s.playerBalance
        tick = s.tick
        nextTailNum = s.nextTailNum
        nextRouteId = s.nextRouteId
        totalRevenue = s.totalRevenue; totalFees = s.totalFees
        totalOperatingCost = s.totalOperatingCost; totalLeaseCost = s.totalLeaseCost
        totalInsuranceSpent = s.totalInsuranceSpent; maintenanceSpend = s.maintenanceSpend
        totalAcquisitionSpend = s.totalAcquisitionSpend; totalRouteSpend = s.totalRouteSpend
        totalHedgeSpend = s.totalHedgeSpend; totalSaleProceeds = s.totalSaleProceeds
        totalOfferIncome = s.totalOfferIncome; totalFlightsFlown = s.totalFlightsFlown
        totalLoanProceeds = s.totalLoanProceeds; totalDebtService = s.totalDebtService
        loans = s.loans.map { Loan(id: $0.id, originalPrincipal: $0.originalPrincipal,
                                   remainingPrincipal: $0.remainingPrincipal, monthlyRate: $0.monthlyRate,
                                   monthlyPayment: $0.monthlyPayment, termMonths: $0.termMonths, takenTick: $0.takenTick) }
        nextLoanId = (loans.map { $0.id }.max() ?? 0) + 1
        isBankrupt = s.isBankrupt; insolventSinceTick = s.insolventSinceTick
        useDemandModel = s.useDemandModel
        reputation = s.reputation
        firedMilestones = Set(s.firedMilestones)
        // Home region BEFORE camera: sets homeFrame without clobbering the
        // restored camera (userAdjustedCamera goes true right after).
        homeRegion = s.homeRegion.flatMap { Airline.PlayerRegion(rawValue: $0) } ?? .northAmerica
        competitorSeed = s.competitorSeed ?? UInt64.random(in: 1...UInt64.max)
        rebuildCompetitorIntel()
        // Restored BEFORE the fleet, so an inherited aircraft can look up its
        // subsidiary's name for the tooltip/airline label.
        subsidiaries = s.subsidiaries ?? []
        totalAcquisitionPrice = s.totalAcquisitionPrice ?? 0
        activeIntegration = s.activeIntegration
        diligencedCarriers = Set(s.diligencedCarriers ?? [])
        totalDiligenceSpend = s.totalDiligenceSpend ?? 0
        publicCompany = s.publicCompany
        marketSentiment = s.marketSentiment ?? 1.0
        displaySharePrice = s.displaySharePrice ?? 0
        totalEquityRaised = s.totalEquityRaised ?? 0
        totalDividendsPaid = s.totalDividendsPaid ?? 0
        totalBuybackSpend = s.totalBuybackSpend ?? 0
        lastDividendTick = tick   // reset the income clock on load (transient)
        nextSentimentTick = tick + Simulation.ticksPerMonth
        totalIntegrationSpend = s.totalIntegrationSpend ?? 0
        totalSenioritySpend = s.totalSenioritySpend ?? 0
        hubs = s.hubs ?? [:]
        rivalHubs = s.rivalHubs ?? [:]
        totalHubSpend = s.totalHubSpend ?? 0
        totalHubLabor = s.totalHubLabor ?? 0
        totalClubRent = s.totalClubRent ?? 0
        nextHubBillTick = s.tick + Simulation.ticksPerMonth   // re-seed like insurance
        homeFrame = Simulation.frame(for: homeRegion, airports: airports)
        cameraZoom = s.cameraZoom; cameraCenter = CGPoint(x: s.cameraCenterX, y: s.cameraCenterY)
        userAdjustedCamera = true   // don't auto-reframe over the restored camera

        // Crew pools first (aircraft reference crew by id within their family).
        crewPoolsByFamily = s.crewPools.mapValues { list in
            list.map { cs in let c = Crew(id: cs.id); c.status = CrewStatus(saveCode: cs.status); c.dutyTicks = cs.dutyTicks; c.restTicksLeft = cs.restTicksLeft; return c }
        }
        reserveCrewsByFamily = s.reserveCrews
        crewTrainingDueByFamily = s.crewTrainingDue
        crewTrainingDeferredByFamily = s.crewTrainingDeferred

        // Routes.
        playerRoutes = s.routes.map(restoreRoute)
        closedPlayerRoutes = s.closedRoutes.map(restoreRoute)

        // Owned fleet (rebuild; background traffic regenerates below).
        let byCode = Dictionary(airports.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
        aircraft.removeAll { $0.purchased }
        for a in s.aircraft {
            guard let type = AircraftType.byId[a.typeId], let o = byCode[a.originCode], let d = byCode[a.destCode] else { continue }
            let ac = Aircraft(tail: a.tail, type: type, origin: o, dest: d, stateIndex: a.stateIndex,
                              cyclesAccrued: a.cyclesAccrued, purchased: true)
            ac.stateTick = a.stateTick; ac.assignedRouteId = a.assignedRouteId
            ac.pendingRouteId = a.pendingRouteId
            ac.sellOfferDismissed = a.sellOfferDismissed; ac.isLeased = a.isLeased; ac.leaseAccrued = a.leaseAccrued
            ac.maint = a.maint; ac.aogAutoClearTick = a.aogAutoClearTick; ac.crewId = a.crewId
            ac.subsidiaryCode = a.subsidiaryCode
            if let code = a.subsidiaryCode { ac.airlineName = subsidiaries.first { $0.code == code }?.name }
            rollRevenue(for: ac)
            aircraft.append(ac)
        }

        // Finance history.
        financeSnapshots = s.financeSnapshots.map { f in
            FinanceSnapshot(tick: f.tick, revenue: f.revenue, fees: f.fees, operatingCost: f.operatingCost,
                            leaseCost: f.leaseCost, insurance: f.insurance, maintenance: f.maintenance,
                            acquisition: f.acquisition, routeSpend: f.routeSpend, hedgeSpend: f.hedgeSpend,
                            saleProceeds: f.saleProceeds, offerIncome: f.offerIncome, flights: f.flights,
                            loanProceeds: f.loanProceeds, debtService: f.debtService,
                            hubSpend: f.hubSpend ?? 0, hubLabor: f.hubLabor ?? 0, clubRent: f.clubRent ?? 0,
                            airlineAcquisition: f.airlineAcquisition ?? 0,
                            integrationSpend: f.integrationSpend ?? 0,
                            equityRaised: f.equityRaised ?? 0,
                            dividendsPaid: f.dividendsPaid ?? 0, buybackSpend: f.buybackSpend ?? 0,
                            cash: f.cash, netWorth: f.netWorth)
        }
        if financeSnapshots.isEmpty { financeSnapshots = [financeSnapshotNow()] }

        // Transient state: reset event, decisions, market; re-account slots.
        currentEvent = .normal
        decisionQueue.removeAll()
        provisionSlots()
        for r in playerRoutes {
            byCode[r.originCode].map { $0.slotsAvailable = max(0, $0.slotsAvailable - 1) }
            byCode[r.destCode].map { $0.slotsAvailable = max(0, $0.slotsAvailable - 1) }
        }
        nextInsuranceBillTick = ((tick / Simulation.ticksPerMonth) + 1) * Simulation.ticksPerMonth
        nextLoanBillTick = ((tick / Simulation.ticksPerMonth) + 1) * Simulation.ticksPerMonth

        // Regenerate the competitor (background) traffic to the saved count.
        setFleetSize(s.stressTestCount)
    }

    /// SELL card option: keep flying (don't re-prompt this aircraft).
    func resolveSellKeep(_ decision: Decision) {
        decision.aircraft?.sellOfferDismissed = true
        decisionQueue.removeAll { $0.id == decision.id }
    }

    /// One sim-minute for the whole world.
    func advanceTick() {
        tick += 1
        // Capture a finance snapshot at each sim-month boundary (the launch
        // baseline is seeded in init) for the Finance tab's period views.
        if tick % Simulation.ticksPerMonth == 0 { financeSnapshots.append(financeSnapshotNow()) }
        tickWeather()
        tickCrewPool()
        tickAOGOnset()
        tickEconomicEvents()
        tickWorldEvents()
        tickSlotAvailability()
        tickLeaseBilling()
        tickInsuranceBilling()
        tickIntegration()
        tickLoanBilling()
        tickStockPrice()
        tickHubBilling()
        tickUsedMarketReplenishment()
        tickSolvency()
        assignSpareToPendingRoutes()   // staff any offer-opened routes with an in-range spare
        checkMilestones()
        for ac in aircraft {
            switch ac.advance(tick: tick, assignCrew: assignCrew, releaseCrew: releaseCrew) {
            case .aogHoldStarted:      pushDecision(.aog, for: ac); dingReputation(Simulation.repHitAOG)
            case .aogRepairCompleted:  clearDecision(.aog, for: ac)   // defensive — card normally already resolved
            case .crewHoldStarted:     pushDecision(.crew, for: ac); dingReputation(Simulation.repHitCrew)
            case .crewHoldResolved:    clearDecision(.crew, for: ac)  // crew freed up outside the card's own buttons
            case .legScheduled:
                // Background traffic picks a NEW route each cycle, but within its
                // carrier's own geographic sphere (home region ± plausible
                // international corridors) — NOT a random global pair, which used to
                // let a carrier wander anywhere. Owned aircraft keep their assigned
                // route (advance already swapped origin/dest).
                if !ac.purchased { (ac.origin, ac.dest) = backgroundLeg(for: ac.homeRegion ?? .us, type: ac.type) }
                rollRevenue(for: ac)
            case .legCompleted:
                settleLeg(ac)
                // It has landed and settled — now honour any deferred move.
                if ac.pendingRouteId != nil { completePendingReassignment(ac) }
            case nil:                  break
            }
            // A booked aircraft still burns money while stuck at the gate
            // (AOG/crew) — accrue that burn as OPERATING COST (not negative
            // revenue), scaled by the effective (hedge-aware) cost multiplier.
            // Charged at a FRACTION of the flight rate (holdBurnRate) — a parked
            // aircraft isn't burning full block-hour cost. Net still slides toward
            // loss the longer it's held (plus the lost flights), so the pressure
            // to resolve a hold / hire crew remains.
            if ac.holdReason == .aog || ac.holdReason == .crew {
                ac.holdBurn += Int((Double(ac.type.holdCostPerTick) * Simulation.holdBurnRate * effectiveCostMultiplier(for: ac)).rounded())
            }
        }
    }

    /// Per-airport weather ground stops. Onset uses each airport's real
    /// groundStopsPerMonth rate; duration 90–330 ticks (1.5–5.5 sim-hours).
    /// Ported from tickWeather(). Universal — applies to all traffic.
    private func tickWeather() {
        let relevant = playerRouteCodes   // only log weather where the player flies
        for ap in airports {
            if ap.groundStop {
                ap.groundStopTicksLeft -= 1
                if ap.groundStopTicksLeft <= 0 {
                    ap.groundStop = false
                    ap.groundStopReason = nil
                    if relevant.contains(ap.code) { logOps(.disruption, "Ground stop lifted", ap.code) }
                }
            } else if Double.random(in: 0..<1) < ap.groundStopsPerMonth / Double(Simulation.ticksPerMonth) {
                ap.groundStop = true
                ap.groundStopTicksLeft = 90 + Int.random(in: 0...240)
                ap.groundStopReason = "Weather"
                if relevant.contains(ap.code) { logOps(.disruption, "Ground stop", "Weather hold at \(ap.code)", airportCode: ap.code) }
            }
        }
    }

    /// The async tick loop. Start once from the view's `.task`; it advances the
    /// world in real time based on `speed`, independent of how often the view
    /// draws. Cancelling the surrounding Task (view disappears) ends it.
    func run() async {
        var last = ContinuousClock.now
        var lastDisplay = ContinuousClock.now
        var accumulatorMs: Double = 0

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(8))
            let now = ContinuousClock.now
            let deltaMs = Double((now - last).components.attoseconds) / 1e15
                        + Double((now - last).components.seconds) * 1000
            last = now

            // Paused (QUIT-to-menu, app backgrounded): no ticks, and DISCARD any
            // accumulated time so unpausing never fast-forwards.
            if isPaused { accumulatorMs = 0; continue }

            guard speed > 0 else { continue }

            // Clamp the per-wake delta: if the process was suspended (app in the
            // background), the wall clock kept running but the game must NOT —
            // without this clamp the accumulator drains the whole absence as
            // catch-up ticks (50 per wake) after resume. Real time away from the
            // app never becomes sim time.
            accumulatorMs += min(deltaMs, 250)
            let intervalMs = Simulation.baseTickMs / speed
            var ticksThisWake = 0
            while accumulatorMs >= intervalMs && ticksThisWake < 50 {
                advanceTick()
                accumulatorMs -= intervalMs
                ticksThisWake += 1
            }

            // Throttle the UI heartbeat to ~5×/sec so list/HUD views observing
            // `displayTick` don't re-evaluate their whole body every sim-tick
            // (which made scrolling/tapping laggy at high speed on iPad).
            if displayTick != tick, now - lastDisplay >= .milliseconds(200) {
                displayTick = tick
                lastDisplay = now
            }
        }
    }
}
