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
    case metro, tropicalIsland, snowyNorth, desert, alpine, coastal, tropical, plains

    var label: String {
        switch self {
        case .metro:          return "Metro skyline"
        case .tropicalIsland: return "Tropical island"
        case .snowyNorth:     return "Northern winter"
        case .desert:         return "Desert"
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
    /// Self-contained archetype heuristic (no sim) — leisure flag, hub size,
    /// latitude, and carrier region. First pass; refine as desired.
    static func archetype(for airport: Airport) -> AirportArchetype {
        let code = airport.code
        let absLat = abs(airport.lat)
        let pax = airport.info?.annualPassengers ?? 0

        if Airport.isLeisure(code) { return .tropicalIsland }
        if pax >= 30_000_000 { return .metro }
        if absLat >= 54 { return .snowyNorth }

        switch Airline.region(code) {
        case .africa, .middleEast:        return absLat <= 20 ? .desert : .coastal
        case .asia:                       return absLat <= 23 ? .tropical : .plains
        case .caribbean, .centralAmerica: return .tropicalIsland
        case .southAmerica:               return absLat <= 12 ? .tropical : .plains
        case .oceania:                    return .coastal
        case .europe:                     return absLat >= 48 ? .alpine : .coastal
        case .us, .canada, .mexico:       return absLat >= 47 ? .snowyNorth : .plains
        }
    }

    /// Bundled MJ art if present (`airport_<archetype>.<ext>` at the bundle
    /// root); nil → the styled placeholder renders. A per-airport override
    /// (`airport_<CODE>.<ext>`) is checked first, for marquee skylines later.
    static func image(for airport: Airport) -> Image? {
        for name in ["airport_\(airport.code)", "airport_\(archetype(for: airport).rawValue)"] {
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
    var height: CGFloat = 138

    var body: some View {
        let arch = AirportPhoto.archetype(for: airport)
        ZStack {
            if let img = AirportPhoto.image(for: airport) {
                img.resizable().scaledToFill()
            } else {
                AirportPhotoPlaceholder(archetype: arch)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
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
