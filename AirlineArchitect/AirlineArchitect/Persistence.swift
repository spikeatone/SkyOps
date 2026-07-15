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
    var savedAtEpoch = 0.0   // wall-clock save time (set by GameStore) — orders the slots

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

/// Lightweight summary of a saved slot, for the load/quit menu without decoding
/// the whole snapshot's object graph.
struct SlotInfo: Identifiable {
    let index: Int
    let airlineName: String
    let day: Int
    let cash: Int
    let fleet: Int
    let routes: Int
    let savedAtEpoch: Double
    var id: Int { index }
}

/// Reads/writes up to `slotCount` save files in the app's Documents directory.
/// The game keeps a bounded number of slots on purpose — enough to try a few
/// strategies, not so many that saves become throwaway.
enum GameStore {
    static let slotCount = 3

    private static func url(_ slot: Int) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("savegame_\(slot).json")
    }

    /// Migrate a legacy single-file save (from the pre-slot build) into slot 0 once.
    private static func migrateLegacyIfNeeded() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacy = dir.appendingPathComponent("savegame.json")
        guard FileManager.default.fileExists(atPath: legacy.path),
              !FileManager.default.fileExists(atPath: url(0).path) else { return }
        try? FileManager.default.moveItem(at: legacy, to: url(0))
    }

    static func hasSave(_ slot: Int) -> Bool {
        FileManager.default.fileExists(atPath: url(slot).path)
    }

    static var anySave: Bool {
        migrateLegacyIfNeeded()
        return (0..<slotCount).contains { hasSave($0) }
    }

    /// Index of a free slot, or nil if all are full.
    static var firstFreeSlot: Int? {
        migrateLegacyIfNeeded()
        return (0..<slotCount).first { !hasSave($0) }
    }

    static func save(_ snapshot: GameSnapshot, slot: Int) {
        var snap = snapshot
        snap.savedAtEpoch = Date().timeIntervalSince1970
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: url(slot), options: .atomic)
        } catch { /* a failed save shouldn't crash the game */ }
    }

    static func load(slot: Int) -> GameSnapshot? {
        migrateLegacyIfNeeded()
        guard let data = try? Data(contentsOf: url(slot)),
              let snap = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              snap.playerAirlineName != nil, !snap.isBankrupt else { return nil }
        return snap
    }

    static func clear(slot: Int) { try? FileManager.default.removeItem(at: url(slot)) }

    /// Summaries for every slot (nil where empty), for the load menu.
    static func slotInfos() -> [SlotInfo?] {
        migrateLegacyIfNeeded()
        return (0..<slotCount).map { slot in
            guard let data = try? Data(contentsOf: url(slot)),
                  let s = try? JSONDecoder().decode(GameSnapshot.self, from: data),
                  let name = s.playerAirlineName, !s.isBankrupt else { return nil }
            return SlotInfo(index: slot, airlineName: name, day: s.tick / 1440,
                            cash: s.playerBalance, fleet: s.aircraft.count,
                            routes: s.routes.count, savedAtEpoch: s.savedAtEpoch)
        }
    }
}
