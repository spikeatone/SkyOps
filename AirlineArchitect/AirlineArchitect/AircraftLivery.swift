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
        // Per-type placement, MEASURED from each illustration (window-row centre →
        // titleCY so the multiply blend punches the cabin windows through the
        // letters; forward-cabin position → titleCX; fin body → tail emblem). The
        // turboprops + small ERJs (AT46/B1900/DH8B/ERJ135/ERJ140) and MAX9 are
        // hand-tuned (marked). New types fall through to the narrowbody default.
        switch id {
        case "A220100": return .init(titleCX: 0.33, titleCY: 0.633, titleW: 0.42, titleScale: 0.16, tailCX: 0.844, tailCY: 0.303, tailScale: 0.193)
        case "A220300": return .init(titleCX: 0.33, titleCY: 0.633, titleW: 0.42, titleScale: 0.16, tailCX: 0.844, tailCY: 0.303, tailScale: 0.193)
        case "A319": return .init(titleCX: 0.339, titleCY: 0.616, titleW: 0.42, titleScale: 0.16, tailCX: 0.763, tailCY: 0.27, tailScale: 0.22)
        case "A319NEO": return .init(titleCX: 0.339, titleCY: 0.616, titleW: 0.42, titleScale: 0.16, tailCX: 0.763, tailCY: 0.27, tailScale: 0.22)
        case "A320": return .init(titleCX: 0.318, titleCY: 0.614, titleW: 0.42, titleScale: 0.16, tailCX: 0.852, tailCY: 0.271, tailScale: 0.172)
        case "A320NEO": return .init(titleCX: 0.318, titleCY: 0.614, titleW: 0.42, titleScale: 0.16, tailCX: 0.852, tailCY: 0.271, tailScale: 0.172)
        case "A321": return .init(titleCX: 0.302, titleCY: 0.6, titleW: 0.42, titleScale: 0.16, tailCX: 0.782, tailCY: 0.284, tailScale: 0.22)
        case "A321NEO": return .init(titleCX: 0.302, titleCY: 0.6, titleW: 0.42, titleScale: 0.16, tailCX: 0.782, tailCY: 0.284, tailScale: 0.22)
        case "A339": return .init(titleCX: 0.277, titleCY: 0.63, titleW: 0.42, titleScale: 0.16, tailCX: 0.894, tailCY: 0.295, tailScale: 0.194)
        case "A340": return .init(titleCX: 0.292, titleCY: 0.653, titleW: 0.42, titleScale: 0.16, tailCX: 0.852, tailCY: 0.3, tailScale: 0.19)
        case "A359": return .init(titleCX: 0.301, titleCY: 0.632, titleW: 0.42, titleScale: 0.16, tailCX: 0.859, tailCY: 0.275, tailScale: 0.162)
        case "A380": return .init(titleCX: 0.308, titleCY: 0.62, titleW: 0.42, titleScale: 0.16, tailCX: 0.875, tailCY: 0.302, tailScale: 0.22)
        case "AT46": return .init(titleCX: 0.245, titleCY: 0.615, titleW: 0.22, titleScale: 0.105, tailCX: 0.83, tailCY: 0.24, tailScale: 0.15) // tuned
        case "B1900": return .init(titleCX: 0.295, titleCY: 0.585, titleW: 0.24, titleScale: 0.095, tailCX: 0.855, tailCY: 0.275, tailScale: 0.16) // tuned
        case "B737700": return .init(titleCX: 0.328, titleCY: 0.671, titleW: 0.42, titleScale: 0.16, tailCX: 0.808, tailCY: 0.302, tailScale: 0.186)
        case "B737800": return .init(titleCX: 0.298, titleCY: 0.674, titleW: 0.42, titleScale: 0.16, tailCX: 0.866, tailCY: 0.291, tailScale: 0.188)
        case "B739": return .init(titleCX: 0.306, titleCY: 0.661, titleW: 0.42, titleScale: 0.16, tailCX: 0.865, tailCY: 0.292, tailScale: 0.17)
        case "B747": return .init(titleCX: 0.255, titleCY: 0.673, titleW: 0.42, titleScale: 0.16, tailCX: 0.887, tailCY: 0.287, tailScale: 0.215)
        case "B773": return .init(titleCX: 0.275, titleCY: 0.668, titleW: 0.42, titleScale: 0.16, tailCX: 0.894, tailCY: 0.3, tailScale: 0.166)
        case "B788": return .init(titleCX: 0.295, titleCY: 0.649, titleW: 0.42, titleScale: 0.16, tailCX: 0.885, tailCY: 0.296, tailScale: 0.201)
        case "B789": return .init(titleCX: 0.295, titleCY: 0.645, titleW: 0.42, titleScale: 0.16, tailCX: 0.886, tailCY: 0.294, tailScale: 0.184)
        case "B78J": return .init(titleCX: 0.298, titleCY: 0.654, titleW: 0.42, titleScale: 0.16, tailCX: 0.888, tailCY: 0.3, tailScale: 0.159)
        case "CRJ1000": return .init(titleCX: 0.291, titleCY: 0.589, titleW: 0.42, titleScale: 0.16, tailCX: 0.91, tailCY: 0.29, tailScale: 0.182)
        case "CRJ900": return .init(titleCX: 0.287, titleCY: 0.58, titleW: 0.42, titleScale: 0.16, tailCX: 0.915, tailCY: 0.263, tailScale: 0.197)
        case "D328": return .init(titleCX: 0.30, titleCY: 0.675, titleW: 0.30, titleScale: 0.13, tailCX: 0.854, tailCY: 0.28, tailScale: 0.19) // tuned
        case "DH8B": return .init(titleCX: 0.255, titleCY: 0.6, titleW: 0.26, titleScale: 0.1, tailCX: 0.865, tailCY: 0.28, tailScale: 0.17) // tuned
        case "E170": return .init(titleCX: 0.323, titleCY: 0.644, titleW: 0.42, titleScale: 0.16, tailCX: 0.866, tailCY: 0.291, tailScale: 0.198)
        case "E175": return .init(titleCX: 0.323, titleCY: 0.644, titleW: 0.42, titleScale: 0.16, tailCX: 0.866, tailCY: 0.291, tailScale: 0.198)
        case "E190": return .init(titleCX: 0.302, titleCY: 0.632, titleW: 0.42, titleScale: 0.16, tailCX: 0.883, tailCY: 0.305, tailScale: 0.166)
        case "E195": return .init(titleCX: 0.328, titleCY: 0.608, titleW: 0.42, titleScale: 0.16, tailCX: 0.89, tailCY: 0.293, tailScale: 0.15)
        case "ERJ135": return .init(titleCX: 0.3, titleCY: 0.615, titleW: 0.34, titleScale: 0.13, tailCX: 0.855, tailCY: 0.3, tailScale: 0.17) // tuned
        case "ERJ140": return .init(titleCX: 0.3, titleCY: 0.615, titleW: 0.34, titleScale: 0.13, tailCX: 0.87, tailCY: 0.29, tailScale: 0.17) // tuned
        case "ERJ145": return .init(titleCX: 0.333, titleCY: 0.613, titleW: 0.42, titleScale: 0.16, tailCX: 0.895, tailCY: 0.297, tailScale: 0.179)
        case "MAX8": return .init(titleCX: 0.3, titleCY: 0.655, titleW: 0.42, titleScale: 0.16, tailCX: 0.867, tailCY: 0.297, tailScale: 0.186)
        case "MAX9": return .init(titleCX: 0.33, titleCY: 0.665, titleW: 0.42, titleScale: 0.16, tailCX: 0.848, tailCY: 0.34, tailScale: 0.19) // tuned
        default:
            return .init(titleCX: 0.32, titleCY: 0.63, titleW: 0.42, titleScale: 0.16,
                         tailCX: 0.87, tailCY: 0.30, tailScale: 0.18)
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
