//
//  RegionCarousel.swift
//  Airline Architect — founding-region picker on the naming screen
//
//  A snapping card carousel (designer's pick over the old 2-column block
//  buttons): one region card centered, the previous/next cards PEEKING at the
//  margins so it reads as swipeable, page dots below. Each card carries the
//  region's real map silhouette (the same pre-projected Basemap geometry the
//  Network map draws, in the same per-region hue) and real stats from the
//  airport data — so the picker teaches the map's color language before the
//  player ever sees the Network tab.
//

import SwiftUI

struct RegionCarousel: View {
    @Binding var region: Airline.PlayerRegion
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    private var cardBG: Color     { isDark ? Color.white.opacity(0.06) : .white }
    private var cardBorder: Color { isDark ? Color.white.opacity(0.14) : Color(red: 0xE2/255, green: 0xE8/255, blue: 0xF0/255) }
    private var nameColor: Color  { isDark ? .white : Color(red: 0x1E/255, green: 0x29/255, blue: 0x3B/255) }
    private var statColor: Color  { isDark ? Color.white.opacity(0.55) : Color(red: 0x64/255, green: 0x74/255, blue: 0x8B/255) }

    /// Fixed card width; whatever container width is left over becomes the
    /// neighbor peek — so the wider the screen, the more of the adjacent
    /// cards' actual content (silhouette included) shows at the margins.
    private let cardWidth: CGFloat = 340

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let margin = max(20, (geo.size.width - cardWidth) / 2)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(Airline.PlayerRegion.allCases, id: \.self) { r in
                            RegionCard(region: r, bg: cardBG, border: cardBorder,
                                       nameColor: nameColor, statColor: statColor)
                                .frame(width: cardWidth)
                                // Neighbors peek scaled-down + dimmed — reads as a deck.
                                .scrollTransition(axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                        .opacity(phase.isIdentity ? 1 : 0.55)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollPosition(id: Binding(get: { Optional(region) },
                                            set: { if let r = $0 { region = r } }))
            }
            .frame(height: 158)

            // Page dots — the active dot stretches and takes the region's map hue.
            HStack(spacing: 6) {
                ForEach(Airline.PlayerRegion.allCases, id: \.self) { r in
                    Capsule()
                        .fill(r == region ? r.mapTint : statColor.opacity(0.35))
                        .frame(width: r == region ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: region)
                }
            }
        }
    }
}

/// One region card: silhouette + name + real network stats. The card wears a
/// faint wash of its region's map hue — so the neighbors peeking at the
/// margins read as distinctly-colored cards even from a narrow sliver.
private struct RegionCard: View {
    let region: Airline.PlayerRegion
    let bg: Color, border: Color, nameColor: Color, statColor: Color

    var body: some View {
        let stats = RegionStats.of(region)
        VStack(spacing: 6) {
            RegionSilhouette(layers: region.silhouetteLayers)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .padding(.top, 10)
            Text(region.label)
                .font(.karla(19, .heavy))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(stats.airports) airports · \(stats.topCodes.joined(separator: " · "))")
                .font(.karla(12))
                .foregroundStyle(statColor)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(bg)
        .background(region.mapTint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(region.mapTint.opacity(0.45), lineWidth: 1))
    }
}

/// Draws a region's basemap rings fit to the card — same geometry and hue as
/// the Network map, so the card IS a preview of the player's founding map.
private struct RegionSilhouette: View {
    let layers: [(rings: [[CGPoint]], tint: Color)]

    var body: some View {
        Canvas { ctx, size in
            // Bounding box across every layer, then a uniform fit-scale.
            var minX = CGFloat.greatestFiniteMagnitude, minY = minX
            var maxX = -CGFloat.greatestFiniteMagnitude, maxY = maxX
            for layer in layers {
                for ring in layer.rings {
                    for p in ring {
                        minX = min(minX, p.x); maxX = max(maxX, p.x)
                        minY = min(minY, p.y); maxY = max(maxY, p.y)
                    }
                }
            }
            guard maxX > minX, maxY > minY else { return }
            let inset: CGFloat = 4
            let scale = min((size.width - inset * 2) / (maxX - minX),
                            (size.height - inset * 2) / (maxY - minY))
            let ox = (size.width - (maxX - minX) * scale) / 2
            let oy = (size.height - (maxY - minY) * scale) / 2
            func place(_ p: CGPoint) -> CGPoint {
                CGPoint(x: ox + (p.x - minX) * scale, y: oy + (p.y - minY) * scale)
            }
            for layer in layers {
                var path = Path()
                for ring in layer.rings where ring.count > 2 {
                    path.move(to: place(ring[0]))
                    for p in ring.dropFirst() { path.addLine(to: place(p)) }
                    path.closeSubpath()
                }
                ctx.fill(path, with: .color(layer.tint.opacity(0.18)))
                ctx.stroke(path, with: .color(layer.tint.opacity(0.85)), lineWidth: 1)
            }
        }
    }
}

/// Real per-region network stats for the card, computed once from the airport
/// data (airport count + the region's three busiest airports by passengers).
private struct RegionStats {
    let airports: Int
    let topCodes: [String]

    private static var cache: [Airline.PlayerRegion: RegionStats] = [:]
    static func of(_ r: Airline.PlayerRegion) -> RegionStats {
        if let hit = cache[r] { return hit }
        let regions = Set(r.gameRegions)
        let mine = Airport.all.filter { regions.contains(Airline.region($0.code)) }
        let top = mine.sorted { ($0.info?.annualPassengers ?? 0) > ($1.info?.annualPassengers ?? 0) }
            .prefix(3).map(\.code)
        let s = RegionStats(airports: mine.count, topCodes: Array(top))
        cache[r] = s
        return s
    }
}

extension Airline.PlayerRegion {
    /// The Network map's per-region geography hue (see MapView) — the card and
    /// its page dot wear the same color the region wears in-game.
    var mapTint: Color {
        switch self {
        case .africa:         return Color(red: 0xFF/255, green: 0xB7/255, blue: 0x00/255)
        case .asia:           return Color(red: 0x89/255, green: 0x85/255, blue: 0x76/255)
        case .oceania:        return Color(red: 0x43/255, green: 0xCC/255, blue: 0xBA/255)
        case .centralAmerica: return Color(red: 0xFF/255, green: 0x9A/255, blue: 0x3C/255)
        case .europe:         return Color(red: 0xA5/255, green: 0x61/255, blue: 0xFF/255)
        case .northAmerica:   return Color(red: 0x4A/255, green: 0x9E/255, blue: 0xFF/255)
        case .southAmerica:   return Color(red: 0xED/255, green: 0xB9/255, blue: 0x3C/255)
        }
    }

    /// Basemap ring sets for the card silhouette. North America composes its
    /// three internal regions, each in its own map hue (US blue, Canada red,
    /// Mexico green) — same as the Network map.
    var silhouetteLayers: [(rings: [[CGPoint]], tint: Color)] {
        let map = Basemap.shared
        switch self {
        case .africa:         return [(map.africa, mapTint)]
        case .asia:           return [(map.asia, mapTint)]
        case .oceania:        return [(map.australia, mapTint)]
        case .centralAmerica: return [(map.centralAmerica, mapTint)]
        case .europe:         return [(map.europe, mapTint)]
        case .southAmerica:   return [(map.southAmerica, mapTint)]
        case .northAmerica:
            return [(map.canada, Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)),
                    (map.nation, mapTint),
                    (map.mexico, Color(red: 0x35/255, green: 0xC7/255, blue: 0x5A/255))]
        }
    }
}
