import Foundation

// Mirrors AirportPhoto.archetype(for:) exactly (that file imports SwiftUI, so the
// logic is duplicated here to run headlessly against the REAL Airport.all data).
enum Arch: String { case metro, tropicalIsland, snowyNorth, desert, savanna, alpine, coastal, tropical, plains }

func archetype(_ ap: Airport) -> Arch {
    let code = ap.code
    let absLat = abs(ap.lat)
    let pax = ap.info?.annualPassengers ?? 0
    if Airport.isLeisure(code) { return .tropicalIsland }
    if pax >= 30_000_000 { return .metro }
    if absLat >= 54 { return .snowyNorth }
    switch Airline.region(code) {
    case .africa, .middleEast:
        if absLat <= 15 { return .savanna }
        return absLat <= 20 ? .desert : .coastal
    case .asia:                       return absLat <= 23 ? .tropical : .plains
    case .caribbean, .centralAmerica: return .tropicalIsland
    case .southAmerica:               return absLat <= 12 ? .tropical : .plains
    case .oceania:                    return .coastal
    case .europe:                     return absLat >= 48 ? .alpine : .coastal
    case .us, .canada, .mexico:       return absLat >= 47 ? .snowyNorth : .plains
    }
}

// Per-code art that already exists — synced to the ACTUAL bundled city heroes
// (Resources/AirportPhotos/airport_<CODE>.jpg), plus the shared-metro aliases those
// stand in for (CHI→ORD/MDW, NYC→JFK/LGA/EWR, TYO→HND/NRT). These never use an archetype.
let bundled: Set<String> = ["AMS","ARN","ATH","ATL","BCN","BKK","BOG","BOM","BOS","BZN",
    "CAN","CDG","CGK","CHI","CLT","CPH","CPT","DEL","DEN","DFW","DOH","DUB","DXB","EDI",
    "FCO","FLL","FRA","GIG","GRU","GVA","HEL","HKG","HNL","IAH","ICN","IST","KEF","KUL",
    "LAS","LAX","LHR","LIS","MAD","MCO","MEL","MEX","MIA","MSP","MUC","NCE","NYC","OAK",
    "OSL","PEK","PHX","PMI","PRG","PVG","SEA","SFO","SIN","SYD","SZX","TYO","VCE","VIE","YYZ","ZRH"]
// Aliases covered by a shared metro hero (AirportPhoto.sharedOverride).
let aliases: Set<String> = ["ORD","MDW","JFK","LGA","EWR","HND","NRT"]
let hasOwnArt = bundled.union(aliases)

let all = Airport.all.sorted { $0.code < $1.code }
print("TOTAL AIRPORTS: \(all.count)  (with own art: \(all.filter { hasOwnArt.contains($0.code) }.count))")
print("")

// ⭐ PRIORITY LIST: the highest-traffic airports that DON'T yet have their own hero
// (still fall back to a generic archetype) — the next heroes to make, ranked by pax.
let candidates = all.filter { !hasOwnArt.contains($0.code) && ($0.info?.annualPassengers ?? 0) > 0 }
    .sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
print("=== NEXT 50 HEROES TO MAKE (highest-traffic airports still on a generic archetype) ===")
for (i, ap) in candidates.prefix(50).enumerated() {
    let city = ap.info?.city ?? "?"
    let pax = (ap.info?.annualPassengers ?? 0) / 1_000_000
    print(String(format: "  %2d. %@  %-30@ %3dM/yr  %@  (now: %@)",
                 i+1, ap.code, city as NSString, pax, "\(Airline.region(ap.code))", archetype(ap).rawValue))
}
print("")
// Group by archetype so wrong buckets are easy to spot.
var byArch: [Arch: [Airport]] = [:]
for ap in all where !hasOwnArt.contains(ap.code) { byArch[archetype(ap), default: []].append(ap) }
for a in [Arch.metro, .plains, .snowyNorth, .alpine, .coastal, .desert, .savanna, .tropical, .tropicalIsland] {
    let list = byArch[a] ?? []
    print("=== \(a.rawValue.uppercased()) — \(list.count) ===")
    for ap in list {
        let city = ap.info?.city ?? "?"
        let pax = (ap.info?.annualPassengers ?? 0) / 1_000_000
        print(String(format: "  %@  %-34@ lat %6.1f  %3dM  %@", ap.code, city as NSString, ap.lat, pax, "\(Airline.region(ap.code))"))
    }
    print("")
}
