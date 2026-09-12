//
//  OpsSection.swift
//  Airline Architect
//
//  The collapsible section boxes on the OPS tab. The player's collapsed set lives
//  on `Simulation.opsCollapsedSections` (persisted as raw values), and an alert
//  about a box re-opens it via `Simulation.opsAutoOpen` — see the OPS DRAWERS note
//  in CLAUDE.md. Framework-free (Sim layer) so the headless harnesses compile it.
//

import Foundation

/// ⚠️ ADDING A CASE IS SAFE: `restore` reads the persisted set with
/// `compactMap(OpsSection.init(rawValue:))`, so an unknown raw value is dropped
/// and a save written before the case existed simply doesn't list it — which
/// leaves the new drawer OPEN, the right default for one the player hasn't met.
enum OpsSection: String, CaseIterable, Codable, Hashable {
    case reputation, opportunities, fuelHedge, integration, needsAttention, maintenance, incentives, hubs, competition, events
}

extension Simulation.Decision.Kind {
    /// The OPS box a decision is "about" (beyond Needs Attention itself), so an alert
    /// auto-opens that drawer. nil = no dedicated box (the card IS the surface).
    var opsSection: OpsSection? {
        switch self {
        case .mxCheck:  return .maintenance
        case .hubOffer: return .hubs
        default:        return nil
        }
    }
}
