//
//  Telemetry.swift
//  Airline Architect — privacy-first product analytics (TelemetryDeck).
//
//  WHY IT EXISTS: RevenueCat tells us the CONVERSION RATE but not the FUNNEL —
//  specifically, not whether a player ever REACHES the paywall. "They bounce off
//  the cap" and "they churn long before the cap" look identical in revenue data
//  and need opposite fixes. These signals answer that.
//
//  TWO RULES:
//  1. NOTHING PERSONAL. No names, tail codes, airline names, airport codes, or
//     free text — only counters, enums and coarse timings. TelemetryDeck is
//     anonymous by design (no IDFA, no ATT prompt); this keeps it that way even
//     as signals get added. If a new signal needs a player-authored string, the
//     answer is no.
//  2. VIEW LAYER ONLY. `Sim/` must stay framework-free so the headless harnesses
//     can compile it with plain `swiftc` — the same reason Feedback.swift (the
//     haptics layer) lives out here. Never import this from Sim/.
//
//  All calls are behind `#if canImport(TelemetryDeck)` with no-op fallbacks, so
//  the app still builds if the package is ever removed — same containment
//  pattern as Store.swift's RevenueCat wiring.
//

import Foundation
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

enum Telemetry {
    /// TelemetryDeck app ID (safe to embed — it's a client-side write key).
    static let appID = "55DD6B12-BA78-4A08-8345-1FE29F9C4983"

    /// Wall-clock start of this launch, so signals can carry "how long had they
    /// actually been playing" — the number that settles whether a cap lands too
    /// early or too late. Coarse (whole minutes); never a timestamp.
    private static let launchedAt = Date()
    private static var minutesPlayed: Int { max(0, Int(Date().timeIntervalSince(launchedAt) / 60)) }

    static func configure() {
        #if canImport(TelemetryDeck)
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        #endif
    }

    private static func send(_ name: String, _ parameters: [String: String] = [:]) {
        #if canImport(TelemetryDeck)
        var p = parameters
        p["minutesPlayed"] = "\(minutesPlayed)"
        TelemetryDeck.signal(name, parameters: p)
        #endif
    }

    // MARK: - The funnel
    //
    // Deliberately lean (a handful per session) so the free tier is ample and
    // the data stays readable. Order below == the player's path.

    /// A brand-new airline was named — the denominator for everything else.
    /// `region` is the founding region (an enum case, not player text).
    static func gameStarted(region: String) {
        send("Game.started", ["region": region])
    }

    /// A route opened. `count` is the player's route total AFTER opening, so the
    /// distribution shows how far players actually get before stopping.
    static func routeOpened(count: Int, simDay: Int) {
        send("Route.opened", ["routeCount": "\(count)", "simDay": "\(simDay)"])
    }

    /// A hub was established — the "aha" the 5-route cap was re-sized to expose.
    /// If few players ever emit this, the caps still sit below the hook.
    static func hubEstablished(routeCount: Int, simDay: Int) {
        send("Hub.established", ["routeCount": "\(routeCount)", "simDay": "\(simDay)"])
    }

    /// The paywall was shown. THE KEY SIGNAL: what fraction of players reach it
    /// at all, via which gate, and how far in.
    static func paywallShown(gate: String, aircraft: Int, routes: Int, simDay: Int) {
        send("Paywall.shown", ["gate": gate, "aircraft": "\(aircraft)",
                               "routes": "\(routes)", "simDay": "\(simDay)"])
    }

    /// Closed without buying — paired with `Paywall.shown` this is the drop-off.
    static func paywallDismissed() { send("Paywall.dismissed") }

    /// Entitlement went active. `plan` is "annual"/"monthly", never a price.
    static func purchaseCompleted(plan: String) {
        send("Purchase.completed", ["plan": plan])
    }
}
