import XCTest
@testable import AirlineArchitect

/// Analytics fail **silently** in both directions, which is why they get a test file at all.
///
/// One direction is Airline's OWN shipped bug (documented in ARCHITECT_FAMILY.md §4): the
/// TelemetryDeck SDK was declared in the PROJECT but never linked to the TARGET, so
/// `canImport(TelemetryDeck)` was false, every signal compiled to a graceful no-op, and the build
/// looked perfect while collecting nothing. `Package.resolved` listing the package proves nothing
/// about linkage. `testTelemetryDeckIsActuallyLinked` is the compile-time proof.
///
/// The other is over-collection — a driven session (a `-devScenario` seed, a gallery/screenshot
/// run) quietly filling the dashboard with data no player generated. Both rules below are pure
/// functions precisely so they can be pinned here without a bundle or a running app.
final class TelemetryTests: XCTestCase {

    // MARK: Linkage — the trap Airline itself shipped once

    /// Fails to COMPILE, not at runtime, if the package stops being linked to the app target.
    /// `#if canImport` is exactly what the wrapper's no-op fallback keys off, so asserting on it
    /// here is asserting on the same fact the signals depend on.
    func testTelemetryDeckIsActuallyLinked() throws {
        #if canImport(TelemetryDeck)
        // Reached only when the product is on the app target's linked dependencies.
        #else
        XCTFail("""
            TelemetryDeck is not linked to the AirlineArchitect target, so every Telemetry signal is \
            silently a no-op — the exact bug Airline shipped once. Add the RevenueCat/TelemetryDeck \
            Swift package to the target's Frameworks, rebuild, and re-run.
            """)
        #endif
    }

    // MARK: The app ID never falls back to a placeholder

    func testPlaceholderAppIDIsTreatedAsUnset() {
        XCTAssertNil(Telemetry.usableAppID(Telemetry.placeholderAppID),
                     "The shipped placeholder must never configure the SDK.")
    }

    func testBlankAppIDIsTreatedAsUnset() {
        XCTAssertNil(Telemetry.usableAppID(nil))
        XCTAssertNil(Telemetry.usableAppID(""))
        XCTAssertNil(Telemetry.usableAppID("   \n "))
    }

    /// A made-up UUID, not AA's real one. The whole point of routing the app ID through gitignored
    /// `Secrets.xcconfig` is that the literal never enters the repo — pasting the real value into a
    /// tracked test would undo that for a fixture that doesn't need to be real.
    func testRealAppIDIsAcceptedAndTrimmed() {
        XCTAssertEqual(Telemetry.usableAppID("  00000000-1111-2222-3333-444444444444\n"),
                       "00000000-1111-2222-3333-444444444444")
    }

    // MARK: Driven sessions emit nothing

    /// Every driving hook fabricates state or skips a player step, so a session carrying one is
    /// verification, not usage — without this a `-devScenario` seed or a gallery run would become
    /// the loudest "player" in the funnel.
    func testEveryDrivingHookSuppressesTelemetry() {
        for hook in Telemetry.drivingHooks {
            XCTAssertTrue(Telemetry.isDriven(arguments: ["/path/to/app", hook],
                                             defaults: Self.emptyDefaults()),
                          "\(hook) must suppress telemetry — it is a driven session, not a player.")
        }
    }

    /// `-useTestStore` must **NOT** suppress — it's the only way to run a purchase through the real
    /// RevenueCat path off-device, and the Test Store is DEBUG-only (testMode → Test Data view), so
    /// its signals never touch live data. Pinned as a decision, not an oversight.
    func testUseTestStoreDoesNotSuppressTelemetry() {
        XCTAssertFalse(Telemetry.isDriven(arguments: ["app", "-useTestStore"],
                                          defaults: Self.emptyDefaults()))
        XCTAssertFalse(Telemetry.drivingHooks.contains("-useTestStore"))
    }

    func testAPlainLaunchIsNotSuppressed() {
        XCTAssertFalse(Telemetry.isDriven(arguments: ["/path/to/app"], defaults: Self.emptyDefaults()))
        XCTAssertFalse(Telemetry.isDriven(arguments: ["/path/to/app", "-someUnrelatedFlag"],
                                          defaults: Self.emptyDefaults()))
    }

    // MARK: The persisted debug-Pro flag — the hole an argument list can't see

    /// AA's current DEV Pro toggle is in-memory only, so nothing writes this flag TODAY — but the
    /// guard is here so it's already correct the day a persisted "unlock Pro for testing" affordance
    /// is added. Such a session carries NO arguments, looks exactly like a real player's, plays
    /// through, and never emits `Paywall.shown` because the gate opens on a fake — corrupting the one
    /// ratio the funnel exists to measure, in the direction that reads as healthy retention.
    /// (Ported from Vineyard/FC, which had this guard first.)
    func testPersistedDebugProSuppressesEvenWithNoArguments() {
        #if DEBUG
        let defaults = Self.emptyDefaults()
        defaults.set(true, forKey: Telemetry.debugProKey)
        XCTAssertTrue(Telemetry.isDriven(arguments: ["/path/to/app"], defaults: defaults),
                      "A persisted debug-Pro entitlement is a driven session even with a bare "
                      + "argument list — an argument check alone cannot see it.")
        #endif
    }

    func testClearedDebugProDoesNotSuppress() {
        let defaults = Self.emptyDefaults()
        defaults.set(false, forKey: Telemetry.debugProKey)
        XCTAssertFalse(Telemetry.isDriven(arguments: ["/path/to/app"], defaults: defaults))
    }

    /// A throwaway suite so these never read or write the real `UserDefaults` — which the app and
    /// `GameStore` also use, and which persists between test runs.
    private static func emptyDefaults() -> UserDefaults {
        let name = "TelemetryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
