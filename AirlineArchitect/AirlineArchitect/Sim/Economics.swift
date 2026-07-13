//
//  Economics.swift
//  Airline Architect — Phase 5
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

    /// The four events, ported from ECONOMIC_EVENTS. Magnitude anchored to a
    /// real ~32% YoY jet-fuel swing (IATA 2026); the specific multipliers and
    /// the fare→load price-elasticity are designed for pacing. A real emergent
    /// property: 4-engine widebodies go NET NEGATIVE under an oil spike while
    /// everything else just compresses — this falls out of the cost/revenue
    /// math, matching the real dynamic that pushed those types to retirement.
    static let all: [EconomicEvent] = [
        .init(id: "OIL_SPIKE", label: "Oil Price Spike", costMultiplier: 1.30, fareMultiplier: 1.15, loadMultiplier: 0.95),
        .init(id: "FUEL_GLUT", label: "Fuel Price Drop", costMultiplier: 0.85, fareMultiplier: 0.95, loadMultiplier: 1.03),
        .init(id: "ECON_BOOM", label: "Economic Boom",   costMultiplier: 1.00, fareMultiplier: 1.10, loadMultiplier: 1.05),
        .init(id: "RECESSION", label: "Recession",       costMultiplier: 1.00, fareMultiplier: 0.85, loadMultiplier: 0.90),
    ]

    var isNormal: Bool { id == "NORMAL" }
}

/// The settled (or projected) economics of one flight leg. `revenue` is the
/// value rolled at scheduling (possibly eroded by a hold); `net` excludes lease
/// (billed separately, later).
struct LegEconomics {
    var revenue: Int
    var landingFee: Int
    var gateFee: Int
    var operatingCost: Int
    /// DISPLAY-ONLY smoothed per-leg lease estimate (0 unless leased). Real
    /// lease is a fixed monthly bill billed separately (tickLeaseBilling), so
    /// this does NOT affect `net` / settlement — it only lets the in-flight
    /// tooltip fold a readable lease figure into its shown operating cost.
    var leaseCostEstimate: Int = 0

    var net: Int { revenue - landingFee - gateFee - operatingCost }
    var fees: Int { landingFee + gateFee }

    /// Tooltip-only: operating cost with the smoothed lease estimate folded in.
    var displayOperatingCost: Int { operatingCost + leaseCostEstimate }
    /// Tooltip-only net, internally consistent with displayOperatingCost.
    var displayNet: Int { revenue - fees - displayOperatingCost }
}
