//
//  Store.swift
//  Airline Architect — in-app-purchase entitlement + free-tier caps
//
//  Monetization model: a free preview that runs the FULL core loop with every
//  feature on, but caps the NETWORK (fleet + open routes) so upgrading unlocks
//  scale — "build a real empire" — rather than unlocking crippled features.
//  Two Pro tiers (monthly / annual) unlock the same thing (uncapped play).
//
//  RevenueCat wiring: the real SDK drives `isPro` from the "Airline Architect
//  Pro" entitlement, with real offerings/prices and real purchase/restore. All
//  RevenueCat code is behind `#if canImport(RevenueCat)` with a local stub
//  fallback, so the app still compiles if the package is ever removed. The
//  RevenueCat dashboard is fully configured: App Store app connected, `yearly`/
//  `monthly` products imported, `Airline Architect Pro` entitlement, and a
//  `default` offering with Annual/Monthly packages → so offerings() returns the
//  real localized prices. Remaining before public launch: submit the two
//  subscriptions with the first app-version App Review (sandbox already works).
//

#if canImport(RevenueCat)
import RevenueCat
#endif
import Foundation

@MainActor @Observable
final class Store {
    /// RevenueCat App Store public SDK key (safe to embed — it's a client key
    /// shipped inside the app). Production key for the "Airline Architect" App
    /// Store app; drives the real `default` offering (yearly/monthly packages)
    /// + the `Airline Architect Pro` entitlement. (The old `test_…` Test Store
    /// key is retained in git history if you ever need simulated purchases.)
    static let apiKey = "appl_VrQXFZPLdMiMOFAQVErmwOeVdup"
    /// The entitlement identifier configured in the RevenueCat dashboard.
    static let entitlementID = "Airline Architect Pro"

    /// Whether the player has unlocked Pro (uncapped play). Driven by the
    /// RevenueCat entitlement when configured; a local flag otherwise.
    var isPro = false

    /// Purchase-flow UI state (paywall reads these).
    var purchasing = false
    var purchaseError: String?

    // MARK: - Free-tier caps (ignored entirely when isPro)

    static let freeFleetCap = 3
    static let freeRouteCap = 2

    func canAcquireAircraft(_ sim: Simulation) -> Bool { isPro || sim.ownedCount < Self.freeFleetCap }
    func canOpenRoute(_ sim: Simulation) -> Bool { isPro || sim.playerRoutes.count < Self.freeRouteCap }

    enum Gate { case fleet, route }
    func capMessage(_ gate: Gate) -> String {
        switch gate {
        case .fleet: return "The free preview is limited to \(Self.freeFleetCap) aircraft. Go Pro for an unlimited fleet."
        case .route: return "The free preview is limited to \(Self.freeRouteCap) open routes. Go Pro to build a nationwide network."
        }
    }

    // MARK: - Plans (paywall display). Prices come from the live RevenueCat
    // offering when available, else these fallbacks. `id` matches the package
    // lookup below.

    struct Plan: Identifiable, Equatable {
        let id: String
        let title: String
        let price: String
        let cadence: String
        let note: String?
    }
    private static let fallbackPlans: [Plan] = [
        .init(id: "annual",  title: "Annual",  price: "$49.99", cadence: "per year",  note: "Best value · save 30%"),
        .init(id: "monthly", title: "Monthly", price: "$5.99",  cadence: "per month", note: nil),
    ]
    private(set) var plans: [Plan] = Store.fallbackPlans

    // MARK: - RevenueCat-backed implementation (or a local stub)

    #if canImport(RevenueCat)
    private var offering: Offering?

    /// Configure the SDK once, before anything reads `Purchases.shared`.
    /// Called from the App's init.
    static func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Load current entitlement + offerings, then observe live updates
    /// (renewals, cross-device purchases). Call from a long-lived `.task`.
    func start() async {
        await refresh()
        for await info in Purchases.shared.customerInfoStream { apply(info) }
    }

    func refresh() async {
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
        await loadOfferings()
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[Self.entitlementID]?.isActive == true
    }

    private func loadOfferings() async {
        guard let current = try? await Purchases.shared.offerings().current else { return }
        offering = current
        var built: [Plan] = []
        if let annual = current.annual ?? current.package(identifier: "yearly") {
            built.append(.init(id: "annual", title: "Annual",
                               price: annual.storeProduct.localizedPriceString,
                               cadence: "per year", note: "Best value · save 30%"))
        }
        if let monthly = current.monthly ?? current.package(identifier: "monthly") {
            built.append(.init(id: "monthly", title: "Monthly",
                               price: monthly.storeProduct.localizedPriceString,
                               cadence: "per month", note: nil))
        }
        if !built.isEmpty { plans = built }
    }

    private func package(for planID: String) -> Package? {
        guard let offering else { return nil }
        switch planID {
        case "annual":  return offering.annual ?? offering.package(identifier: "yearly")
        case "monthly": return offering.monthly ?? offering.package(identifier: "monthly")
        default:        return nil
        }
    }

    func purchase(planID: String) async {
        guard let pkg = package(for: planID) else {
            purchaseError = "That plan isn’t available right now. Check back once billing is set up."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let (_, info, cancelled) = try await Purchases.shared.purchase(package: pkg)
            if !cancelled { apply(info) }
        } catch {
            purchaseError = (error as NSError).localizedDescription
        }
    }

    func restore() async {
        purchasing = true
        defer { purchasing = false }
        do { apply(try await Purchases.shared.restorePurchases()) }
        catch { purchaseError = (error as NSError).localizedDescription }
    }
    #else
    // STUB — no package present. Flips the local flag so the gating experience
    // is still testable end-to-end.
    static func configure() {}
    func start() async {}
    func refresh() async {}
    func purchase(planID: String) async { isPro = true }
    func restore() async {}
    #endif
}
