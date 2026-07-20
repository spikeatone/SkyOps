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
    var totalLoanProceeds = 0, totalDebtService = 0
    var loans: [LoanSave] = []

    // Flags
    var isBankrupt = false
    var insolventSinceTick: Int?
    var useDemandModel = true
    var reputation = Simulation.reputationStart
    var firedMilestones: [String] = []
    var stressTestCount = 0

    // Home region (player's start-region choice; nil in pre-region saves → NA)
    var homeRegion: String?

    // Competitor-intel seed (nil in pre-1.1 saves → a fresh seed is rolled, so
    // an existing game simply gains a competitor market on first load).
    var competitorSeed: UInt64?

    // Acquisitions (nil in pre-acquisition saves)
    var subsidiaries: [Subsidiary]? = nil
    var totalAcquisitionPrice: Int? = nil
    var activeIntegration: Integration? = nil
    var totalIntegrationSpend: Int? = nil
    var totalSenioritySpend: Int? = nil
    var diligencedCarriers: [String]? = nil
    var totalDiligenceSpend: Int? = nil

    // Go public (nil in pre-IPO saves)
    var publicCompany: PublicCompany? = nil
    var marketSentiment: Double? = nil
    var displaySharePrice: Double? = nil
    var totalEquityRaised: Int? = nil
    var totalDividendsPaid: Int? = nil
    var totalBuybackSpend: Int? = nil
    var activistCampaign: ActivistCampaign? = nil
    var monthsBelowIPO: Int? = nil

    // Hubs & Clubs (nil in pre-hub saves)
    var hubs: [String: Simulation.Hub]? = nil
    var rivalHubs: [String: String]? = nil
    var totalHubSpend: Int? = nil
    var totalHubLabor: Int? = nil
    var totalClubRent: Int? = nil

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
    var crewTrainingDue: [String: Int] = [:]
    var crewTrainingDeferred: [String: Int] = [:]
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
    /// Optional for back-compat with saves written before reassignment existed.
    var pendingRouteId: Int?
    var sellOfferDismissed: Bool
    var isLeased: Bool
    var leaseAccrued: Double
    var maint: Bool
    var aogAutoClearTick: Int?
    var crewId: Int?
    /// Non-nil for an aircraft inherited with an acquired subsidiary.
    var subsidiaryCode: String? = nil
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
    var competitionLevel: Int = 0
    var competitors: [String] = []
    var incentiveBonus: Int = 0
    var incentiveWaived: Int = 0
    var fulfillByTick: Int? = nil
    /// Non-nil for a route that came with an acquired subsidiary.
    var subsidiaryCode: String? = nil
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
    var loanProceeds = 0, debtService = 0
    var hubSpend: Int? = nil, hubLabor: Int? = nil, clubRent: Int? = nil
    var airlineAcquisition: Int? = nil
    var integrationSpend: Int? = nil
    var equityRaised: Int? = nil
    var dividendsPaid: Int? = nil, buybackSpend: Int? = nil
}

struct LoanSave: Codable {
    var id: Int
    var originalPrincipal: Int
    var remainingPrincipal: Double
    var monthlyRate: Double
    var monthlyPayment: Int
    var termMonths: Int
    var takenTick: Int
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
            mirrorToCloud(data, slot: slot)   // keep the player's other devices in sync
        } catch { /* a failed save shouldn't crash the game */ }
    }

    static func load(slot: Int) -> GameSnapshot? {
        migrateLegacyIfNeeded()
        guard let data = try? Data(contentsOf: url(slot)),
              let snap = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              snap.playerAirlineName != nil, !snap.isBankrupt else { return nil }
        return snap
    }

    static func clear(slot: Int) {
        try? FileManager.default.removeItem(at: url(slot))
        cloudDelete(slot: slot)   // save key removed + a dated tombstone written
    }

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

// MARK: - iCloud sync (key-value store, keyed to the device's Apple ID)
//
// The local Documents files stay the source of truth the app reads/writes
// (offline-first — everything keeps working with no iCloud account). On top of
// that, each slot is mirrored into the iCloud key-value store, which Apple syncs
// across every device signed into the SAME Apple ID. On launch (and whenever
// another device changes a slot while we're running) we RECONCILE: for each
// slot, the copy with the newer `savedAtEpoch` wins and is written into the
// local file — so "save on the iPad, pick up on the iPhone" just works.
//
// Data is tiny (a save is ~1–7 KB; 3 slots ≈ a few KB) — far under KVS's 1 MB
// limit. KVS is best-effort/eventually-consistent (syncs within seconds–minutes,
// not instantly); that's fine for turn-based save handoff.
//
// DELETE TOMBSTONES: deleting a slot writes a dated tombstone to iCloud (and
// removes the cloud save). Reconcile treats a delete as an EVENT that competes
// on recency with saves — so a delete that's newer than every save wins (the
// slot stays gone on all devices, no resurrection), but starting a NEW game in
// that slot afterward produces a save newer than the tombstone, which correctly
// wins. Data is only ever removed when a delete is genuinely the most-recent
// action for that slot.
extension GameStore {
    private static var kvs: NSUbiquitousKeyValueStore { .default }
    private static func cloudKey(_ slot: Int) -> String { "savegame_slot_\(slot)" }
    private static func tombKey(_ slot: Int) -> String { "savegame_slot_\(slot)_deleted" }

    /// The reconcile decision for one slot, given the local save's epoch, the
    /// cloud save's epoch, and any delete-tombstone epoch. Pure + unit-tested.
    /// The most-recent EVENT wins: a save (adopt/push the newest) or a delete
    /// (remove local). Ties/no-ops do nothing.
    enum SyncAction: Equatable { case none, adoptCloud, pushLocal, deleteLocal }
    static func reconcileAction(localEpoch: Double?, cloudSaveEpoch: Double?,
                                tombstoneEpoch: Double?) -> SyncAction {
        let newestSave = [localEpoch, cloudSaveEpoch].compactMap { $0 }.max()
        // A delete only wins if it's strictly newer than every known save.
        if let t = tombstoneEpoch, newestSave == nil || t > newestSave! {
            return .deleteLocal
        }
        // Otherwise a save is the newest event — adopt/push whichever is newer.
        switch (localEpoch, cloudSaveEpoch) {
        case (nil, nil):   return .none
        case (_?, nil):    return .pushLocal
        case (nil, _?):    return .adoptCloud
        case let (l?, c?): return c > l ? .adoptCloud : (l > c ? .pushLocal : .none)
        }
    }

    /// `savedAtEpoch` of an encoded snapshot, or nil if it isn't a valid save.
    private static func epoch(of data: Data?) -> Double? {
        guard let data,
              let s = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              s.playerAirlineName != nil else { return nil }
        return s.savedAtEpoch
    }

    private static func mirrorToCloud(_ data: Data, slot: Int) {
        kvs.set(data, forKey: cloudKey(slot))
        // A fresh save supersedes any prior deletion of this slot.
        kvs.removeObject(forKey: tombKey(slot))
        kvs.synchronize()
    }
    private static func cloudDelete(slot: Int) {
        kvs.removeObject(forKey: cloudKey(slot))
        kvs.set(Date().timeIntervalSince1970, forKey: tombKey(slot))
        kvs.synchronize()
    }

    /// Reconcile every slot between local files and iCloud, so the local store
    /// the app reads is always the freshest across the player's devices (a save
    /// or a delete — whichever happened most recently, anywhere, wins). Cheap —
    /// a few small file reads against the KVS local cache.
    static func reconcileCloud() {
        kvs.synchronize()
        for slot in 0..<slotCount {
            let localData = try? Data(contentsOf: url(slot))
            let cloudData = kvs.data(forKey: cloudKey(slot))
            let tomb = kvs.object(forKey: tombKey(slot)) as? Double
            switch reconcileAction(localEpoch: epoch(of: localData),
                                   cloudSaveEpoch: epoch(of: cloudData),
                                   tombstoneEpoch: tomb) {
            case .adoptCloud:
                if let cloudData { try? cloudData.write(to: url(slot), options: .atomic) }
            case .pushLocal:
                if let localData { kvs.set(localData, forKey: cloudKey(slot)) }
            case .deleteLocal:
                try? FileManager.default.removeItem(at: url(slot))
                kvs.removeObject(forKey: cloudKey(slot))   // clear any stale cloud save
            case .none:
                break
            }
        }
        kvs.synchronize()
    }

    /// Register for iCloud external-change notifications (another device saved a
    /// slot while we're running). Reconciles, then calls `onChange` so the UI —
    /// e.g. the load menu — can refresh. Call once at launch.
    static func observeCloudChanges(_ onChange: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main) { _ in
                reconcileCloud()
                onChange()
        }
    }
}
