//
//  Acquisition.swift
//  Airline Architect — acquiring a competitor airline (types + pure logic)
//
//  Step 2 of ACQUISITIONS_SPEC.md: the transaction and inheritance.
//
//  OWNERSHIP MODEL (designer): you own the airline and it KEEPS FLYING UNDER ITS
//  OWN FLAG. An acquired carrier is never erased or repainted — it becomes a
//  subsidiary. That serves the hardest guardrail in the spec: consolidation
//  removes a COMPETITOR, not a CARRIER, so the map never empties.
//
//  ⚠️ STEP 2 IS NOT SHIPPABLE ON ITS OWN. Without the integration burden (step 3
//  — crew seniority, double-coverage cannibalization, integration bills) this is
//  exactly the "spend money, receive assets" design the spec rejects, and it
//  reads as a money printer. Do not ship without step 3.
//
//  The MUTATING implementation lives in Simulation.swift ("Competitor
//  acquisition" MARK) because nearly all the state it touches (playerBalance,
//  aircraft, playerRoutes, hubs, crew pools, reputation) is private(set) and so
//  is only settable from that file — the same reason the Hubs & Clubs core
//  lives there. This file holds the types and the pure, read-only logic.
//

import Foundation

/// An airline the player has bought. It keeps its own identity and livery; its
/// aircraft and routes carry `subsidiaryCode` so they can be told apart from
/// mainline everywhere it matters.
struct Subsidiary: Codable, Identifiable, Equatable {
    var id: String { code }
    let code: String            // the carrier's IATA code (its identity)
    let name: String
    let region: String
    let acquiredTick: Int
    let pricePaid: Int
    /// Its service score at acquisition — the number the partial reputation
    /// blend uses, and what step 3's integration will move.
    let serviceScoreAtAcquisition: Double
    let fleetInherited: Int
    let routesInherited: Int
}

/// Why an acquisition can't proceed. Each maps to real player-facing copy.
enum AcquisitionBlock: Equatable {
    case belowNetWorthGate(needed: Int)
    case alreadyOwned
    case integrationInProgress(String)
    case lifetimeCapReached(Int)
    case cannotAfford(needed: Int)
    case notInYourMarkets
    // Player-facing copy lives in the VIEW (CompetitorIntelView.blockMessage):
    // the Sim layer stays framework-free so the headless harness can compile it,
    // and compactMoney is a UI helper.

}

/// A live merger integration. The BURDEN, not the purchase — this is what makes
/// an acquisition a challenge rather than a shopping trip (ACQUISITIONS_SPEC.md
/// "The integration burden").
struct Integration: Codable, Equatable {
    let subsidiaryCode: String
    let subsidiaryName: String
    let startTick: Int
    /// Integration completes here. Overlap cannibalization eases toward its
    /// floor across this window, and the monthly bill runs until it.
    let endTick: Int
    /// Charged monthly until `endTick`.
    let monthlyBill: Int
    /// The seniority dispute runs to this tick unless settled early.
    var seniorityExpiryTick: Int
    /// One-off cost to end the dispute now. Nil once settled.
    var senioritySettlementCost: Int?
    /// Crew families sidelined by the dispute (present in BOTH airlines).
    var disputedFamilies: [String]
    var nextBillTick: Int
    var billsPaid: Int = 0

    var isSettled: Bool { senioritySettlementCost == nil }
}

extension Simulation {

    // MARK: - Integration constants (DESIGNED pacing; the balance A/B settles them)

    /// How long an integration runs. The window over which schedule
    /// deconfliction eases the overlap penalty.
    static let integrationMonths = 18
    /// Monthly integration bill as a fraction of the price paid — systems,
    /// repainting, training. RETUNED from the spec draft's 0.015: that worked out
    /// to 27% of the purchase price over 18 months and accounted for ~¾ of the
    /// measured loss. 0.004 → ~7% of price, which is the real-world order for
    /// merger integration costs.
    static let integrationBillRate = 0.004
    /// Seniority dispute duration if never settled.
    static let seniorityDisputeMonths = 9
    /// One-off settlement cost as a fraction of the price paid. RETUNED from
    /// 0.08: at that level the settlement was nearly pure cost and MANAGED play
    /// lost to PASSIVE, inverting the skill expression.
    static let senioritySettlementRate = 0.025
    /// Fraction of a disputed family's crew sidelined while it runs.
    static let senioritySidelinedFraction = 0.35
    /// Reputation hit the moment a deal closes (passengers feel the disruption).
    static let acquisitionReputationHit = 8.0

    // MARK: - Route overlap (double coverage)

    /// Demand coordination on a double-covered pair at the START of an
    /// integration — schedules are uncoordinated and both routes fly half-empty.
    static let overlapCoordinationStart = 0.70
    /// The FLOOR it decays to. Schedule optimization is automatic work an
    /// integration team really does; OVERCAPACITY is not — two aircraft on one
    /// pair still split it. So time never reaches 1.0, and the residual only
    /// clears when the player closes or reassigns one of the pair.
    /// ⚠️ THIS IS THE LOAD-BEARING BALANCE NUMBER. Too shallow and passive
    /// holding pays back inside 36 months (a printer); too deep and the decay is
    /// cosmetic. Sweep it — do not eyeball it.
    static let overlapCoordinationFloor = 0.92

    /// Demand multiplier for a route, accounting for double coverage.
    /// 1.0 when the pair is uniquely served.
    func overlapDemandMultiplier(for route: Route) -> Double {
        let n = playerRoutes.filter {
            ($0.originCode == route.originCode && $0.destCode == route.destCode) ||
            ($0.originCode == route.destCode && $0.destCode == route.originCode)
        }.count
        guard n > 1 else { return 1.0 }
        // Split the pair's demand n ways, then apply coordination — which
        // improves over the integration window but stops at the floor.
        return (1.0 / Double(n)) * overlapCoordination
    }

    /// Eases from `overlapCoordinationStart` to `overlapCoordinationFloor` across
    /// the active integration, then holds at the floor.
    var overlapCoordination: Double {
        guard let ig = activeIntegration else { return Simulation.overlapCoordinationFloor }
        let span = Double(max(1, ig.endTick - ig.startTick))
        let progress = min(1.0, max(0.0, Double(tick - ig.startTick) / span))
        return Simulation.overlapCoordinationStart
            + (Simulation.overlapCoordinationFloor - Simulation.overlapCoordinationStart) * progress
    }

    /// City pairs the player serves more than once — the rationalization list.
    var doubleCoveredPairs: [(String, String, Int)] {
        var counts: [String: (String, String, Int)] = [:]
        for r in playerRoutes {
            let key = [r.originCode, r.destCode].sorted().joined(separator: "-")
            let existing = counts[key]?.2 ?? 0
            counts[key] = (r.originCode, r.destCode, existing + 1)
        }
        return counts.values.filter { $0.2 > 1 }.sorted { $0.2 > $1.2 }
    }

    // MARK: - Gate constants

    /// Net worth at which acquisitions unlock. Testers reported the game going
    /// flat here; this is the answer to that, not a reward for reaching it.
    static let acquisitionNetWorthGate = 1_000_000_000
    /// Lifetime cap. Prevents eating the roster and keeps the map populated.
    static let acquisitionLifetimeCap = 3
    /// Control premium over the carrier's LIQUIDATION value. Sized by the
    /// economic measurement, not by intuition: a well-managed ~46-aircraft
    /// acquisition creates roughly $23M/month, so a premium near 0.8× fleet value
    /// puts full payback around 5–6 years for shrewd play, while passive holding
    /// (~$5M/month) struggles past 10 — the designer's intended gradient.
    static let acquisitionControlPremium = 0.80
    /// Price escalation per completed acquisition (1st / 2nd / 3rd).
    static let acquisitionEscalation: [Double] = [1.0, 1.4, 1.9]

    // MARK: - Pure, read-only logic

    var netWorth: Int { playerBalance + fleetMarketValue }
    var acquisitionsUnlocked: Bool { netWorth >= Simulation.acquisitionNetWorthGate }

    /// One integration at a time — the integration IS the content, and stacking
    /// them would hide it.
    var integrationInProgress: Bool { activeIntegration != nil }

    func isSubsidiary(_ code: String) -> Bool { subsidiaries.contains { $0.code == code } }

    /// The asking price for a carrier: its estimated value plus a control
    /// premium, escalated by how many acquisitions the player has already made.
    /// Price is built on the fleet's LIQUIDATION value plus any positive
    /// goodwill, never on `estimatedValue` alone.
    ///
    /// ⚠️ WHY: a loss-making carrier has NEGATIVE goodwill, which pushed
    /// `estimatedValue` below fleet value — so the old
    /// `estimatedValue × 1.3` could price a carrier BELOW what its aircraft
    /// fetch, letting the player buy it, liquidate the fleet, and profit. That
    /// arbitrage was measured, not hypothesised (a $2,051M deal handed over
    /// ~$1,890M of sellable aircraft). Pricing off liquidation value makes the
    /// floor structural rather than a number that happens to be large enough.
    func askingPrice(for p: CompetitorProfile) -> Int {
        let escalation = Simulation.acquisitionEscalation[
            min(subsidiaries.count, Simulation.acquisitionEscalation.count - 1)]
        let goodwill = max(0, p.estimatedValue - p.fleetLiquidationValue)
        let base = p.fleetLiquidationValue * (1 + Simulation.acquisitionControlPremium) + goodwill
        return Int(base * escalation)
    }

    /// Nil when the player can go ahead. Order matters: the most specific and
    /// most actionable reason wins, so the button never says "you're too poor"
    /// when the real answer is "you already own them".
    func acquisitionBlock(for p: CompetitorProfile) -> AcquisitionBlock? {
        if isSubsidiary(p.id) { return .alreadyOwned }
        if integrationInProgress, let active = subsidiaries.last {
            return .integrationInProgress(active.name)
        }
        if subsidiaries.count >= Simulation.acquisitionLifetimeCap {
            return .lifetimeCapReached(Simulation.acquisitionLifetimeCap)
        }
        if !acquisitionsUnlocked {
            return .belowNetWorthGate(needed: Simulation.acquisitionNetWorthGate - netWorth)
        }
        guard relevantCompetitors.contains(where: { $0.id == p.id }) else { return .notInYourMarkets }
        let price = askingPrice(for: p)
        if playerBalance < price { return .cannotAfford(needed: price - playerBalance) }
        return nil
    }
}
