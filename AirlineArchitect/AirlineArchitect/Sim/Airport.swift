//
//  Airport.swift
//  Airline Architect — Phase 2
//
//  93 real airports — 48 U.S. (ported from AIRPORTS) + 45 Latin American
//  (Mexico/Central/South America, added this session). Each has
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

    /// The real airport network: 48 U.S. (top-50 by fee, minus 2 cross-batch
    /// duplicates; includes ANC/HNL) + 45 Latin American, 93 total.
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

        // ── Latin America (added this session). Real lat/lon; fee/ground-stop
        // figures are TIER-BASED ESTIMATES calibrated to the existing US ranges
        // and each airport's real size/role — NOT per-airport sourced signatory
        // rates (real published rates aren't available for most of these). Same
        // "weakest tier" confidence as the regional-jet weights; refine with
        // sourced data if precision matters. Airline roster stays US-weighted
        // (competitors can fly here, but there are no LatAm carriers yet).

        // Mexico (top 15)
        .init(code: "MEX", lat: 19.4363, lon: -99.0721,  landingFeePerKlb: 4.20, gateFeeNarrowbody: 400, gateFeeWidebody: 900, groundStopsPerMonth: 5.5),
        .init(code: "CUN", lat: 21.0365, lon: -86.8771,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 350, gateFeeWidebody: 760, groundStopsPerMonth: 3.5),
        .init(code: "GDL", lat: 20.5218, lon: -103.3111, landingFeePerKlb: 2.60, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 3.0),
        .init(code: "TIJ", lat: 32.5411, lon: -116.9702, landingFeePerKlb: 2.10, gateFeeNarrowbody: 280, gateFeeWidebody: 560, groundStopsPerMonth: 2.0),
        .init(code: "MTY", lat: 25.7785, lon: -100.1069, landingFeePerKlb: 2.50, gateFeeNarrowbody: 310, gateFeeWidebody: 620, groundStopsPerMonth: 3.2),
        .init(code: "SJD", lat: 23.1518, lon: -109.7215, landingFeePerKlb: 2.00, gateFeeNarrowbody: 270, gateFeeWidebody: 540, groundStopsPerMonth: 1.8),
        .init(code: "PVR", lat: 20.6801, lon: -105.2544, landingFeePerKlb: 1.90, gateFeeNarrowbody: 260, gateFeeWidebody: 520, groundStopsPerMonth: 2.0),
        .init(code: "NLU", lat: 19.7558, lon: -99.0147,  landingFeePerKlb: 2.20, gateFeeNarrowbody: 290, gateFeeWidebody: 580, groundStopsPerMonth: 3.0),
        .init(code: "MID", lat: 20.9370, lon: -89.6577,  landingFeePerKlb: 1.80, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 2.5),
        .init(code: "BJX", lat: 20.9935, lon: -101.4808, landingFeePerKlb: 1.85, gateFeeNarrowbody: 255, gateFeeWidebody: 510, groundStopsPerMonth: 2.0),
        .init(code: "CUL", lat: 24.7645, lon: -107.4747, landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 2.3),
        .init(code: "VER", lat: 19.1459, lon: -96.1873,  landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 2.8),
        .init(code: "HMO", lat: 29.0959, lon: -111.0478, landingFeePerKlb: 1.75, gateFeeNarrowbody: 245, gateFeeWidebody: 490, groundStopsPerMonth: 2.2),
        .init(code: "OAX", lat: 16.9999, lon: -96.7266,  landingFeePerKlb: 1.65, gateFeeNarrowbody: 235, gateFeeWidebody: 470, groundStopsPerMonth: 2.5),
        .init(code: "MZT", lat: 23.1614, lon: -106.2661, landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 2.0),

        // Central America (top 10)
        .init(code: "PTY", lat: 9.0714,  lon: -79.3835,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 360, gateFeeWidebody: 780, groundStopsPerMonth: 2.5),
        .init(code: "SJO", lat: 9.9939,  lon: -84.2088,  landingFeePerKlb: 2.60, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 3.5),
        .init(code: "SAL", lat: 13.4409, lon: -89.0557,  landingFeePerKlb: 1.90, gateFeeNarrowbody: 260, gateFeeWidebody: 520, groundStopsPerMonth: 2.5),
        .init(code: "GUA", lat: 14.5833, lon: -90.5275,  landingFeePerKlb: 2.50, gateFeeNarrowbody: 310, gateFeeWidebody: 620, groundStopsPerMonth: 3.0),
        .init(code: "LIR", lat: 10.5933, lon: -85.5444,  landingFeePerKlb: 1.80, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 2.0),
        .init(code: "SAP", lat: 15.4526, lon: -87.9234,  landingFeePerKlb: 1.75, gateFeeNarrowbody: 245, gateFeeWidebody: 490, groundStopsPerMonth: 2.8),
        .init(code: "MGA", lat: 12.1415, lon: -86.1682,  landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 2.5),
        .init(code: "BZE", lat: 17.5391, lon: -88.3082,  landingFeePerKlb: 1.50, gateFeeNarrowbody: 200, gateFeeWidebody: 400, groundStopsPerMonth: 2.0),
        .init(code: "XPL", lat: 14.3822, lon: -87.6211,  landingFeePerKlb: 1.55, gateFeeNarrowbody: 210, gateFeeWidebody: 420, groundStopsPerMonth: 2.2),
        .init(code: "RTB", lat: 16.3167, lon: -86.5230,  landingFeePerKlb: 1.45, gateFeeNarrowbody: 195, gateFeeWidebody: 390, groundStopsPerMonth: 2.5),

        // South America (top 20)
        .init(code: "BOG", lat: 4.7016,   lon: -74.1469,  landingFeePerKlb: 3.80, gateFeeNarrowbody: 380, gateFeeWidebody: 820, groundStopsPerMonth: 6.5),
        .init(code: "GRU", lat: -23.4356, lon: -46.4731,  landingFeePerKlb: 4.80, gateFeeNarrowbody: 420, gateFeeWidebody: 950, groundStopsPerMonth: 5.0),
        .init(code: "SCL", lat: -33.3930, lon: -70.7858,  landingFeePerKlb: 3.40, gateFeeNarrowbody: 370, gateFeeWidebody: 800, groundStopsPerMonth: 3.0),
        .init(code: "LIM", lat: -12.0219, lon: -77.1143,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 375, gateFeeWidebody: 810, groundStopsPerMonth: 2.0),
        .init(code: "CGH", lat: -23.6266, lon: -46.6556,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 360, gateFeeWidebody: 720, groundStopsPerMonth: 5.0),
        .init(code: "AEP", lat: -34.5592, lon: -58.4156,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 350, gateFeeWidebody: 700, groundStopsPerMonth: 4.5),
        .init(code: "GIG", lat: -22.8100, lon: -43.2506,  landingFeePerKlb: 3.80, gateFeeNarrowbody: 380, gateFeeWidebody: 820, groundStopsPerMonth: 4.0),
        .init(code: "VCP", lat: -23.0074, lon: -47.1345,  landingFeePerKlb: 2.30, gateFeeNarrowbody: 295, gateFeeWidebody: 590, groundStopsPerMonth: 3.0),
        .init(code: "MDE", lat: 6.1645,   lon: -75.4231,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 330, gateFeeWidebody: 660, groundStopsPerMonth: 4.0),
        .init(code: "BSB", lat: -15.8697, lon: -47.9208,  landingFeePerKlb: 2.70, gateFeeNarrowbody: 320, gateFeeWidebody: 650, groundStopsPerMonth: 2.5),
        .init(code: "EZE", lat: -34.8222, lon: -58.5358,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 375, gateFeeWidebody: 810, groundStopsPerMonth: 4.5),
        .init(code: "UIO", lat: -0.1292,  lon: -78.3575,  landingFeePerKlb: 2.90, gateFeeNarrowbody: 335, gateFeeWidebody: 670, groundStopsPerMonth: 4.5),
        .init(code: "SDU", lat: -22.9105, lon: -43.1631,  landingFeePerKlb: 2.60, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 4.5),
        .init(code: "CLO", lat: 3.5432,   lon: -76.3816,  landingFeePerKlb: 2.00, gateFeeNarrowbody: 270, gateFeeWidebody: 540, groundStopsPerMonth: 3.5),
        .init(code: "CNF", lat: -19.6336, lon: -43.9686,  landingFeePerKlb: 2.10, gateFeeNarrowbody: 280, gateFeeWidebody: 560, groundStopsPerMonth: 2.8),
        .init(code: "CTG", lat: 10.4424,  lon: -75.5130,  landingFeePerKlb: 1.95, gateFeeNarrowbody: 265, gateFeeWidebody: 530, groundStopsPerMonth: 3.0),
        .init(code: "POA", lat: -29.9944, lon: -51.1714,  landingFeePerKlb: 2.00, gateFeeNarrowbody: 270, gateFeeWidebody: 540, groundStopsPerMonth: 3.2),
        .init(code: "REC", lat: -8.1265,  lon: -34.9236,  landingFeePerKlb: 1.95, gateFeeNarrowbody: 265, gateFeeWidebody: 530, groundStopsPerMonth: 3.0),
        .init(code: "SSA", lat: -12.9086, lon: -38.3225,  landingFeePerKlb: 1.95, gateFeeNarrowbody: 265, gateFeeWidebody: 530, groundStopsPerMonth: 3.2),
        .init(code: "GYE", lat: -2.1574,  lon: -79.8836,  landingFeePerKlb: 2.40, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.8),
    ]

    /// Two distinct random airports — ported from randomRoutePair().
    static func randomPair() -> (Airport, Airport) {
        let a = all.randomElement()!
        var b = all.randomElement()!
        while b === a { b = all.randomElement()! }
        return (a, b)
    }
}
