//
//  AircraftType.swift
//  SkyOps — Phase 2
//
//  The fleet catalogue, ported from AIRCRAFT_TYPES in the prototype. 30 real
//  named variants across 15 crew-type-rating families. Per CLAUDE.md: each
//  real variant is its own entry (real specs), while `family` follows the
//  coarser real type-rating groupings (e.g. all six A320-family variants share
//  one crew family; E170/E175 split from E190/E195). Spawn `weight` is
//  real-world-proportional (sourced in-service fleet counts for the mainline
//  families; estimated for the regional tier — see CLAUDE.md Fleet section).
//
//  This is a big table but it is DATA, not logic — ported verbatim so the
//  numbers stay real. Don't re-round "for cleanliness."
//

import Foundation

/// Drives three independent things (per CLAUDE.md): gate-fee tier, render
/// scale, and which icon tier the aircraft uses. Changing what a case means
/// has consequences in all three places.
enum BodyType: String {
    case regionalJet
    case narrowbody
    case widebody2Engine
    case widebody4Engine

    /// On-map render length in points. Values are the prototype's per-tier
    /// `targetLength`s (already +15% per designer feedback), preserving the
    /// real size hierarchy: RJ < narrowbody < 2-engine widebody < 4-engine.
    var iconLength: CGFloat {
        switch self {
        case .regionalJet:     return 9.9
        case .narrowbody:      return 12.5
        case .widebody2Engine: return 17.1
        case .widebody4Engine: return 19.9
        }
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
    let purchasePrice: Int
    let expectedLifespanCycles: Int

    /// Full fleet catalogue — ported verbatim from AIRCRAFT_TYPES.
    static let all: [AircraftType] = [
        // A320 family (ceo + neo) — one crew family
        .init(id: "A319",    name: "Airbus A319",       seats: 140, family: "A320_FAMILY", bodyType: .narrowbody, weight: 19, mlwLbs: 134480, purchasePrice: 67_000_000, expectedLifespanCycles: 48000),
        .init(id: "A320",    name: "Airbus A320",       seats: 165, family: "A320_FAMILY", bodyType: .narrowbody, weight: 56, mlwLbs: 142200, purchasePrice: 74_000_000, expectedLifespanCycles: 48000),
        .init(id: "A321",    name: "Airbus A321",       seats: 200, family: "A320_FAMILY", bodyType: .narrowbody, weight: 29, mlwLbs: 171520, purchasePrice: 86_000_000, expectedLifespanCycles: 48000),
        .init(id: "A319NEO", name: "Airbus A319neo",    seats: 145, family: "A320_FAMILY", bodyType: .narrowbody, weight: 2,  mlwLbs: 137790, purchasePrice: 74_000_000, expectedLifespanCycles: 48000),
        .init(id: "A320NEO", name: "Airbus A320neo",    seats: 168, family: "A320_FAMILY", bodyType: .narrowbody, weight: 24, mlwLbs: 146170, purchasePrice: 81_000_000, expectedLifespanCycles: 48000),
        .init(id: "A321NEO", name: "Airbus A321neo",    seats: 200, family: "A320_FAMILY", bodyType: .narrowbody, weight: 30, mlwLbs: 179000, purchasePrice: 94_000_000, expectedLifespanCycles: 48000),
        // 737 family (NG + MAX) — one crew family
        .init(id: "B737700", name: "Boeing 737-700",    seats: 140, family: "B737_FAMILY", bodyType: .narrowbody, weight: 9,  mlwLbs: 128000, purchasePrice: 59_000_000, expectedLifespanCycles: 75000),
        .init(id: "B737800", name: "Boeing 737-800",    seats: 175, family: "B737_FAMILY", bodyType: .narrowbody, weight: 37, mlwLbs: 146300, purchasePrice: 70_000_000, expectedLifespanCycles: 75000),
        .init(id: "B739",    name: "Boeing 737-900",    seats: 180, family: "B737_FAMILY", bodyType: .narrowbody, weight: 15, mlwLbs: 146300, purchasePrice: 74_000_000, expectedLifespanCycles: 75000),
        .init(id: "MAX8",    name: "Boeing 737 MAX 8",  seats: 175, family: "B737_FAMILY", bodyType: .narrowbody, weight: 30, mlwLbs: 146300, purchasePrice: 86_000_000, expectedLifespanCycles: 75000),
        .init(id: "MAX9",    name: "Boeing 737 MAX 9",  seats: 190, family: "B737_FAMILY", bodyType: .narrowbody, weight: 10, mlwLbs: 152800, purchasePrice: 94_000_000, expectedLifespanCycles: 75000),
        // A220 family — one crew family (A220-300 narrowbody, A220-100 RJ per designer)
        .init(id: "A220300", name: "Airbus A220-300",   seats: 140, family: "A220_FAMILY", bodyType: .narrowbody,  weight: 4, mlwLbs: 137300, purchasePrice: 67_000_000, expectedLifespanCycles: 60000),
        .init(id: "A220100", name: "Airbus A220-100",   seats: 115, family: "A220_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 122300, purchasePrice: 59_000_000, expectedLifespanCycles: 60000),
        // Twin-engine widebodies — each its own crew family
        .init(id: "B773",    name: "Boeing 777-300",       seats: 380, family: "B777", bodyType: .widebody2Engine, weight: 23, mlwLbs: 460000, purchasePrice: 289_000_000, expectedLifespanCycles: 44000),
        .init(id: "B788",    name: "Boeing 787 Dreamliner", seats: 280, family: "B787", bodyType: .widebody2Engine, weight: 14, mlwLbs: 380000, purchasePrice: 225_000_000, expectedLifespanCycles: 44000),
        .init(id: "A339",    name: "Airbus A330-900",      seats: 300, family: "A330", bodyType: .widebody2Engine, weight: 10, mlwLbs: 421082, purchasePrice: 230_000_000, expectedLifespanCycles: 44000),
        .init(id: "A359",    name: "Airbus A350-900",      seats: 306, family: "A350", bodyType: .widebody2Engine, weight: 8,  mlwLbs: 456357, purchasePrice: 300_000_000, expectedLifespanCycles: 44000),
        // Four-engine widebodies — each its own crew family
        .init(id: "B747",    name: "Boeing 747-8",  seats: 467, family: "B747", bodyType: .widebody4Engine, weight: 6, mlwLbs: 745700,  purchasePrice: 322_000_000, expectedLifespanCycles: 35000),
        .init(id: "A380",    name: "Airbus A380",   seats: 555, family: "A380", bodyType: .widebody4Engine, weight: 2, mlwLbs: 1133000, purchasePrice: 342_000_000, expectedLifespanCycles: 19000),
        .init(id: "A340",    name: "Airbus A340-300", seats: 295, family: "A340", bodyType: .widebody4Engine, weight: 1, mlwLbs: 380000, purchasePrice: 183_000_000, expectedLifespanCycles: 20000),
        // Regional jets — real type-rating splits (E170/E175 vs E190/E195)
        .init(id: "E170",    name: "Embraer E170",   seats: 72,  family: "E170_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 72500,  purchasePrice: 38_000_000, expectedLifespanCycles: 60000),
        .init(id: "E175",    name: "Embraer E175",   seats: 78,  family: "E170_FAMILY", bodyType: .regionalJet, weight: 8, mlwLbs: 79400,  purchasePrice: 42_000_000, expectedLifespanCycles: 60000),
        .init(id: "E190",    name: "Embraer E190",   seats: 106, family: "E190_FAMILY", bodyType: .regionalJet, weight: 6, mlwLbs: 99200,  purchasePrice: 47_000_000, expectedLifespanCycles: 60000),
        .init(id: "E195",    name: "Embraer E195",   seats: 118, family: "E190_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 107800, purchasePrice: 49_000_000, expectedLifespanCycles: 60000),
        .init(id: "CRJ900",  name: "Bombardier CRJ900",  seats: 82,  family: "CRJ_FAMILY", bodyType: .regionalJet, weight: 6, mlwLbs: 74950, purchasePrice: 36_000_000, expectedLifespanCycles: 60000),
        .init(id: "CRJ1000", name: "Bombardier CRJ1000", seats: 100, family: "CRJ_FAMILY", bodyType: .regionalJet, weight: 3, mlwLbs: 80470, purchasePrice: 42_000_000, expectedLifespanCycles: 60000),
        .init(id: "ERJ135",  name: "Embraer ERJ135", seats: 37, family: "ERJ_FAMILY", bodyType: .regionalJet, weight: 1, mlwLbs: 39900, purchasePrice: 14_000_000, expectedLifespanCycles: 50000),
        .init(id: "ERJ140",  name: "Embraer ERJ140", seats: 44, family: "ERJ_FAMILY", bodyType: .regionalJet, weight: 1, mlwLbs: 42550, purchasePrice: 15_000_000, expectedLifespanCycles: 50000),
        .init(id: "ERJ145",  name: "Embraer ERJ145", seats: 50, family: "ERJ_FAMILY", bodyType: .regionalJet, weight: 2, mlwLbs: 43430, purchasePrice: 20_000_000, expectedLifespanCycles: 50000),
        .init(id: "ARJ21",   name: "COMAC ARJ21",    seats: 90, family: "ARJ21_FAMILY", bodyType: .regionalJet, weight: 2, mlwLbs: 88000, purchasePrice: 34_000_000, expectedLifespanCycles: 60000),
    ]

    /// Sum of all spawn weights — computed, never hand-maintained (the
    /// prototype's `TYPE_WEIGHT_TOTAL` comment went stale; the value never did).
    static let weightTotal: Int = all.reduce(0) { $0 + $1.weight }

    /// Distinct crew families, derived from the type list (matches the
    /// prototype's auto-derived CREW_FAMILIES — 15 families).
    static let crewFamilies: [String] = {
        var seen = Set<String>()
        return all.compactMap { seen.insert($0.family).inserted ? $0.family : nil }
    }()

    /// Weighted random pick, real-world-proportional. Ported from pickAircraftType().
    static func pickWeighted() -> AircraftType {
        var r = Int.random(in: 0..<max(1, weightTotal))
        for t in all {
            r -= t.weight
            if r < 0 { return t }
        }
        return all[all.count - 1]
    }
}
