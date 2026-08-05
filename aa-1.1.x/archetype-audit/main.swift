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

// Per-code art that already exists (marquee overrides) — these never use an archetype.
let hasOwnArt: Set<String> = ["LHR","CDG","SYD","SFO","SEA","LAX","DEN","BZN",
                              "JFK","LGA","EWR","HND","NRT","ORD","MDW",
                              "PEK","DXB","SIN","HKG","IST","FCO","BCN","AMS","PVG","BKK","YYZ","LAS","DOH","MIA"]

let all = Airport.all.sorted { $0.code < $1.code }
print("TOTAL AIRPORTS: \(all.count)  (with own art: \(all.filter { hasOwnArt.contains($0.code) }.count))")
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
