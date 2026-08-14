//
//  AircraftLivery.swift
//  Airline Architect — the livery OVERLAY that paints the player's chosen name +
//  tail emblem onto a side-view aircraft illustration.
//
//  The two techniques that make it read as a real paint job (from the prototype):
//   1. TITLES on the WINDOW LINE with .blendMode(.multiply) — placed at the
//      fuselage vertical centre (not above the windows), the multiply blend makes
//      the illustration's own dark windows punch through the letters as cutouts
//      (the United look). No per-window masking needed.
//   2. TAIL EMBLEM tinted (.renderingMode(.template)) + placed on the fin.
//
//  Model lives in Livery.swift (LiveryFont / LiveryPalette / TailArt / Livery).
//

import SwiftUI

/// Per-type placement of the titles + tail emblem, as fractions (0…1) of the
/// fitted-image rect. `scale` is a fraction of image height.
///
/// The emblems are now NORMALISED (each trimmed to its artwork + centred in a
/// square), so `tailScale` is a consistent visual weight across all 10 and a
/// single fin placement centres any of them.
struct LiveryPlacement {
    var titleCX: CGFloat, titleCY: CGFloat, titleW: CGFloat, titleScale: CGFloat
    var tailCX: CGFloat, tailCY: CGFloat, tailScale: CGFloat

    static func forType(_ id: String) -> LiveryPlacement {
        switch id {
        // 737 MAX 9 — the livery-design REFERENCE (tuned against MAX9.png). The
        // fin sits high-right; titles run forward over the fuselage window line.
        // titleCY = 0.665 is the MEASURED window-row centre of MAX9.png (the
        // dashed cabin-window line), so the multiply blend punches the windows
        // through the letters — the "United" look. Don't nudge it off the row.
        // titleCX pushed forward (toward the nose) per designer — reads better and
        // leaves long airline names more room before they reach the wing box.
        case "MAX9", "MAX8", "B737700", "B737800", "B739":
            return .init(titleCX: 0.33, titleCY: 0.665, titleW: 0.42, titleScale: 0.16,
                         tailCX: 0.848, tailCY: 0.34, tailScale: 0.19)
        // A320 family — the prototype's locked reference.
        case "A319", "A320", "A321", "A319NEO", "A320NEO", "A321NEO":
            return .init(titleCX: 0.34, titleCY: 0.62, titleW: 0.38, titleScale: 0.16,
                         tailCX: 0.865, tailCY: 0.34, tailScale: 0.26)
        case "DH8B":
            return .init(titleCX: 0.25, titleCY: 0.73, titleW: 0.22, titleScale: 0.10,
                         tailCX: 0.865, tailCY: 0.30, tailScale: 0.26)
        default:
            return .init(titleCX: 0.36, titleCY: 0.61, titleW: 0.36, titleScale: 0.15,
                         tailCX: 0.87, tailCY: 0.33, tailScale: 0.25)
        }
    }
}

/// Overlays the chosen livery on a type's side-view illustration. Every Fleet /
/// Acquire surface routes its aircraft art through `AircraftArt`, so swapping this
/// in is a one-line change per surface.
struct AircraftLiveryImage: View {
    let typeID: String
    let name: String
    let livery: Livery
    /// Set false to draw only the illustration (e.g. a type with no art).
    var showLivery: Bool = true

    var body: some View {
        let ui = AircraftArt.uiImage(for: typeID)
        let aspect = ui.map { $0.size.width / max(1, $0.size.height) } ?? (1024.0 / 306.0)
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { if let ui { Image(uiImage: ui).resizable().scaledToFit() } }
            .overlay {
                if showLivery, ui != nil {
                    GeometryReader { geo in
                        let p = LiveryPlacement.forType(typeID)
                        let pal = livery.palette

                        // Titles — colour 1, multiply so the fuselage shading + the
                        // window row show through the letters.
                        Text(name.uppercased())
                            .font(livery.font.font(geo.size.height * p.titleScale))
                            .kerning(geo.size.height * p.titleScale * 0.02)
                            .foregroundStyle(pal.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .frame(width: geo.size.width * p.titleW)
                            .blendMode(.multiply)
                            .position(x: geo.size.width * p.titleCX,
                                      y: geo.size.height * p.titleCY)

                        // Tail emblem — colour 2 tint, on the fin.
                        if livery.tailArtIndex > 0, let tail = TailArt.uiImage(livery.tailArtIndex) {
                            Image(uiImage: tail)
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .foregroundStyle(pal.secondary)
                                .frame(width: geo.size.height * p.tailScale,
                                       height: geo.size.height * p.tailScale)
                                .position(x: geo.size.width * p.tailCX,
                                          y: geo.size.height * p.tailCY)
                        }
                    }
                }
            }
    }
}
