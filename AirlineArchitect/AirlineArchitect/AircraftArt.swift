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

    static func image(for typeID: String) -> Image? {
        if let hit = cache[typeID] { return hit }
        let img: Image?
        if let path = Bundle.main.path(forResource: typeID, ofType: "png"),
           let ui = UIImage(contentsOfFile: path) {
            img = Image(uiImage: ui)
        } else {
            img = nil
        }
        cache[typeID] = img
        return img
    }
}
