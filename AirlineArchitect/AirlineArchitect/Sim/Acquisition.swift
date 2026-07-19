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

extension Simulation {

    // MARK: - Gate constants

    /// Net worth at which acquisitions unlock. Testers reported the game going
    /// flat here; this is the answer to that, not a reward for reaching it.
    static let acquisitionNetWorthGate = 1_000_000_000
    /// Lifetime cap. Prevents eating the roster and keeps the map populated.
    static let acquisitionLifetimeCap = 3
    /// Control premium over the carrier's estimated value — you never buy a
    /// company at book.
    static let acquisitionControlPremium = 0.30
    /// Price escalation per completed acquisition (1st / 2nd / 3rd).
    static let acquisitionEscalation: [Double] = [1.0, 1.4, 1.9]

    // MARK: - Pure, read-only logic

    var netWorth: Int { playerBalance + fleetMarketValue }
    var acquisitionsUnlocked: Bool { netWorth >= Simulation.acquisitionNetWorthGate }

    /// Step 3 will make this real (an integration runs for N months). Until then
    /// nothing is ever in progress, so the one-at-a-time rule is inert.
    var integrationInProgress: Bool { false }

    func isSubsidiary(_ code: String) -> Bool { subsidiaries.contains { $0.code == code } }

    /// The asking price for a carrier: its estimated value plus a control
    /// premium, escalated by how many acquisitions the player has already made.
    func askingPrice(for p: CompetitorProfile) -> Int {
        let escalation = Simulation.acquisitionEscalation[
            min(subsidiaries.count, Simulation.acquisitionEscalation.count - 1)]
        return Int(p.estimatedValue * (1 + Simulation.acquisitionControlPremium) * escalation)
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
