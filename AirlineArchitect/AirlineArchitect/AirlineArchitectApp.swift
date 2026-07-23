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
