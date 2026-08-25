//
//  AirlineArchitectApp.swift
//  Airline Architect
//
//  Created by Michael Stevens on 7/12/26.
//
//  Phase 1: no persistence yet — the app just runs the live tick simulation.
//  SwiftData returns in Phase 5 (saving the player's fleet/routes/economy);
//  the project is still configured for it, we simply don't have anything to
//  persist while porting the engine.
//

import SwiftUI

@main
struct AirlineArchitectApp: App {
    init() {
        // Configure RevenueCat once, before anything reads Purchases.shared.
        Store.configure()
        // Analytics (anonymous, no IDFA). TelemetryDeck asks to be initialized
        // here in init() rather than in an .onAppear, so it's ready before the
        // first window is built.
        Telemetry.configure()
        // Crash/hang visibility via MetricKit — routes crash TYPE (never a stack)
        // to Telemetry's Errors bucket. After Telemetry.configure() so a report
        // has somewhere to land; a driven session skips subscribing entirely.
        CrashReporter.start()
    }
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Design experiment: `-backdropTest` opens the architect's-tools
            // brand-motif harness instead of the game. DEBUG-only, so it is
            // compiled out of Release entirely.
            if ProcessInfo.processInfo.arguments.contains("-backdropTest") {
                ArchitectBackdropTestView()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
