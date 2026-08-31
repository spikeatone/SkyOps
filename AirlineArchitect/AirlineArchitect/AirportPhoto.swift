//
//  AirportPhoto.swift
//  Airline Architect — airport-card hero imagery (1.2 feature; see
//  AIRPORT_PHOTOS_SPEC.md).
//
//  Each airport maps to one of a curated set of region/terrain ARCHETYPES
//  rather than a unique photo (380+ airports → licensing + ~95 MB bundle).
//  Real art is Midjourney-generated in the Vineyard-Architect style and dropped
//  into Resources/AirportPhotos/airport_<archetype>.jpg (flattened to the bundle
//  root, like the fonts/illustrations). Until an image exists, a styled
//  PLACEHOLDER renders so the card layout can be approved now.
//

import SwiftUI
import UIKit

enum AirportArchetype: String, CaseIterable {
    case metro, tropicalIsland, snowyNorth, desert, savanna, alpine, coastal, tropical, plains

    var label: String {
        switch self {
        case .metro:          return "Metro skyline"
        case .tropicalIsland: return "Tropical island"
        case .snowyNorth:     return "Northern winter"
        case .desert:         return "Desert"
        case .savanna:        return "Savanna"
        case .alpine:         return "Alpine"
        case .coastal:        return "Coastal"
        case .tropical:       return "Tropics"
        case .plains:         return "Heartland"
        }
    }

    /// Placeholder sky→horizon gradient (golden-hour warmth, like the VA
    /// reference). Real art replaces this entirely.
    var placeholderColors: [Color] {
        switch self {
        case .metro:          return [c(0x241E46), c(0x6B4E86), c(0xEDA45E)]
        case .tropicalIsland: return [c(0x186C7C), c(0x33B4AE), c(0xF3D28C)]
        case .snowyNorth:     return [c(0x3A597F), c(0x8AA9C6), c(0xEAF0F6)]
        case .desert:         return [c(0x7C4A2C), c(0xD68C4C), c(0xF6D289)]
        case .savanna:        return [c(0x6E5A2E), c(0xC7A14E), c(0xF0DC94)]
        case .alpine:         return [c(0x3A4B79), c(0x8090C1), c(0xDBE1EE)]
        case .coastal:        return [c(0x235C7E), c(0x3E9BC4), c(0xF3D8A2)]
        case .tropical:       return [c(0x2C6A38), c(0x5BA85B), c(0xF1D688)]
        case .plains:         return [c(0x695A85), c(0xC28C6E), c(0xF4CB79)]
        }
    }

    var isMetro: Bool { self == .metro }
    private func c(_ h: UInt) -> Color { Color(skyHex: h) }
}

enum AirportPhoto {
    /// Per-airport archetype CORRECTIONS — the highest-priority rule.
    ///
    /// The heuristic below works off latitude + carrier region, which genuinely
    /// cannot tell a mountain city from prairie from coastline: it put Salt Lake
    /// City (ringed by the Wasatch) on `plains`, Cusco at 11,000 ft on `plains`,
    /// Honolulu on `plains`, and — worst — labelled Berlin/Hamburg/Warsaw `alpine`
    /// while Zurich and Geneva fell through to `coastal`. Geography isn't derivable
    /// from a bounding box, so anywhere the heuristic lands somewhere clearly WRONG
    /// for a real place, it's pinned here. Curated from a full 385-airport audit
    /// (`aa-1.1.x/archetype-audit`) — re-run it after adding airports.
    ///
    /// Only CLEAR errors are listed; the archetypes are deliberately generic, so
    /// "close enough" is fine and marginal calls are left to the heuristic.
    static let archetypeOverrides: [String: AirportArchetype] = [
        // ── Mountains (were plains/coastal) ──────────────────────────────
        "SLC": .alpine, "RNO": .alpine,                       // Wasatch · Sierra
        "MTY": .alpine, "OAX": .alpine,                       // Sierra Madre
        "CUZ": .alpine, "SCL": .alpine,                       // Andes
        "KTM": .alpine, "PBH": .alpine, "ALA": .alpine,       // Himalaya · Tian Shan
        "ZRH": .alpine, "GVA": .alpine,                       // the actual Alps
        "SJJ": .alpine, "SOF": .alpine,                       // Dinarides · Vitosha
        "ZQN": .alpine,                                       // Southern Alps, NZ

        // ── Northern Europe is FLAT, not alpine (the inverted rule) ──────
        "BER": .plains, "HAM": .plains, "DUS": .plains, "WAW": .plains,
        "PRG": .plains, "BRU": .plains, "MSQ": .plains, "KBP": .plains,
        "MAN": .plains, "STN": .plains, "BRS": .plains, "BTS": .plains,
        // ── Inland central/eastern Europe (were "coastal") ───────────────
        "BUD": .plains, "OTP": .plains, "BEG": .plains, "ZAG": .plains,

        // ── Coastline (were plains) ─────────────────────────────────────
        "SAN": .coastal, "OAK": .coastal, "SJC": .coastal, "SNA": .coastal,
        "PVD": .coastal, "CHS": .coastal, "ORF": .coastal, "MSY": .coastal,
        "TPA": .coastal, "RSW": .coastal,
        "YVR": .coastal, "YYJ": .coastal, "YHZ": .coastal, "YSJ": .coastal,
        "TIJ": .coastal, "PVR": .coastal, "SJD": .coastal, "MZT": .coastal,
        "VER": .coastal,
        "KIX": .coastal, "FUK": .coastal, "KOJ": .coastal, "KHI": .coastal,
        "GIG": .coastal, "SDU": .coastal, "SSA": .coastal, "VIX": .coastal,
        "FLN": .coastal, "LIM": .coastal,

        // ── Real snow country (were plains) ──────────────────────────────
        "BUF": .snowyNorth, "SYR": .snowyNorth, "ROC": .snowyNorth,
        "BTV": .snowyNorth, "BGR": .snowyNorth, "PWM": .snowyNorth,
        "YUL": .snowyNorth, "YOW": .snowyNorth, "YTZ": .snowyNorth,
        "YQM": .snowyNorth, "YFC": .snowyNorth,
        "CTS": .snowyNorth,                                   // Sapporo
        "YQG": .plains,                                       // Windsor is mild + southern

        // ── Islands (were plains/coastal) ───────────────────────────────
        "HNL": .tropicalIsland, "GUM": .tropicalIsland,
        "CZM": .tropicalIsland, "LPA": .tropicalIsland,       // Cozumel · Canaries

        // ── Desert: the Gulf + Sahara were falling to "coastal" ─────────
        "ABQ": .desert, "HMO": .desert, "CUL": .desert,
        "AMM": .desert, "KWI": .desert, "DMM": .desert, "MED": .desert,
        "MCT": .desert, "SHJ": .desert, "AUH": .desert, "BAH": .desert,
        "IKA": .desert, "THR": .desert, "MHD": .desert,
        "RAK": .desert, "AGA": .desert, "BSK": .desert,
        "HRG": .desert, "SSH": .desert,
        "ASB": .desert, "AMD": .desert,

        // ── Grassland / tropics ─────────────────────────────────────────
        "JNB": .savanna, "BFN": .savanna,                     // highveld
        "BSB": .savanna,                                      // cerrado
        "CGB": .tropical, "MID": .tropical, "DAC": .tropical,
        "CNS": .tropical, "DRW": .tropical, "TSV": .tropical, "POM": .tropical,
        "CHC": .plains,                                       // Canterbury Plains
    ]

    /// Self-contained archetype heuristic (no sim) — a per-airport correction
    /// first, then leisure flag, hub size, latitude, and carrier region.
    static func archetype(for airport: Airport) -> AirportArchetype {
        let code = airport.code
        let absLat = abs(airport.lat)
        let pax = airport.info?.annualPassengers ?? 0

        if let pinned = archetypeOverrides[code] { return pinned }
        if Airport.isLeisure(code) { return .tropicalIsland }
        if pax >= 30_000_000 { return .metro }
        if absLat >= 54 { return .snowyNorth }

        switch Airline.region(code) {
        case .africa, .middleEast:
            // Equatorial Africa + the Sahel + the East-African plateau are golden
            // grassland, not dune desert — the old `absLat <= 20 -> desert` put a
            // Sahara scene on Lagos/Nairobi/Accra. Split that green band off to
            // savanna; the 15–20° dry belt (Sahara edge) stays desert; >20 as before.
            if absLat <= 15 { return .savanna }
            return absLat <= 20 ? .desert : .coastal
        case .asia:                       return absLat <= 23 ? .tropical : .plains
        case .caribbean, .centralAmerica: return .tropicalIsland
        case .southAmerica:               return absLat <= 12 ? .tropical : .plains
        case .oceania:                    return .coastal
        // Northern Europe is the NORTH EUROPEAN PLAIN, not the Alps — the old
        // `>= 48 -> alpine` had this exactly backwards (Berlin alpine, Zurich
        // coastal). Alpine is now override-only, which is the honest default:
        // a new European airport is far more likely flat than mountainous.
        case .europe:                     return absLat >= 48 ? .plains : .coastal
        case .us, .canada, .mexico:       return absLat >= 47 ? .snowyNorth : .plains
        }
    }

    /// Airports that SHARE one override image because several codes serve a single
    /// metro (e.g. NYC = JFK/LGA/EWR → `airport_NYC`). A per-airport `airport_<CODE>`
    /// file still wins if present; otherwise the shared image is used. Extend as
    /// needed (Bay Area, LA-area, …).
    static let sharedOverride: [String: String] = [
        "JFK": "NYC", "LGA": "NYC", "EWR": "NYC",   // New York → airport_NYC
        "HND": "TYO", "NRT": "TYO",                 // Tokyo    → airport_TYO
        "ORD": "CHI", "MDW": "CHI",                 // Chicago  → airport_CHI
    ]

    /// Bundled MJ art if present; nil → the styled placeholder renders. Lookup
    /// order: per-airport override (`airport_<CODE>`) → shared-metro override
    /// (`airport_<shared>`, e.g. `airport_NYC`) → archetype (`airport_<archetype>`).
    static func image(for airport: Airport) -> Image? {
        var names = ["airport_\(airport.code)"]
        if let shared = sharedOverride[airport.code] { names.append("airport_\(shared)") }
        names.append("airport_\(archetype(for: airport).rawValue)")
        for name in names {
            for ext in ["jpg", "png", "heic"] {
                if let path = Bundle.main.path(forResource: name, ofType: ext),
                   let ui = UIImage(contentsOfFile: path) {
                    return Image(uiImage: ui)
                }
            }
        }
        return nil
    }
}

/// The hero band at the top of `AirportInfoCard`: real art if bundled, else a
/// styled placeholder keyed to the airport's archetype.
struct AirportHero: View {
    let airport: Airport
    /// Hero height scales with the card's WIDTH so the band keeps a pleasant
    /// proportion at any size. A fixed height reads ~2.5:1 on iPhone but a thin
    /// strip on the wide iPad-portrait card — this clamps it to a sensible band
    /// everywhere (iPhone/iPad-landscape land near `minHeight`; the wide
    /// iPad-portrait card grows toward `maxHeight`).
    var aspect: CGFloat = 2.5          // target width : height
    var minHeight: CGFloat = 132
    // Raised 220 -> 300: on the wide iPad card, width/2.5 was clamping the band
    // short, which made scaledToFill crop a thin center strip and lop the SKY
    // off skyline heroes. A taller cap keeps the band nearer 2.5:1 there, so
    // less of the image is thrown away.
    var maxHeight: CGFloat = 300
    @State private var measuredWidth: CGFloat = 0

    private var height: CGFloat {
        guard measuredWidth > 0 else { return minHeight }
        return min(max(measuredWidth / aspect, minHeight), maxHeight)
    }

    var body: some View {
        // scaledToFill defaults to CENTER cropping — for a 16:9 source shown in a
        // shorter band that slices equal strips off top and bottom, so a city
        // skyline (which sits in the upper-middle of the frame) loses its sky and
        // tower-tops. Fill by WIDTH (image becomes full 16:9 height, taller than
        // the band), then clip to the band with the image nudged UP so the visible
        // window lands on the upper part of the frame — sky + subject kept, the
        // excess taken from the foreground.
        GeometryReader { geo in
            // Fill height = whichever is larger, the image's natural 16:9 height or
            // the band itself, so the image never ends up shorter than the band
            // (which would leave a gap). scaledToFill semantics, done by hand.
            let imageH = max(geo.size.width * 9.0 / 16.0, geo.size.height)
            let slack  = max(0, imageH - geo.size.height)       // how much taller than the band
            let biasFromTop: CGFloat = 0.38                     // 0 = show top, 0.5 = center
            Group {
                if let img = AirportPhoto.image(for: airport) {
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: imageH)
                        .offset(y: -slack * biasFromTop)
                } else {
                    AirportPhotoPlaceholder(archetype: AirportPhoto.archetype(for: airport))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .onAppear { measuredWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, w in measuredWidth = w }
        }
        .frame(height: height)
        .clipped()
    }
}

private struct AirportPhotoPlaceholder: View {
    let archetype: AirportArchetype

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: archetype.placeholderColors, startPoint: .top, endPoint: .bottom)
            // Soft sun / glow.
            GeometryReader { g in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: g.size.width * 0.10, height: g.size.width * 0.10)
                    .blur(radius: 5)
                    .position(x: g.size.width * 0.70, y: g.size.height * 0.40)
            }
            // Horizon silhouette — skyline for metros, hills otherwise.
            if archetype.isMetro {
                SkylineSilhouette().fill(Color.black.opacity(0.30))
            } else {
                HillsSilhouette().fill(Color.black.opacity(0.24))
            }
            // "This is a stand-in" tag + which archetype resolved. DEBUG-only —
            // must never ship; real MJ art replaces the whole placeholder anyway.
            #if DEBUG
            HStack(spacing: 4) {
                Image(systemName: "photo").font(.system(size: 9))
                Text("Placeholder · \(archetype.label)").font(.karla(10, .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.black.opacity(0.32), in: Capsule())
            .padding(8)
            #endif
        }
    }
}

private struct HillsSilhouette: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.height * 0.74))
        p.addQuadCurve(to: CGPoint(x: r.width * 0.5, y: r.height * 0.62),
                       control: CGPoint(x: r.width * 0.26, y: r.height * 0.50))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.height * 0.72),
                       control: CGPoint(x: r.width * 0.80, y: r.height * 0.86))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct SkylineSilhouette: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = r.height * 0.94
        let widths: [CGFloat]  = [0.06, 0.05, 0.07, 0.045, 0.08, 0.05, 0.065, 0.05, 0.07, 0.05]
        let heights: [CGFloat] = [0.42, 0.60, 0.34, 0.70,  0.48, 0.76, 0.40,  0.58, 0.50, 0.36]
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: base))
        var x = r.width * 0.02
        for (w, hh) in zip(widths, heights) {
            let bw = r.width * w
            let top = base - r.height * hh
            p.addLine(to: CGPoint(x: x, y: base))
            p.addLine(to: CGPoint(x: x, y: top))
            p.addLine(to: CGPoint(x: x + bw, y: top))
            p.addLine(to: CGPoint(x: x + bw, y: base))
            x += bw + r.width * 0.012
        }
        p.addLine(to: CGPoint(x: r.maxX, y: base))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
