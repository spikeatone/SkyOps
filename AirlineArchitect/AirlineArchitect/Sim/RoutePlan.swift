//
//  RoutePlan.swift
//  Airline Architect
//
//  A RESEARCHED-but-not-opened route the player parked for later — the "Plans"
//  shelf. Deliberately stores ONLY the identity (the stop codes + when it was
//  saved), never any economics: every number a plan shows is recomputed live
//  from the current sim, so a plan can NEVER go stale, and saving one moves NO
//  money (it is the whole reason plans persist as pure data and stay out of the
//  cash invariant — the deliberate contrast to opening a real Route, which
//  charges an opening cost).
//
//  Framework-free (Sim layer) so the headless harnesses compile it.
//

import Foundation

struct RoutePlan: Identifiable, Equatable, Codable {
    let id: Int
    /// The ordered stops. `[origin, dest]` for a city pair; 3–5 codes for a
    /// multi-city loop — the SAME convention as `Route.stops`, so the plan row and
    /// the map ghost arc reuse `Simulation.rotationLegs`.
    let stops: [String]
    /// When it was researched — for a "saved Day N" line only, never for economics.
    let savedTick: Int

    var isMultiStop: Bool { stops.count > 2 }
    var originCode: String { stops.first ?? "" }
    var destCode: String { stops.count >= 2 ? stops[1] : "" }
    /// "DEN → ORD" for a pair, "DEN → ORD → MSP → ↺" for a loop.
    var label: String {
        isMultiStop ? stops.joined(separator: " → ") + " → ↺"
                    : "\(originCode) → \(destCode)"
    }
}
