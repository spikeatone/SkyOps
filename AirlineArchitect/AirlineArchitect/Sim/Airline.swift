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
        // Fallback for real-world orphaned types (rare variants / China-only / retired-from-US-feed)
        .init(name: "Independent Operator", code: "", weight: 1, types: ["A319NEO","E190","E195","ERJ135","ERJ140"]),
    ]

    /// Overseas carriers whose home airports aren't on the map. Painted ONLY on
    /// routes between two US international gateways (see `pick`) — a stand-in for
    /// the long-haul widebody traffic that really concentrates at those airports,
    /// so they never show up on random US-domestic legs. Air Canada is NOT here:
    /// it has a real in-network home (canadaRoster) and is placed by the region
    /// rule like every other regional carrier.
    ///
    // The old US-gateway `internationalRoster` hack is GONE. Every major overseas
    // carrier now has a real home on the map: Emirates/Qatar/etc. live in
    // `middleEastRoster`, Japan Airlines/ANA/etc. in `asiaRoster`, the European
    // carriers in `europeRoster`. Transatlantic/transpacific traffic is handled
    // by the real cross-region pick in `pick(forType:originCode:destCode:)`, so a
    // US↔DXB leg naturally mixes US + Middle East carriers with no special-casing.
    // (Oceania is the only populated continent still without on-map airports.)

    // MARK: - Regional rosters (background traffic by geography)

    /// The five geographic regions a flight can touch. A leg draws carriers from
    /// its endpoints' regions, so a Mexican domestic leg shows Mexican carriers,
    /// a Brazilian one South American carriers, etc. — not a lumped LatAm pool.
    enum Region { case us, canada, mexico, centralAmerica, southAmerica, europe, africa, asia, middleEast, oceania }

    /// The PLAYER-facing start-region choice (designer's list of seven), mapped
    /// onto the finer internal carrier regions above. Chosen on the naming
    /// screen; drives the starting map framing and the home-scoped pools
    /// (spare bases, route opportunities, airport recruitment offers).
    enum PlayerRegion: String, Codable, CaseIterable {
        case africa, asia, oceania, centralAmerica, europe, northAmerica, southAmerica

        /// Display label, in the designer's wording.
        var label: String {
            switch self {
            case .africa:         return "Africa"
            case .asia:           return "Asia"
            case .oceania:        return "Australia / New Zealand"
            case .centralAmerica: return "Central America"
            case .europe:         return "Europe"
            case .northAmerica:   return "North America"
            case .southAmerica:   return "South America"
            }
        }

        /// The internal carrier regions this start choice spans. North America
        /// folds US+Canada+Mexico; Asia folds in the Middle East (not offered
        /// as its own start); Oceania covers the whole South Pacific.
        var gameRegions: [Region] {
            switch self {
            case .africa:         return [.africa]
            case .asia:           return [.asia, .middleEast]
            case .oceania:        return [.oceania]
            case .centralAmerica: return [.centralAmerica]
            case .europe:         return [.europe]
            case .northAmerica:   return [.us, .canada, .mexico]
            case .southAmerica:   return [.southAmerica]
            }
        }
    }

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

    /// Real European carriers, per-type eligibility researched per carrier (limited
    /// to the game's types). Weights approximate European seat-share (Ryanair/
    /// easyJet/Lufthansa group/IAG on top). Transatlantic legs additionally draw
    /// US widebody carriers via the cross-region pick — real US carriers DO fly
    /// into Europe. Regional-brand liveries (CityLine/Cityhopper/Air Nostrum)
    /// cover the E-Jet/CRJ feed so European regional legs aren't all "Independent".
    static let europeRoster: [Airline] = [
        .init(name: "Ryanair",           code: "FR", weight: 20, types: ["B737800","MAX8"]),
        .init(name: "easyJet",           code: "U2", weight: 14, types: ["A319","A320","A320NEO","A321NEO"]),
        .init(name: "Lufthansa",         code: "LH", weight: 11, types: ["A319","A320","A320NEO","A321","A321NEO","A340","A359","B747","B789"]),
        .init(name: "Turkish Airlines",  code: "TK", weight: 11, types: ["A319","A320","A320NEO","A321","A321NEO","B737800","MAX8","MAX9","B773","B789","A339","A359"]),
        .init(name: "British Airways",   code: "BA", weight: 10, types: ["A319","A320","A320NEO","A321","A321NEO","B773","B788","B789","B78J","A359"]),
        .init(name: "Air France",        code: "AF", weight: 9,  types: ["A220300","A319","A320","A321","A339","A359","B773","B789"]),
        .init(name: "Wizz Air",          code: "W6", weight: 8,  types: ["A320","A320NEO","A321NEO"]),
        .init(name: "KLM",               code: "KL", weight: 7,  types: ["B737700","B737800","B739","A321NEO","B773","B789","B78J","A339"]),
        .init(name: "Pegasus Airlines",  code: "PC", weight: 6,  types: ["B737800","A320NEO","A321NEO"]),
        .init(name: "Aeroflot",          code: "SU", weight: 6,  types: ["A319","A320","A320NEO","A321","B737800","B773","A339"]),
        .init(name: "Iberia",            code: "IB", weight: 6,  types: ["A319","A320","A320NEO","A321","A321NEO","A339","A359"]),
        .init(name: "Vueling",           code: "VY", weight: 6,  types: ["A319","A320","A321"]),
        .init(name: "SAS",               code: "SK", weight: 5,  types: ["A319","A320","A320NEO","A321NEO","A339","A359"]),
        .init(name: "TAP Air Portugal",  code: "TP", weight: 5,  types: ["A319","A320","A320NEO","A321","A321NEO","A339"]),
        .init(name: "Norwegian",         code: "DY", weight: 5,  types: ["B737800","MAX8"]),
        .init(name: "ITA Airways",       code: "AZ", weight: 4,  types: ["A319","A320","A320NEO","A321NEO","A339","A359"]),
        .init(name: "Swiss",             code: "LX", weight: 4,  types: ["A319","A320","A320NEO","A321","A340","B773","A339"]),
        .init(name: "Aer Lingus",        code: "EI", weight: 4,  types: ["A320","A321NEO","A339"]),
        .init(name: "Finnair",           code: "AY", weight: 4,  types: ["A319","A320","A321","A339","A359"]),
        .init(name: "Aegean Airlines",   code: "A3", weight: 4,  types: ["A319","A320","A320NEO","A321NEO"]),
        .init(name: "Austrian Airlines", code: "OS", weight: 3,  types: ["A319","A320","A320NEO","A321","B773","B789"]),
        .init(name: "airBaltic",         code: "BT", weight: 3,  types: ["A220300"]),
        // Central & Eastern Europe (Warsaw/Budapest/Bucharest/Belgrade/Kyiv/Minsk
        // hubs). Wizz Air (above) already covers the CEE low-cost A320/A321 feed.
        .init(name: "LOT Polish Airlines", code: "LO", weight: 5, types: ["B737800","MAX8","B788","B789","E170","E175","E190","E195"]),
        .init(name: "TAROM",             code: "RO", weight: 3,  types: ["B737800","A319","A320"]),
        .init(name: "Air Serbia",        code: "JU", weight: 3,  types: ["A319","A320","A321","A339"]),
        .init(name: "Ukraine Int'l",     code: "PS", weight: 3,  types: ["B737800","B739"]),
        .init(name: "Belavia",           code: "B2", weight: 3,  types: ["B737800","E195"]),
        .init(name: "Croatia Airlines",  code: "OU", weight: 3,  types: ["A319","A320","A320NEO"]),
        .init(name: "Bulgaria Air",      code: "FB", weight: 3,  types: ["A319","A320","A320NEO","E190"]),
        .init(name: "Binter Canarias",   code: "NT", weight: 3,  types: ["E195"]),
        .init(name: "Azores Airlines",   code: "S4", weight: 2,  types: ["A320","A320NEO","A321NEO"]),
        // Regional-brand liveries (E-Jet / CRJ feed)
        .init(name: "Lufthansa CityLine", code: "CL", weight: 4, types: ["E190","E195","CRJ900"]),
        .init(name: "KLM Cityhopper",     code: "WA", weight: 3, types: ["E175","E190","E195"]),
        .init(name: "Air Nostrum",        code: "YW", weight: 3, types: ["CRJ900","CRJ1000","ERJ145","ERJ140"]),
    ]

    /// Real African carriers, per-type eligibility researched per carrier. Ethiopian
    /// (Africa's largest), EgyptAir, Royal Air Maroc, South African, Kenya Airways
    /// on top. Some intercontinental legs also draw the big European/US carriers via
    /// the cross-region pick. No African 747/A380 passenger operators, so those types
    /// fall to Independent Operator on African legs — realistic.
    static let africaRoster: [Airline] = [
        .init(name: "Ethiopian Airlines",  code: "ET", weight: 14, types: ["B737700","B737800","MAX8","B773","B788","B789","A359"]),
        .init(name: "EgyptAir",            code: "MS", weight: 11, types: ["B737800","A220300","A320","A320NEO","A321NEO","B773","B789","A339"]),
        .init(name: "Royal Air Maroc",     code: "AT", weight: 10, types: ["B737700","B737800","MAX8","B788","B789","A320"]),
        .init(name: "South African Airways", code: "SA", weight: 8, types: ["A319","A320","A339","A340"]),
        .init(name: "Kenya Airways",       code: "KQ", weight: 7,  types: ["B737800","B788","E190"]),
        .init(name: "Air Algérie",         code: "AH", weight: 6,  types: ["B737700","B737800","MAX8","A339","A359"]),
        .init(name: "Air Peace",           code: "P4", weight: 6,  types: ["B737800","E195","B773"]),
        .init(name: "FlySafair",           code: "FA", weight: 6,  types: ["B737700","B737800"]),
        .init(name: "Tunisair",            code: "TU", weight: 5,  types: ["A319","A320","A321","A339"]),
        .init(name: "RwandAir",            code: "WB", weight: 4,  types: ["B737800","A339","CRJ900"]),
        .init(name: "Air Côte d'Ivoire",   code: "HF", weight: 4,  types: ["A319","A320","A339"]),
        .init(name: "Air Senegal",         code: "HC", weight: 3,  types: ["A319","A320","A339"]),
        .init(name: "TAAG Angola Airlines", code: "DT", weight: 3, types: ["B737700","B773"]),
        .init(name: "ASKY Airlines",       code: "KP", weight: 3,  types: ["B737700","B737800"]),
        .init(name: "Air Tanzania",        code: "TC", weight: 3,  types: ["A220300","B788"]),
    ]

    // Asia = East + Southeast + South Asia. The Middle East is a SEPARATE region
    // (see middleEastRoster) even though NE draws it on the same outline — so an
    // intra-China or intra-Japan leg won't paint Emirates, and an Asia↔Gulf leg
    // correctly mixes both. Per-type eligibility researched per carrier.
    static let asiaRoster: [Airline] = [
        .init(name: "Air China",           code: "CA", weight: 12, types: ["A319","A320","A320NEO","A321","A321NEO","B737800","B773","B789","A359","A339"]),
        .init(name: "China Eastern",       code: "MU", weight: 12, types: ["A319","A320","A320NEO","A321","A321NEO","B737800","B773","B789","A359","A339"]),
        .init(name: "China Southern",      code: "CZ", weight: 12, types: ["A319","A320","A320NEO","A321","A321NEO","B737800","B773","B788","B789","A359","A339"]),
        .init(name: "IndiGo",              code: "6E", weight: 12, types: ["A320","A320NEO","A321","A321NEO"]),
        .init(name: "Air India",           code: "AI", weight: 9,  types: ["A319","A320","A320NEO","A321","A321NEO","B773","B788","B789","A359"]),
        .init(name: "All Nippon Airways",  code: "NH", weight: 9,  types: ["B737800","B773","B788","B789","B78J","A320NEO","A321NEO","A380"]),
        .init(name: "Japan Airlines",      code: "JL", weight: 8,  types: ["B737800","B773","B788","B789","A359","A321NEO"]),
        .init(name: "AirAsia",             code: "AK", weight: 8,  types: ["A320","A320NEO","A321NEO"]),
        .init(name: "Cathay Pacific",      code: "CX", weight: 7,  types: ["B773","A339","A359","A321NEO"]),
        .init(name: "Hainan Airlines",     code: "HU", weight: 7,  types: ["B737800","MAX8","B788","B789","A339","A359"]),
        .init(name: "Korean Air",          code: "KE", weight: 7,  types: ["B737800","MAX8","B773","B789","B78J","A339","A380"]),
        .init(name: "Singapore Airlines",  code: "SQ", weight: 7,  types: ["B773","B78J","A359","A380","A339"]),
        .init(name: "Xiamen Airlines",     code: "MF", weight: 6,  types: ["B737700","B737800","MAX8","B788","B789"]),
        .init(name: "Lion Air",            code: "JT", weight: 6,  types: ["B737800","B739","MAX8","A339"]),
        .init(name: "Thai Airways",        code: "TG", weight: 6,  types: ["B773","B788","B789","A359","A320"]),
        .init(name: "VietJet Air",         code: "VJ", weight: 6,  types: ["A320","A320NEO","A321NEO"]),
        .init(name: "Vietnam Airlines",    code: "VN", weight: 5,  types: ["A320","A321","A321NEO","B789","B78J","A359"]),
        .init(name: "Cebu Pacific",        code: "5J", weight: 5,  types: ["A320","A320NEO","A321NEO","A339"]),
        .init(name: "Philippine Airlines", code: "PR", weight: 5,  types: ["A320","A321","A321NEO","A339","A359","B773"]),
        .init(name: "Garuda Indonesia",    code: "GA", weight: 5,  types: ["B737800","MAX8","B773","A339","A320"]),
        .init(name: "Malaysia Airlines",   code: "MH", weight: 5,  types: ["B737800","MAX8","A339","A359","A380"]),
        .init(name: "Sichuan Airlines",    code: "3U", weight: 5,  types: ["A319","A320","A321","A339","A359"]),
        .init(name: "Shenzhen Airlines",   code: "ZH", weight: 5,  types: ["A319","A320","A321","B737800"]),
        .init(name: "Spring Airlines",     code: "9C", weight: 5,  types: ["A320","A320NEO","A321NEO"]),
        .init(name: "Asiana Airlines",     code: "OZ", weight: 5,  types: ["A320","A321","B773","A339","A359","A380"]),
        .init(name: "China Airlines",      code: "CI", weight: 5,  types: ["B737800","B773","A339","A359"]),
        .init(name: "EVA Air",             code: "BR", weight: 5,  types: ["B773","B789","B78J","A339","A321NEO"]),
        .init(name: "SpiceJet",            code: "SG", weight: 5,  types: ["B737800","MAX8"]),
        .init(name: "Vistara",             code: "UK", weight: 5,  types: ["A320","A320NEO","A321NEO","B789"]),
        .init(name: "Scoot",               code: "TR", weight: 4,  types: ["A320","A320NEO","A321NEO","B788","B789"]),
        .init(name: "Akasa Air",           code: "QP", weight: 4,  types: ["MAX8"]),
        .init(name: "Pakistan Int'l",      code: "PK", weight: 4,  types: ["A320","A320NEO","B773"]),
        .init(name: "AirBlue",             code: "PA", weight: 2,  types: ["A320","A321"]),
        .init(name: "Royal Brunei",        code: "BI", weight: 2,  types: ["A320NEO","B788"]),
        .init(name: "Cambodia Angkor Air", code: "K6", weight: 2,  types: ["A320","A321"]),
        .init(name: "Myanmar National",    code: "UB", weight: 2,  types: ["B737800","E190"]),
    ]

    static let middleEastRoster: [Airline] = [
        .init(name: "Emirates",            code: "EK", weight: 12, types: ["B773","A380"]),
        .init(name: "Qatar Airways",       code: "QR", weight: 11, types: ["A320","A321","B773","B788","B789","A359","A339"]),
        .init(name: "Saudia",              code: "SV", weight: 8,  types: ["A320","A321","A321NEO","B773","B789","B78J","A339"]),
        .init(name: "Etihad Airways",      code: "EY", weight: 7,  types: ["A320","A321","A321NEO","B773","B789","B78J","A359","A380"]),
        .init(name: "flydubai",            code: "FZ", weight: 6,  types: ["B737800","MAX8","MAX9"]),
        .init(name: "Air Arabia",          code: "G9", weight: 5,  types: ["A320","A320NEO","A321NEO"]),
        .init(name: "Oman Air",            code: "WY", weight: 4,  types: ["B737800","MAX8","B788","B789","A339"]),
        .init(name: "Kuwait Airways",      code: "KU", weight: 4,  types: ["A320","A321","A321NEO","B773","A339"]),
        .init(name: "Gulf Air",            code: "GF", weight: 4,  types: ["A320","A321","A321NEO","B789"]),
        .init(name: "Royal Jordanian",     code: "RJ", weight: 4,  types: ["A319","A320","A321","B788","B789"]),
        .init(name: "El Al",               code: "LY", weight: 4,  types: ["B737800","B739","B788","B789","B773"]),
        .init(name: "Iran Air",            code: "IR", weight: 4,  types: ["A319","A320","A321","A339"]),
        .init(name: "Mahan Air",           code: "W5", weight: 3,  types: ["A319","A320","A321","A340"]),
    ]

    // Oceania & South Pacific — Australia / New Zealand / Fiji / Tahiti / New
    // Caledonia / PNG. Per-type researched. (GUM is US-region, not here — see the
    // note in Airport.all — so United carries Guam's Pacific traffic.)
    static let oceaniaRoster: [Airline] = [
        .init(name: "Qantas",             code: "QF", weight: 14, types: ["B737800","A339","B789","A380"]),
        .init(name: "Air New Zealand",    code: "NZ", weight: 10, types: ["A320","A321NEO","B789","B773"]),
        .init(name: "Virgin Australia",   code: "VA", weight: 10, types: ["B737800","MAX8"]),
        .init(name: "Jetstar",            code: "JQ", weight: 9,  types: ["A320","A321","A321NEO","B788"]),
        .init(name: "Fiji Airways",       code: "FJ", weight: 5,  types: ["B737800","MAX8","A339","A359"]),
        .init(name: "Rex Airlines",       code: "ZL", weight: 4,  types: ["B737800"]),
        .init(name: "Air Tahiti Nui",     code: "TN", weight: 3,  types: ["B789"]),
        .init(name: "Aircalin",           code: "SB", weight: 3,  types: ["A320NEO","A339"]),
        .init(name: "Air Niugini",        code: "PX", weight: 3,  types: ["B737800","A320"]),
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
        // Caribbean leisure islands ride the Central America carrier region
        // (Copa/Avianca genuinely blanket the Caribbean; a dedicated Caribbean
        // roster — Caribbean Airlines, interCaribbean — is a future refinement).
        // SJU/STT are deliberately NOT here: US territories, US carriers (same
        // principle as GUM).
        "NAS","PLS","GCM","EIS","AXA","SXM","SBH","ANU","SKB","DOM",
        "UVF","SVD","GND","BGI","AUA","CUR","BON","POS",
    ]
    static let southAmericaCodes: Set<String> = [
        "BOG","GRU","SCL","LIM","CGH","AEP","GIG","VCP","MDE","BSB","EZE","UIO","SDU","CLO","CNF","CTG","POA","REC","SSA","GYE",
    ]
    static let europeCodes: Set<String> = [
        "LHR","IST","CDG","AMS","MAD","FRA","BCN","FCO","SVO","LGW","MUC","SAW","LIS","DUB","PMI","ORY","MAN","STN","DME","CPH",
        "MXP","ATH","AYT","VIE","OSL","BRU","ARN","LED","BER","ZRH","DUS","AGP","VCE","OTP","GVA","HAM","NCE","NAP","EDI","PRG",
        "KEF","VKO","BRS","OPO","BGY","ALC","HEL",
        "WAW","BUD","BTS","BEG","KBP","RIX","VNO","TLL","MSQ","ZAG","SOF","SJJ","LPA","PDL",
    ]
    static let africaCodes: Set<String> = [
        "CAI","JNB","ADD","CMN","CPT","HRG","NBO","RAK","LOS","ALG","TUN","DUR","ABJ","ACC","ABV","DSS","SSH","MRU","RBA","KGL",
        "EBB","LAD","DAR","AGA","TNG","SEZ",
    ]
    // Asia = East + Southeast + South Asia (Middle East is separate, below).
    static let asiaCodes: Set<String> = [
        "PEK","HND","PVG","CAN","SIN","ICN","BKK","HKG","KUL","SZX","CTU","TPE","MNL","KIX","CGK","KMG","XIY","HGH","NRT","CKG",
        "WUH","SGN","SUB","HAN","PNH","RGN","NYT","BWN",
        "DEL","BOM","BLR","HYD","MAA","CCU","AMD","COK","PNQ","GOI","KHI","LHE","ISB","MLE",
    ]
    static let middleEastCodes: Set<String> = [
        "DXB","DOH","JED","RUH","AUH","MCT","KWI","BAH","DMM","SHJ","TLV","MED","AMM","BEY","MHD","IKA","THR",
    ]
    // Oceania & South Pacific. GUM (Guam) is deliberately NOT here — it's a US
    // territory / United hub, so it stays in the US carrier region.
    static let oceaniaCodes: Set<String> = [
        "SYD","MEL","BNE","AKL","PER","ADL","CHC","OOL","WLG","CNS","NAN","HBA","DRW","ZQN","PPT","TSV","LST","NOU","CBR","POM",
    ]

    static func region(_ code: String) -> Region {
        if canadaCodes.contains(code) { return .canada }
        if mexicoCodes.contains(code) { return .mexico }
        if centralAmericaCodes.contains(code) { return .centralAmerica }
        if southAmericaCodes.contains(code) { return .southAmerica }
        if europeCodes.contains(code) { return .europe }
        if africaCodes.contains(code) { return .africa }
        if asiaCodes.contains(code) { return .asia }
        if middleEastCodes.contains(code) { return .middleEast }
        if oceaniaCodes.contains(code) { return .oceania }
        return .us
    }
    static func roster(for r: Region) -> [Airline] {
        switch r {
        case .us:             return roster
        case .canada:         return canadaRoster
        case .mexico:         return mexicoRoster
        case .centralAmerica: return centralAmericaRoster
        case .southAmerica:   return southAmericaRoster
        case .europe:         return europeRoster
        case .africa:         return africaRoster
        case .asia:           return asiaRoster
        case .middleEast:     return middleEastRoster
        case .oceania:        return oceaniaRoster
        }
    }

    /// Real-world-aware weighted pick among carriers that actually fly `typeId`
    /// AND realistically serve this leg. A carrier is eligible only if it serves
    /// one of the leg's endpoints' regions (so a Mexican carrier never appears on
    /// a US-domestic leg); overseas carriers additionally require BOTH endpoints
    /// to be US international gateways. Every type still resolves (Independent
    /// Operator fallback). This is the code path background traffic uses.
    static func pick(forType typeId: String, originCode: String, destCode: String) -> Airline {
        let oR = region(originCode), dR = region(destCode)
        let pool = oR == dR ? roster(for: oR) : roster(for: oR) + roster(for: dR)
        return weightedPick(pool.filter { $0.types.contains(typeId) })
    }

    /// Weighted pick over an arbitrary airline pool (used by the background-traffic
    /// airline-first model: pick the carrier, THEN a type it flies + a route in
    /// its sphere — so each aircraft is one coherent airline).
    static func weighted(_ pool: [Airline]) -> Airline { weightedPick(pool) }

    /// Plausible international corridors between regions — a cross-region
    /// (international) background leg only connects regions listed here, and only
    /// between GATEWAY airports (see Simulation). Captures real intercontinental
    /// flows and excludes ones nobody flies nonstop (e.g. Oceania↔Africa,
    /// South America↔Asia). Keeps a carrier's routes inside its real reach.
    static let corridors: [Region: [Region]] = [
        .us:             [.canada, .mexico, .centralAmerica, .southAmerica, .europe, .asia, .oceania, .middleEast, .africa],
        .canada:         [.us, .europe, .asia, .mexico, .centralAmerica, .southAmerica],
        .mexico:         [.us, .canada, .centralAmerica, .southAmerica, .europe],
        .centralAmerica: [.us, .mexico, .southAmerica, .canada],
        .southAmerica:   [.us, .europe, .centralAmerica, .mexico, .canada, .africa, .middleEast],
        .europe:         [.us, .canada, .africa, .middleEast, .asia, .southAmerica, .mexico],
        .africa:         [.europe, .middleEast, .us, .asia, .southAmerica],
        .middleEast:     [.europe, .africa, .asia, .us, .canada, .oceania, .southAmerica],
        .asia:           [.middleEast, .europe, .us, .canada, .oceania, .africa],
        .oceania:        [.asia, .us, .middleEast],
    ]

    /// Every region that carries background traffic (has a roster).
    static let allRegions: [Region] = [.us, .canada, .mexico, .centralAmerica, .southAmerica, .europe, .africa, .asia, .middleEast, .oceania]

    /// Region-based overload kept for callers/tests that reason in regions.
    /// No gateway logic — overseas carriers never enter through this path.
    static func pick(forType typeId: String, origin: Region, dest: Region) -> Airline {
        let pool = origin == dest ? roster(for: origin) : roster(for: origin) + roster(for: dest)
        return weightedPick(pool.filter { $0.types.contains(typeId) })
    }

    /// US-domestic convenience.
    static func pick(forType typeId: String) -> Airline {
        weightedPick(roster.filter { $0.types.contains(typeId) })
    }

    private static func weightedPick(_ eligible: [Airline]) -> Airline {
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
        // Latin American carriers (added with the LatAm airport expansion; the
        // majors AM/CM/LA/AV/AR are already listed above)
        "AD": "Azul", "VB": "Viva Aerobus", "JA": "JetSMART",
        // Canadian carriers (WS/AC already listed above)
        "TS": "Air Transat", "PD": "Porter Airlines", "QK": "Jazz",
        // European carriers (LH/BA/AF/TK/KL/IB/LX/EI/AY/TP/SU/OS/DY/SK already above)
        "FR": "Ryanair", "VY": "Vueling", "AZ": "ITA Airways", "BT": "airBaltic",
        "CL": "Lufthansa CityLine", "WA": "KLM Cityhopper", "YW": "Air Nostrum",
        "W6": "Wizz Air", "RO": "TAROM", "JU": "Air Serbia", "PS": "Ukraine Int'l",
        "B2": "Belavia", "U2": "easyJet", "PC": "Pegasus Airlines", "A3": "Aegean Airlines",
        "OU": "Croatia Airlines", "FB": "Bulgaria Air", "NT": "Binter Canarias", "S4": "Azores Airlines",
        // African carriers (ET/MS/SA already above)
        "AT": "Royal Air Maroc", "KQ": "Kenya Airways", "AH": "Air Algérie",
        "TU": "Tunisair", "FA": "FlySafair", "WB": "RwandAir", "HF": "Air Côte d'Ivoire",
        "HC": "Air Senegal", "DT": "TAAG Angola Airlines", "KP": "ASKY Airlines", "TC": "Air Tanzania",
        // Asian carriers (CA/MU/CZ/NH/JL/CX/KE/SQ/AI/TG/VN/PR/GA/MH/OZ/CI/BR/UK already above)
        "BI": "Royal Brunei", "K6": "Cambodia Angkor Air", "UB": "Myanmar National", "PA": "AirBlue",
        "HU": "Hainan Airlines", "MF": "Xiamen Airlines", "ZH": "Shenzhen Airlines",
        "SG": "SpiceJet", "TR": "Scoot", "AK": "AirAsia", "VJ": "VietJet Air",
        "JT": "Lion Air", "QP": "Akasa Air",
        // Middle East carriers (EK/QR/SV/EY/WY/GF/RJ already above)
        "FZ": "flydubai", "KU": "Kuwait Airways", "LY": "El Al", "IR": "Iran Air",
        // Oceania / South Pacific carriers (QF/NZ/VA/JQ already above)
        "FJ": "Fiji Airways", "ZL": "Rex Airlines", "TN": "Air Tahiti Nui",
        "SB": "Aircalin", "PX": "Air Niugini",
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
