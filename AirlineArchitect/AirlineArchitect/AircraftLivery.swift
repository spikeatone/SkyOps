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
        // titleCX). TAIL EMBLEMS are AUTO-FITTED: a pass (this session's git history)
        // detects each fin's silhouette and finds the LARGEST SQUARE that fits fully
        // INSIDE it, then insets by a comfort margin — so the emblem is centred on the
        // fin body and can NEVER exceed the fin edge, on any airframe. tailCX/CY/Scale
        // below are that pass's output, baked in as constants (no runtime image work).
        // Re-run the pass after new/changed art. New types → narrowbody default.
        switch id {
        case "A220100": return .init(titleCX: 0.33, titleCY: 0.65, titleW: 0.42, titleScale: 0.125, tailCX: 0.83, tailCY: 0.301, tailScale: 0.811) // tuned
        case "A220300": return .init(titleCX: 0.33, titleCY: 0.65, titleW: 0.42, titleScale: 0.125, tailCX: 0.83, tailCY: 0.301, tailScale: 0.811) // tuned
        case "A319": return .init(titleCX: 0.339, titleCY: 0.63, titleW: 0.42, titleScale: 0.135, tailCX: 0.801, tailCY: 0.269, tailScale: 0.734) // tuned
        case "A319NEO": return .init(titleCX: 0.339, titleCY: 0.63, titleW: 0.42, titleScale: 0.135, tailCX: 0.801, tailCY: 0.269, tailScale: 0.734) // tuned
        case "A320": return .init(titleCX: 0.318, titleCY: 0.628, titleW: 0.42, titleScale: 0.135, tailCX: 0.843, tailCY: 0.27, tailScale: 0.737) // tuned
        case "A320NEO": return .init(titleCX: 0.318, titleCY: 0.628, titleW: 0.42, titleScale: 0.135, tailCX: 0.843, tailCY: 0.27, tailScale: 0.737) // tuned
        case "A321": return .init(titleCX: 0.302, titleCY: 0.615, titleW: 0.42, titleScale: 0.135, tailCX: 0.88, tailCY: 0.252, tailScale: 0.65) // tuned
        case "A321NEO": return .init(titleCX: 0.302, titleCY: 0.615, titleW: 0.42, titleScale: 0.135, tailCX: 0.88, tailCY: 0.252, tailScale: 0.65) // tuned
        case "A339": return .init(titleCX: 0.277, titleCY: 0.63, titleW: 0.42, titleScale: 0.144, tailCX: 0.876, tailCY: 0.293, tailScale: 1.018) // tuned
        case "A340": return .init(titleCX: 0.292, titleCY: 0.653, titleW: 0.42, titleScale: 0.144, tailCX: 0.838, tailCY: 0.298, tailScale: 0.979) // tuned
        case "A359": return .init(titleCX: 0.301, titleCY: 0.632, titleW: 0.42, titleScale: 0.145, tailCX: 0.852, tailCY: 0.273, tailScale: 0.849) // tuned
        case "A380": return .init(titleCX: 0.295, titleCY: 0.685, titleW: 0.42, titleScale: 0.125, tailCX: 0.864, tailCY: 0.3, tailScale: 0.875) // tuned
        case "AT46": return .init(titleCX: 0.64, titleCY: 0.628, titleW: 0.2, titleScale: 0.08, tailCX: 0.786, tailCY: 0.385, tailScale: 0.56) // tuned
        case "B1900": return .init(titleCX: 0.6, titleCY: 0.61, titleW: 0.2, titleScale: 0.078, tailCX: 0.819, tailCY: 0.384, tailScale: 0.53) // tuned
        case "B737700": return .init(titleCX: 0.328, titleCY: 0.671, titleW: 0.42, titleScale: 0.125, tailCX: 0.784, tailCY: 0.3, tailScale: 0.872) // tuned
        case "B737800": return .init(titleCX: 0.298, titleCY: 0.674, titleW: 0.42, titleScale: 0.125, tailCX: 0.843, tailCY: 0.289, tailScale: 0.91) // tuned
        case "B739": return .init(titleCX: 0.306, titleCY: 0.675, titleW: 0.42, titleScale: 0.125, tailCX: 0.851, tailCY: 0.283, tailScale: 0.807) // tuned
        case "B747": return .init(titleCX: 0.255, titleCY: 0.673, titleW: 0.42, titleScale: 0.145, tailCX: 0.877, tailCY: 0.286, tailScale: 0.94) // tuned
        case "B773": return .init(titleCX: 0.262, titleCY: 0.668, titleW: 0.42, titleScale: 0.145, tailCX: 0.886, tailCY: 0.299, tailScale: 0.804) // tuned
        case "B788": return .init(titleCX: 0.282, titleCY: 0.649, titleW: 0.42, titleScale: 0.135, tailCX: 0.872, tailCY: 0.294, tailScale: 0.861) // tuned
        case "B789": return .init(titleCX: 0.27, titleCY: 0.645, titleW: 0.42, titleScale: 0.145, tailCX: 0.873, tailCY: 0.293, tailScale: 0.895) // tuned
        case "B78J": return .init(titleCX: 0.285, titleCY: 0.654, titleW: 0.42, titleScale: 0.16, tailCX: 0.878, tailCY: 0.298, tailScale: 0.812) // tuned
        case "CRJ1000": return .init(titleCX: 0.291, titleCY: 0.61, titleW: 0.42, titleScale: 0.16, tailCX: 0.87, tailCY: 0.287, tailScale: 1.186) // tuned
        case "CRJ900": return .init(titleCX: 0.287, titleCY: 0.605, titleW: 0.42, titleScale: 0.16, tailCX: 0.872, tailCY: 0.261, tailScale: 1.241) // tuned
        case "D328": return .init(titleCX: 0.61, titleCY: 0.68, titleW: 0.2, titleScale: 0.078, tailCX: 0.808, tailCY: 0.346, tailScale: 0.7) // tuned
        case "DH8B": return .init(titleCX: 0.615, titleCY: 0.68, titleW: 0.38, titleScale: 0.144, tailCX: 0.83, tailCY: 0.362, tailScale: 0.73) // tuned
        case "E170": return .init(titleCX: 0.34, titleCY: 0.644, titleW: 0.42, titleScale: 0.112, tailCX: 0.844, tailCY: 0.29, tailScale: 0.904) // tuned
        case "E175": return .init(titleCX: 0.34, titleCY: 0.644, titleW: 0.42, titleScale: 0.112, tailCX: 0.844, tailCY: 0.29, tailScale: 0.904) // tuned
        case "E190": return .init(titleCX: 0.302, titleCY: 0.632, titleW: 0.42, titleScale: 0.112, tailCX: 0.871, tailCY: 0.303, tailScale: 0.756) // tuned
        case "E195": return .init(titleCX: 0.328, titleCY: 0.64, titleW: 0.42, titleScale: 0.13, tailCX: 0.871, tailCY: 0.291, tailScale: 0.826) // tuned
        case "ERJ135": return .init(titleCX: 0.33, titleCY: 0.615, titleW: 0.34, titleScale: 0.13, tailCX: 0.794, tailCY: 0.277, tailScale: 1.337) // tuned
        case "ERJ140": return .init(titleCX: 0.33, titleCY: 0.615, titleW: 0.34, titleScale: 0.13, tailCX: 0.821, tailCY: 0.268, tailScale: 1.342) // tuned
        case "ERJ145": return .init(titleCX: 0.333, titleCY: 0.645, titleW: 0.42, titleScale: 0.144, tailCX: 0.843, tailCY: 0.295, tailScale: 1.373) // tuned
        case "MAX8": return .init(titleCX: 0.3, titleCY: 0.655, titleW: 0.42, titleScale: 0.14, tailCX: 0.843, tailCY: 0.295, tailScale: 0.863) // tuned
        case "MAX9": return .init(titleCX: 0.32, titleCY: 0.665, titleW: 0.42, titleScale: 0.144, tailCX: 0.834, tailCY: 0.276, tailScale: 0.767) // tuned
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
                        let finMask = FinMask.uiImage(for: typeID)

                        // PAINTED TAIL — the whole fin filled with the secondary colour,
                        // and the WHITE emblem oversized on top, both CLIPPED to the fin
                        // silhouette (United / Delta / Lufthansa style). An emblem larger
                        // than the fin simply clips at the edge instead of overflowing.
                        if let finMask {
                            ZStack {
                                pal.secondary                    // fill the fin
                                if livery.tailArtIndex > 0, let tail = TailArt.uiImage(livery.tailArtIndex) {
                                    // Per-emblem nudge: some emblems carry their visual
                                    // weight forward/high, so a small offset (fraction of
                                    // the emblem box) re-centres them on the fin.
                                    let nudge = TailArt.nudge(livery.tailArtIndex)
                                    let emSize = geo.size.height * p.tailScale
                                    Image(uiImage: tail)
                                        .renderingMode(.template)
                                        .resizable().scaledToFit()
                                        .foregroundStyle(.white)  // white emblem on the coloured tail
                                        .frame(width: emSize, height: emSize)
                                        .position(x: geo.size.width * p.tailCX + emSize * nudge.dx,
                                                  y: geo.size.height * p.tailCY + emSize * nudge.dy)
                                }
                            }
                            .mask(
                                Image(uiImage: finMask).resizable().scaledToFit()
                                    .frame(width: geo.size.width, height: geo.size.height)
                            )
                        }

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
                    }
                }
            }
    }
}
