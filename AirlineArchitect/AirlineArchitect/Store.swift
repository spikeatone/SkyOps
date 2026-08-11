//
//  Store.swift
//  Airline Architect — in-app-purchase entitlement + free-tier caps
//
//  Monetization model (1.2.0): a free preview that runs the FULL core loop with
//  every feature on, but caps the NETWORK (fleet + open routes) so upgrading
//  unlocks scale — "build a real empire" — rather than crippled features. The
//  upgrade is now a ONE-TIME PURCHASE (non-consumable "Full Unlock"), replacing
//  the old monthly/annual subscriptions: premium games convert far better on a
//  buy-once than on a rental (3 trials / 300 installs said as much).
//
//  FOUNDING PLAYER PRICING: the unlock is $9.99 through the founding window, then
//  rises to $19.99 (an App Store Connect SCHEDULED PRICE CHANGE — buyers in the
//  window keep $9.99 forever, since it's non-consumable). The live price comes
//  from StoreKit; the app only date-gates the "FOUNDING PLAYER · regularly
//  $19.99" treatment off `foundingUntil`, which MUST match the ASC change date.
//
//  RevenueCat wiring: the SDK drives `isPro` from the "Airline Architect Pro"
//  entitlement. The non-consumable is the offering's LIFETIME package. The two
//  legacy subscription products stay attached to the entitlement (existing
//  subscribers keep Pro until they cancel) but are REMOVED from the offering, so
//  new users only ever see the one-time unlock. All RevenueCat code is behind
//  `#if canImport(RevenueCat)` with a local stub fallback.
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
    /// by BOTH the new non-consumable AND the two legacy subscriptions.
    static let entitlementID = "Airline Architect Pro"

    /// Whether the player has unlocked the full game (uncapped play). Driven by
    /// the RevenueCat entitlement when configured; a local flag otherwise.
    var isPro = false

    /// Purchase-flow UI state (paywall reads these).
    var purchasing = false
    var purchaseError: String?
    /// Non-error feedback from a completed restore. A restore that finds no
    /// entitlement SUCCEEDS at the StoreKit level — it just returns customer
    /// info with nothing active — so without this the paywall said nothing at
    /// all and the button read as broken. Neutral copy, not an error.
    var restoreNotice: String?

    /// Clear stale feedback before a new purchase/restore attempt, so a message
    /// from a previous attempt can't be mistaken for the result of this one.
    private func clearFeedback() {
        purchaseError = nil
        restoreNotice = nil
    }

    // MARK: - Free-tier caps (ignored entirely when isPro)

    /// SIZED SO A FREE PLAYER CAN BUILD EXACTLY ONE HUB, then hits the wall.
    /// `Simulation.hubMinRoutes` is 5, so 5 routes lets them reach one hub and
    /// feel the game open up; the cap then bites when they want a SECOND hub —
    /// the emotional peak. Fleet is route-cap + 1 (one spare, never a useless buy).
    /// With a one-time unlock the free tier IS the "try before you buy" — no trial
    /// clock, no card, which converts better for a premium game than a 3-day trial.
    static let freeFleetCap = 6
    static let freeRouteCap = 5

    func canAcquireAircraft(_ sim: Simulation) -> Bool { isPro || sim.ownedCount < Self.freeFleetCap }
    func canOpenRoute(_ sim: Simulation) -> Bool { isPro || sim.playerRoutes.count < Self.freeRouteCap }

    enum Gate { case fleet, route }
    /// Sells the DEPTH waiting past the cap, not the quantity — names the systems
    /// they can't reach yet.
    func capMessage(_ gate: Gate) -> String {
        switch gate {
        case .fleet:
            return "The free preview flies \(Self.freeFleetCap) aircraft. Unlock the full game for an unlimited fleet — widebodies, long-haul, and a network big enough to need them."
        case .route:
            return "The free preview opens \(Self.freeRouteCap) routes. Unlock the full game to expand the network, build more hubs, take the airline public, and buy out your rivals."
        }
    }

    // MARK: - Founding Player pricing

    /// Founding Player pricing ($9.99) runs until this date, after which the App
    /// Store price rises to `foundingRegularPrice`. This MUST match the SCHEDULED
    /// PRICE CHANGE configured in App Store Connect — the app date-gates the
    /// founding badge/reference off this, while StoreKit reports the real price.
    static let foundingUntil: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 12; c.day = 1
        c.hour = 0; c.minute = 0
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    /// The regular (post-founding) price — a DISPLAY reference only. StoreKit
    /// can't report a future price, so this is the ONE place $19.99 lives in the
    /// binary; keep it in sync with the ASC scheduled price change.
    static let foundingRegularPrice = "$19.99"

    /// True while the founding price is in effect (drives the badge + struck-
    /// through regular price). Not observed against the wall clock — a months-long
    /// window; a running app that crosses the date corrects on next launch.
    var isFoundingWindow: Bool { Date() < Self.foundingUntil }

    /// "Dec 1, 2026" — the day the price rises, for the founding urgency line.
    static var foundingChangeDateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: foundingUntil)
    }

    // MARK: - Live price (from the RevenueCat offering's Lifetime package)

    /// Localized price of the one-time unlock ($9.99 now, $19.99 after the
    /// founding window), nil until the live offering loads.
    private(set) var unlockPrice: String?
    /// True once the real price from the live offering is in `unlockPrice`. The
    /// paywall shows a neutral placeholder until then (never a stale/guessed price).
    private(set) var pricesAreLive = false
    /// Whether the active entitlement is backed by a live SUBSCRIPTION (a legacy
    /// subscriber). Drives the Finance card's "Manage subscription" — a one-time
    /// buyer has nothing to manage.
    private(set) var hasActiveSubscription = false

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

    /// The one-time unlock package: STRICTLY the offering's Lifetime slot (the
    /// non-consumable). Deliberately NOT `?? availablePackages.first` — during the
    /// subscription→one-time transition the offering may still carry the legacy
    /// monthly/annual subscriptions, and a fallback would show/sell a subscription
    /// under this "one-time, yours forever" UI. If Lifetime isn't configured yet,
    /// prices stay non-live (placeholder) and purchase reports "not available".
    private func unlockPackage(_ o: Offering?) -> Package? {
        o?.lifetime
    }

    private func loadOffering() async {
        guard let current = try? await Purchases.shared.offerings().current else { return }
        offering = current
        if let unlock = unlockPackage(current) {
            unlockPrice = unlock.storeProduct.localizedPriceString
            pricesAreLive = true
        }
    }

    func purchase() async {
        clearFeedback()
        guard let pkg = unlockPackage(offering) else {
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
            // A restore with nothing to restore is a SUCCESS, not a failure — say
            // so plainly. When it DID restore, isPro flips and the paywall
            // dismisses, which is its own confirmation.
            if !isPro {
                restoreNotice = "No previous purchase found on this Apple Account. If you bought on a different account, sign in to that one in Settings and try again."
            }
        } catch {
            purchaseError = (error as NSError).localizedDescription
        }
    }
    #else
    // STUB — no package present. Flips the local flag so the gating experience is
    // still testable end-to-end, and seeds the founding price for the DEV paywall.
    static func configure() {}
    func start() async {
        unlockPrice = "$9.99"
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
