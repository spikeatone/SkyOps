//
//  Crew.swift
//  Airline Architect — Phase 3 (crew)
//
//  Per-family flight crews with real FAA 14 CFR Part 117 duty/rest timing.
//  A crew accumulates duty time ACROSS consecutive flight assignments (a real
//  Flight Duty Period — the whole duty day, potentially several segments), and
//  only resets after a completed rest period — NOT per-flight. Porting the
//  broken per-assignment-reset version would let a lone crew fly forever;
//  don't. Verified in the prototype: a lone crew flies ~2 consecutive cycles
//  before mandatory rest, which is the pressure toward more crew.
//

import Foundation

enum CrewStatus {
    case available   // in the pool, ready to be assigned
    case onDuty      // assigned to an aircraft, accruing duty time
    case resting     // completing a mandatory rest period
}

final class Crew {
    /// Real Part 117 figures. 10 duty-hours before rest is required; 10
    /// CONSECUTIVE rest-hours to reset the clock (was wrongly 8hr once — the
    /// minimum-sleep component, not the full rest period).
    static let maxDutyTicks = 600   // 10 sim-hours
    static let restTicks = 600      // 10 sim-hours

    let id: Int
    var status: CrewStatus = .available
    var dutyTicks: Int = 0
    var restTicksLeft: Int = 0

    init(id: Int) { self.id = id }
}

/// Display labels per crew family. Hand-maintained (NOT auto-derived) — must be
/// updated whenever a family is added/removed, or the crew UI shows a raw key.
let FAMILY_LABELS: [String: String] = [
    "A320_FAMILY": "A320", "B737_FAMILY": "B737", "A220_FAMILY": "A220",
    "B777": "B777", "B787": "B787", "A330": "A330", "A350": "A350",
    "B747": "B747", "A380": "A380", "A340": "A340",
    "E170_FAMILY": "E170/175", "E190_FAMILY": "E190/195",
    "CRJ_FAMILY": "CRJ", "ERJ_FAMILY": "ERJ",
]
