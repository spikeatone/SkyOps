//
//  GeoProjection.swift
//  Airline Architect — Phase 1
//
//  Lightweight equirectangular projection with a longitude cosine correction
//  at the map's centre latitude, ported from the prototype's projectPoint().
//  NOT a survey-grade conic projection — a defensible approximation at this
//  latitude range. It converts an airport's real lat/lon into resolution-
//  independent "world units"; MapLayout (see Airport/Simulation) then fits
//  those units into the actual view size in pixels.
//

import Foundation
import CoreGraphics

enum GeoProjection {
    /// Same bounds as the prototype's WORLD_BOUNDS (Alaska → Hawaii → East Coast).
    static let latMin: Double = 18
    static let latMax: Double = 71
    static let lonMin: Double = -170
    static let lonMax: Double = -66.5

    /// Longitude compression at the centre latitude, so east–west distances
    /// aren't overstated the further north you go.
    static let lonCorrection: Double = {
        let avgLatRad = ((latMin + latMax) / 2) * .pi / 180
        return cos(avgLatRad)
    }()

    /// Project real lat/lon to unscaled world units (y grows southward, so
    /// higher latitude → smaller y, matching screen coordinates).
    static func unit(lat: Double, lon: Double) -> CGPoint {
        let xUnits = (lon - lonMin) * lonCorrection
        let yUnits = (latMax - lat)
        return CGPoint(x: xUnits, y: yUnits)
    }
}
