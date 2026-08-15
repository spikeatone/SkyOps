// Minimal stand-ins for the SwiftUI-side livery catalogs, so the sim layer can be
// compiled headlessly. Values mirror Livery.swift (5 fonts, 10 palettes, 10 emblems).
struct Livery: Equatable { var fontIndex: Int; var paletteIndex: Int; var tailArtIndex: Int }
enum LiveryFont { struct F {}; static let all = Array(repeating: F(), count: 5) }
enum LiveryPalette { struct P {}; static let all = Array(repeating: P(), count: 10) }
enum TailArt { static let count = 10 }
extension Livery { static let maxTextLength = 16 }
