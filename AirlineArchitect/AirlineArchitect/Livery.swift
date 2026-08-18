//
//  Livery.swift
//  Airline Architect — the player's chosen airline livery (font + palette + tail
//  emblem), picked on the livery design screen right after naming, and painted on
//  every side-view aircraft illustration (Fleet / Marketplace / tooltip).
//
//  Three catalogs live here (all value types, no state):
//   • LiveryFont    — 5 bundled OFL display faces the name is painted in.
//   • LiveryPalette — 10 designer-authored 2-colour packs (colour 1 = titles,
//                     colour 2 = tail emblem tint).
//   • TailArt       — the 10 normalised, tintable tail emblems.
//
//  The chosen selection is stored on Simulation as three small ints
//  (fontIndex / paletteIndex / tailArtIndex) + persisted nil-safe, exactly like
//  playerTailCode. Everything else derives from those three ints via the catalogs,
//  so a save only carries the indices, never resolved colours/fonts.
//

import SwiftUI
import UIKit

// MARK: - Colour helper

extension Color {
    /// Build a Color from a 0xRRGGBB hex literal.
    init(hex h: UInt) {
        self.init(red: Double((h >> 16) & 0xFF) / 255,
                  green: Double((h >> 8) & 0xFF) / 255,
                  blue: Double(h & 0xFF) / 255)
    }
}

// MARK: - Fonts

/// A display face the airline name can be painted in. `psName` is the font's
/// PostScript name (registered via Info.plist UIAppFonts); Font.custom falls back
/// to the system font if a face is somehow missing, so this degrades gracefully.
struct LiveryFont: Identifiable {
    let id: Int
    let label: String          // shown in the picker
    let psName: String         // PostScript name for Font.custom
    /// Some display faces read visually smaller/larger at the same point size;
    /// this multiplies the placement scale so titles look balanced across faces.
    let sizeAdjust: CGFloat

    func font(_ size: CGFloat) -> Font { .custom(psName, size: size * sizeAdjust) }

    /// The 5 bundled livery faces, chosen for distinct airline personalities.
    static let all: [LiveryFont] = [
        .init(id: 0, label: "Archivo",  psName: "ArchivoBlack-Regular",   sizeAdjust: 0.92),  // heavy grotesque
        .init(id: 1, label: "Bebas",    psName: "BebasNeue-Regular",      sizeAdjust: 1.32),  // tall condensed caps
        .init(id: 2, label: "Poppins",  psName: "Poppins-SemiBold",       sizeAdjust: 1.00),  // geometric, clean
        .init(id: 3, label: "Righteous",psName: "Righteous-Regular",      sizeAdjust: 1.02),  // rounded retro
        .init(id: 4, label: "Serif",    psName: "DMSerifDisplay-Regular",  sizeAdjust: 1.06),  // elegant serif
    ]

    static func at(_ i: Int) -> LiveryFont { all[max(0, min(all.count - 1, i))] }
}

// MARK: - Palettes

/// A designer-authored 2-colour pack. `primary` (colour 1) paints the fuselage
/// titles; `secondary` (colour 2) tints the tail emblem.
struct LiveryPalette: Identifiable {
    let id: Int
    let name: String
    let primary: Color
    let secondary: Color

    /// The 10 designer palettes (name · #primary · #secondary · character).
    /// To retune, edit the hex literals here — nothing else references the colours.
    static let all: [LiveryPalette] = [
        .init(id: 0, name: "Atlantic",  primary: Color(hex: 0x175A8A), secondary: Color(hex: 0x19A0A5)),  // established global carrier
        .init(id: 1, name: "Cardinal",  primary: Color(hex: 0xA93646), secondary: Color(hex: 0xD75B32)),  // bold, premium
        .init(id: 2, name: "Pacific",   primary: Color(hex: 0x164E72), secondary: Color(hex: 0x367FB4)),  // clean, corporate aviation
        .init(id: 3, name: "Meridian",  primary: Color(hex: 0x553C8C), secondary: Color(hex: 0xB34673)),  // distinctive, upscale
        .init(id: 4, name: "Evergreen", primary: Color(hex: 0x28634F), secondary: Color(hex: 0x6D8437)),  // outdoorsy, regional
        .init(id: 5, name: "Copper",    primary: Color(hex: 0x91472E), secondary: Color(hex: 0xC46B32)),  // warm, heritage airline
        .init(id: 6, name: "Azure",     primary: Color(hex: 0x174B8A), secondary: Color(hex: 0x5661B3)),  // modern international
        .init(id: 7, name: "Tropic",    primary: Color(hex: 0x08766F), secondary: Color(hex: 0x2471A3)),  // leisure/island carrier
        .init(id: 8, name: "Burgundy",  primary: Color(hex: 0x762E46), secondary: Color(hex: 0xA95672)),  // luxury, sophisticated
        .init(id: 9, name: "Velocity",  primary: Color(hex: 0x333F76), secondary: Color(hex: 0xD04C46)),  // sporty, contemporary
    ]

    static func at(_ i: Int) -> LiveryPalette { all[max(0, min(all.count - 1, i))] }
}

// MARK: - Tail emblems

/// The 10 recolourable tail emblems (normalised from the designer's SVGs to
/// bundled tailart<1…10>.png template images — each trimmed to its own artwork
/// bounds and centred in a square, so one placement centres any of them).
/// Tinted at render time via `.renderingMode(.template)`.
enum TailArt {
    static let count = 10
    private static var cache: [Int: UIImage?] = [:]
    /// n is 1-based (tailart1…tailart10).
    static func uiImage(_ n: Int) -> UIImage? {
        if let hit = cache[n] { return hit }
        let ui = Bundle.main.path(forResource: "tailart\(n)", ofType: "png")
            .flatMap { UIImage(contentsOfFile: $0) }
        cache[n] = ui
        return ui
    }

    /// Per-emblem re-centring nudge on the fin, as a fraction of the emblem box.
    /// Some emblems carry their visual mass forward/high; a small +dx pushes them
    /// back (toward the fin trailing edge), +dy pushes them down. 1-based index.
    static func nudge(_ n: Int) -> (dx: CGFloat, dy: CGFloat) {
        switch n {
        case 3: return (0.10, 0)   // eagle — mass is forward, push back
        case 4: return (0.10, 0)   // shield
        case 5: return (0.10, 0)   // swoosh-arrow
        case 7: return (0.10, 0)   // heart
        case 9: return (0.10, 0)   // leaf — push back within the fin
        default: return (0, 0)
        }
    }
}

// MARK: - Fin masks (painted-tail livery)

/// The per-aircraft FIN silhouette (white fin shape on transparent), generated from
/// each illustration by `aa-livery/fin_place.py` and bundled as `<TYPE>_fin.png`.
/// Used to (1) paint the fin the palette's secondary colour and (2) CLIP the white
/// emblem to the fin shape — a solid-tail livery (United / Delta / Lufthansa style)
/// where an oversized emblem simply clips at the fin edge instead of overflowing.
enum FinMask {
    private static var cache: [String: UIImage?] = [:]
    static func uiImage(for typeID: String) -> UIImage? {
        if let hit = cache[typeID] { return hit }
        let ui = Bundle.main.path(forResource: "\(typeID)_fin", ofType: "png")
            .flatMap { UIImage(contentsOfFile: $0) }
        cache[typeID] = ui
        return ui
    }
}

// MARK: - The resolved selection

/// The player's chosen livery, resolved from the three stored indices. Passed
/// into `AircraftLiveryImage`. Equatable so SwiftUI can diff it cheaply.
struct Livery: Equatable {
    /// Max characters for the fuselage text — long enough for real titles
    /// ("Singapore" style) but short enough to stay on the window line.
    static let maxTextLength = 16

    var fontIndex: Int
    var paletteIndex: Int
    /// 1-based tail emblem (1…10), or 0 for "no emblem".
    var tailArtIndex: Int

    var font: LiveryFont { .at(fontIndex) }
    var palette: LiveryPalette { .at(paletteIndex) }

    /// A sensible default (first font, first palette, first emblem) for the very
    /// first frame before the player has designed anything, and for legacy saves.
    static let `default` = Livery(fontIndex: 0, paletteIndex: 0, tailArtIndex: 1)
}
