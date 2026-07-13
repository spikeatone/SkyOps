//
//  Store.swift
//  Airline Architect — in-app-purchase entitlement + free-tier caps
//
//  Monetization model: a free preview that runs the FULL core loop with every
//  feature on, but caps the NETWORK (fleet + open routes) so upgrading unlocks
//  scale — "build a real empire" — rather than unlocking crippled features.
//  Two Pro tiers (monthly / annual) unlock the same thing (uncapped play).
//
//  RevenueCat wiring is DEFERRED: `isPro`, prices, purchase() and restore() are
//  STUBS today (a local flag toggled by the paywall / a dev control), so the
//  whole gating experience is buildable and testable now. To go live: add the
//  RevenueCat SPM package, set the public SDK key, and in this one file drive
//  `isPro` from `Purchases.shared` customerInfo (entitlement "pro") and route
//  purchase()/restore() through `Purchases.shared`. Nothing else in the app
//  changes — every gate reads this type.
//

import Foundation

@MainActor @Observable
final class Store {
    /// Whether the player has unlocked Pro (uncapped play). STUB — see file note.
    var isPro = false

    // MARK: - Free-tier caps (ignored entirely when isPro)

    /// A free airline can own at most this many aircraft (bought + leased)…
    static let freeFleetCap = 3
    /// …and keep at most this many routes open at once.
    static let freeRouteCap = 2

    /// True if the player may acquire another aircraft right now.
    func canAcquireAircraft(_ sim: Simulation) -> Bool {
        isPro || sim.ownedCount < Self.freeFleetCap
    }
    /// True if the player may open another route right now.
    func canOpenRoute(_ sim: Simulation) -> Bool {
        isPro || sim.playerRoutes.count < Self.freeRouteCap
    }

    /// Short "why you hit the wall" line for the paywall, given what was tapped.
    enum Gate { case fleet, route }
    func capMessage(_ gate: Gate) -> String {
        switch gate {
        case .fleet: return "The free preview is limited to \(Self.freeFleetCap) aircraft. Go Pro for an unlimited fleet."
        case .route: return "The free preview is limited to \(Self.freeRouteCap) open routes. Go Pro to build a nationwide network."
        }
    }

    // MARK: - Plans (STUB display — RevenueCat's Offering supplies real,
    // localized prices at runtime once wired)

    struct Plan: Identifiable, Equatable {
        let id: String
        let title: String
        let price: String
        let cadence: String
        let note: String?
    }
    let plans: [Plan] = [
        .init(id: "annual",  title: "Annual",  price: "$49.99", cadence: "per year",  note: "Best value · save 30%"),
        .init(id: "monthly", title: "Monthly", price: "$5.99",  cadence: "per month", note: nil),
    ]

    /// STUB — flips the local flag. Replace with `Purchases.shared.purchase(...)`.
    func purchase(_ plan: Plan) { isPro = true }
    /// STUB — no-op. Replace with `Purchases.shared.restorePurchases()`.
    func restore() { /* RevenueCat restore; stub */ }
}
