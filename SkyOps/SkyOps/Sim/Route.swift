//
//  Route.swift
//  SkyOps — Phase 5 (player route network)
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
    /// Per-flight record (the data a P&L chart needs). Grows unbounded; the
    /// panel caps only its DISPLAY list, never the aggregate summaries.
    var history: [FlightRecord] = []
    /// Aircraft assigned to this route over its life.
    var assignmentHistory: [RouteAssignment] = []
    /// Set when the route is archived (its aircraft was sold). nil = open.
    var closedTick: Int?

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

    // Aggregates from the FULL history (never truncated).
    var totalRevenue: Int { history.reduce(0) { $0 + $1.revenue } }
    var totalFees: Int { history.reduce(0) { $0 + $1.fees } }
    var totalOperatingCost: Int { history.reduce(0) { $0 + $1.operatingCost } }
    var averageLoadPct: Int {
        guard !history.isEmpty else { return 0 }
        return Int((100 * history.reduce(0.0) { $0 + $1.loadFactor } / Double(history.count)).rounded())
    }
}
