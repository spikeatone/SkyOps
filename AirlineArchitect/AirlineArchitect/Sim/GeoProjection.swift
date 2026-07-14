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
    /// World bounds. Extended south to Tierra del Fuego and east to Brazil's
    /// coast so the map covers Alaska → Hawaii → the Americas down to Argentina.
    /// `lonMin`/`latMax` are UNCHANGED and the cosine reference is PINNED (see
    /// `cosRefLat`), so every previously-added point (US/Canada, all US
    /// airports) projects to the exact same unit position as before — only the
    /// canvas grows to the south and east.
    static let latMin: Double = -56    // was 18 — now includes South America
    static let latMax: Double = 71
    static let lonMin: Double = -170
    static let lonMax: Double = 180     // was -33 — now spans the Eastern Hemisphere
                                        // (Europe/Africa/Asia/Australia). unit()
                                        // doesn't use lonMax, so existing points
                                        // are unaffected; only the canvas grows east.

    /// Latitude the longitude compression is anchored to. Pinned at the ORIGINAL
    /// map centre (18…71 → 44.5) so extending the bounds doesn't re-scale or
    /// shift the existing North American geometry.
    static let cosRefLat: Double = 44.5

    /// Longitude compression, so east–west distances aren't overstated. Anchored
    /// at `cosRefLat` (not the new bounds' centre) to preserve existing layout.
    static let lonCorrection: Double = cos(cosRefLat * .pi / 180)

    /// Project real lat/lon to unscaled world units (y grows southward, so
    /// higher latitude → smaller y, matching screen coordinates).
    static func unit(lat: Double, lon: Double) -> CGPoint {
        let xUnits = (lon - lonMin) * lonCorrection
        let yUnits = (latMax - lat)
        return CGPoint(x: xUnits, y: yUnits)
    }
}
