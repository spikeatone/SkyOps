//
//  Aircraft.swift
//  SkyOps — Phase 1
//
//  One aircraft on the state machine. Phase 1 is intentionally minimal: no
//  crew, AOG, weather, economy or ownership — those are Phases 2/3/5. This is
//  just the pure motion loop: advance a tick, transition on schedule, and swap
//  origin/dest each full cycle so the aircraft actually SERVES its route
//  (A→B, then B→A, repeat) rather than flying one-way.
//

import Foundation
import CoreGraphics

final class Aircraft: Identifiable {
    let id = UUID()
    let tail: String
    let type: AircraftType

    var origin: Airport
    var dest: Airport

    var stateIndex: Int = FlightState.parked.rawValue
    var stateTick: Int = 0

    /// One completed turnaround = one flight cycle (takeoff + landing).
    var cyclesAccrued: Int = 0

    init(tail: String, type: AircraftType, origin: Airport, dest: Airport,
         stateIndex: Int = FlightState.parked.rawValue, cyclesAccrued: Int = 0) {
        self.tail = tail
        self.type = type
        self.origin = origin
        self.dest = dest
        self.stateIndex = stateIndex
        self.cyclesAccrued = cyclesAccrued
    }

    var state: FlightState { FlightState(rawValue: stateIndex)! }

    /// Advance one tick. Faithful reduction of the prototype's advanceAircraft()
    /// with all hold/economy/crew gating removed for Phase 1.
    func advance() {
        let duration = state.durationTicks
        stateTick += 1

        guard stateTick >= duration else { return }

        // transition to the next phase
        stateIndex = state.next.rawValue
        stateTick = 0
        let newState = state

        if newState == .turnaround {
            cyclesAccrued += 1
        }

        if newState == .parked {
            // fly the return leg — swap endpoints
            swap(&origin, &dest)
        }
    }

    /// Current interpolated screen position for rendering.
    var position: AircraftPosition {
        let p = Double(stateTick) / Double(state.durationTicks)
        return FlightPath.position(state: state,
                                   progress: p,
                                   origin: origin.screen,
                                   dest: dest.screen)
    }
}
