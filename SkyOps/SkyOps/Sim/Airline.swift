//
//  Airline.swift
//  SkyOps — Phase 5 (competitor airline identity)
//
//  Real US-market-share-weighted competitor airlines painted on background
//  (non-owned) traffic, so the airspace reads as real, busy airspace around
//  the player's own airline. Ported from AIRLINE_ROSTER. Eligibility is by
//  SPECIFIC aircraft type, individually researched (not by size category) —
//  e.g. Delta flies zero Boeing widebodies, Southwest only 737-700/800/MAX8,
//  Lufthansa is the world's largest A340 operator. Weights are real 2025-26 US
//  domestic capacity share for the Big Four + Alaska; the remainder is a
//  designed split. Hardcoded to the US market (matches the US-only airport
//  network) — would need to become region-aware for other regions.
//

import Foundation

struct Airline {
    let name: String
    let weight: Int
    /// AircraftType ids this airline actually operates in this game.
    let types: Set<String>

    static let roster: [Airline] = [
        .init(name: "American Airlines", weight: 21, types: ["A319","A320","A321","A321NEO","B737800","MAX8","B773","B788"]),
        .init(name: "Delta Air Lines",   weight: 19, types: ["A319","A320","A321","A321NEO","B737800","B739","A220300","A220100","A339","A359"]),
        .init(name: "Southwest Airlines", weight: 18, types: ["B737700","B737800","MAX8"]),
        .init(name: "United Airlines",   weight: 17, types: ["A319","A320","A321NEO","B737700","B737800","B739","MAX8","MAX9","B773","B788","B78J"]),
        .init(name: "Alaska Airlines",   weight: 6,  types: ["B737700","B737800","B739","MAX8","MAX9","B788","E175"]),
        .init(name: "JetBlue Airways",   weight: 5,  types: ["A320","A321","A321NEO","A220300"]),
        .init(name: "Spirit Airlines",   weight: 3,  types: ["A319","A320","A320NEO","A321","A321NEO"]),
        .init(name: "Frontier Airlines", weight: 3,  types: ["A319","A320","A320NEO","A321","A321NEO"]),
        .init(name: "Allegiant Air",     weight: 2,  types: ["A319","A320","MAX8"]),
        // Regional-brand liveries (American Eagle / Delta Connection / United Express)
        .init(name: "SkyWest Airlines",  weight: 4, types: ["CRJ900","CRJ1000","E170","E175","ERJ145"]),
        .init(name: "Republic Airways",  weight: 3, types: ["E170","E175"]),
        .init(name: "Envoy Air",         weight: 3, types: ["CRJ900","CRJ1000","E170","E175"]),
        .init(name: "Endeavor Air",      weight: 3, types: ["CRJ900","CRJ1000"]),
        .init(name: "Horizon Air",       weight: 2, types: ["E175"]),
        .init(name: "PSA Airlines",      weight: 2, types: ["CRJ900","CRJ1000","E175"]),
        // International — widebody only, deliberately rare
        .init(name: "Air France",        weight: 1, types: ["B773","B788","A339","A359"]),
        .init(name: "Lufthansa",         weight: 1, types: ["B788","B747","A380","A340","A359"]),
        .init(name: "British Airways",   weight: 1, types: ["B773","B788","B78J","A380","A359"]),
        .init(name: "Emirates",          weight: 1, types: ["B773","A380"]),
        .init(name: "Air Canada",        weight: 1, types: ["B773","B788","A339"]),
        .init(name: "Japan Airlines",    weight: 1, types: ["B773","B788","A359"]),
        // Fallback for real-world orphaned types (rare variants / China-only / retired-from-US-feed)
        .init(name: "Independent Operator", weight: 1, types: ["A319NEO","E190","E195","ERJ135","ERJ140","ARJ21"]),
    ]

    /// Weighted pick among airlines that actually fly `typeId`. Every type in
    /// AIRCRAFT_TYPES resolves to at least one eligible entry (the fallback
    /// covers the orphans), so this never returns nil.
    static func pick(forType typeId: String) -> String {
        let eligible = roster.filter { $0.types.contains(typeId) }
        guard !eligible.isEmpty else { return "Independent Operator" }
        var r = Int.random(in: 0..<max(1, eligible.reduce(0) { $0 + $1.weight }))
        for a in eligible {
            r -= a.weight
            if r < 0 { return a.name }
        }
        return eligible.last!.name
    }
}
