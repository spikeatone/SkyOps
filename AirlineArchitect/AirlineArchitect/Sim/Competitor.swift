//
//  Competitor.swift
//  Airline Architect — competitor carriers as real, scoutable companies
//
//  Until now a competitor was {name, code, weight, types}: a livery on
//  background traffic and a string in Route.competitors. This gives each one a
//  PROFILE — fleet, network, and topline financials — so the player can study
//  the market they're competing in, and (in 1.1) evaluate an acquisition.
//
//  DISCLOSURE PRINCIPLE (designer): a profile shows what a PUBLIC FILING would
//  show — fleet, network size, revenue, margin, load factor, service score.
//  Never per-route P&L or anything an owner-but-not-an-investor would see. That
//  boundary is deliberate and leaves room for due diligence to reveal more.
//
//  DETERMINISM: profiles are derived purely from (airline, seed), so they are
//  regenerated exactly on load from the one persisted `competitorSeed`. That
//  keeps saves small AND makes targets stable — a player can't re-roll a
//  carrier's books by quitting without saving.
//

import Foundation

/// SplitMix64 — a tiny, dependency-free seeded generator. The system RNG can't
/// be used here: profiles must regenerate identically on every load.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A competitor's publicly-visible position. All figures are annual.
struct CompetitorProfile: Identifiable, Equatable {
    let id: String              // airline code, or name when the code is empty
    let name: String
    let code: String
    let region: String          // Airline.Region, as a display string

    // Fleet
    let fleetSize: Int
    let fleetByType: [String: Int]   // AircraftType.id → count
    /// 0 = all new, 1 = at design life. Drives value and tells the player how
    /// much of this fleet is junk they'd have to retire.
    let fleetAgeFraction: Double

    // Network
    let routeCount: Int
    let citiesServed: Int
    let hubCodes: [String]

    // Topline financials
    let annualRevenue: Double
    let operatingMargin: Double      // -0.08 … 0.16
    let loadFactor: Double           // 0.72 … 0.88
    let serviceScore: Double         // 0 … 100, comparable to player reputation

    /// Year-over-year capacity trend — the public signal of momentum.
    enum Trend: String { case growing = "Growing", stable = "Stable", shrinking = "Shrinking" }
    let trend: Trend

    /// Estimated enterprise value: depreciated fleet + goodwill on operating
    /// profit. NOT the asking price.
    let estimatedValue: Double
    /// What the fleet alone would fetch if broken up — mirrors the game's own
    /// `sellValue` depreciation. THE PRICE FLOOR: an asking price below this
    /// would let a player buy a carrier, liquidate it, and profit (pure
    /// arbitrage). Also the honest due-diligence number — it tells the player how
    /// much of the price is metal and how much is the business.
    let fleetLiquidationValue: Double

    var annualOperatingProfit: Double { annualRevenue * operatingMargin }

    /// The ACTUAL aircraft this carrier owns: one entry per airframe, with its
    /// real age. Derived deterministically from the world seed, so what stage-2
    /// due diligence reveals is EXACTLY what inheritance hands over — the books
    /// can't lie, and the player can't re-roll them by quitting.
    ///
    /// Stage 1 only ever sees `fleetAgeFraction` (the average), so a pre-NDA
    /// estimate is genuinely uncertain about the SPREAD. That divergence is the
    /// feature (designer: projections must not be iron-clad) — don't "fix" it.
    func fleetManifest(seed: UInt64) -> [(type: AircraftType, ageFraction: Double)] {
        var rng = SeededRNG(seed: seed &+ CompetitorIntel.manifestSalt(id))
        var out: [(AircraftType, Double)] = []
        for (typeID, count) in fleetByType.sorted(by: { $0.key < $1.key }) {
            guard let t = AircraftType.all.first(where: { $0.id == typeID }) else { continue }
            for _ in 0..<count {
                let age = min(1.0, max(0.0, fleetAgeFraction * Double.random(in: 0.6...1.35, using: &rng)))
                out.append((t, age))
            }
        }
        return out
    }
    var averageFleetAgeLabel: String {
        switch fleetAgeFraction {
        case ..<0.30: return "Young"
        case ..<0.55: return "Mid-life"
        case ..<0.75: return "Aging"
        default:      return "Old"
        }
    }
}

enum CompetitorIntel {

    /// Build every carrier's profile for this game. Deterministic in `seed`.
    static func generateAll(seed: UInt64, airports: [Airport]) -> [CompetitorProfile] {
        let regions: [Airline.Region] = [.us, .canada, .mexico, .centralAmerica, .caribbean,
                                         .southAmerica, .europe, .africa, .asia,
                                         .middleEast, .oceania]
        var out: [CompetitorProfile] = []
        var seen = Set<String>()
        for region in regions {
            let pool = airports.filter { Airline.region($0.code) == region }
            for airline in Airline.roster(for: region) {
                // Skip the generic fallback and any carrier already built for
                // another region (a few operate in more than one roster).
                guard !airline.name.isEmpty, !airline.types.isEmpty else { continue }
                let key = airline.code.isEmpty ? airline.name : airline.code
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(profile(for: airline, region: region, regionAirports: pool, seed: seed))
            }
        }
        return out.sorted { $0.annualRevenue > $1.annualRevenue }
    }

    /// One carrier's profile. Every figure is derived from real game data — the
    /// airline's real `types`, real `AircraftType` prices/seats, the real fare
    /// model, and its real region's airports — so the numbers stay internally
    /// consistent with the economy the player is operating in.
    static func profile(for airline: Airline, region: Airline.Region,
                        regionAirports: [Airport], seed: UInt64) -> CompetitorProfile {
        // Seed per airline so one carrier's numbers never depend on roster order.
        var rng = SeededRNG(seed: seed &+ stableHash(airline.code + airline.name))

        // --- Fleet -------------------------------------------------------
        // GAME scale, not real-world scale: a real major flies ~900 aircraft,
        // which would price an acquisition far beyond any reachable net worth.
        // Roster weight (market share) drives relative size instead.
        let base = 3 + airline.weight * 2
        let jitter = Double.random(in: 0.80...1.20, using: &rng)
        let fleetSize = max(4, min(60, Int((Double(base) * jitter).rounded())))

        let operable = AircraftType.all.filter { airline.types.contains($0.id) }
        let typePool = operable.isEmpty ? AircraftType.all : operable
        var fleetByType: [String: Int] = [:]
        for _ in 0..<fleetSize {
            let t = weightedType(typePool, using: &rng)
            fleetByType[t.id, default: 0] += 1
        }
        let fleetAgeFraction = Double.random(in: 0.20...0.78, using: &rng)

        // --- Network -----------------------------------------------------
        // ~1.6 routes per aircraft, capped by how many airports the region has.
        let routeCount = max(2, min(Int(Double(fleetSize) * Double.random(in: 1.3...1.9, using: &rng)),
                                    max(2, regionAirports.count * 2)))
        let citiesServed = max(2, min(regionAirports.count,
                                      Int(Double(routeCount) * Double.random(in: 0.55...0.85, using: &rng))))
        // Hubs = its region's busiest airports, so a carrier's stated hubs are
        // somewhere the player recognises from their own map.
        let hubCount = fleetSize > 30 ? 3 : (fleetSize > 12 ? 2 : 1)
        let hubCodes = regionAirports
            .sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
            .prefix(hubCount).map(\.code)

        // --- Operations --------------------------------------------------
        let loadFactor = Double.random(in: 0.72...0.88, using: &rng)
        let serviceScore = Double.random(in: 45...92, using: &rng)

        // Revenue from the REAL fare model: each aircraft flies ~2 legs/day at a
        // stage length typical for its body type.
        // Sorted, NOT raw dictionary order: Dictionary iteration order isn't
        // stable across instances, and float addition isn't associative — so an
        // unsorted sum makes the last bits of revenue/value vary between two
        // generations from the SAME seed, breaking the regenerate-on-load
        // guarantee. (Caught by the determinism check, not by inspection.)
        var annualRevenue = 0.0
        for (typeID, count) in fleetByType.sorted(by: { $0.key < $1.key }) {
            guard let t = AircraftType.all.first(where: { $0.id == typeID }) else { continue }
            let stageNM = typicalStageNM(t.bodyType)
            let fare = FareModel.farePerSeat(distanceNM: stageNM)
            annualRevenue += Double(count) * Double(t.seats) * loadFactor * fare * legsPerYear
        }

        // Margins in the real industry band, skewed by service score — a
        // well-run carrier earns more. A weak one can be genuinely lossmaking,
        // which is exactly the target that looks cheap and isn't.
        let quality = (serviceScore - 45) / 47                     // 0…1
        let operatingMargin = (-0.06 + 0.20 * quality) + Double.random(in: -0.025...0.025, using: &rng)

        let trendRoll = Double.random(in: 0...1, using: &rng)
        let trend: CompetitorProfile.Trend = operatingMargin < 0
            ? (trendRoll < 0.65 ? .shrinking : .stable)
            : (trendRoll < 0.45 ? .growing : (trendRoll < 0.85 ? .stable : .shrinking))

        // --- Valuation ---------------------------------------------------
        // Depreciated fleet + goodwill on operating profit. Loss-making
        // carriers carry NEGATIVE goodwill (you'd pay less than metal value).
        var fleetValue = 0.0
        for (typeID, count) in fleetByType.sorted(by: { $0.key < $1.key }) {
            guard let t = AircraftType.all.first(where: { $0.id == typeID }) else { continue }
            fleetValue += Double(count) * Double(t.purchasePrice) * max(0.05, 1.0 - fleetAgeFraction)
        }
        let goodwill = annualRevenue * operatingMargin * goodwillYears
        let estimatedValue = max(fleetValue * 0.35, fleetValue + goodwill)

        return CompetitorProfile(
            id: airline.code.isEmpty ? airline.name : airline.code,
            name: airline.name, code: airline.code,
            region: regionLabel(region),
            fleetSize: fleetSize, fleetByType: fleetByType, fleetAgeFraction: fleetAgeFraction,
            routeCount: routeCount, citiesServed: citiesServed, hubCodes: hubCodes,
            annualRevenue: annualRevenue, operatingMargin: operatingMargin,
            loadFactor: loadFactor, serviceScore: serviceScore, trend: trend,
            estimatedValue: estimatedValue, fleetLiquidationValue: fleetValue)
    }

    // MARK: - Constants & helpers

    /// The sim's own cadence: a ~369-tick leg gives roughly 2 legs/day.
    private static let legsPerYear = 730.0
    /// Years of operating profit capitalised into goodwill.
    private static let goodwillYears = 6.0

    private static func typicalStageNM(_ b: BodyType) -> Double {
        switch b {
        case .turboprop:       return 250
        case .regionalJet:     return 450
        case .narrowbody:      return 900
        case .widebody2Engine: return 3_400
        case .widebody4Engine: return 4_200
        }
    }

    private static func weightedType(_ pool: [AircraftType], using rng: inout SeededRNG) -> AircraftType {
        let total = pool.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return pool[0] }
        var roll = Int.random(in: 0..<total, using: &rng)
        for t in pool {
            roll -= t.weight
            if roll < 0 { return t }
        }
        return pool[pool.count - 1]
    }

    /// Order-independent, platform-stable hash. `String.hashValue` is seeded per
    /// process and would give a different world on every launch.
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x1000_0000_01b3 }
        return h
    }

    /// Salt so the manifest draw is independent of the profile draw.
    static func manifestSalt(_ id: String) -> UInt64 { stableHash("manifest:" + id) }

    static func regionLabel(_ r: Airline.Region) -> String {
        switch r {
        case .us:             return "United States"
        case .canada:         return "Canada"
        case .mexico:         return "Mexico"
        case .centralAmerica: return "Central America"
        case .caribbean:      return "Caribbean"
        case .southAmerica:   return "South America"
        case .europe:         return "Europe"
        case .africa:         return "Africa"
        case .asia:           return "Asia"
        case .middleEast:     return "Middle East"
        case .oceania:        return "Oceania"
        }
    }
}
