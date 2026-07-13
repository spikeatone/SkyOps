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
    case sidelined   // pulled out by a labor action (unavailable until it ends)
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

/// Crew-card display: a full family name + the type-rating coverage line (Crews
/// home, Figma 5:2439). Hand-maintained like FAMILY_LABELS — keep the coverage
/// in sync with the AircraftType variants in each family if the fleet changes.
let CREW_FAMILY_INFO: [String: (name: String, coverage: String)] = [
    "A320_FAMILY": ("Airbus A320 family", "Covers A319/320/321 (ceo + neo)"),
    "B737_FAMILY": ("Boeing 737 family", "Covers 737-700/800/900/MAX 8/9"),
    "A220_FAMILY": ("Airbus A220 family", "Covers A220-100/300"),
    "B777":        ("Boeing 777 family", "Covers 777-300"),
    "B787":        ("Boeing 787 family", "Covers 787-8/9/10"),
    "A330":        ("Airbus A330 family", "Covers A330-900"),
    "A350":        ("Airbus A350 family", "Covers A350-900"),
    "B747":        ("Boeing 747 family", "Covers 747-400"),
    "A380":        ("Airbus A380 family", "Covers A380"),
    "A340":        ("Airbus A340 family", "Covers A340-300"),
    "E170_FAMILY": ("Embraer E170 family", "Covers E170/175"),
    "E190_FAMILY": ("Embraer E190 family", "Covers E190/195"),
    "CRJ_FAMILY":  ("Bombardier CRJ family", "Covers CRJ900/1000"),
    "ERJ_FAMILY":  ("Embraer ERJ family", "Covers ERJ135/140/145"),
]
