//
//  Airport.swift
//  SkyOps — Phase 2
//
//  The 48 real U.S. airports, ported from AIRPORTS in the prototype. Each has
//  real lat/lon plus real fee/ground-stop data (used from Phase 2's economy
//  onward). `unit` is the resolution-independent projected position; `screen`
//  is the pixel position assigned by Simulation.layout(in:).
//

import Foundation
import CoreGraphics

final class Airport: Identifiable {
    let id = UUID()
    let code: String
    let lat: Double
    let lon: Double

    // Real fee / disruption data (ported; consumed by later phases).
    let landingFeePerKlb: Double
    let gateFeeNarrowbody: Double
    let gateFeeWidebody: Double
    let groundStopsPerMonth: Double

    /// Resolution-independent projected position (world units).
    let unit: CGPoint
    /// Pixel position in the current view (assigned each layout).
    var screen: CGPoint = .zero

    // Weather ground-stop state (Phase 3). Universal — applies to all traffic.
    var groundStop: Bool = false
    var groundStopTicksLeft: Int = 0

    // Route-slot scarcity (Phase 5). Abstract capacity for new player routes —
    // busier/more-expensive airports have fewer. NOT real competitor modeling.
    var slotsTotal: Int = 0
    var slotsAvailable: Int = 0

    init(code: String, lat: Double, lon: Double,
         landingFeePerKlb: Double = 0, gateFeeNarrowbody: Double = 0,
         gateFeeWidebody: Double = 0, groundStopsPerMonth: Double = 0) {
        self.code = code
        self.lat = lat
        self.lon = lon
        self.landingFeePerKlb = landingFeePerKlb
        self.gateFeeNarrowbody = gateFeeNarrowbody
        self.gateFeeWidebody = gateFeeWidebody
        self.groundStopsPerMonth = groundStopsPerMonth
        self.unit = GeoProjection.unit(lat: lat, lon: lon)
    }

    /// The real 48-airport network (top-50 by fee, minus 2 cross-batch
    /// duplicates; includes ANC/HNL). Ported verbatim from AIRPORTS.
    static let all: [Airport] = [
        .init(code: "ORD", lat: 41.9786, lon: -87.9048,  landingFeePerKlb: 10.58, gateFeeNarrowbody: 600,  gateFeeWidebody: 1500, groundStopsPerMonth: 9.4),
        .init(code: "ATL", lat: 33.6407, lon: -84.4277,  landingFeePerKlb: 1.63,  gateFeeNarrowbody: 250,  gateFeeWidebody: 450,  groundStopsPerMonth: 4.8),
        .init(code: "DFW", lat: 32.8998, lon: -97.0403,  landingFeePerKlb: 2.78,  gateFeeNarrowbody: 350,  gateFeeWidebody: 750,  groundStopsPerMonth: 7.1),
        .init(code: "DEN", lat: 39.8561, lon: -104.6737, landingFeePerKlb: 4.95,  gateFeeNarrowbody: 400,  gateFeeWidebody: 800,  groundStopsPerMonth: 8.7),
        .init(code: "LAS", lat: 36.0840, lon: -115.1537, landingFeePerKlb: 1.20,  gateFeeNarrowbody: 275,  gateFeeWidebody: 650,  groundStopsPerMonth: 0.5),
        .init(code: "LAX", lat: 33.9416, lon: -118.4085, landingFeePerKlb: 5.74,  gateFeeNarrowbody: 500,  gateFeeWidebody: 1200, groundStopsPerMonth: 0.1),
        .init(code: "CLT", lat: 35.2144, lon: -80.9473,  landingFeePerKlb: 1.23,  gateFeeNarrowbody: 200,  gateFeeWidebody: 500,  groundStopsPerMonth: 2.9),
        .init(code: "MIA", lat: 25.7959, lon: -80.2870,  landingFeePerKlb: 1.65,  gateFeeNarrowbody: 350,  gateFeeWidebody: 800,  groundStopsPerMonth: 3.2),
        .init(code: "PHX", lat: 33.4342, lon: -112.0116, landingFeePerKlb: 2.23,  gateFeeNarrowbody: 184,  gateFeeWidebody: 184,  groundStopsPerMonth: 0.4),
        .init(code: "JFK", lat: 40.6413, lon: -73.7781,  landingFeePerKlb: 8.47,  gateFeeNarrowbody: 900,  gateFeeWidebody: 1800, groundStopsPerMonth: 10.8),
        .init(code: "IAH", lat: 29.9902, lon: -95.3368,  landingFeePerKlb: 3.45,  gateFeeNarrowbody: 350,  gateFeeWidebody: 750,  groundStopsPerMonth: 4.5),
        .init(code: "SEA", lat: 47.4502, lon: -122.3088, landingFeePerKlb: 4.62,  gateFeeNarrowbody: 722,  gateFeeWidebody: 1444, groundStopsPerMonth: 0.8),
        .init(code: "MCO", lat: 28.4312, lon: -81.3081,  landingFeePerKlb: 1.59,  gateFeeNarrowbody: 210,  gateFeeWidebody: 450,  groundStopsPerMonth: 3.6),
        .init(code: "SFO", lat: 37.6213, lon: -122.3790, landingFeePerKlb: 7.73,  gateFeeNarrowbody: 1164, gateFeeWidebody: 1338, groundStopsPerMonth: 13.5),
        .init(code: "EWR", lat: 40.6895, lon: -74.1745,  landingFeePerKlb: 10.32, gateFeeNarrowbody: 850,  gateFeeWidebody: 1400, groundStopsPerMonth: 14.2),
        .init(code: "MSP", lat: 44.8848, lon: -93.2223,  landingFeePerKlb: 3.15,  gateFeeNarrowbody: 300,  gateFeeWidebody: 650,  groundStopsPerMonth: 1.8),
        .init(code: "BOS", lat: 42.3656, lon: -71.0096,  landingFeePerKlb: 5.12,  gateFeeNarrowbody: 450,  gateFeeWidebody: 900,  groundStopsPerMonth: 5.9),
        .init(code: "DTW", lat: 42.2124, lon: -83.3534,  landingFeePerKlb: 1.76,  gateFeeNarrowbody: 240,  gateFeeWidebody: 500,  groundStopsPerMonth: 1.5),
        .init(code: "FLL", lat: 26.0726, lon: -80.1527,  landingFeePerKlb: 2.58,  gateFeeNarrowbody: 380,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.8),
        .init(code: "LGA", lat: 40.7769, lon: -73.8740,  landingFeePerKlb: 17.72, gateFeeNarrowbody: 1231, gateFeeWidebody: 1231, groundStopsPerMonth: 12.1),
        .init(code: "PHL", lat: 39.8744, lon: -75.2424,  landingFeePerKlb: 4.10,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 6.4),
        .init(code: "SLC", lat: 40.7884, lon: -111.9778, landingFeePerKlb: 2.95,  gateFeeNarrowbody: 280,  gateFeeWidebody: 600,  groundStopsPerMonth: 0.3),
        .init(code: "BWI", lat: 39.1774, lon: -76.6684,  landingFeePerKlb: 4.65,  gateFeeNarrowbody: 400,  gateFeeWidebody: 750,  groundStopsPerMonth: 2.4),
        .init(code: "SAN", lat: 32.7338, lon: -117.1933, landingFeePerKlb: 4.85,  gateFeeNarrowbody: 420,  gateFeeWidebody: 850,  groundStopsPerMonth: 0.2),
        .init(code: "IAD", lat: 38.9531, lon: -77.4565,  landingFeePerKlb: 3.98,  gateFeeNarrowbody: 380,  gateFeeWidebody: 800,  groundStopsPerMonth: 1.4),
        .init(code: "MDW", lat: 41.7868, lon: -87.7522,  landingFeePerKlb: 3.45,  gateFeeNarrowbody: 310,  gateFeeWidebody: 310,  groundStopsPerMonth: 5.4),
        .init(code: "AUS", lat: 30.1975, lon: -97.6664,  landingFeePerKlb: 6.07,  gateFeeNarrowbody: 250,  gateFeeWidebody: 500,  groundStopsPerMonth: 1.2),
        .init(code: "DAL", lat: 32.8471, lon: -96.8518,  landingFeePerKlb: 4.50,  gateFeeNarrowbody: 280,  gateFeeWidebody: 280,  groundStopsPerMonth: 1.9),
        .init(code: "PDX", lat: 45.5898, lon: -122.5951, landingFeePerKlb: 2.95,  gateFeeNarrowbody: 260,  gateFeeWidebody: 480,  groundStopsPerMonth: 0.6),
        .init(code: "TPA", lat: 27.9755, lon: -82.5332,  landingFeePerKlb: 2.25,  gateFeeNarrowbody: 220,  gateFeeWidebody: 450,  groundStopsPerMonth: 2.8),
        .init(code: "STL", lat: 38.7487, lon: -90.3700,  landingFeePerKlb: 5.00,  gateFeeNarrowbody: 200,  gateFeeWidebody: 400,  groundStopsPerMonth: 1.5),
        .init(code: "HOU", lat: 29.6454, lon: -95.2789,  landingFeePerKlb: 2.28,  gateFeeNarrowbody: 96,   gateFeeWidebody: 137,  groundStopsPerMonth: 2.6),
        .init(code: "RDU", lat: 35.8776, lon: -78.7875,  landingFeePerKlb: 2.50,  gateFeeNarrowbody: 240,  gateFeeWidebody: 450,  groundStopsPerMonth: 1.1),
        .init(code: "SMF", lat: 38.6954, lon: -121.5908, landingFeePerKlb: 4.70,  gateFeeNarrowbody: 212,  gateFeeWidebody: 420,  groundStopsPerMonth: 0.5),
        .init(code: "SJC", lat: 37.3626, lon: -121.9291, landingFeePerKlb: 6.80,  gateFeeNarrowbody: 420,  gateFeeWidebody: 750,  groundStopsPerMonth: 0.3),
        .init(code: "MCI", lat: 39.2976, lon: -94.7139,  landingFeePerKlb: 3.67,  gateFeeNarrowbody: 210,  gateFeeWidebody: 450,  groundStopsPerMonth: 1.4),
        .init(code: "SNA", lat: 33.6757, lon: -117.8682, landingFeePerKlb: 3.56,  gateFeeNarrowbody: 450,  gateFeeWidebody: 450,  groundStopsPerMonth: 0.2),
        .init(code: "IND", lat: 39.7173, lon: -86.2944,  landingFeePerKlb: 1.95,  gateFeeNarrowbody: 190,  gateFeeWidebody: 380,  groundStopsPerMonth: 1.1),
        .init(code: "CVG", lat: 39.0488, lon: -84.6678,  landingFeePerKlb: 2.40,  gateFeeNarrowbody: 260,  gateFeeWidebody: 500,  groundStopsPerMonth: 1.6),
        .init(code: "PIT", lat: 40.4915, lon: -80.2329,  landingFeePerKlb: 3.15,  gateFeeNarrowbody: 220,  gateFeeWidebody: 450,  groundStopsPerMonth: 1.4),
        .init(code: "CMH", lat: 39.9980, lon: -82.8919,  landingFeePerKlb: 5.54,  gateFeeNarrowbody: 180,  gateFeeWidebody: 350,  groundStopsPerMonth: 0.9),
        .init(code: "MSY", lat: 29.9934, lon: -90.2580,  landingFeePerKlb: 2.35,  gateFeeNarrowbody: 280,  gateFeeWidebody: 500,  groundStopsPerMonth: 2.1),
        .init(code: "CLE", lat: 41.4117, lon: -81.8498,  landingFeePerKlb: 2.70,  gateFeeNarrowbody: 210,  gateFeeWidebody: 400,  groundStopsPerMonth: 2.9),
        .init(code: "RSW", lat: 26.5362, lon: -81.7552,  landingFeePerKlb: 2.85,  gateFeeNarrowbody: 230,  gateFeeWidebody: 450,  groundStopsPerMonth: 1.4),
        .init(code: "OAK", lat: 37.7213, lon: -122.2207, landingFeePerKlb: 5.52,  gateFeeNarrowbody: 936,  gateFeeWidebody: 1170, groundStopsPerMonth: 0.6),
        .init(code: "SAT", lat: 29.5337, lon: -98.4698,  landingFeePerKlb: 3.50,  gateFeeNarrowbody: 200,  gateFeeWidebody: 400,  groundStopsPerMonth: 0.8),
        .init(code: "ANC", lat: 61.1743, lon: -149.9963, landingFeePerKlb: 2.11,  gateFeeNarrowbody: 300,  gateFeeWidebody: 550,  groundStopsPerMonth: 1.8),
        .init(code: "HNL", lat: 21.3245, lon: -157.9251, landingFeePerKlb: 2.74,  gateFeeNarrowbody: 320,  gateFeeWidebody: 600,  groundStopsPerMonth: 0.2),
    ]

    /// Two distinct random airports — ported from randomRoutePair().
    static func randomPair() -> (Airport, Airport) {
        let a = all.randomElement()!
        var b = all.randomElement()!
        while b === a { b = all.randomElement()! }
        return (a, b)
    }
}
