//
//  Persistence.swift
//  Airline Architect
//
//  Save/restore the game so the player picks up where they left off. A Codable
//  GameSnapshot captures the persistent state (fleet, routes, crew, economy,
//  camera); it's written to Documents when the app backgrounds and offered back
//  on the next cold launch. Background (competitor) traffic, in-flight event
//  state, and the used market are NOT persisted — they regenerate on load, which
//  keeps the snapshot small and the restore robust.
//

import Foundation

// MARK: - Codable snapshot

struct GameSnapshot: Codable {
    var version = 3
    var savedAtTick = 0

    // Identity + economy
    var playerAirlineName: String?
    var playerTailCode = "ZQ"
    var playerBalance = 0
    var tick = 0
    var nextTailNum = 1
    var nextRouteId = 1

    var totalRevenue = 0, totalFees = 0, totalOperatingCost = 0, totalLeaseCost = 0
    var totalInsuranceSpent = 0, maintenanceSpend = 0
    var totalAcquisitionSpend = 0, totalRouteSpend = 0, totalHedgeSpend = 0
    var totalSaleProceeds = 0, totalOfferIncome = 0, totalFlightsFlown = 0

    // Flags
    var isBankrupt = false
    var insolventSinceTick: Int?
    var useDemandModel = true
    var firedMilestones: [String] = []
    var stressTestCount = 0

    // Camera
    var cameraZoom = 1.0
    var cameraCenterX = 0.0
    var cameraCenterY = 0.0

    // World
    var aircraft: [AircraftSave] = []
    var routes: [RouteSave] = []
    var closedRoutes: [RouteSave] = []
    var crewPools: [String: [CrewSave]] = [:]
    var reserveCrews: [String: Int] = [:]
    var financeSnapshots: [FinanceSave] = []
}

struct AircraftSave: Codable {
    var tail: String
    var typeId: String
    var originCode: String
    var destCode: String
    var stateIndex: Int
    var stateTick: Int
    var cyclesAccrued: Int
    var assignedRouteId: Int?
    var sellOfferDismissed: Bool
    var isLeased: Bool
    var leaseAccrued: Double
    var maint: Bool
    var aogAutoClearTick: Int?
    var crewId: Int?
}

struct RouteSave: Codable {
    var id: Int
    var originCode: String
    var destCode: String
    var openedTick: Int
    var openingCost: Int
    var cumulativeNet: Int
    var flights: Int
    var totalLeaseCost: Int
    var closedTick: Int?
    var history: [FlightRecordSave]
    var assignmentHistory: [RouteAssignmentSave]
}

struct FlightRecordSave: Codable {
    var id: Int, tick: Int, tail: String, revenue: Int, fees: Int, operatingCost: Int
    var leaseCostEstimate: Int, net: Int, pax: Int, seats: Int, loadFactor: Double, cumulativeNet: Int
}

struct RouteAssignmentSave: Codable {
    var id: Int, tail: String, typeName: String, assignedTick: Int
}

struct CrewSave: Codable {
    var id: Int
    var status: Int   // 0 available · 1 onDuty · 2 resting · (sidelined → available on load)
    var dutyTicks: Int
    var restTicksLeft: Int
}

struct FinanceSave: Codable {
    var tick, revenue, fees, operatingCost, leaseCost, insurance, maintenance: Int
    var acquisition, routeSpend, hedgeSpend, saleProceeds, offerIncome, flights, cash, netWorth: Int
}

extension CrewStatus {
    /// A sidelined crew (labor action) resets to available on reload — the labor
    /// action itself isn't persisted.
    var saveCode: Int {
        switch self {
        case .available, .sidelined: return 0
        case .onDuty:  return 1
        case .resting: return 2
        }
    }
    init(saveCode: Int) {
        switch saveCode { case 1: self = .onDuty; case 2: self = .resting; default: self = .available }
    }
}

// MARK: - Disk store

/// Reads/writes the single-slot save file in the app's Documents directory.
enum GameStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("savegame.json")
    }

    static var hasSave: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func save(_ snapshot: GameSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch { /* a failed save shouldn't crash the game */ }
    }

    static func load() -> GameSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              snap.playerAirlineName != nil, !snap.isBankrupt else { return nil }
        return snap
    }

    static func clear() { try? FileManager.default.removeItem(at: url) }
}
