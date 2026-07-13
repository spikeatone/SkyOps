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

    // MARK: - Regional rosters (background traffic by geography)

    /// The five geographic regions a flight can touch. A leg draws carriers from
    /// its endpoints' regions, so a Mexican domestic leg shows Mexican carriers,
    /// a Brazilian one South American carriers, etc. — not a lumped LatAm pool.
    enum Region { case us, canada, mexico, centralAmerica, southAmerica }

    /// Real Canadian carriers. Per-type eligibility researched per carrier,
    /// limited to the game's types. Air Canada also appears in the US roster
    /// (transborder widebody); that overlap is intentional.
    static let canadaRoster: [Airline] = [
        .init(name: "Air Canada",      code: "AC", weight: 20, types: ["A220300","A319","A320","A321","MAX8","MAX9","B788","B789","A339","B773"]),
        .init(name: "WestJet",         code: "WS", weight: 15, types: ["B737700","B737800","MAX8","B789"]),
        .init(name: "Jazz",            code: "QK", weight: 8,  types: ["CRJ900","E175"]),
        .init(name: "Porter Airlines", code: "PD", weight: 7,  types: ["E195"]),
        .init(name: "Air Transat",     code: "TS", weight: 5,  types: ["A321NEO","A339"]),
        .init(name: "Flair Airlines",  code: "F8", weight: 4,  types: ["B737800","MAX8"]),
    ]

    /// Real Mexican carriers.
    static let mexicoRoster: [Airline] = [
        .init(name: "Aeroméxico",   code: "AM", weight: 12, types: ["B737800","MAX8","MAX9","B788","B789","E190"]),
        .init(name: "Volaris",      code: "Y4", weight: 12, types: ["A319","A320","A321","A320NEO","A321NEO"]),
        .init(name: "Viva Aerobus", code: "VB", weight: 9,  types: ["A320","A321","A320NEO","A321NEO"]),
    ]

    /// Real Central American carriers (Copa Panama hub, Avianca's regional feed).
    static let centralAmericaRoster: [Airline] = [
        .init(name: "Copa Airlines", code: "CM", weight: 12, types: ["B737700","B737800","MAX8","MAX9"]),
        .init(name: "Avianca",       code: "AV", weight: 8,  types: ["A319","A320","A321","A320NEO","A321NEO","B788"]),
        .init(name: "Volaris",       code: "Y4", weight: 6,  types: ["A319","A320","A321","A320NEO","A321NEO"]),
    ]

    /// Real South American carriers.
    static let southAmericaRoster: [Airline] = [
        .init(name: "LATAM Airlines",        code: "LA", weight: 20, types: ["A319","A320","A321","A321NEO","B788","B789","B773"]),
        .init(name: "GOL Linhas Aéreas",     code: "G3", weight: 11, types: ["B737700","B737800","MAX8"]),
        .init(name: "Azul",                  code: "AD", weight: 10, types: ["A320NEO","A321NEO","E195","A339"]),
        .init(name: "Avianca",               code: "AV", weight: 9,  types: ["A319","A320","A321","A320NEO","A321NEO","B788"]),
        .init(name: "Aerolíneas Argentinas", code: "AR", weight: 6,  types: ["B737700","B737800","MAX8","A339"]),
        .init(name: "SKY Airline",           code: "H2", weight: 4,  types: ["A320NEO","A321NEO"]),
        .init(name: "JetSMART",              code: "JA", weight: 4,  types: ["A320","A320NEO","A321NEO"]),
    ]

    // Airport-code → region membership (US is the default / everything else).
    static let canadaCodes: Set<String> = [
        "YYZ","YVR","YUL","YYC","YEG","YOW","YWG","YHZ","YTZ","YLW","YYJ","YYT","YXE","YQR","YQM","YSJ","YQG","YFC","YQT","YMM",
    ]
    static let mexicoCodes: Set<String> = [
        "MEX","CUN","GDL","TIJ","MTY","SJD","PVR","NLU","MID","BJX","CUL","VER","HMO","OAX","MZT","CZM",
    ]
    static let centralAmericaCodes: Set<String> = [
        "PTY","SJO","SAL","GUA","LIR","SAP","MGA","BZE","XPL","RTB",
    ]
    static let southAmericaCodes: Set<String> = [
        "BOG","GRU","SCL","LIM","CGH","AEP","GIG","VCP","MDE","BSB","EZE","UIO","SDU","CLO","CNF","CTG","POA","REC","SSA","GYE",
    ]

    static func region(_ code: String) -> Region {
        if canadaCodes.contains(code) { return .canada }
        if mexicoCodes.contains(code) { return .mexico }
        if centralAmericaCodes.contains(code) { return .centralAmerica }
        if southAmericaCodes.contains(code) { return .southAmerica }
        return .us
    }
    static func roster(for r: Region) -> [Airline] {
        switch r {
        case .us:             return roster
        case .canada:         return canadaRoster
        case .mexico:         return mexicoRoster
        case .centralAmerica: return centralAmericaRoster
        case .southAmerica:   return southAmericaRoster
        }
    }

    /// Region-aware weighted pick among carriers that actually fly `typeId`.
    /// A same-region leg draws that region's roster; a cross-region leg draws
    /// both. Every type resolves (Independent Operator fallback).
    static func pick(forType typeId: String, origin: Region, dest: Region) -> Airline {
        let pool = origin == dest ? roster(for: origin) : roster(for: origin) + roster(for: dest)
        let eligible = pool.filter { $0.types.contains(typeId) }
        guard !eligible.isEmpty else { return fallback }
        var r = Int.random(in: 0..<max(1, eligible.reduce(0) { $0 + $1.weight }))
        for a in eligible {
            r -= a.weight
            if r < 0 { return a }
        }
        return eligible.last!
    }

    /// US-region convenience (unchanged behaviour for existing callers/tests).
    static func pick(forType typeId: String) -> Airline {
        pick(forType: typeId, origin: .us, dest: .us)
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
        // Latin American carriers (added with the LatAm airport expansion; the
        // majors AM/CM/LA/AV/AR are already listed above)
        "AD": "Azul", "VB": "Viva Aerobus", "JA": "JetSMART",
        // Canadian carriers (WS/AC already listed above)
        "TS": "Air Transat", "PD": "Porter Airlines", "QK": "Jazz",
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
