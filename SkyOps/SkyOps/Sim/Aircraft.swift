//
//  Aircraft.swift
//  SkyOps — Phase 1–3
//
//  One aircraft on the state machine. The pure motion loop (advance a tick,
//  transition on schedule, swap origin/dest each cycle) is Phase 1. Phase 3
//  adds weather HOLDS: a departure ground-stop freezes the aircraft at the
//  runway; an arrival ground-stop puts it into a holding-pattern orbit near
//  the approach fix, then eases it back onto the approach path (REJOIN) once
//  the stop lifts — instead of freezing in place or snapping onto final.
//  Crew/AOG holds (also using `holdReason`) come in later Phase 3 slices.
//

import Foundation
import CoreGraphics

/// Why an aircraft is held past its normal state duration.
enum HoldReason {
    case weather   // ground stop at origin (departure) or dest (arrival)
    case rejoin    // easing out of the holding pattern back onto approach
    case aog       // grounded for unscheduled maintenance, awaiting decision
    case crew      // no legal crew available to board
}

/// Things that happen inside Aircraft.advance() that the Simulation must act
/// on (push or clear a decision card). Returned rather than called back so
/// the aircraft stays free of any UI/queue knowledge.
enum AdvanceEvent {
    case aogHoldStarted     // held at the gate, needs an AOG decision card
    case aogRepairCompleted // timed standard repair finished on its own
    case crewHoldStarted    // held at the gate, needs a CREW decision card
    case crewHoldResolved    // crew became available, hold cleared
}

final class Aircraft: Identifiable {
    static let rejoinDuration = 10  // ticks to ease from holding pattern onto approach

    let id = UUID()
    let tail: String
    let type: AircraftType
    /// Stable per-tail value used to desync holding-pattern orbits.
    let tailHash: Int

    var origin: Airport
    var dest: Airport

    var stateIndex: Int = FlightState.parked.rawValue
    var stateTick: Int = 0

    /// One completed turnaround = one flight cycle (takeoff + landing).
    var cyclesAccrued: Int = 0

    // Hold state (Phase 3).
    var holdReason: HoldReason?
    var rejoinTick: Int = 0
    var rejoinStart: CGPoint = .zero
    var rejoinStartHeading: Double = 0

    // AOG state (Phase 3). `maint` flags the aircraft for unscheduled
    // maintenance; it blocks at the PARKED boarding gate (an in-flight
    // aircraft finishes its flight first). `holdLogged` ensures the decision
    // card is pushed once per hold, not every tick.
    var maint: Bool = false
    var aogAutoClearTick: Int?
    var holdLogged: Bool = false

    /// Assigned crew's id within its family pool (nil = none assigned yet).
    var crewId: Int?

    init(tail: String, type: AircraftType, origin: Airport, dest: Airport,
         stateIndex: Int = FlightState.parked.rawValue, cyclesAccrued: Int = 0) {
        self.tail = tail
        self.type = type
        self.origin = origin
        self.dest = dest
        self.stateIndex = stateIndex
        self.cyclesAccrued = cyclesAccrued
        self.tailHash = tail.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    var state: FlightState { FlightState(rawValue: stateIndex)! }
    var isHeld: Bool { holdReason != nil }

    /// Advance one tick. Ports advanceAircraft()'s hold gating: hold blocks
    /// only fire at the transition boundary (stateTick >= duration - 1); every
    /// other tick clears holdReason and advances normally. Returns an event
    /// when the Simulation needs to push/clear a decision card.
    /// `assignCrew` tries to take an available crew from this aircraft's family
    /// pool (setting crewId, WITHOUT resetting its duty clock) → true on
    /// success. `releaseCrew` returns the current crew to rest-or-available and
    /// clears crewId. Both are injected by the Simulation, which owns the pools
    /// — the aircraft stays free of pool knowledge (and stays headless-testable).
    @discardableResult
    func advance(tick: Int,
                 assignCrew: (Aircraft) -> Bool = { _ in true },
                 releaseCrew: (Aircraft) -> Void = { _ in }) -> AdvanceEvent? {
        // A scheduled "standard repair" (player-chosen) completes on its own
        // timer — the hold then clears through the normal gate below.
        var event: AdvanceEvent?
        if let clearAt = aogAutoClearTick, tick >= clearAt {
            maint = false
            aogAutoClearTick = nil
            event = .aogRepairCompleted
        }

        let duration = state.durationTicks

        if stateTick >= duration - 1 {
            switch state {
            case .parked:
                // grounded for maintenance — nothing moves until resolved
                if maint {
                    holdReason = .aog
                    if !holdLogged {
                        holdLogged = true
                        return .aogHoldStarted
                    }
                    return event
                }
                // must have a legal crew before boarding
                if crewId == nil {
                    if assignCrew(self) {
                        if holdReason == .crew { event = .crewHoldResolved }
                        holdReason = nil
                        holdLogged = false
                        // fall through — the aircraft boards this tick
                    } else {
                        holdReason = .crew
                        if !holdLogged {
                            holdLogged = true
                            return .crewHoldStarted
                        }
                        return event
                    }
                }

            case .taxiOut:
                // departure ground stop — freeze at the runway until it lifts
                if origin.groundStop { holdReason = .weather; return event }

            case .approach:
                if dest.groundStop {
                    holdReason = .weather; return event    // hold in the pattern
                } else if holdReason == .weather {
                    // stop just lifted — capture the current orbit position and
                    // ease from it onto the approach path, don't snap on
                    let path = FlightPath.pathPoints(origin: origin.screen, dest: dest.screen)
                    let fix = FlightPath.point(path, at: 0.90)
                    let angle = Double((tick + tailHash) % 120) / 120 * 2 * .pi
                    rejoinStart = CGPoint(x: fix.x + cos(angle) * 20, y: fix.y + sin(angle) * 12)
                    rejoinStartHeading = angle + .pi / 2
                    holdReason = .rejoin
                    rejoinTick = 0
                    return event
                } else if holdReason == .rejoin {
                    rejoinTick += 1
                    if rejoinTick < Aircraft.rejoinDuration { return event }
                    holdReason = nil   // rejoin complete — fall through to transition
                }

            default:
                break
            }
        }

        holdReason = nil
        holdLogged = false
        stateTick += 1

        guard stateTick >= duration else { return event }

        // transition to the next phase
        stateIndex = state.next.rawValue
        stateTick = 0
        let newState = state

        if newState == .turnaround {
            cyclesAccrued += 1
            releaseCrew(self)   // duty done for this leg — rest or return to pool
        }
        if newState == .parked { swap(&origin, &dest) }   // fly the return leg
        return event
    }

    /// Interpolated screen position for rendering. Handles the weather
    /// holding-pattern orbit and the rejoin easing (both APPROACH sub-cases);
    /// everything else delegates to FlightPath. `tick` desyncs the orbit.
    func position(tick: Int) -> AircraftPosition {
        let s = state

        if s == .approach, let hold = holdReason {
            let path = FlightPath.pathPoints(origin: origin.screen, dest: dest.screen)
            switch hold {
            case .weather:
                // orbit near the approach fix instead of freezing in place
                let fix = FlightPath.point(path, at: 0.90)
                let angle = Double((tick + tailHash) % 120) / 120 * 2 * .pi
                return AircraftPosition(
                    point: CGPoint(x: fix.x + cos(angle) * 20, y: fix.y + sin(angle) * 12),
                    alt: 0.5, heading: angle + .pi / 2)
            case .rejoin:
                let rp = Double(rejoinTick) / Double(Aircraft.rejoinDuration)
                let eased = rp * rp * (3 - 2 * rp)   // smoothstep
                let target = FlightPath.point(path, at: 0.92)
                let targetHeading = FlightPath.heading(path, 0.92)
                return AircraftPosition(
                    point: CGPoint(x: rejoinStart.x + (target.x - rejoinStart.x) * eased,
                                   y: rejoinStart.y + (target.y - rejoinStart.y) * eased),
                    alt: 0.5 - eased * 0.2,
                    heading: FlightPath.lerpAngle(rejoinStartHeading, targetHeading, eased))
            case .aog, .crew:
                break   // AOG/crew holds only happen at the gate (PARKED), not on approach
            }
        }

        let p = Double(stateTick) / Double(s.durationTicks)
        return FlightPath.position(state: s, progress: p, origin: origin.screen, dest: dest.screen)
    }
}
