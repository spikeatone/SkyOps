//
//  GameCenter.swift
//  Airline Architect — Game Center achievements + efficiency leaderboards.
//
//  VIEW LAYER ONLY (like Feedback/Telemetry — the Sim layer stays framework-
//  free for the headless harnesses). Everything degrades to a no-op when the
//  player isn't signed into Game Center, so nothing here can block play.
//
//  DESIGN RULE (from CLAUDE.md's GameKit note): rank on EFFICIENCY, not
//  accumulation — the sim is time-decoupled and runs at 25×, so raw net worth
//  would just reward grind. The two leaderboards are:
//    · aa.fastest_100m   — sim-DAYS to reach $100M net worth (ascending: lower
//                          is better). Submitted once, when the nw_100000000
//                          milestone fires.
//    · aa.networth_day365 — net worth on sim-day 365 (a fixed-horizon score).
//                          Submitted once, when the year_one milestone fires.
//  Achievements map 1:1 onto the existing milestone ladder (firedMilestones is
//  persisted, so submissions are once-per-save by construction; re-reporting a
//  100%-complete achievement is a harmless no-op to Game Center).
//
//  DESIGNER SETUP (one-time, in App Store Connect — see GAMEKIT_SETUP.md):
//  enable Game Center for the app, create the achievement/leaderboard IDs
//  below. Until they exist, submissions fail silently server-side — safe.
//

import UIKit
#if canImport(GameKit)
import GameKit
#endif

@MainActor
enum GameCenter {
    private(set) static var isAuthenticated = false
    /// Session-level dedup so a burst of onChange calls doesn't spam reports.
    private static var reportedThisSession: Set<String> = []

    /// Milestone key → Game Center achievement ID. Only the static ladder —
    /// dynamic keys (recoup_<routeId>) stay app-side toasts.
    static let achievementIDs: [String: String] = [
        "first_aircraft": "aa.first_aircraft",
        "first_flight": "aa.first_flight",
        "first_route": "aa.first_route",
        "first_hub": "aa.first_hub",
        "first_club": "aa.first_club",
        "first_widebody": "aa.first_widebody",
        "first_intl": "aa.first_intl",
        "flights_100": "aa.flights_100",
        "flights_1k": "aa.flights_1k",
        "fleet_5": "aa.fleet_5",
        "fleet_10": "aa.fleet_10",
        "fleet_25": "aa.fleet_25",
        "fleet_50": "aa.fleet_50",
        "routes_5": "aa.routes_5",
        "routes_10": "aa.routes_10",
        "routes_25": "aa.routes_25",
        "regions_4": "aa.regions_4",
        "regions_7": "aa.regions_7",
        "nw_30000000": "aa.nw_30m",
        "nw_50000000": "aa.nw_50m",
        "nw_100000000": "aa.nw_100m",
        "nw_250000000": "aa.nw_250m",
        "nw_500000000": "aa.nw_500m",
        "nw_1000000000": "aa.nw_1b",
        "iconic_SBH": "aa.iconic_sbh",
        "iconic_PPT": "aa.iconic_ppt",
        "first_subsidiary": "aa.first_subsidiary",
        "went_public": "aa.went_public",
        "year_one": "aa.year_one",
    ]
    static let leaderboardFastest100M = "aa.fastest_100m"
    static let leaderboardNetWorthDay365 = "aa.networth_day365"

    /// Authenticate the local player. Call once the cold-launch splash is done
    /// (so the sign-in sheet never lands on top of the intro animation). If
    /// GameKit hands us a login view controller, present it; an already-signed-
    /// in player just gets the small system welcome banner.
    static func configure(onAuthenticated: (() -> Void)? = nil) {
        #if canImport(GameKit)
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let vc = viewController {
                topViewController()?.present(vc, animated: true)
            } else if GKLocalPlayer.local.isAuthenticated {
                isAuthenticated = true
                onAuthenticated?()
            } else {
                isAuthenticated = false
                #if DEBUG
                if let error { print("[GameCenter] auth unavailable: \(error.localizedDescription)") }
                #endif
            }
        }
        #endif
    }

    /// The floating Game Center widget — shown on the load menu only (in-game
    /// it would sit on top of the HUD).
    static func setAccessPointActive(_ active: Bool) {
        #if canImport(GameKit)
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.showHighlights = false
        GKAccessPoint.shared.isActive = active && isAuthenticated
        #endif
    }

    /// A milestone fired live (from the celebration hook): report its
    /// achievement, plus the two leaderboard moments.
    static func reportMilestone(_ key: String, sim: Simulation) {
        #if canImport(GameKit)
        guard isAuthenticated, reportedThisSession.insert(key).inserted else { return }
        if let achievementID = achievementIDs[key] {
            reportAchievements([achievementID])
        }
        // Leaderboard moments — the value is read AT the milestone's firing.
        if key == "nw_100000000" {
            submit(leaderboardFastest100M, value: Simulation.gameDay(at: sim.tick))
        }
        if key == "year_one" {
            submit(leaderboardNetWorthDay365, value: sim.playerBalance + sim.fleetMarketValue)
        }
        #endif
    }

    /// Bring Game Center's achievement state up to date with a loaded save
    /// (milestones earned before GC existed, or on another device). Completed
    /// achievements re-report as no-ops, so this is idempotent. Leaderboards
    /// are NOT back-filled — their values are only known at the moment the
    /// milestone fires.
    static func syncAchievements(_ firedKeys: Set<String>) {
        #if canImport(GameKit)
        guard isAuthenticated else { return }
        let ids = firedKeys.compactMap { achievementIDs[$0] }
        guard !ids.isEmpty else { return }
        reportAchievements(ids)
        #endif
    }

    #if canImport(GameKit)
    private static func reportAchievements(_ ids: [String]) {
        let achievements = ids.map { id -> GKAchievement in
            let a = GKAchievement(identifier: id)
            a.percentComplete = 100
            a.showsCompletionBanner = false   // the app's own milestone toast is the banner
            return a
        }
        GKAchievement.report(achievements) { error in
            #if DEBUG
            if let error { print("[GameCenter] achievement report failed: \(error.localizedDescription)") }
            #endif
        }
    }

    private static func submit(_ leaderboardID: String, value: Int) {
        GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { error in
            #if DEBUG
            if let error { print("[GameCenter] score submit failed: \(error.localizedDescription)") }
            #endif
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif
}
