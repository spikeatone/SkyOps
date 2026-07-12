//
//  Airport.swift
//  SkyOps — Phase 1
//
//  A minimal airport for the tick-engine port: real IATA code + real lat/lon.
//  `unit` is its resolution-independent projected position; `screen` is where
//  it lands in the current view (assigned by Simulation.layout(in:)). The
//  fuller AIRPORTS table (48 airports, fees, ground stops) is a later phase —
//  Phase 1 only needs two real points to fly one route between.
//

import Foundation
import CoreGraphics

final class Airport: Identifiable {
    let id = UUID()
    let code: String
    let lat: Double
    let lon: Double

    /// Resolution-independent projected position (world units).
    let unit: CGPoint

    /// Pixel position in the current view. Recomputed whenever the view
    /// resizes; the flight-path math works in this pixel space, exactly like
    /// the prototype projected into canvas pixels.
    var screen: CGPoint = .zero

    init(code: String, lat: Double, lon: Double) {
        self.code = code
        self.lat = lat
        self.lon = lon
        self.unit = GeoProjection.unit(lat: lat, lon: lon)
    }
}
