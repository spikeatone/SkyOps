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
    /// Control premium over the carrier's LIQUIDATION value — and the single
    /// constant that sets payback, because the deal's real economic cost is
    /// (premium × liquidation value) + goodwill.
    ///
    /// SIZED BY A 12-SEED SWEEP, not intuition. Managed play creates a median
    /// $5.65M/month and passive $1.97M/month (a consistent 2.9× skill gradient
    /// that held across seeds). At 0.80 the median cost was $1,551M → 22.9 years
    /// managed / 68.7 passive, far outside the target. 0.25 puts the median cost
    /// near $485M → ~7 years for shrewd play (inside the designer's 5–10 window)
    /// and ~20 for passive holding, which is the intended "a first-timer may
    /// struggle to break even at ten".
    ///
    /// FLOOR CHECK: at 0.25 the player still pays 25% over what the fleet would
    /// fetch broken up, so the liquidation arbitrage stays closed.
    static let acquisitionControlPremium = 0.25
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

// MARK: - Due diligence (two stages)
//
// DESIGNER'S FRAMING: acquisitions mirror real deal-making, where what you can
// see depends on how far into the process you are.
//
//   STAGE 1 "sniffing around" (pre-NDA) — public info only. Thin, estimated,
//   enough to decide what's worth pursuing. Free.
//   STAGE 2 "open the kimono" (post-NDA) — the real books. Per-aircraft ages, a
//   firm renewal bill, actual network overlap. Costs money, so choosing WHICH
//   targets to diligence is itself a decision.
//
// ⚠️ PROJECTIONS ARE DELIBERATELY NOT IRON-CLAD (designer, explicit). Real
// projections are best guesses reality diverges from; that divergence is the
// feature. Stage 1 reads only the carrier's AVERAGE fleet age, so it cannot see
// the spread; stage 2 reads the real manifest. Do not "fix" the gap.

/// One modelled outcome. Payback is in years; `nil` means it never pays back.
struct AcquisitionScenario: Equatable {
    let label: String
    let annualContribution: Double
    let paybackYears: Double?
}

/// What due diligence tells the player. Bands are WIDE at stage 1 and tight at
/// stage 2 — the difference between the two is what the player is buying.
struct AcquisitionProjection: Equatable {
    let stage: Int                     // 1 = pre-NDA estimate, 2 = real books
    let askingPrice: Int
    let economicCost: Int              // price − assets received: the real cost
    let renewalCostLow: Int            // fleet replacement exposure
    let renewalCostHigh: Int
    let agedAircraft: Int              // airframes past the renewal threshold
    let sameRegion: Bool
    let scenarios: [AcquisitionScenario]
}

extension Simulation {

    /// Aircraft past this share of design life are renewal candidates — the
    /// measured point where the quadratic maintenance/AOG escalators start
    /// eating an acquisition alive.
    static let renewalThreshold = 0.85

    /// Per-aircraft monthly value creation, CALIBRATED FROM THE 12-SEED SWEEP:
    /// managed play produced a median $9.69M/month on ~46-aircraft carriers
    /// (~$0.21M each), passive $3.74M (~$0.08M each). These are the honest
    /// anchors for a projection — a heuristic, which is what a projection IS.
    /// NOTE these are BEFORE the age drag below, and they ALREADY INCLUDE the
    /// cost of renewing the fleet — the sweep's managed arm renewed every 6
    /// months and still produced this. Renewal must therefore NOT be subtracted
    /// again from a scenario (an early version did, which made every deal look
    /// unpayable); it is surfaced separately as the CAPITAL the player must
    /// commit, which is what the designer asked to see.
    static let perAircraftManagedMonthly = 290_000.0
    static let perAircraftPassiveMonthly = 112_000.0
    /// How much better or worse a specific carrier is than the generic average —
    /// deterministic per carrier, and ONLY visible at stage 2. Stage 1 has to
    /// assume the average, which is exactly what a buyer without the books does.
    /// Centred slightly BELOW 1.0: the average acquisition is unexciting, and a
    /// projection that assumes otherwise is the rosiness the designer objected to.
    static func carrierQuality(_ id: String, seed: UInt64) -> Double {
        var rng = SeededRNG(seed: seed &+ CompetitorIntel.stableHash("quality:" + id))
        return Double.random(in: 0.55...1.25, using: &rng)
    }

    /// Cross-region acquisitions were value-DESTROYING in every sweep seed:
    /// an out-of-region carrier's hubs and routes sit outside the player's
    /// network, so there's no overlap to rationalise and no connecting traffic.
    static let crossRegionContributionFactor = -0.35

    /// Cost to replace the worn-out portion of a carrier's fleet.
    /// Stage 1 estimates from the AVERAGE age (wide, because the spread is
    /// unknown); stage 2 counts the real manifest.
    func renewalExposure(for p: CompetitorProfile, stage: Int) -> (low: Int, high: Int, aged: Int) {
        if stage >= 2 {
            let manifest = p.fleetManifest(seed: competitorSeed)
            let worn = manifest.filter { $0.ageFraction > Simulation.renewalThreshold }
            let bill = worn.reduce(0.0) { $0 + Double($1.type.purchasePrice) }
            // Still a small band: replacement timing and prices move.
            return (Int(bill * 0.92), Int(bill * 1.08), worn.count)
        }
        // Stage 1: infer the worn share analytically from the average age and the
        // known 0.6–1.35 spread, then band it WIDE.
        let avg = p.fleetAgeFraction
        let lo = avg * 0.6, hi = avg * 1.35
        let wornShare: Double = hi <= Simulation.renewalThreshold ? 0.0
            : (lo >= Simulation.renewalThreshold ? 1.0
               : (hi - Simulation.renewalThreshold) / max(0.0001, hi - lo))
        let aged = Int((Double(p.fleetSize) * wornShare).rounded())
        let avgPrice = p.fleetLiquidationValue / max(1.0, Double(p.fleetSize)) /
                       max(0.05, 1.0 - p.fleetAgeFraction)
        let bill = Double(aged) * avgPrice
        return (Int(bill * 0.55), Int(bill * 1.6), aged)   // deliberately wide
    }

    /// Build the projection the player actually reads.
    func projection(for p: CompetitorProfile, stage: Int) -> AcquisitionProjection {
        let price = askingPrice(for: p)
        // Economic cost = price minus what the fleet is actually worth to you.
        let cost = max(1, price - Int(p.fleetLiquidationValue))
        let renewal = renewalExposure(for: p, stage: stage)

        let homeRegions = Set(homeRegion.gameRegions.map { CompetitorIntel.regionLabel($0) })
        let sameRegion = homeRegions.contains(p.region)

        // Age drags contribution: an old fleet earns less and breaks more.
        let ageDrag = max(0.45, 1.0 - p.fleetAgeFraction * 0.55)
        let regionFactor = sameRegion ? 1.0 : Simulation.crossRegionContributionFactor
        // Stage 1 must assume an average carrier; stage 2 learns what this one is
        // actually worth — which can be WORSE than the assumption, not just
        // better. That is where a projection earns the right to disappoint.
        let quality = stage >= 2 ? Simulation.carrierQuality(p.id, seed: competitorSeed) : 1.0
        let common = Double(p.fleetSize) * ageDrag * regionFactor * quality
        let base = common * Simulation.perAircraftManagedMonthly
        let passive = common * Simulation.perAircraftPassiveMonthly

        func scenario(_ label: String, _ monthly: Double) -> AcquisitionScenario {
            // Renewal is NOT deducted here: it's an asset swap (sell old, buy
            // new) that's roughly net-worth neutral, and the calibration rates
            // already include a renewing operator. It's reported separately as
            // the capital requirement instead.
            let annual = monthly * 12
            let years: Double? = annual > 0 ? Double(cost) / annual : nil
            return AcquisitionScenario(label: label, annualContribution: annual, paybackYears: years)
        }
        return AcquisitionProjection(
            stage: stage, askingPrice: price, economicCost: cost,
            renewalCostLow: renewal.low, renewalCostHigh: renewal.high, agedAircraft: renewal.aged,
            sameRegion: sameRegion,
            // ANCHORED ON THE MEASURED SWEEP, not inflated around it. "Well run"
            // IS the managed median and "Struggling" IS the passive median — an
            // earlier version multiplied these out to base×1.45 and passive×0.55,
            // which put the best case 45% above anything the sweep ever produced
            // and made every projection read rosy.
            scenarios: [
                scenario("Struggling", passive),
                scenario("Expected",   (base + passive) / 2),
                scenario("Well run",   base),
            ])
    }
}
