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
    /// The TelemetryDeck app ID, by the same route as `REVENUECAT_API_KEY`:
    /// `Secrets.xcconfig` (gitignored) → Info.plist → here. It's a client-side
    /// WRITE key (safe in a binary), but per the family rule it is NOT hardcoded.
    /// A blank/placeholder value reads as "unset" and `configure()` declines to
    /// initialize, so a keyless clone stays silent.
    static let infoPlistKey = "TELEMETRYDECK_APP_ID"
    /// The placeholder shipped in `Secrets.xcconfig.example`; treated as "unset".
    static let placeholderAppID = "your_telemetrydeck_app_id_here"

    static func appID(bundle: Bundle = .main) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String else { return nil }
        return usableAppID(raw)
    }
    /// Reject blank and placeholder values. Split out so the rule is testable
    /// without a bundle — same shape as `Store.usableKey`.
    static func usableAppID(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed != placeholderAppID else { return nil }
        return trimmed
    }

    /// The launch arguments that mean "a developer is driving this, not a
    /// player." Every one either fabricates game state, seeds a screenshot/gallery
    /// scene, or skips a step a real player takes — so any session carrying one is
    /// verification, not usage, and must emit nothing. `-useTestStore` is
    /// deliberately NOT here: it's honoured only in DEBUG (where the SDK's
    /// testMode routes to the dashboard's Test Data view anyway), and suppressing
    /// it would make `Purchase.completed` — the one signal with real call-site
    /// logic — impossible to exercise off-device.
    static let drivingHooks = [
        "-devScenario", "-freshFlow",
        "-liveryGallery", "-liveryPreview",
        "-galleryName", "-galleryPalette", "-galleryType",
        "-backdropTest", "-backdropMode", "-backdropLight", "-backdropOpacity",
        "-hideControls",
    ]

    /// Key for a persisted debug-Pro flag, IF one is ever added (a paywall "unlock
    /// Pro for testing" button that persists across relaunch). AA's current DEV
    /// Pro toggle is in-memory only (`store.isPro.toggle()`), so nothing writes
    /// this today — but `isDriven` checks it so the guard is already correct the
    /// day a persisted toggle lands. See FC's note: an arg list alone can't see a
    /// persisted fake entitlement, and such a session emits a fabricated healthy
    /// funnel forever.
    static let debugProKey = "aa.debugPro"

    /// Whether this launch is a driven session and must emit nothing. Pure, so the
    /// rule is testable without a running app. The argument check is NOT wrapped
    /// in `#if DEBUG` — the hooks are plain command-line arguments (one Set lookup,
    /// can't misfire in the wild); the persisted-flag half is DEBUG-only because a
    /// debug-Pro flag only exists in DEBUG.
    static func isDriven(arguments: [String] = CommandLine.arguments,
                         defaults: UserDefaults = .standard) -> Bool {
        let args = Set(arguments)
        if drivingHooks.contains(where: args.contains) { return true }
        #if DEBUG
        if defaults.bool(forKey: debugProKey) { return true }
        #endif
        return false
    }

    /// Wall-clock start of this launch, so signals can carry "how long had they
    /// actually been playing" — the number that settles whether a cap lands too
    /// early or too late. Coarse (whole minutes); never a timestamp.
    private static let launchedAt = Date()
    private static var minutesPlayed: Int { max(0, Int(Date().timeIntervalSince(launchedAt) / 60)) }

    /// True once `configure()` has actually initialized TelemetryDeck. `send()`
    /// guards on this so a signal fired before configure — in a keyless build, a
    /// driven session, or a build where TelemetryDeck isn't linked — is a clean
    /// no-op instead of a silent misfire.
    private(set) static var isConfigured = false

    /// Initialize the SDK once, from the App's `init()` beside `Store.configure()`.
    /// **A driven session ⇒ no initialize** (stronger than filtering at the send
    /// site — nothing is even queued), and **no app ID ⇒ no initialize** (a keyless
    /// clone stays silent). The SDK's `testMode` defaults to `#if DEBUG`, so a
    /// hand-driven Debug build lands in the dashboard's Test Data view and Release
    /// goes live — that separation is free; don't override it.
    static func configure() {
        guard !isDriven() else {
            #if DEBUG
            let hooks = drivingHooks.filter(CommandLine.arguments.contains)
            let why = hooks.isEmpty ? "persisted debug-Pro flag" : hooks.joined(separator: " ")
            print("[Telemetry] Driven session (\(why)) — signals suppressed.")
            #endif
            return
        }
        guard let appID = appID() else {
            #if DEBUG
            print("[Telemetry] No \(infoPlistKey) — analytics disabled. Add it to Secrets.xcconfig.")
            #endif
            return
        }
        #if canImport(TelemetryDeck)
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        isConfigured = true
        #endif
    }

    private static func send(_ name: String, _ parameters: [String: String] = [:]) {
        guard isConfigured else { return }
        var p = parameters
        p["minutesPlayed"] = "\(minutesPlayed)"
        #if DEBUG
        // Makes a driven verification pass readable: every signal names itself and its parameters
        // in the console, so "did it fire" is answerable without waiting on the dashboard.
        print("[Telemetry] → \(name) \(p.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
        #endif
        #if canImport(TelemetryDeck)
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

    // MARK: - Errors
    //
    // Handled failures we want to SEE without shipping a crash reporter. Uses
    // TelemetryDeck's Errors preset so the dashboard can group and count them:
    // the event is `TelemetryDeck.Error.occurred`, keyed by a STABLE `id`
    // (never a localized description — grouping breaks if the string varies).
    //
    // RULE 1 still holds: `id` and `category` are developer-chosen enums/slugs,
    // never player text and never a raw error's `localizedDescription`, which
    // can carry file paths or user input. Pass a short stable slug set at the
    // call site (e.g. "purchase.verifyFailed"), not `error.localizedDescription`.

    /// One of the three TelemetryDeck error buckets. `thrown` = a caught
    /// exception/throw; `userInput` = bad/rejected input; `appState` = an
    /// invariant we expected to hold didn't.
    enum ErrorCategory: String {
        case thrown = "thrown-exception"
        case userInput = "user-input"
        case appState = "app-state"
    }

    /// Report a handled error. `id` is a stable slug for grouping (dot.case,
    /// no player text). Optional `detail` is a short developer-authored note —
    /// still no personal data, no `localizedDescription`.
    static func errorOccurred(_ id: String,
                              category: ErrorCategory = .thrown,
                              detail: String? = nil) {
        var p: [String: String] = [
            "TelemetryDeck.Error.id": id,
            "TelemetryDeck.Error.category": category.rawValue,
        ]
        if let detail = detail, !detail.isEmpty {
            p["TelemetryDeck.Error.message"] = detail
        }
        send("TelemetryDeck.Error.occurred", p)
    }
}
