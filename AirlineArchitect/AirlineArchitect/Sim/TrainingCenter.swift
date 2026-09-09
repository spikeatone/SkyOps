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
        /// Σ value of CREW-DAYS returned to the line by finishing courses sooner.
        /// This is the real reason airlines own simulators — throughput and control,
        /// not the course fee. At real simulator prices the fee saving alone can
        /// never repay a bay, so counting only that made the payback line read
        /// "never" even when owning the sim was plainly right. nil in ledgers
        /// written before this existed.
        var timeValue: Int? = nil
        var monthly: [TrainingSnapshot] = []
        var payback: Int { savings + (timeValue ?? 0) - facilitySpend - opexPaid }
    }
    struct TrainingSnapshot: Codable {
        var tick: Int
        var payback: Int
    }
    /// Monthly points are CAPPED (the unbounded-history save-crash lesson).
    static let maxSnapshots = 120
}
