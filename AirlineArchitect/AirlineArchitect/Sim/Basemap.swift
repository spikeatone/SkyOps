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
    /// Per-region context outlines, each rendered in its own hue (see
    /// MapView.drawBasemap). Not interactive.
    let mexico: [[CGPoint]]
    let centralAmerica: [[CGPoint]]
    let southAmerica: [[CGPoint]]
    // Eastern-hemisphere continents (Natural Earth 110m country outlines).
    let europe: [[CGPoint]]
    let asia: [[CGPoint]]
    let africa: [[CGPoint]]
    let australia: [[CGPoint]]

    /// Decoded + projected once at first use.
    static let shared: Basemap = load()

    private struct Raw: Decodable {
        let nation: [[[Double]]]
        let states: [[[[Double]]]]
        let canada: [[[Double]]]
        let mexico: [[[Double]]]?
        let centralAmerica: [[[Double]]]?
        let southAmerica: [[[Double]]]?
        let europe: [[[Double]]]?
        let asia: [[[Double]]]?
        let africa: [[[Double]]]?
        let australia: [[[Double]]]?
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
            return Basemap(nation: [], states: [], canada: [], mexico: [], centralAmerica: [], southAmerica: [],
                           europe: [], asia: [], africa: [], australia: [])
        }
        let nation = raw.nation.map { $0.map(project) }
        let states = raw.states.map { $0.map { $0.map(project) } }
        let canada = raw.canada.map { $0.map(project) }
        let mexico = (raw.mexico ?? []).map { $0.map(project) }
        let central = (raw.centralAmerica ?? []).map { $0.map(project) }
        let south = (raw.southAmerica ?? []).map { $0.map(project) }
        let europe = (raw.europe ?? []).map { $0.map(project) }
        let asia = (raw.asia ?? []).map { $0.map(project) }
        let africa = (raw.africa ?? []).map { $0.map(project) }
        let australia = (raw.australia ?? []).map { $0.map(project) }
        return Basemap(nation: nation, states: states, canada: canada,
                       mexico: mexico, centralAmerica: central, southAmerica: south,
                       europe: europe, asia: asia, africa: africa, australia: australia)
    }
}
