//
//  Route.swift
//  Airline Architect — Phase 5 (player route network)
//
//  A route the player has opened between two airports. A purchased aircraft is
//  assigned to it and flies it back and forth; every completed leg's net feeds
//  `cumulativeNet`, which is judged against `openingCost` — a route isn't
//  "profitable" the moment one flight nets positive, it's profitable once
//  cumulative net actually recoups what it cost to open. Ported from the
//  prototype's route object (history/assignmentHistory deferred to a later
//  slice — this keeps the running P&L, which is what the panel needs first).
//

import Foundation

/// One completed flight on a route — deliberately more than net/cumulative, so
/// a detail view can show load & revenue history (and a future chart can plot
/// the whole curve and pinpoint the flight that crossed into profit). Kept even
/// after a route closes. `leaseCostEstimate` is DISPLAY-ONLY (does not affect
/// net); real lease bills live on Route.totalLeaseCost.
struct FlightRecord: Identifiable {
    let id: Int              // sequential within the route (for stable ForEach)
    let tick: Int
    let tail: String
    let revenue: Int
    let fees: Int
    let operatingCost: Int
    let leaseCostEstimate: Int
    let net: Int
    let pax: Int
    let seats: Int
    let loadFactor: Double
    let cumulativeNet: Int   // route cumulative net AT this flight
}

/// Which aircraft flew a route and when assigned. A real array (not a single
/// field) so a future reassignment mechanic works without a rewrite — today a
/// route only ever has one aircraft for its whole life.
struct RouteAssignment: Identifiable {
    let id: Int
    let tail: String
    let typeName: String
    let assignedTick: Int
}

final class Route: Identifiable {
    let id: Int
    let originCode: String
    let destCode: String
    let openedTick: Int
    let openingCost: Int

    /// Sum of every completed leg's net on this route, minus lease bills.
    var cumulativeNet: Int = 0
    /// Legs flown on this route (== history.count).
    var flights: Int = 0
    /// Real fixed lease bills charged while this route's aircraft was leased
    /// (billed by tickLeaseBilling, NOT a flight event) — a real cost against
    /// this route's profitability even when no flight happened at that tick.
    var totalLeaseCost: Int = 0
    /// Per-flight record (the data the P&L chart/log needs). CAPPED at
    /// `maxHistory` (oldest dropped) so a long-running route can't bloat the save
    /// into a multi-MB file that blows the launch watchdog / memory on load. The
    /// LIFETIME aggregate summaries below are running totals, so capping the log
    /// never loses them.
    static let maxHistory = 60
    var history: [FlightRecord] = []
    /// Lifetime running totals (independent of the capped history), incremented
    /// per completed leg in settleLeg. `flights`/`cumulativeNet` above are the
    /// same pattern; these back the Routes-detail revenue/fees/opcost/avg-load.
    var revenueTotal = 0
    var feesTotal = 0
    var opCostTotal = 0
    var loadFactorSum: Double = 0
    /// Aircraft assigned to this route over its life.
    var assignmentHistory: [RouteAssignment] = []
    /// Set when the route is archived (its aircraft was sold). nil = open.
    var closedTick: Int?

    // Competition: rival carriers that have entered this market (they enter a
    // profitable route to chase the traffic, and split its demand). `competitors`
    // names them for display; count drives the share split.
    var competitionLevel: Int = 0
    var competitors: [String] = []
    /// Non-nil when this route came with an acquired subsidiary.
    var subsidiaryCode: String?

    // Airport incentive (from an accepted route offer): the signing bonus banked
    // and the opening cost that was waived — both for the Ops incentives display.
    var incentiveBonus: Int = 0
    var incentiveWaived: Int = 0
    var hasIncentive: Bool { incentiveBonus > 0 || incentiveWaived > 0 }
    /// Deadline to STAFF an offer-opened route (put an aircraft on it). Miss it and
    /// the route is forfeited + the marketing bonus clawed back. nil = fulfilled /
    /// no obligation.
    var fulfillByTick: Int? = nil

    /// The player's share of this route's demand given the competition on it and
    /// the airline's reputation. Uncontested = 1.0. Each rival takes a slice, but
    /// a strong reputation lets the airline hold more of the market.
    /// `shareFloor` defaults to the base 0.2; a club at either endpoint raises
    /// it to 0.35 (loyal flyers don't defect — the caller passes the floor).
    func competitionShare(reputation: Double, shareFloor: Double = 0.2) -> Double {
        guard competitionLevel > 0 else { return 1.0 }
        let factor = 0.6 - 0.3 * (reputation / 100)   // rep 100 → 0.30, rep 0 → 0.60
        return max(shareFloor, 1.0 / (1.0 + Double(competitionLevel) * factor))
    }
    /// Signed demand impact of competition for the Ops box, given reputation.
    func competitionPercent(reputation: Double) -> Int {
        Int(((competitionShare(reputation: reputation) - 1) * 100).rounded())
    }

    init(id: Int, originCode: String, destCode: String, openedTick: Int, openingCost: Int) {
        self.id = id
        self.originCode = originCode
        self.destCode = destCode
        self.openedTick = openedTick
        self.openingCost = openingCost
    }

    var isOpen: Bool { closedTick == nil }
    /// True once the route has earned back its opening cost.
    var isProfitable: Bool { cumulativeNet >= openingCost }
    /// P&L against the establishment cost (negative until recouped).
    var netVsOpeningCost: Int { cumulativeNet - openingCost }

    // Lifetime aggregates — running totals (the history log is capped, so these
    // do NOT recompute from it).
    var totalRevenue: Int { revenueTotal }
    var totalFees: Int { feesTotal }
    var totalOperatingCost: Int { opCostTotal }
    var averageLoadPct: Int {
        guard flights > 0 else { return 0 }
        return Int((100 * loadFactorSum / Double(flights)).rounded())
    }
}
