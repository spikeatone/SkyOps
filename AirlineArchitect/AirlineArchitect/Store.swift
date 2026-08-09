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
    ///
    /// `Simulation.hubMinRoutes` is 5, so the old 2-route cap made hubs — and
    /// therefore the network effect, the hub payback chart, meaningful
    /// competition, Go Public and acquisitions — STRUCTURALLY invisible to a free
    /// player. They were being asked to pay for depth they'd never seen, which is
    /// the likeliest reason early conversion was poor. At 5 routes they reach the
    /// hub, feel it start paying back, and the cap now bites when they want a
    /// SECOND hub — the emotional peak rather than before the game opens up.
    ///
    /// The old 3/2 pairing was also internally inconsistent: with 2 routes a 3rd
    /// aircraft could never be assigned, so buying it was a pure loss. Fleet is
    /// now route-cap + 1 — enough for one spare, never a useless purchase.
    ///
    /// (The original 3/2 was calibrated when the cheapest aircraft was the $14M
    /// ERJ135, i.e. "a $20M start affords ~1 jet, so CASH is the early gate."
    /// The $2.5M turboprop tier invalidated that: 3 × B1900 = $7.5M, so both caps
    /// were reachable within minutes of starting.)
    static let freeFleetCap = 6
    static let freeRouteCap = 5

    func canAcquireAircraft(_ sim: Simulation) -> Bool { isPro || sim.ownedCount < Self.freeFleetCap }
    func canOpenRoute(_ sim: Simulation) -> Bool { isPro || sim.playerRoutes.count < Self.freeRouteCap }

    enum Gate { case fleet, route }
    /// Sells the DEPTH waiting past the cap, not the quantity. The old copy
    /// ("Go Pro for an unlimited fleet") pitched more of what they already had;
    /// these name the systems they can't reach yet.
    func capMessage(_ gate: Gate) -> String {
        switch gate {
        case .fleet:
            return "The free preview flies \(Self.freeFleetCap) aircraft. Go Pro for an unlimited fleet — widebodies, long-haul, and a network big enough to need them."
        case .route:
            return "The free preview opens \(Self.freeRouteCap) routes. Go Pro to expand the network, build more hubs, take the airline public, and buy out your rivals."
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
        /// e.g. "3 days free" when this plan carries a free-trial intro offer the
        /// user is ELIGIBLE for (nil otherwise). Drives the paywall trial line +
        /// the "Start Free Trial" CTA. See PRICING_EXPERIMENT_SPEC.md §5a.
        var trial: String? = nil
    }
    // NOTE the fallback carries NO price string and NO savings note: until the
    // real offering loads, the paywall must not show a SPECIFIC price. A
    // RevenueCat price-experiment serves a treatment cohort a different offering,
    // and if a network hiccup let the old hardcoded $49.99/$5.99 show through, a
    // treatment user would see the CONTROL price they wouldn't be charged —
    // silently polluting the experiment. `pricesAreLive` gates the price display
    // (see PaywallView); the fallback exists only to seed the row structure +
    // default selection. See PRICING_EXPERIMENT_SPEC.md.
    private static let fallbackPlans: [Plan] = [
        .init(id: "annual",  title: "Annual",  price: "",  cadence: "per year",  note: nil),
        .init(id: "monthly", title: "Monthly", price: "",  cadence: "per month", note: nil),
    ]
    private(set) var plans: [Plan] = Store.fallbackPlans
    /// True once real prices from the live RevenueCat offering are in `plans`.
    /// The paywall shows a neutral placeholder until then.
    private(set) var pricesAreLive: Bool = false

    /// The annual savings badge, computed from the REAL prices (never hardcoded
    /// — a price experiment changes the true saving, e.g. $4.99/$39.99 → 33%, so
    /// a literal "Save 30%" would ship a false claim). nil when it can't be
    /// computed or the discount is trivial.
    static func savingsNote(annual: Decimal, monthly: Decimal) -> String? {
        let yearOfMonthly = monthly * 12
        guard yearOfMonthly > 0, annual > 0, annual < yearOfMonthly else { return nil }
        let pct = ((yearOfMonthly - annual) / yearOfMonthly) * 100
        // Round via doubleValue, NOT `(pct as NSDecimalNumber).intValue` — the
        // latter returns 0 for a Decimal carrying a long fractional mantissa
        // (30.4535…e-…), which would silently drop the badge for EVERYONE.
        let rounded = Int((pct as NSDecimalNumber).doubleValue.rounded())
        return rounded >= 5 ? "Save \(rounded)%" : nil
    }

    #if canImport(RevenueCat)
    /// "3 days free" / "1 week free" / "1 month free" from a free-trial intro
    /// offer's period. Only ever shown when the user is eligible (checked in
    /// loadOfferings) — an intro offer is once per subscription group per Apple ID.
    static func freeTrialLabel(_ period: SubscriptionPeriod) -> String {
        let n = period.value
        let unit: String
        switch period.unit {
        case .day:   unit = "day"
        case .week:  return n == 1 ? "7 days free" : "\(n) weeks free"   // "1 week" reads better as 7 days
        case .month: unit = "month"
        case .year:  unit = "year"
        @unknown default: unit = "day"
        }
        return "\(n) \(unit)\(n == 1 ? "" : "s") free"
    }
    #endif

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
        let annual  = current.annual  ?? current.package(identifier: "yearly")
        let monthly = current.monthly ?? current.package(identifier: "monthly")
        // Savings badge from the REAL prices of THIS offering — so a price
        // experiment's treatment cohort shows its own true discount, not a
        // hardcoded one (see savingsNote + PRICING_EXPERIMENT_SPEC.md).
        let note: String? = {
            guard let a = annual?.storeProduct.price, let m = monthly?.storeProduct.price else { return nil }
            return Self.savingsNote(annual: a, monthly: m)
        }()

        // Free-trial labels — ONLY for products with a free-trial intro offer the
        // user is actually ELIGIBLE for. An intro offer is once per subscription
        // group per Apple ID, so a returning user must NOT be told "3 days free"
        // and then be charged in full — that's a misleading-offer risk. We ask
        // StoreKit per-user rather than trusting the product's static offer.
        let trialCandidates = [annual, monthly].compactMap { pkg -> String? in
            guard let pkg, let intro = pkg.storeProduct.introductoryDiscount,
                  intro.paymentMode == .freeTrial else { return nil }
            return pkg.storeProduct.productIdentifier
        }
        var trialByProduct: [String: String] = [:]
        if !trialCandidates.isEmpty {
            let elig = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: trialCandidates)
            for pkg in [annual, monthly] {
                guard let pkg, let intro = pkg.storeProduct.introductoryDiscount,
                      intro.paymentMode == .freeTrial,
                      elig[pkg.storeProduct.productIdentifier]?.status == .eligible else { continue }
                trialByProduct[pkg.storeProduct.productIdentifier] = Self.freeTrialLabel(intro.subscriptionPeriod)
            }
        }
        func trial(_ pkg: Package?) -> String? {
            guard let pkg else { return nil }
            return trialByProduct[pkg.storeProduct.productIdentifier]
        }

        var built: [Plan] = []
        if let annual {
            built.append(.init(id: "annual", title: "Annual",
                               price: annual.storeProduct.localizedPriceString,
                               cadence: "per year", note: note, trial: trial(annual)))
        }
        if let monthly {
            built.append(.init(id: "monthly", title: "Monthly",
                               price: monthly.storeProduct.localizedPriceString,
                               cadence: "per month", note: nil, trial: trial(monthly)))
        }
        if !built.isEmpty { plans = built; pricesAreLive = true }
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
        clearFeedback()
        guard let pkg = package(for: planID) else {
            purchaseError = "That plan isn’t available right now. Check back once billing is set up."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let (_, info, cancelled) = try await Purchases.shared.purchase(package: pkg)
            if !cancelled {
                apply(info)
                if isPro { Telemetry.purchaseCompleted(plan: planID) }
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
            // A restore with nothing to restore is a SUCCESS, not a failure —
            // say so plainly instead of leaving the player staring at silence.
            // When it DID restore, isPro flips and the paywall dismisses, which
            // is its own confirmation.
            if !isPro {
                restoreNotice = "No previous purchase found on this Apple Account. If you subscribed with a different account, sign in to that one in Settings and try again."
            }
        } catch {
            purchaseError = (error as NSError).localizedDescription
        }
    }
    #else
    // STUB — no package present. Flips the local flag so the gating experience
    // is still testable end-to-end.
    static func configure() {}
    func start() async {
        // No RevenueCat → seed representative prices so the DEV paywall renders
        // (real prices only ever come from a live offering).
        plans = [
            .init(id: "annual",  title: "Annual",  price: "$49.99", cadence: "per year",  note: "Save 30%", trial: "3 days free"),
            .init(id: "monthly", title: "Monthly", price: "$5.99",  cadence: "per month", note: nil),
        ]
        pricesAreLive = true
    }
    func refresh() async {}
    func purchase(planID: String) async { clearFeedback(); isPro = true }
    func restore() async {
        clearFeedback()
        // Mirrors the real path: nothing to restore against a local stub.
        if !isPro {
            restoreNotice = "No previous purchase found on this Apple Account. If you subscribed with a different account, sign in to that one in Settings and try again."
        }
    }
    #endif
}
