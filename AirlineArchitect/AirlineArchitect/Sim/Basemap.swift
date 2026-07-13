//
//  Basemap.swift
//  Airline Architect — basemap geometry (pulled forward from Phase 4)
//
//  Real U.S. nation outline + state borders + Canada context geometry, ported
//  from the prototype's US_NATION_RINGS / US_STATE_RINGS / CANADA_RINGS (real
//  us-atlas / world-atlas data, topology-simplified). Loaded once from the
//  bundled Basemap.json and pre-projected to resolution-independent "unit"
//  space via the SAME GeoProjection the airports use, so the map can never
//  drift out of alignment. Rendered as a background context layer beneath the
//  airports/aircraft (see MapView.drawBasemap).
//

import Foundation
import CoreGraphics

struct Basemap {
    /// Rings (closed polylines) in unit space.
    let nation: [[CGPoint]]
    /// State features — each is a set of rings.
    let states: [[[CGPoint]]]
    let canada: [[CGPoint]]

    /// Decoded + projected once at first use.
    static let shared: Basemap = load()

    private struct Raw: Decodable {
        let nation: [[[Double]]]
        let states: [[[[Double]]]]
        let canada: [[[Double]]]
    }

    /// Project one [lon, lat] pair to unit space.
    private static func project(_ p: [Double]) -> CGPoint {
        // stored as [lon, lat]
        GeoProjection.unit(lat: p[1], lon: p[0])
    }

    private static func load() -> Basemap {
        guard let url = Bundle.main.url(forResource: "Basemap", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else {
            // No basemap available — render airports/aircraft without it.
            return Basemap(nation: [], states: [], canada: [])
        }
        let nation = raw.nation.map { $0.map(project) }
        let states = raw.states.map { $0.map { $0.map(project) } }
        let canada = raw.canada.map { $0.map(project) }
        return Basemap(nation: nation, states: states, canada: canada)
    }
}
