//
//  MaintenanceBase.swift
//  Airline Architect
//
//  The player's own maintenance network — Phase 2 of `aa-1.1.x/MX_BASES_SCOPE.md`
//  (designer decisions 3 and 4). Early game every check goes to a CONTRACT MRO at a
//  premium, with a hangar-slot wait on the heavy checks; mid-game you build your own
//  line stations and hangar bases, which remove both.
//
//  This is deliberately the SAME SHAPE as the Training Center (§3.5): contract out
//  early (premium + wait) → build your own (capital + opex, capacity, −cost, −time,
//  no wait) → overflow falls back to the contractor, so an under-built network is
//  felt in the wallet and never as a dead end.
//
//  Framework-free (Sim layer) so the headless harnesses compile it.
//

import Foundation

/// Who does the work on a given check.
enum MXProvider: Int, Codable {
    case contract = 0   // third-party MRO: +premium, and a slot wait on C/D
    case base = 1       // the player's own line station or hangar base
}

struct MaintenanceBase: Codable {
    var code: String        // the airport it sits at
    var tier: Tier
    var openedTick: Int
    var ledger = MXBaseLedger()

    /// Two tiers, matching how airlines really build: a LINE STATION is a crew and a
    /// van at an outstation where aircraft already overnight (A checks — the overnight
    /// work that never touches the schedule); a HANGAR BASE is a building big enough
    /// to take an aircraft apart for a week (C/D too). Widebody-capable hangars are a
    /// different building, not a bigger version of the same one.
    enum Tier: Int, Codable, CaseIterable {
        case lineStation = 0
        case hangarNarrow = 1
        case hangarWide = 2

        var handlesHeavyChecks: Bool { self != .lineStation }
        /// A narrowbody hangar physically cannot take a widebody. Line stations do
        /// A checks on anything (it's ramp work).
        func canHandle(_ body: BodyType, kind: Aircraft.MXKind) -> Bool {
            if kind == .a { return true }
            switch self {
            case .lineStation:  return false
            case .hangarNarrow: return !MaintenanceBase.isWidebody(body)
            case .hangarWide:   return true
            }
        }
    }

    static func isWidebody(_ b: BodyType) -> Bool {
        b == .widebody2Engine || b == .widebody4Engine
    }

    /// Payback bookkeeping — the MX P&L line, built the same way the hub and
    /// training-center charts are: it only RECORDS spend that is already deducted
    /// and tracked in the global totals, so it introduces no new cash flow and the
    /// Finance invariant is untouched.
    struct MXBaseLedger: Codable {
        var buildSpend = 0       // capital: the station/hangar itself
        var opexPaid = 0         // monthly running cost
        /// Σ (what the contract MRO would have charged − what this base charged)
        /// over every check it has delivered. A counterfactual, labelled as one.
        var feeSavings = 0
        /// Σ value of the flying days the base handed back — the legs an aircraft
        /// did NOT lose because its A check ran overnight, or because its heavy
        /// check skipped the MRO's slot queue and finished sooner. This is the real
        /// reason airlines build hangars, and at these prices the fee saving alone
        /// would never repay one.
        var timeValue = 0
        var checksDone = 0
        var monthly: [MXBaseSnapshot] = []
        var payback: Int { feeSavings + timeValue - buildSpend - opexPaid }
    }
    struct MXBaseSnapshot: Codable {
        var tick: Int
        var payback: Int
    }
    /// Monthly points are CAPPED — the unbounded-history save-crash lesson.
    static let maxSnapshots = 120
}
