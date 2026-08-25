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
                wakeAccountRecord()
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

    /// Wake the account-side app-presence record with a real report→LOAD
    /// round-trip (FC Architect's fix, 2026-08-23). An app that shipped to the
    /// App Store BEFORE its GC integration carries a stale record that suppresses
    /// GameKit registration even though auth + reporting work. FCA found that a
    /// genuine `report` FOLLOWED BY `loadAchievements` from a signed-in device
    /// registers the app — AA 1.4 reported but never loaded, the missing half.
    ///
    /// **VERIFIED ON DEVICE (build 49): this WORKS for the wake.** After it runs,
    /// AA appears in the Apple Games app ("Now Playing"), the in-app achievements
    /// pill reads N/29, and the Apple Games achievements grid renders our real
    /// badges with dates. The stale-record poison is gone.
    ///
    /// **WHAT IT DOES NOT FIX (confirmed on device, both AA + FCA): the in-app
    /// `GKGameCenterViewController` dashboard the rocket opens still renders
    /// BLANK** — a SEPARATE GameKit issue from the stale record, affecting both
    /// apps identically, unfixed by a device restart. Leading theory (FCA): the
    /// in-app dashboard reads a STORE-SIDE GC declaration that only propagates
    /// after a GC-carrying version is RELEASED (FCA 1.2 live ~2 days, still blank
    /// → propagation is slow or gated; AA has never released a GC version). So
    /// Apple Games is the working surface today; the rocket is NOT shipped (see
    /// `setAccessPointActive`). Idempotent + a no-op when signed out; safe to run
    /// on every authenticated launch.
    private static func wakeAccountRecord() {
        #if canImport(GameKit)
        guard isAuthenticated else { return }
        GKAchievement.loadAchievements { _, error in
            #if DEBUG
            if let error { print("[GameCenter] loadAchievements failed: \(error.localizedDescription)") }
            else { print("[GameCenter] account record woken (loadAchievements ok)") }
            #endif
        }
        #endif
    }

    /// Apple's standard floating Game Center access point (the rocket). **STILL a
    /// hard-off stub in 1.4.1 (build 49) — DELIBERATE, after an on-device test.**
    ///
    /// The story so far: it was off through 1.4 because the app's stale
    /// account-side record (shipped 1.0–1.3 pre-GC) opened the access point EMPTY.
    /// 1.4.1 first RE-ENABLED it, paired with `wakeAccountRecord` — but the device
    /// test (build 49, 2026-08-23) showed the wake fixes the RECORD (Apple Games
    /// fully populated) yet the rocket's in-app `GKGameCenterViewController`
    /// dashboard STILL renders blank. FC Architect confirmed the identical result
    /// on FCA — two apps, same blank in-app dashboard while Apple Games works. So
    /// the blank dashboard is a SEPARATE GameKit issue we can't fix in code (no VC
    /// present-timing change helps; a restart doesn't clear it). Shipping the
    /// rocket would just hand players an empty popover. So it stays OFF; players
    /// reach achievements via the Apple Games app (now populated by the wake) + the
    /// app's own milestone toasts.
    ///
    /// Leading theory (FCA) for the blank dashboard: it reads a STORE-SIDE GC
    /// declaration that only propagates after a GC-carrying version is RELEASED
    /// (FCA 1.2 live ~2 days, still blank → slow or gated; AA has never released a
    /// GC version). If so it may start working on its own — RE-CHECK the plain
    /// rocket on device ~1 week after AA's first GC release with NO new build; if
    /// it populates, re-enable here (the `active && isAuthenticated` +
    /// `atLaunchScreen` wiring below is the clean re-enable, just restore
    /// `isActive = active && isAuthenticated`). FCA is also testing a
    /// `GKGameCenterViewController(state: .achievements)` button vs the rocket's
    /// `.dashboard` state — if `.achievements` populates while `.dashboard` is
    /// blank, that's a 1.4.2 button. Until confirmed populating: NO entry point.
    static func setAccessPointActive(_ active: Bool) {
        #if canImport(GameKit)
        GKAccessPoint.shared.isActive = false
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
