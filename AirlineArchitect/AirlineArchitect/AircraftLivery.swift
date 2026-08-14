//
//  AircraftLivery.swift
//  Airline Architect — PROTOTYPE (Phase 1 surprise-&-delight). Branch-only.
//
//  v3 — after the "they float" feedback + the United reference:
//   • TITLES: solid primary colour, sized to sit WITHIN the upper-fuselage band
//     ABOVE the window line (not above the crown), MULTIPLY-blended so the metal's
//     shading shows through. No outline, no pill — those read as stickers.
//   • TAIL LOGO: one of the designer's emblems (rasterised from the SVGs to a
//     template PNG via rsvg-convert), TINTED to a palette colour and placed on the
//     fin. "Just add a chosen logo and tint it", not repaint the whole tail.
//
//  Still open (needs per-type fuselage MASKS from the Figma source): clipping the
//  titles to the fuselage + masking the window row so titles can sit LOWER without
//  covering windows. This prototype places titles ABOVE the windows to sidestep that.
//

import SwiftUI

struct LiveryColors: Equatable {
    var primary: Color     // titles + (by default) the tail logo
    var secondary: Color   // accent (unused in v3's minimal treatment; reserved)
}

/// The recolourable tail emblems (rasterised from Resources/Tail logos/SVG → the
/// bundled tailart<N>.png template images). Tinted at render time.
enum TailArt {
    static let count = 5
    private static var cache: [Int: UIImage?] = [:]
    static func uiImage(_ n: Int) -> UIImage? {
        if let hit = cache[n] { return hit }
        let ui = Bundle.main.path(forResource: "tailart\(n)", ofType: "png").flatMap { UIImage(contentsOfFile: $0) }
        cache[n] = ui
        return ui
    }
}

/// Per-type placement: titles on the fuselage + the tail emblem on the fin.
/// Fractions of the fitted-image rect (0…1). `scale` = size as a fraction of height.
struct LiveryPlacement {
    var titleCX: CGFloat, titleCY: CGFloat, titleW: CGFloat, titleScale: CGFloat
    var tailCX: CGFloat, tailCY: CGFloat, tailScale: CGFloat

    static func forType(_ id: String) -> LiveryPlacement {
        switch id {
        // titleCY sits ON the window line (fuselage vertical centre) so the windows
        // punch through the letters as cutouts via the multiply blend — the United look.
        case "A319", "A320", "A321", "A319NEO", "A320NEO", "A321NEO":
            return .init(titleCX: 0.37, titleCY: 0.62, titleW: 0.38, titleScale: 0.17,
                         tailCX: 0.885, tailCY: 0.24, tailScale: 0.18)
        case "DH8B":
            return .init(titleCX: 0.575, titleCY: 0.66, titleW: 0.28, titleScale: 0.13,
                         tailCX: 0.875, tailCY: 0.19, tailScale: 0.19)
        default:
            return .init(titleCX: 0.38, titleCY: 0.62, titleW: 0.34, titleScale: 0.15,
                         tailCX: 0.88, tailCY: 0.22, tailScale: 0.18)
        }
    }
}

struct AircraftLiveryImage: View {
    let typeID: String
    let name: String
    let colors: LiveryColors
    /// 1…5, or nil for no tail emblem.
    var tailArt: Int? = 1
    /// Which palette colour tints the emblem.
    var tailUsesSecondary: Bool = false

    var body: some View {
        let ui = AircraftArt.uiImage(for: typeID)
        let aspect = ui.map { $0.size.width / max(1, $0.size.height) } ?? (1024.0 / 306.0)
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { if let ui { Image(uiImage: ui).resizable().scaledToFit() } }
            .overlay {
                GeometryReader { geo in
                    let p = LiveryPlacement.forType(typeID)
                    // Titles — solid primary, multiply so the fuselage shading shows through.
                    Text(name.uppercased())
                        .font(.karla(geo.size.height * p.titleScale, .heavy))
                        .kerning(geo.size.height * p.titleScale * 0.02)
                        .foregroundStyle(colors.primary)
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .frame(width: geo.size.width * p.titleW)
                        .blendMode(.multiply)
                        .position(x: geo.size.width * p.titleCX, y: geo.size.height * p.titleCY)

                    // Tail emblem — tinted template, placed on the fin.
                    if let n = tailArt, let tail = TailArt.uiImage(n) {
                        Image(uiImage: tail)
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .foregroundStyle(tailUsesSecondary ? colors.secondary : colors.primary)
                            .frame(width: geo.size.height * p.tailScale,
                                   height: geo.size.height * p.tailScale)
                            .position(x: geo.size.width * p.tailCX, y: geo.size.height * p.tailCY)
                    }
                }
            }
    }
}

// MARK: - Prototype preview (branch-only; reached via -liveryPreview)

struct LiveryPrototypeView: View {
    let name = "Aster Air"
    let colors = LiveryColors(primary: Color(red: 0.09, green: 0.20, blue: 0.42),
                              secondary: Color(red: 0.89, green: 0.66, blue: 0.24))

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Titles above the window line + a tinted tail emblem")
                    .font(.system(size: 14, weight: .bold))
                    .multilineTextAlignment(.center).padding(.top, 6)

                // A320 with each of the 5 tail emblems.
                ForEach(1...TailArt.count, id: \.self) { n in
                    card("A320 · tail emblem \(n)") {
                        AircraftLiveryImage(typeID: "A320", name: name, colors: colors, tailArt: n)
                    }
                }
                // Turboprop with emblem 1.
                card("Dash-8 · tail emblem 1") {
                    AircraftLiveryImage(typeID: "DH8B", name: name, colors: colors, tailArt: 1)
                }
            }
            .padding(14)
        }
        .background(Color(white: 0.93))
    }

    private func card<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content().frame(height: 128)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.85)))
    }
}
