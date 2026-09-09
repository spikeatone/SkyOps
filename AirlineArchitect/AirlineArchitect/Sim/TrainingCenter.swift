//
//  TrainingCenter.swift
//  Airline Architect
//
//  The player's own training center — Phase 2 of the crew-training pipeline
//  (aa-1.1.x/CREW_TRAINING_SCOPE.md §3.5, designer decision 3). One facility per
//  airline, at an OPERATING hub; one full-flight SIM BAY per crew family it's
//  equipped for. The contract provider ("Global Aviation Training") stays the
//  fallback for families without a bay and for overflow past a bay's capacity —
//  an under-built center never dead-ends, it just pays the contractor.
//  Framework-free (Sim layer) so the headless harnesses compile it.
//

import Foundation

/// Who delivers a crew's course. A rated hire's IOE is line flying, so it has
/// no provider at all (nil on the crew).
enum TrainingProvider: Int, Codable { case contract = 0, center = 1 }

struct TrainingCenter: Codable {
    var hubCode: String
    var openedTick: Int
    /// Crew family → its sim bay.
    var bays: [String: SimBay] = [:]
    var ledger = TrainingLedger()

    struct SimBay: Codable {
        var builtTick: Int
    }

    /// Payback bookkeeping: what the center cost vs. what it saved against the
    /// contract price of every course it delivered. The savings are a
    /// COUNTERFACTUAL (the contract price that was never charged) — the UI labels
    /// it that way, the hub-chart framing.
    struct TrainingLedger: Codable {
        var facilitySpend = 0     // build + bays (capital-out)
        var opexPaid = 0          // monthly facility + bay opex (overhead)
        var savings = 0           // Σ (contract price − in-house price) per course delivered
        var monthly: [TrainingSnapshot] = []
        var payback: Int { savings - facilitySpend - opexPaid }
    }
    struct TrainingSnapshot: Codable {
        var tick: Int
        var payback: Int
    }
    /// Monthly points are CAPPED (the unbounded-history save-crash lesson).
    static let maxSnapshots = 120
}
