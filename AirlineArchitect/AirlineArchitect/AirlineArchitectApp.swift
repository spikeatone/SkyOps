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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
