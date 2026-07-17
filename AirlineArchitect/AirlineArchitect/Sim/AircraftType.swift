//
//  AircraftType.swift
//  Airline Architect — Phase 2 (fleet) + Phase 5 (economy fields)
//
//  The fleet catalogue, ported from AIRCRAFT_TYPES. 30 real named variants
//  across 15 crew-type-rating families. `costPerHour` is real direct operating
//  cost/hour (SimpleFlying/AirInsight-tier, 2025-26); `holdCostPerTick` derives
//  it per sim-minute. Spawn `weight` is real-world-proportional. This is DATA,
//  not logic — ported verbatim; don't re-round "for cleanliness."
//

import Foundation

/// Drives gate-fee tier, render scale, icon tier, AND (Phase 5) the operating-
/// cost stage length + average fare per seat. Changing a case ripples widely.
enum BodyType: String {
    case turboprop
    case regionalJet
    case narrowbody
    case widebody2Engine
    case widebody4Engine

    /// On-map render length in points (prototype targetLengths, +15%).
    var iconLength: CGFloat {
        switch self {
        case .turboprop:       return 8.5
        case .regionalJet:     return 9.9
        case .narrowbody:      return 12.5
        case .widebody2Engine: return 17.1
        case .widebody4Engine: return 19.9
        }
    }

    /// Realistic average stage length in block-minutes, used to charge
    /// operating cost (NOT the fixed ~visual flight cycle) — ported from
    /// OPERATING_COST_BLOCK_MINUTES_BY_BODYTYPE. Sourced cost/hour figures
    /// assume each type's typical real mission length, so this must match.
    var operatingCostBlockMinutes: Int {
        switch self {
        case .turboprop:       return 55    // ~55 min — short island/regional hops
        case .regionalJet:     return 75    // ~1.25 hr
        case .narrowbody:      return 120   // ~2 hr
        case .widebody2Engine: return 480   // ~8 hr
        case .widebody4Engine: return 540   // ~9 hr
        }
    }

    /// Average one-way fare per seat (AVG_FARE_PER_SEAT_BY_BODYTYPE). Domestic
    /// ~$214, international ~$608 (real 2025-26); regional $165 is an estimate.
    /// SUPERSEDED by the distance-based `FareModel` (fare depends on the route,
    /// not the aircraft) — kept only as a reference / calibration anchor.
    var avgFarePerSeat: Double {
        switch self {
        case .turboprop:       return 150
        case .narrowbody:      return 214
        case .regionalJet:     return 165
        case .widebody2Engine: return 608
        case .widebody4Engine: return 608
        }
    }

    /// Minimum runway length (ft) this body-type needs to operate — bigger/
    /// heavier jets need more. Gates which airports it can serve: a widebody
    /// can't use a short regional field, so route planning matches fleet to
    /// network.
    var minRunwayFt: Int {
        switch self {
        case .turboprop:       return 3400   // short-field capable (Beech 1900 class)
        case .regionalJet:     return 5000
        case .narrowbody:      return 6800
        case .widebody2Engine: return 8000
        case .widebody4Engine: return 9500
        }
    }

    /// Cruise speed in nautical miles per block-minute (for distance-based
    /// operating cost). Bigger jets cruise a touch faster.
    var cruiseNMPerMin: Double {
        switch self {
        case .turboprop:       return 4.6   // ~275 kt
        case .regionalJet:     return 6.8   // ~410 kt
        case .narrowbody:      return 7.5   // ~450 kt
        case .widebody2Engine: return 8.3   // ~500 kt
        case .widebody4Engine: return 8.3
        }
    }

    /// Block minutes for a leg of `nm` nautical miles: a fixed taxi/climb/descent
    /// overhead plus cruise time. Replaces the fixed `operatingCostBlockMinutes`
    /// so operating cost scales with the ACTUAL route length — the necessary
    /// companion to distance-based fares (otherwise a long route is same-cost,
    /// more-revenue free money). Floored so a very short hop still pays a minimum.
    func blockMinutes(forNM nm: Double) -> Double {
        max(Double(operatingCostBlockMinutes) * 0.5, 35 + max(0, nm) / cruiseNMPerMin)
    }

    /// True for the widebody gate-fee tier (WIDEBODY_BODY_TYPES).
    var usesWidebodyGateFee: Bool {
        self == .widebody2Engine || self == .widebody4Engine
    }
}

struct AircraftType: Identifiable {
    let id: String
    let name: String
    let seats: Int
    let family: String
    let bodyType: BodyType
    let weight: Int
    let mlwLbs: Int
    let costPerHour: Int
    let purchasePrice: Int
    let expectedLifespanCycles: Int
    /// Per-type runway minimum override (ft). nil = use the body-type default.
    /// The Dash 8-200 sets this low (our shortest-field STOL type — reaches
    /// St. Barths, which the other turboprops can't).
    var minRunwayFtOverride: Int? = nil

    /// Shortest runway this specific type can use — its override if set,
    /// otherwise the body-type tier default. The route-runway gate reads this.
    var minRunwayFt: Int { minRunwayFtOverride ?? bodyType.minRunwayFt }

    /// Operating cost per sim-minute (1 tick). Ported: round(costPerHour / 60).
    var holdCostPerTick: Int { Int((Double(costPerHour) / 60).rounded()) }

    /// Relative FUEL burn intensity — how exposed this type is to fuel-price
    /// swings (an Oil Spike / Fuel Drop event). 1.0 = baseline; the modern
    /// new-generation types burn ~28% less (0.72), 4-engine widebodies ~60% more
    /// (1.6). This is what makes fuel efficiency a real per-aircraft axis: a
    /// neo/MAX/787/A350/A330neo/A220 fleet weathers a fuel spike far better than
    /// old thirsty metal, so it's worth its price premium as a hedge. (Normal-
    /// condition efficiency is ALSO already in each type's real `costPerHour`;
    /// this is the extra, differential fuel-PRICE sensitivity on top.)
    var fuelIntensity: Double {
        switch id {
        case "A319NEO", "A320NEO", "A321NEO", "MAX8", "MAX9",
             "B788", "B789", "B78J", "A339", "A359", "A220100", "A220300":
            return 0.72
        default:
            return bodyType == .widebody4Engine ? 1.6 : 1.0
        }
    }

    /// Practical range in nautical miles — representative published figures per
    /// type (shown in the Acquire card). Display-only; not sim-critical.
    var rangeNM: Int { AircraftType.rangeByID[id] ?? 3000 }
    private static let rangeByID: [String: Int] = [
        "A319": 3700, "A320": 3300, "A321": 3200, "A319NEO": 3750, "A320NEO": 3400, "A321NEO": 4000,
        "B737700": 3010, "B737800": 2935, "B739": 2950, "MAX8": 3550, "MAX9": 3300,
        "A220300": 3350, "A220100": 3400,
        "B773": 6014, "B788": 7355, "B789": 7565, "B78J": 6330, "A339": 7200, "A359": 8100,
        "B747": 7260, "A380": 8000, "A340": 7400,
        "E170": 2150, "E175": 2200, "E190": 2450, "E195": 2300,
        "CRJ900": 1550, "CRJ1000": 1650,
        "ERJ135": 1750, "ERJ140": 1630, "ERJ145": 1550,
        "B1900": 1000, "AT46": 840, "D328": 900, "DH8B": 1100,
    ]

    /// Fixed MONTHLY lease payment: 0.8% of purchase price (LEASE_MONTHLY_RATE
    /// — the midpoint of the real 0.6–1.2% "lease rate factor", Acumen Aero,
    /// cross-checked against real narrowbody lease quotes). Charged every
    /// sim-month regardless of utilization — see Simulation.tickLeaseBilling().
    var monthlyLeaseCost: Int { Int((Double(purchasePrice) * 0.008).rounded()) }

    /// Full fleet catalogue — ported verbatim from AIRCRAFT_TYPES.
    static let all: [AircraftType] = [
        // A320 family (ceo + neo) — one crew family
        .init(id: "A319",    name: "Airbus A319",       seats: 140, family: "A320_FAMILY", bodyType: .narrowbody, weight: 19, mlwLbs: 134480, costPerHour: 7900,  purchasePrice: 67_000_000, expectedLifespanCycles: 48000),
        .init(id: "A320",    name: "Airbus A320",       seats: 165, family: "A320_FAMILY", bodyType: .narrowbody, weight: 56, mlwLbs: 142200, costPerHour: 8200,  purchasePrice: 74_000_000, expectedLifespanCycles: 48000),
        .init(id: "A321",    name: "Airbus A321",       seats: 200, family: "A320_FAMILY", bodyType: .narrowbody, weight: 29, mlwLbs: 171520, costPerHour: 11100, purchasePrice: 86_000_000, expectedLifespanCycles: 48000),
        .init(id: "A319NEO", name: "Airbus A319neo",    seats: 145, family: "A320_FAMILY", bodyType: .narrowbody, weight: 2,  mlwLbs: 137790, costPerHour: 7100,  purchasePrice: 74_000_000, expectedLifespanCycles: 48000),
        .init(id: "A320NEO", name: "Airbus A320neo",    seats: 168, family: "A320_FAMILY", bodyType: .narrowbody, weight: 24, mlwLbs: 146170, costPerHour: 7400,  purchasePrice: 81_000_000, expectedLifespanCycles: 48000),
        .init(id: "A321NEO", name: "Airbus A321neo",    seats: 200, family: "A320_FAMILY", bodyType: .narrowbody, weight: 30, mlwLbs: 179000, costPerHour: 8000,  purchasePrice: 94_000_000, expectedLifespanCycles: 48000),
        // 737 family (NG + MAX) — one crew family
        .init(id: "B737700", name: "Boeing 737-700",    seats: 140, family: "B737_FAMILY", bodyType: .narrowbody, weight: 9,  mlwLbs: 128000, costPerHour: 7500,  purchasePrice: 59_000_000, expectedLifespanCycles: 75000),
        .init(id: "B737800", name: "Boeing 737-800",    seats: 175, family: "B737_FAMILY", bodyType: .narrowbody, weight: 37, mlwLbs: 146300, costPerHour: 7900,  purchasePrice: 70_000_000, expectedLifespanCycles: 75000),
        .init(id: "B739",    name: "Boeing 737-900",    seats: 180, family: "B737_FAMILY", bodyType: .narrowbody, weight: 15, mlwLbs: 146300, costPerHour: 8000,  purchasePrice: 74_000_000, expectedLifespanCycles: 75000),
        .init(id: "MAX8",    name: "Boeing 737 MAX 8",  seats: 175, family: "B737_FAMILY", bodyType: .narrowbody, weight: 30, mlwLbs: 146300, costPerHour: 7000,  purchasePrice: 86_000_000, expectedLifespanCycles: 75000),
        .init(id: "MAX9",    name: "Boeing 737 MAX 9",  seats: 190, family: "B737_FAMILY", bodyType: .narrowbody, weight: 10, mlwLbs: 152800, costPerHour: 7500,  purchasePrice: 94_000_000, expectedLifespanCycles: 75000),
        // A220 family — one crew family (A220-300 narrowbody, A220-100 RJ per designer)
        .init(id: "A220300", name: "Airbus A220-300",   seats: 140, family: "A220_FAMILY", bodyType: .narrowbody,  weight: 4, mlwLbs: 137300, costPerHour: 4300, purchasePrice: 67_000_000, expectedLifespanCycles: 60000),
        .init(id: "A220100", name: "Airbus A220-100",   seats: 115, family: "A220_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 122300, costPerHour: 3800, purchasePrice: 59_000_000, expectedLifespanCycles: 60000),
        // Twin-engine widebodies — each its own crew family
        .init(id: "B773",    name: "Boeing 777-300",       seats: 380, family: "B777", bodyType: .widebody2Engine, weight: 23, mlwLbs: 460000, costPerHour: 20000, purchasePrice: 289_000_000, expectedLifespanCycles: 44000),
        .init(id: "B788",    name: "Boeing 787-8 Dreamliner",  seats: 242, family: "B787", bodyType: .widebody2Engine, weight: 10, mlwLbs: 380000, costPerHour: 11500, purchasePrice: 200_000_000, expectedLifespanCycles: 44000),
        .init(id: "B789",    name: "Boeing 787-9 Dreamliner",  seats: 280, family: "B787", bodyType: .widebody2Engine, weight: 14, mlwLbs: 425000, costPerHour: 12000, purchasePrice: 225_000_000, expectedLifespanCycles: 44000),
        .init(id: "B78J",    name: "Boeing 787-10 Dreamliner", seats: 330, family: "B787", bodyType: .widebody2Engine, weight: 7,  mlwLbs: 445000, costPerHour: 12500, purchasePrice: 250_000_000, expectedLifespanCycles: 44000),
        .init(id: "A339",    name: "Airbus A330-900",      seats: 300, family: "A330", bodyType: .widebody2Engine, weight: 10, mlwLbs: 421082, costPerHour: 11500, purchasePrice: 230_000_000, expectedLifespanCycles: 44000),
        .init(id: "A359",    name: "Airbus A350-900",      seats: 306, family: "A350", bodyType: .widebody2Engine, weight: 8,  mlwLbs: 456357, costPerHour: 13500, purchasePrice: 300_000_000, expectedLifespanCycles: 44000),
        // Four-engine widebodies — each its own crew family
        // 747-400 (not the -8: the -8 passenger variant never really sold — it
        // was essentially freighter-only). Real 747-400 profile: an aging,
        // out-of-production jumbo — CHEAP to buy but expensive to run and
        // aging out. lifespan 20,000 = real Boeing 747-400 Design Service Goal;
        // costPerHour/purchasePrice are representative for a retiring jumbo
        // (higher op cost than the more-efficient -8; much lower price).
        .init(id: "B747",    name: "Boeing 747-400",  seats: 416, family: "B747", bodyType: .widebody4Engine, weight: 6, mlwLbs: 652700,  costPerHour: 26000, purchasePrice: 130_000_000, expectedLifespanCycles: 20000),
        .init(id: "A380",    name: "Airbus A380",   seats: 555, family: "A380", bodyType: .widebody4Engine, weight: 2, mlwLbs: 1133000, costPerHour: 28000, purchasePrice: 342_000_000, expectedLifespanCycles: 19000),
        .init(id: "A340",    name: "Airbus A340-300", seats: 295, family: "A340", bodyType: .widebody4Engine, weight: 1, mlwLbs: 380000, costPerHour: 18000, purchasePrice: 183_000_000, expectedLifespanCycles: 20000),
        // Regional jets — real type-rating splits (E170/E175 vs E190/E195)
        .init(id: "E170",    name: "Embraer E170",   seats: 72,  family: "E170_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 72500,  costPerHour: 2800, purchasePrice: 38_000_000, expectedLifespanCycles: 60000),
        .init(id: "E175",    name: "Embraer E175",   seats: 78,  family: "E170_FAMILY", bodyType: .regionalJet, weight: 8, mlwLbs: 79400,  costPerHour: 3200, purchasePrice: 42_000_000, expectedLifespanCycles: 60000),
        .init(id: "E190",    name: "Embraer E190",   seats: 106, family: "E190_FAMILY", bodyType: .regionalJet, weight: 6, mlwLbs: 99200,  costPerHour: 3800, purchasePrice: 47_000_000, expectedLifespanCycles: 60000),
        .init(id: "E195",    name: "Embraer E195",   seats: 118, family: "E190_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 107800, costPerHour: 4200, purchasePrice: 49_000_000, expectedLifespanCycles: 60000),
        .init(id: "CRJ900",  name: "Bombardier CRJ900",  seats: 82,  family: "CRJ_FAMILY", bodyType: .regionalJet, weight: 6, mlwLbs: 74950, costPerHour: 3200, purchasePrice: 36_000_000, expectedLifespanCycles: 60000),
        .init(id: "CRJ1000", name: "Bombardier CRJ1000", seats: 100, family: "CRJ_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 80470, costPerHour: 3600, purchasePrice: 42_000_000, expectedLifespanCycles: 60000),
        .init(id: "ERJ135",  name: "Embraer ERJ135", seats: 37, family: "ERJ_FAMILY", bodyType: .regionalJet, weight: 1, mlwLbs: 39900, costPerHour: 2000, purchasePrice: 14_000_000, expectedLifespanCycles: 50000),
        .init(id: "ERJ140",  name: "Embraer ERJ140", seats: 44, family: "ERJ_FAMILY", bodyType: .regionalJet, weight: 1, mlwLbs: 42550, costPerHour: 2100, purchasePrice: 15_000_000, expectedLifespanCycles: 50000),
        .init(id: "ERJ145",  name: "Embraer ERJ145", seats: 50, family: "ERJ_FAMILY", bodyType: .regionalJet, weight: 2, mlwLbs: 43430, costPerHour: 2200, purchasePrice: 20_000_000, expectedLifespanCycles: 50000),
        // COMAC ARJ21 removed per designer direction (illustration unavailable;
        // few carriers fly it, none in the US-market roster).
        // Turboprop tier (designer added Figma side-view art). Short-field
        // capable; unlocks small regional/island airports jets can't use.
        .init(id: "B1900", name: "Beechcraft 1900D", seats: 19, family: "B1900_FAMILY", bodyType: .turboprop, weight: 6, mlwLbs: 16765, costPerHour: 1600, purchasePrice: 2_500_000,  expectedLifespanCycles: 30000),
        .init(id: "AT46",  name: "ATR 42-600",       seats: 48, family: "ATR42_FAMILY", bodyType: .turboprop, weight: 10, mlwLbs: 40345, costPerHour: 2000, purchasePrice: 18_000_000, expectedLifespanCycles: 70000),
        .init(id: "D328",  name: "Dornier 328-110",  seats: 33, family: "D328_FAMILY",  bodyType: .turboprop, weight: 3, mlwLbs: 30401, costPerHour: 1800, purchasePrice: 4_000_000,  expectedLifespanCycles: 35000),
        .init(id: "DH8B",  name: "De Havilland Dash 8-200", seats: 39, family: "DASH8_FAMILY", bodyType: .turboprop, weight: 5, mlwLbs: 33900, costPerHour: 1900, purchasePrice: 4_500_000, expectedLifespanCycles: 40000, minRunwayFtOverride: 2000),
    ]

    static let weightTotal: Int = all.reduce(0) { $0 + $1.weight }

    /// Lookup by id (for resolving an airline's `types` strings to real types).
    static let byId: [String: AircraftType] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let crewFamilies: [String] = {
        var seen = Set<String>()
        return all.compactMap { seen.insert($0.family).inserted ? $0.family : nil }
    }()

    static func pickWeighted() -> AircraftType {
        var r = Int.random(in: 0..<max(1, weightTotal))
        for t in all {
            r -= t.weight
            if r < 0 { return t }
        }
        return all[all.count - 1]
    }
}
