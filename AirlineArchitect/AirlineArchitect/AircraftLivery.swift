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
        // Per-type placement. TITLES are hand-tuned (window-row centre → titleCY so
        // the multiply blend punches the windows through the letters; forward-cabin →
        // titleCX). TAIL EMBLEMS are AUTO-PLACED: a fin-detection pass (this session's
        // git history) finds each illustration's vertical stabiliser and centres the
        // emblem on the fin BODY — tailCX/tailCY/tailScale below are its output, baked
        // in as constants (no runtime image work). To re-derive after new/changed art,
        // re-run that pass. New types fall through to the narrowbody default.
        switch id {
        case "A220100": return .init(titleCX: 0.33, titleCY: 0.65, titleW: 0.42, titleScale: 0.125, tailCX: 0.842, tailCY: 0.384, tailScale: 0.632) // tuned
        case "A220300": return .init(titleCX: 0.33, titleCY: 0.65, titleW: 0.42, titleScale: 0.125, tailCX: 0.842, tailCY: 0.384, tailScale: 0.632) // tuned
        case "A319": return .init(titleCX: 0.339, titleCY: 0.63, titleW: 0.42, titleScale: 0.135, tailCX: 0.81, tailCY: 0.347, tailScale: 0.591) // tuned
        case "A319NEO": return .init(titleCX: 0.339, titleCY: 0.63, titleW: 0.42, titleScale: 0.135, tailCX: 0.81, tailCY: 0.347, tailScale: 0.591) // tuned
        case "A320": return .init(titleCX: 0.318, titleCY: 0.628, titleW: 0.42, titleScale: 0.135, tailCX: 0.852, tailCY: 0.348, tailScale: 0.593) // tuned
        case "A320NEO": return .init(titleCX: 0.318, titleCY: 0.628, titleW: 0.42, titleScale: 0.135, tailCX: 0.852, tailCY: 0.348, tailScale: 0.593) // tuned
        case "A321": return .init(titleCX: 0.302, titleCY: 0.615, titleW: 0.42, titleScale: 0.135, tailCX: 0.886, tailCY: 0.321, tailScale: 0.525) // tuned
        case "A321NEO": return .init(titleCX: 0.302, titleCY: 0.615, titleW: 0.42, titleScale: 0.135, tailCX: 0.886, tailCY: 0.321, tailScale: 0.525) // tuned
        case "A339": return .init(titleCX: 0.277, titleCY: 0.63, titleW: 0.42, titleScale: 0.144, tailCX: 0.891, tailCY: 0.377, tailScale: 0.639) // tuned
        case "A340": return .init(titleCX: 0.292, titleCY: 0.653, titleW: 0.42, titleScale: 0.144, tailCX: 0.85, tailCY: 0.382, tailScale: 0.638) // tuned
        case "A359": return .init(titleCX: 0.301, titleCY: 0.632, titleW: 0.42, titleScale: 0.145, tailCX: 0.852, tailCY: 0.353, tailScale: 0.599) // tuned
        case "A380": return .init(titleCX: 0.295, titleCY: 0.685, titleW: 0.42, titleScale: 0.125, tailCX: 0.865, tailCY: 0.388, tailScale: 0.668) // tuned
        case "AT46": return .init(titleCX: 0.28, titleCY: 0.665, titleW: 0.24, titleScale: 0.105, tailCX: 0.822, tailCY: 0.244, tailScale: 0.365) // tuned
        case "B1900": return .init(titleCX: 0.36, titleCY: 0.585, titleW: 0.30, titleScale: 0.115, tailCX: 0.829, tailCY: 0.312, tailScale: 0.383) // tuned
        case "B737700": return .init(titleCX: 0.328, titleCY: 0.671, titleW: 0.42, titleScale: 0.125, tailCX: 0.809, tailCY: 0.386, tailScale: 0.653) // tuned
        case "B737800": return .init(titleCX: 0.298, titleCY: 0.674, titleW: 0.42, titleScale: 0.125, tailCX: 0.867, tailCY: 0.378, tailScale: 0.678) // tuned
        case "B739": return .init(titleCX: 0.306, titleCY: 0.675, titleW: 0.42, titleScale: 0.125, tailCX: 0.867, tailCY: 0.367, tailScale: 0.634) // tuned
        case "B747": return .init(titleCX: 0.255, titleCY: 0.673, titleW: 0.42, titleScale: 0.145, tailCX: 0.883, tailCY: 0.363, tailScale: 0.584) // tuned
        case "B773": return .init(titleCX: 0.262, titleCY: 0.668, titleW: 0.42, titleScale: 0.145, tailCX: 0.889, tailCY: 0.38, tailScale: 0.62) // tuned
        case "B788": return .init(titleCX: 0.282, titleCY: 0.649, titleW: 0.42, titleScale: 0.135, tailCX: 0.88, tailCY: 0.378, tailScale: 0.641) // tuned
        case "B789": return .init(titleCX: 0.27, titleCY: 0.645, titleW: 0.42, titleScale: 0.145, tailCX: 0.882, tailCY: 0.379, tailScale: 0.654) // tuned
        case "B78J": return .init(titleCX: 0.285, titleCY: 0.654, titleW: 0.42, titleScale: 0.16, tailCX: 0.883, tailCY: 0.379, tailScale: 0.612) // tuned
        case "CRJ1000": return .init(titleCX: 0.291, titleCY: 0.61, titleW: 0.42, titleScale: 0.16, tailCX: 0.881, tailCY: 0.349, tailScale: 0.463) // tuned
        case "CRJ900": return .init(titleCX: 0.287, titleCY: 0.605, titleW: 0.42, titleScale: 0.16, tailCX: 0.884, tailCY: 0.325, tailScale: 0.481) // tuned
        case "D328": return .init(titleCX: 0.30, titleCY: 0.71, titleW: 0.30, titleScale: 0.11, tailCX: 0.852, tailCY: 0.369, tailScale: 0.627) // tuned
        case "DH8B": return .init(titleCX: 0.27, titleCY: 0.69, titleW: 0.22, titleScale: 0.072, tailCX: 0.851, tailCY: 0.278, tailScale: 0.451) // tuned
        case "E170": return .init(titleCX: 0.34, titleCY: 0.644, titleW: 0.42, titleScale: 0.112, tailCX: 0.87, tailCY: 0.374, tailScale: 0.642) // tuned
        case "E175": return .init(titleCX: 0.34, titleCY: 0.644, titleW: 0.42, titleScale: 0.112, tailCX: 0.87, tailCY: 0.374, tailScale: 0.642) // tuned
        case "E190": return .init(titleCX: 0.302, titleCY: 0.632, titleW: 0.42, titleScale: 0.112, tailCX: 0.883, tailCY: 0.385, tailScale: 0.62) // tuned
        case "E195": return .init(titleCX: 0.328, titleCY: 0.64, titleW: 0.42, titleScale: 0.13, tailCX: 0.891, tailCY: 0.37, tailScale: 0.593) // tuned
        case "ERJ135": return .init(titleCX: 0.33, titleCY: 0.615, titleW: 0.34, titleScale: 0.13, tailCX: 0.832, tailCY: 0.344, tailScale: 0.5) // tuned
        case "ERJ140": return .init(titleCX: 0.33, titleCY: 0.615, titleW: 0.34, titleScale: 0.13, tailCX: 0.858, tailCY: 0.335, tailScale: 0.507) // tuned
        case "ERJ145": return .init(titleCX: 0.333, titleCY: 0.645, titleW: 0.42, titleScale: 0.144, tailCX: 0.88, tailCY: 0.364, tailScale: 0.516) // tuned
        case "MAX8": return .init(titleCX: 0.3, titleCY: 0.655, titleW: 0.42, titleScale: 0.14, tailCX: 0.867, tailCY: 0.38, tailScale: 0.643) // tuned
        case "MAX9": return .init(titleCX: 0.32, titleCY: 0.665, titleW: 0.42, titleScale: 0.144, tailCX: 0.847, tailCY: 0.357, tailScale: 0.622) // tuned
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
