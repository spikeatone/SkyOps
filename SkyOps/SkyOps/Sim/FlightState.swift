//
//  FlightState.swift
//  SkyOps — Phase 1 (tick engine port)
//
//  The aircraft state machine and per-state tick durations, ported VERBATIM
//  from the validated browser prototype (prototype-reference/…Stress Test.html).
//  Do NOT re-derive these numbers — they were tuned so peak velocity matches
//  across phases; changing them reintroduces the takeoff-jolt / landing-teleport
//  bugs that were already debugged out of the JS prototype.
//

import Foundation

/// One aircraft's phase in the flight cycle. Order matters — the loop advances
/// through these in sequence, then wraps back to `.parked` for the return leg.
enum FlightState: Int, CaseIterable {
    case parked      // sitting at the gate
    case boarding    // loading pax
    case taxiOut     // gate → runway
    case takeoff     // roll + initial climb
    case cruise      // enroute
    case approach    // descent toward destination
    case landing     // flare + rollout
    case taxiIn      // runway → gate
    case turnaround  // at destination gate; flight settles here

    /// Ticks this state lasts at any speed (1 tick = 1 sim-minute).
    /// Ported verbatim from TICKS_PER_STATE in the prototype.
    var durationTicks: Int {
        switch self {
        case .parked:     return 40
        case .boarding:   return 35
        case .taxiOut:    return 12
        case .takeoff:    return 50
        case .cruise:     return 150
        case .approach:   return 32
        case .landing:    return 35
        case .taxiIn:     return 10
        case .turnaround: return 45
        }
    }

    /// True while the aircraft is physically on the ground (used for colouring).
    var isOnGround: Bool {
        switch self {
        case .parked, .boarding, .taxiOut, .taxiIn, .turnaround: return true
        case .takeoff, .cruise, .approach, .landing:             return false
        }
    }

    /// The next state in the cycle, wrapping turnaround → parked.
    var next: FlightState {
        FlightState(rawValue: (rawValue + 1) % FlightState.allCases.count)!
    }
}
