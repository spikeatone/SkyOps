//
//  Economics.swift
//  SkyOps — Phase 5
//
//  Per-flight economics: revenue (seats × load factor × fare, rolled at
//  SCHEDULING time so a hold can erode it), real operating cost (per-bodyType
//  stage length × cost/tick), and real fees (weight-based landing + body-type
//  gate). Ported from computeLegEconomics / rollRevenue. Economic-EVENT
//  multipliers are modeled here but only NORMAL exists until the events slice.
//

import Foundation

/// Industry load factor baseline (IATA 2026 record high, supply-constrained).
let baseLoadFactor = 0.838

/// An economic condition that scales cost / fare / demand together.
struct EconomicEvent {
    let id: String
    let label: String
    let costMultiplier: Double
    let fareMultiplier: Double
    let loadMultiplier: Double

    static let normal = EconomicEvent(id: "NORMAL", label: "Normal",
                                      costMultiplier: 1, fareMultiplier: 1, loadMultiplier: 1)
}

/// The settled (or projected) economics of one flight leg. `revenue` is the
/// value rolled at scheduling (possibly eroded by a hold); `net` excludes lease
/// (billed separately, later).
struct LegEconomics {
    var revenue: Int
    var landingFee: Int
    var gateFee: Int
    var operatingCost: Int
    var net: Int { revenue - landingFee - gateFee - operatingCost }
    var fees: Int { landingFee + gateFee }
}
