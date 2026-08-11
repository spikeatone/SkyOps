//
//  Store.swift
//  Airline Architect — in-app-purchase entitlement + free-tier caps
//
//  Monetization model (1.2.0): a free preview that runs the FULL core loop with
//  every feature on, but caps the NETWORK (fleet + open routes) so upgrading
//  unlocks scale. The upgrade is a ONE-TIME PURCHASE (non-consumable "Full
//  Unlock"), replacing the old monthly/annual subscriptions — premium games
//  convert far better on a buy-once than a rental.
//
//  FOUNDING PLAYER PRICING — the POSTMARK DIGITAL FAMILY STANDARD (two products;
//  see PostmarkOps/ARCHITECT_FAMILY.md). There are TWO non-consumables, both
//  granting the SAME entitlement:
//    • `aa_unlock_founding`  ($9.99)  — the founding price
//    • `aa_unlock`           ($19.99) — the standard price
//  In the RevenueCat `default` offering they carry the custom package identifiers
//  `founding` and `standard`. The app reads BOTH live prices, shows the founding
//  price with the standard struck through DURING the founding window, and — the
//  key — SELLS whichever the window dictates (`foundingUntil`, the single source
//  of truth for the flip; NO ASC scheduled price change). Two products means the
//  struck-through regular price is LIVE from StoreKit, never a hardcoded number.
//
//  RevenueCat wiring: the SDK drives `isPro` from the "Airline Architect Pro"
//  entitlement. The two legacy subscription products stay attached to the
//  entitlement (existing subscribers keep Pro until they cancel) but are REMOVED
//  from the offering, so new users only see the one-time unlock. All RevenueCat
//  code is behind `#if canImport(RevenueCat)` with a local stub fallback.
//

#if canImport(RevenueCat)
import RevenueCat
#endif
import Foundation

@MainActor @Observable
final class Store {
    /// RevenueCat App Store public SDK key (safe to embed — a client key shipped
    /// inside the app). Production key for the "Airline Architect" App Store app.
    static let apiKey = "appl_VrQXFZPLdMiMOFAQVErmwOeVdup"
    /// The entitlement identifier configured in the RevenueCat dashboard. Granted
    /// by BOTH one-time products AND the two legacy subscriptions.
    static let entitlementID = "Airline Architect Pro"

    /// Custom package identifiers in the RevenueCat `default` offering for the two
    /// one-time products (family convention — see ARCHITECT_FAMILY.md).
    static let foundingPackageID = "founding"   // → aa_unlock_founding ($9.99)
    static let standardPackageID = "standard"   // → aa_unlock ($19.99)

    /// Whether the player has unlocked the full game (uncapped play). Driven by
    /// the RevenueCat entitlement when configured; a local flag otherwise.
    var isPro = false

    /// Purchase-flow UI state (paywall reads these).
    var purchasing = false
    var purchaseError: String?
    /// Non-error feedback from a completed restore (a restore that finds nothing
    /// SUCCEEDS at the StoreKit level — neutral copy, not an error).
    var restoreNotice: String?

    private func clearFeedback() {
        purchaseError = nil
        restoreNotice = nil
    }

    // MARK: - Free-tier caps (ignored entirely when isPro)

    /// SIZED SO A FREE PLAYER CAN BUILD EXACTLY ONE HUB, then hits the wall.
    /// `Simulation.hubMinRoutes` is 5, so 5 routes lets them reach one hub and
    /// feel the game open up; the cap then bites when they want a SECOND hub.
    /// Fleet is route-cap + 1 (one spare, never a useless buy). With a one-time
    /// unlock the free tier IS the "try before you buy" — no trial clock, no card.
    static let freeFleetCap = 6
    static let freeRouteCap = 5

    func canAcquireAircraft(_ sim: Simulation) -> Bool { isPro || sim.ownedCount < Self.freeFleetCap }
    func canOpenRoute(_ sim: Simulation) -> Bool { isPro || sim.playerRoutes.count < Self.freeRouteCap }

    enum Gate { case fleet, route }
    /// Sells the DEPTH waiting past the cap, not the quantity.
    func capMessage(_ gate: Gate) -> String {
        switch gate {
        case .fleet:
            return "The free preview flies \(Self.freeFleetCap) aircraft. Unlock the full game for an unlimited fleet — widebodies, long-haul, and a network big enough to need them."
        case .route:
            return "The free preview opens \(Self.freeRouteCap) routes. Unlock the full game to expand the network, build more hubs, take the airline public, and buy out your rivals."
        }
    }

    // MARK: - Founding Player pricing (in-app date-gate — no ASC scheduled change)

    /// Founding Player pricing runs until this date, after which the app sells the
    /// STANDARD product instead of the FOUNDING one. This app constant is the ONLY
    /// thing that controls the flip (both products stay in the offering the whole
    /// time), so no App Store Connect scheduled price change is involved.
    static let foundingUntil: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 12; c.day = 1
        c.hour = 0; c.minute = 0
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    /// True while founding pricing is in effect. Not observed against the wall
    /// clock — a months-long window; a running app that crosses the date corrects
    /// on next launch (and `purchase()` re-checks it at tap time regardless).
    var isFoundingWindow: Bool { Date() < Self.foundingUntil }

    /// "Dec 1, 2026" — the day the price rises, for the founding urgency line.
    static var foundingChangeDateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: foundingUntil)
    }

    // MARK: - Live prices (both products, from the RevenueCat offering)

    /// Localized founding price ($9.99), nil until the live offering loads.
    private(set) var foundingPrice: String?
    /// Localized standard price ($19.99), nil until the live offering loads.
    private(set) var standardPrice: String?
    /// True once the price the app will actually CHARGE this window is loaded (the
    /// paywall shows a neutral placeholder until then — never a stale/guessed price).
    private(set) var pricesAreLive = false
    /// Whether the active entitlement is backed by a live SUBSCRIPTION (a legacy
    /// subscriber). Drives the Finance card's "Manage subscription".
    private(set) var hasActiveSubscription = false

    /// The price the player pays right now (founding during the window, else standard).
    var currentPrice: String? { isFoundingWindow ? foundingPrice : standardPrice }
    /// The struck-through reference — the standard price, shown only during the
    /// founding window (and only if it loaded). Live from StoreKit, never hardcoded.
    var strikePrice: String? { isFoundingWindow ? standardPrice : nil }

    // MARK: - RevenueCat-backed implementation (or a local stub)

    #if canImport(RevenueCat)
    private var offering: Offering?

    /// Configure the SDK once, before anything reads `Purchases.shared`.
    static func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Load current entitlement + offering, then observe live updates
    /// (cross-device purchases, restores). Call from a long-lived `.task`.
    func start() async {
        await refresh()
        for await info in Purchases.shared.customerInfoStream { apply(info) }
    }

    func refresh() async {
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
        await loadOffering()
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[Self.entitlementID]?.isActive == true
        hasActiveSubscription = !info.activeSubscriptions.isEmpty
    }

    /// The package the app should SELL this window (founding during, standard after).
    private func activePackage() -> Package? {
        offering?.package(identifier: isFoundingWindow ? Self.foundingPackageID : Self.standardPackageID)
    }

    private func loadOffering() async {
        guard let current = try? await Purchases.shared.offerings().current else { return }
        offering = current
        foundingPrice = current.package(identifier: Self.foundingPackageID)?.storeProduct.localizedPriceString
        standardPrice = current.package(identifier: Self.standardPackageID)?.storeProduct.localizedPriceString
        // Live once the price we'll actually CHARGE this window is present. (The
        // strikethrough — the OTHER price — is optional; its absence just hides it.)
        pricesAreLive = currentPrice != nil
    }

    func purchase() async {
        clearFeedback()
        // Re-checks the window at tap time, so the product sold always matches the
        // window even if the paywall was left open across the flip date.
        guard let pkg = activePackage() else {
            purchaseError = "The unlock isn’t available right now. Check back once billing is set up."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let (_, info, cancelled) = try await Purchases.shared.purchase(package: pkg)
            if !cancelled {
                apply(info)
                if isPro { Telemetry.purchaseCompleted(plan: "unlock") }
            }
        } catch {
            purchaseError = (error as NSError).localizedDescription
        }
    }

    func restore() async {
        clearFeedback()
        purchasing = true
        defer { purchasing = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
            if !isPro {
                restoreNotice = "No previous purchase found on this Apple Account. If you bought on a different account, sign in to that one in Settings and try again."
            }
        } catch {
            purchaseError = (error as NSError).localizedDescription
        }
    }
    #else
    // STUB — no package present. Flips the local flag so the gating experience is
    // still testable, and seeds both prices for the DEV paywall.
    static func configure() {}
    func start() async {
        foundingPrice = "$9.99"
        standardPrice = "$19.99"
        pricesAreLive = true
    }
    func refresh() async {}
    func purchase() async { clearFeedback(); isPro = true }
    func restore() async {
        clearFeedback()
        if !isPro {
            restoreNotice = "No previous purchase found on this Apple Account. If you bought on a different account, sign in to that one in Settings and try again."
        }
    }
    #endif
}
