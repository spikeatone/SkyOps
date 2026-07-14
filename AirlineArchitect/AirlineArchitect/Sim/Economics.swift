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
/// Used only when the demand model is OFF (dev A/B toggle) — otherwise load
/// factor is an OUTCOME of route demand vs. aircraft capacity (see Demand).
let baseLoadFactor = 0.838

/// Passenger-demand gravity model (prototype). Each city pair has a real daily
/// passenger pool ∝ the two airports' throughput and shaped by distance, so a
/// route's load factor becomes an OUTCOME (how full you fly vs. how many want to
/// go) rather than a flat constant. This makes route selection and aircraft
/// SIZE-vs-route matching a real decision: a widebody on a thin route flies
/// half-empty and loses money; a regional jet fills it.
///
/// Calibration: `k` is set so a route between two ~5M-annual-passenger airports
/// at medium haul yields ~135 passengers per one-way leg — a narrowbody at ~75%
/// load across the sim's ~2 daily frequencies each way. Trunk routes (big×big,
/// short) overflow any aircraft (capped fill → reward big jets); thin routes
/// (small×small) only pay on small aircraft. All values are tunable.
enum Demand {
    static let k = 3.0e-5
    static let maxLoadFactor = 0.92          // timing/no-shows cap fill even with excess demand
    static let dailyFrequenciesEachWay = 2.0 // sim: ~369-tick legs → ~2/day/direction

    /// Effective air-travel throughput of an airport (annual passengers; falls
    /// back to a metro-population proxy, then a small default) — the "mass" in
    /// the gravity model.
    static func throughput(_ ap: Airport) -> Double {
        if let p = ap.info?.annualPassengers, p > 0 { return Double(p) }
        if let m = ap.info?.metroPopulation, m > 0 { return Double(m) * 3 }  // ~3 air trips/capita/yr
        return 800_000
    }

    /// Distance shaping: gentle. Very short hops lose a little (people drive);
    /// medium haul is the 1.0 sweet spot; very long haul decays slowly (a niche,
    /// not zero). Distance's bigger economic effect is via fare/cost, not demand.
    static func distanceFactor(_ nm: Double) -> Double {
        if nm < 200 { return 0.8 }
        if nm < 2000 { return 1.0 }
        return max(0.5, 1.0 - (nm - 2000) / 8000)   // → 0.5 at ~6000 nm
    }

    /// Daily one-way passenger demand for a city pair. Geometric mean of the two
    /// throughputs (so demand tracks the SMALLER endpoint — realistic — and the
    /// big×small spread stays sane, unlike the raw product).
    static func dailyOneWay(_ a: Airport, _ b: Airport) -> Double {
        let size = (throughput(a) * throughput(b)).squareRoot()
        return k * size * distanceFactor(a.greatCircleNM(to: b))
    }

    /// The load factor `seats` capacity would achieve on a route with this daily
    /// demand (demand-per-leg ÷ seats, capped), before event/random modifiers.
    static func loadFactor(seats: Int, dailyOneWay: Double) -> Double {
        guard seats > 0 else { return 0 }
        return min(maxLoadFactor, (dailyOneWay / dailyFrequenciesEachWay) / Double(seats))
    }
}

/// Distance-based one-way fare per seat: `fare = base + rate × nm^0.65`. Fare now
/// depends on the ROUTE's stage length, not the aircraft's bodyType — which also
/// FIXES the old quirk where a widebody on a short domestic leg charged the $608
/// "international" fare. The curve rises with distance but SUBLINEARLY (per-mile
/// yield falls the farther you go): ~$145 at 300 nm, $252 at 800 nm, $464 at
/// 2,200 nm, $744 at 4,700 nm, $982 at 7,300 nm. The long-haul end is rich enough
/// (premium-cabin blended yield) to keep widebodies profitable on the long routes
/// they exist for, given the matching distance-based OPERATING cost (see
/// `BodyType.blockMinutes(forNM:)`) — the two were calibrated together against a
/// full aircraft×distance profitability matrix so each type has a real distance
/// sweet spot and mismatches (widebody on a short hop, regional beyond range) lose
/// money. Tunable; a small per-flight random spread still applies in rollRevenue.
enum FareModel {
    static let base = 25.0
    static let rate = 2.95
    static let exponent = 0.65
    static func farePerSeat(distanceNM: Double) -> Double {
        base + rate * pow(max(0, distanceNM), exponent)
    }
}

/// An economic condition that scales cost / fare / demand together.
struct EconomicEvent {
    let id: String
    let label: String
    let costMultiplier: Double
    let fareMultiplier: Double
    let loadMultiplier: Double

    static let normal = EconomicEvent(id: "NORMAL", label: "Normal",
                                      costMultiplier: 1, fareMultiplier: 1, loadMultiplier: 1)

    /// The economic conditions, ported from ECONOMIC_EVENTS (mutually exclusive,
    /// one active at a time). Magnitude anchored to a real ~32% YoY jet-fuel
    /// swing (IATA 2026); the specific multipliers and the fare→load
    /// price-elasticity are designed for pacing. A real emergent property:
    /// 4-engine widebodies go NET NEGATIVE under an oil spike while everything
    /// else just compresses — this falls out of the cost/revenue math, matching
    /// the real dynamic that pushed those types to retirement.
    ///
    /// FFR_SURGE is the one where fare and load move in OPPOSITE directions: a
    /// frequent-flyer redemption surge fills more seats (load up) but with award
    /// tickets that book far less real cash per seat (fare down).
    static let all: [EconomicEvent] = [
        // costMultiplier is a FUEL-PRICE multiplier — it scales only the fuel
        // share (~35%) of operating cost, and by each aircraft's fuelIntensity
        // (thirsty types hit harder, modern ones protected). Bigger swings here
        // than the old flat-cost model because only the fuel share is affected.
        .init(id: "OIL_SPIKE", label: "Oil Price Spike", costMultiplier: 1.50, fareMultiplier: 1.15, loadMultiplier: 0.95),
        .init(id: "FUEL_GLUT", label: "Fuel Price Drop", costMultiplier: 0.70, fareMultiplier: 0.95, loadMultiplier: 1.03),
        .init(id: "ECON_BOOM", label: "Economic Boom",   costMultiplier: 1.00, fareMultiplier: 1.10, loadMultiplier: 1.05),
        .init(id: "RECESSION", label: "Recession",       costMultiplier: 1.00, fareMultiplier: 0.85, loadMultiplier: 0.90),
        .init(id: "FFR_SURGE", label: "Frequent-Flyer Redemption Surge", costMultiplier: 1.00, fareMultiplier: 0.85, loadMultiplier: 1.12),
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
