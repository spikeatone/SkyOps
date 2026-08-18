//
//  AircraftArt.swift
//  Airline Architect — bundled side-view aircraft illustrations (from the designer's Figma
//  "Aircraft Illustrations" frame). 13 done so far, keyed by AircraftType.id
//  (Resources/Illustrations/<id>.png); types without one fall back to the
//  body-type vector placeholder in the Acquire card. Loaded from the flattened
//  bundle by name (same mechanism as the fonts / Basemap.json).
//

import SwiftUI
import UIKit

enum AircraftArt {
    /// Cache so we don't hit the disk every card re-render.
    private static var cache: [String: Image?] = [:]
    private static var uiCache: [String: UIImage?] = [:]

    static func image(for typeID: String) -> Image? {
        if let hit = cache[typeID] { return hit }
        let img = uiImage(for: typeID).map { Image(uiImage: $0) }
        cache[typeID] = img
        return img
    }

    /// The raw UIImage (for callers that need the pixel size / aspect ratio,
    /// e.g. livery overlays that place text on the fuselage).
    static func uiImage(for typeID: String) -> UIImage? {
        if let hit = uiCache[typeID] { return hit }
        let ui: UIImage?
        if let path = Bundle.main.path(forResource: typeID, ofType: "png") {
            ui = UIImage(contentsOfFile: path)
        } else {
            ui = nil
        }
        uiCache[typeID] = ui
        return ui
    }
}
