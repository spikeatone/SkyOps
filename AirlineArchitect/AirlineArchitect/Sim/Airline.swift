//
//  Airline.swift
//  Airline Architect — Phase 5 (competitor airline identity)
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
    /// Real IATA airline designator — used for this carrier's aircraft tails
    /// (e.g. "N123DL" for Delta). Empty for the generic fallback (random tail).
    let code: String
    let weight: Int
    /// AircraftType ids this airline actually operates in this game.
    let types: Set<String>

    static let roster: [Airline] = [
        .init(name: "American Airlines", code: "AA", weight: 21, types: ["A319","A320","A321","A321NEO","B737800","MAX8","B773","B788","B789"]),
        .init(name: "Delta Air Lines",   code: "DL", weight: 19, types: ["A319","A320","A321","A321NEO","B737800","B739","A220300","A220100","A339","A359"]),
        .init(name: "Southwest Airlines", code: "WN", weight: 18, types: ["B737700","B737800","MAX8"]),
        .init(name: "United Airlines",   code: "UA", weight: 17, types: ["A319","A320","A321NEO","B737700","B737800","B739","MAX8","MAX9","B773","B788","B789","B78J"]),
        .init(name: "Alaska Airlines",   code: "AS", weight: 6,  types: ["B737700","B737800","B739","MAX8","MAX9","B789","E175"]),
        .init(name: "JetBlue Airways",   code: "B6", weight: 5,  types: ["A320","A321","A321NEO","A220300"]),
        .init(name: "Spirit Airlines",   code: "NK", weight: 3,  types: ["A319","A320","A320NEO","A321","A321NEO"]),
        .init(name: "Frontier Airlines", code: "F9", weight: 3,  types: ["A319","A320","A320NEO","A321","A321NEO"]),
        .init(name: "Allegiant Air",     code: "G4", weight: 2,  types: ["A319","A320","MAX8"]),
        // Regional-brand liveries (American Eagle / Delta Connection / United Express)
        .init(name: "SkyWest Airlines",  code: "OO", weight: 4, types: ["CRJ900","CRJ1000","E170","E175","ERJ145"]),
        .init(name: "Republic Airways",  code: "YX", weight: 3, types: ["E170","E175"]),
        .init(name: "Envoy Air",         code: "MQ", weight: 3, types: ["CRJ900","CRJ1000","E170","E175"]),
        .init(name: "Endeavor Air",      code: "9E", weight: 3, types: ["CRJ900","CRJ1000"]),
        .init(name: "Horizon Air",       code: "QX", weight: 2, types: ["E175"]),
        .init(name: "PSA Airlines",      code: "OH", weight: 2, types: ["CRJ900","CRJ1000","E175"]),
        // International — widebody only, deliberately rare
        .init(name: "Air France",        code: "AF", weight: 1, types: ["B773","B789","A339","A359"]),
        .init(name: "Lufthansa",         code: "LH", weight: 1, types: ["B789","B747","A380","A340","A359"]),
        .init(name: "British Airways",   code: "BA", weight: 1, types: ["B773","B788","B789","B78J","A380","A359"]),
        .init(name: "Emirates",          code: "EK", weight: 1, types: ["B773","A380"]),
        .init(name: "Air Canada",        code: "AC", weight: 1, types: ["B773","B788","B789","A339"]),
        .init(name: "Japan Airlines",    code: "JL", weight: 1, types: ["B773","B788","B789","A359"]),
        // Fallback for real-world orphaned types (rare variants / China-only / retired-from-US-feed)
        .init(name: "Independent Operator", code: "", weight: 1, types: ["A319NEO","E190","E195","ERJ135","ERJ140"]),
    ]

    /// Weighted pick among airlines that actually fly `typeId`. Every type in
    /// AIRCRAFT_TYPES resolves to at least one eligible entry (the fallback
    /// covers the orphans), so this never returns nil.
    static func pick(forType typeId: String) -> Airline {
        let eligible = roster.filter { $0.types.contains(typeId) }
        guard !eligible.isEmpty else { return fallback }
        var r = Int.random(in: 0..<max(1, eligible.reduce(0) { $0 + $1.weight }))
        for a in eligible {
            r -= a.weight
            if r < 0 { return a }
        }
        return eligible.last!
    }

    static let fallback = roster.last!   // Independent Operator

    // MARK: - Real-world designator collision guard (for player tail-code entry)

    /// Real 2-letter IATA airline codes the player must NOT be able to claim as
    /// their fleet's tail code — the roster's own carriers plus a broad set of
    /// well-known world airlines. Keyed by code → display name so the naming
    /// screen can say exactly whose code it is ("UA is used by United"). Only
    /// all-letter codes matter here (the player types letters only).
    static let realCodes: [String: String] = [
        // Roster carriers (US + international) — the ones the game actually paints
        "AA": "American Airlines", "DL": "Delta Air Lines", "WN": "Southwest Airlines",
        "UA": "United Airlines", "AS": "Alaska Airlines", "NK": "Spirit Airlines",
        "OO": "SkyWest Airlines", "YX": "Republic Airways", "MQ": "Envoy Air",
        "QX": "Horizon Air", "OH": "PSA Airlines", "AF": "Air France",
        "LH": "Lufthansa", "BA": "British Airways", "EK": "Emirates",
        "AC": "Air Canada", "JL": "Japan Airlines",
        // Other major world carriers (2-letter, all-alpha)
        "HA": "Hawaiian Airlines", "SK": "SAS", "QF": "Qantas", "SQ": "Singapore Airlines",
        "CX": "Cathay Pacific", "EY": "Etihad Airways", "QR": "Qatar Airways",
        "TK": "Turkish Airlines", "KL": "KLM", "IB": "Iberia", "VS": "Virgin Atlantic",
        "NH": "ANA", "KE": "Korean Air", "OZ": "Asiana Airlines", "CA": "Air China",
        "MU": "China Eastern", "CZ": "China Southern", "EI": "Aer Lingus",
        "LX": "Swiss", "OS": "Austrian Airlines", "SN": "Brussels Airlines",
        "AY": "Finnair", "TP": "TAP Air Portugal", "SU": "Aeroflot", "ET": "Ethiopian Airlines",
        "SA": "South African Airways", "NZ": "Air New Zealand", "VA": "Virgin Australia",
        "JQ": "Jetstar", "AI": "Air India", "GA": "Garuda Indonesia", "MH": "Malaysia Airlines",
        "TG": "Thai Airways", "VN": "Vietnam Airlines", "PR": "Philippine Airlines",
        "BR": "EVA Air", "CI": "China Airlines", "AM": "Aeroméxico", "CM": "Copa Airlines",
        "LA": "LATAM", "AV": "Avianca", "AR": "Aerolíneas Argentinas", "WS": "WestJet",
        "DY": "Norwegian", "FI": "Icelandair", "LO": "LOT Polish Airlines", "OK": "Czech Airlines",
        "MS": "EgyptAir", "RJ": "Royal Jordanian", "GF": "Gulf Air", "WY": "Oman Air",
        "SV": "Saudia", "UL": "SriLankan Airlines", "PK": "Pakistan International", "UK": "Vistara",
    ]

    /// A random 2-uppercase-letter code that isn't a real airline code — used
    /// for the fallback carrier's tails so they aren't all identical.
    static func randomTailCode() -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        while true {
            let c = "\(letters.randomElement()!)\(letters.randomElement()!)"
            if realCodes[c] == nil { return c }
        }
    }
}
