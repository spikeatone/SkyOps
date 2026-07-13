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

final class Route: Identifiable {
    let id: Int
    let originCode: String
    let destCode: String
    let openedTick: Int
    let openingCost: Int

    /// Sum of every completed leg's net on this route.
    var cumulativeNet: Int = 0
    /// Legs flown on this route.
    var flights: Int = 0
    /// Real fixed lease bills charged while this route's aircraft was leased
    /// (billed by tickLeaseBilling, NOT a flight event) — a real cost against
    /// this route's profitability even when no flight happened at that tick.
    var totalLeaseCost: Int = 0

    init(id: Int, originCode: String, destCode: String, openedTick: Int, openingCost: Int) {
        self.id = id
        self.originCode = originCode
        self.destCode = destCode
        self.openedTick = openedTick
        self.openingCost = openingCost
    }

    /// True once the route has earned back its opening cost.
    var isProfitable: Bool { cumulativeNet >= openingCost }
    /// P&L against the establishment cost (negative until recouped).
    var netVsOpeningCost: Int { cumulativeNet - openingCost }
}
