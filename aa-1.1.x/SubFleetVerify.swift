//  SubFleetVerify.swift — BUY FOR / TRANSFER TO A SUBSIDIARY
//
//  Verifies the paying-player request "add planes to an airline I've acquired":
//  the transient `purchaseFor` intent routes a marketplace purchase to a
//  subsidiary (flag tail + code + name), the transfer action moves owned
//  aircraft between the mainline and a sub (identity only, registration kept),
//  and none of it moves the accounting.
//
//  RUN (entry file must be named main.swift):
//    mkdir -p /tmp/sub && cp aa-1.1.x/SubFleetVerify.swift /tmp/sub/main.swift
//    cp aa-1.1.x/RepaintVerifyStubs.swift /tmp/sub/
//    swiftc -O -DDEBUG -o /tmp/sub/sub \
//      $(ls AirlineArchitect/AirlineArchitect/Sim/*.swift | grep -vE 'AircraftIcon|SVGPath') \
//      AirlineArchitect/AirlineArchitect/Persistence.swift \
//      /tmp/sub/RepaintVerifyStubs.swift /tmp/sub/main.swift && /tmp/sub/sub

import Foundation

@MainActor func run() {
    var pass = 0, fail = 0
    func check(_ l: String, _ c: Bool, _ d: String = "") {
        if c { pass += 1; print("  ok   \(l)") } else { fail += 1; print("  FAIL \(l) \(d)") }
    }

    // A $1B+ airline that acquires a competitor (the real gate + machinery).
    let sim = Simulation()
    sim.nameAirline("Group Air", tailCode: "GX")
    sim.devInjectCash(8_000_000_000)
    guard let a320 = AircraftType.all.first(where: { $0.id == "A320" }),
          sim.buyAircraft(a320) != nil else { print("  FAIL setup"); exit(1) }
    guard let target = sim.relevantCompetitors.first(where: { !$0.code.isEmpty }),
          sim.acquire(target) else { print("  FAIL acquisition didn't close"); exit(1) }
    guard let sub = sim.subsidiaries.first else { print("  FAIL no subsidiary"); exit(1) }

    // ---- Buy FOR the subsidiary -------------------------------------------
    let residualBefore = sim.cashInvariantResidual()
    sim.purchaseFor = sub.code
    guard let subJet = sim.buyAircraft(a320) else { print("  FAIL sub buy"); exit(1) }
    check("subsidiary purchase carries the sub's code", subJet.subsidiaryCode == sub.code)
    check("...and displays the sub's name", subJet.airlineName == sub.name)
    let expectedPrefix = Airline.registrationPrefix(code: sub.code)
    check("tail flies the sub's flag (\(expectedPrefix)…\(sub.code))",
          subJet.tail.hasPrefix(expectedPrefix) && subJet.tail.hasSuffix(sub.code), subJet.tail)
    check("...not the player's N-code", !subJet.tail.hasSuffix(sim.playerTailCode) || sub.code == sim.playerTailCode)
    check("lease + used follow the same intent path", {
        guard let leased = sim.leaseAircraft(a320) else { return false }
        return leased.subsidiaryCode == sub.code && leased.tail.hasSuffix(sub.code)
    }())

    // Back to mainline: intent cleared → normal N-tail.
    sim.purchaseFor = nil
    guard let mainJet = sim.buyAircraft(a320) else { print("  FAIL mainline buy"); exit(1) }
    check("cleared intent buys for the mainline",
          mainJet.subsidiaryCode == nil && mainJet.tail.hasPrefix("N") && mainJet.tail.hasSuffix(sim.playerTailCode))

    // Invalid intent (no such sub) safely falls back to the mainline.
    sim.purchaseFor = "ZZ_NOT_A_SUB"
    guard let fallback = sim.buyAircraft(a320) else { print("  FAIL fallback buy"); exit(1) }
    check("unknown code falls back to mainline", fallback.subsidiaryCode == nil)
    sim.purchaseFor = nil

    // ---- Transfer within the group ----------------------------------------
    sim.assignAircraft(mainJet, toSubsidiary: sub.code)
    check("transfer joins the subsidiary", mainJet.subsidiaryCode == sub.code && mainJet.airlineName == sub.name)
    let tailAtTransfer = mainJet.tail
    sim.assignAircraft(mainJet, toSubsidiary: nil)
    check("transfer back to mainline", mainJet.subsidiaryCode == nil && mainJet.airlineName == nil)
    check("registration is kept across transfers", mainJet.tail == tailAtTransfer)
    let subCount = sim.aircraft.filter { $0.subsidiaryCode == sub.code }.count
    sim.assignAircraft(mainJet, toSubsidiary: "ZZ_NOT_A_SUB")
    check("transfer to unknown sub is inert", mainJet.subsidiaryCode == nil
          && sim.aircraft.filter { $0.subsidiaryCode == sub.code }.count == subCount)

    // ---- Money + persistence ----------------------------------------------
    check("purchases/transfers move no unaccounted cash",
          sim.cashInvariantResidual() == residualBefore,
          "residual \(sim.cashInvariantResidual()) vs \(residualBefore)")
    let snap = sim.snapshot()
    let restored = Simulation()
    restored.restore(from: snap)
    let restoredJet = restored.aircraft.first { $0.tail == subJet.tail }
    check("sub-bought aircraft survives save/load",
          restoredJet?.subsidiaryCode == sub.code && restoredJet?.airlineName == sub.name)
    check("purchase intent is transient (not persisted)", {
        sim.purchaseFor = sub.code
        let fresh = Simulation()
        fresh.restore(from: sim.snapshot())
        return fresh.purchaseFor == nil
    }())

    // Sub aircraft flies a route + earns like any group aircraft.
    if let o = sim.airports.first(where: { $0.code == subJet.origin.code }) {
        let inRange = sim.airports.first { $0.code != o.code
            && o.greatCircleNM(to: $0) > 300 && o.greatCircleNM(to: $0) < Double(a320.rangeNM) * 0.7 }
        if let d = inRange {
            _ = sim.openRoute(from: o, to: d, using: subJet)
            let before = subJet.cyclesAccrued
            var t = 0
            while subJet.cyclesAccrued == before && t < 20_000 { sim.advanceTick(); t += 1 }
            check("subsidiary aircraft flies and completes legs", subJet.cyclesAccrued > before)
        } else { check("subsidiary aircraft flies and completes legs", false, "no in-range dest") }
    }

    print("\n\(pass) passed, \(fail) failed")
    exit(fail == 0 ? 0 : 1)
}
MainActor.assumeIsolated { run() }
