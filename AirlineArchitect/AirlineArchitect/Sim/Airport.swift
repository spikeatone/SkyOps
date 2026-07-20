//
//  Airport.swift
//  Airline Architect — Phase 2
//
//  114 real airports — 48 U.S. (ported from AIRPORTS) + 46 Latin American
//  (Mexico/Central/South America) + 20 Canadian. Each has
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
    /// What triggered the current ground stop (Weather / ATC staffing shortage /
    /// Security incident) — shown on the airport card's red-ring explainer.
    var groundStopReason: String? = nil

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

    /// "Leisure route destinations" (designer): island/beach markets where
    /// fares run a PREMIUM and route establishment costs MORE (labor, setup,
    /// materials all cost more on an island). Hawaii neighbors + the Caribbean
    /// primaries + Indian Ocean/South Pacific islands. PPT (Tahiti) included by
    /// the same logic even though it predates the list; the Mexican beach
    /// airports (CUN/CZM/SJD/PVR) are deliberately NOT leisure yet — easy to
    /// extend if the designer wants them in.
    static let leisureCodes: Set<String> = [
        "LIH", "OGG", "ITO", "KOA",                                  // Hawaii
        "SJU", "STT", "NAS", "PLS", "GCM", "EIS", "AXA", "SXM",      // Caribbean
        "SBH", "ANU", "SKB", "DOM", "UVF", "SVD", "GND", "BGI",
        "AUA", "CUR", "BON", "POS",
        "MLE", "SEZ", "MRU", "ZNZ",                                   // Indian Ocean
        "NAN", "PPT", "OKA",                                          // South Pacific + Okinawa
        "SID",                                                        // Cape Verde (Sal)
        "BDA",                                                        // Bermuda (mid-Atlantic)
    ]
    static func isLeisure(_ code: String) -> Bool { leisureCodes.contains(code) }

    /// The real airport network: 48 U.S. (top-50 by fee, minus 2 cross-batch
    /// duplicates; includes ANC/HNL) + 46 Latin American + 20 Canadian, 114 total.
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

        // Hawaii neighbor islands + Caribbean US territories — LEISURE
        // destinations (designer request). Fee/ground-stop figures are
        // tier-based ESTIMATES like the LatAm set.
        .init(code: "LIH", lat: 21.9760, lon: -159.3390, landingFeePerKlb: 2.40, gateFeeNarrowbody: 290, gateFeeWidebody: 560, groundStopsPerMonth: 0.3),
        .init(code: "OGG", lat: 20.8986, lon: -156.4305, landingFeePerKlb: 2.50, gateFeeNarrowbody: 300, gateFeeWidebody: 580, groundStopsPerMonth: 0.3),
        .init(code: "ITO", lat: 19.7188, lon: -155.0478, landingFeePerKlb: 2.30, gateFeeNarrowbody: 280, gateFeeWidebody: 540, groundStopsPerMonth: 0.5),
        .init(code: "KOA", lat: 19.7388, lon: -156.0456, landingFeePerKlb: 2.40, gateFeeNarrowbody: 290, gateFeeWidebody: 560, groundStopsPerMonth: 0.3),
        .init(code: "SJU", lat: 18.4394, lon: -66.0018,  landingFeePerKlb: 2.60, gateFeeNarrowbody: 310, gateFeeWidebody: 620, groundStopsPerMonth: 2.5),
        .init(code: "STT", lat: 18.3373, lon: -64.9734,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.5),
        // Additional US airports (mid-continent / mountain-west / mid-south).
        .init(code: "BZN", lat: 45.7772, lon: -111.1530, landingFeePerKlb: 3.20,  gateFeeNarrowbody: 300,  gateFeeWidebody: 620,  groundStopsPerMonth: 4.0),
        .init(code: "BOI", lat: 43.5644, lon: -116.2228, landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.0),
        .init(code: "ABQ", lat: 35.0402, lon: -106.6090, landingFeePerKlb: 3.90,  gateFeeNarrowbody: 340,  gateFeeWidebody: 720,  groundStopsPerMonth: 2.5),
        .init(code: "OMA", lat: 41.3032, lon: -95.8940,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.5),
        .init(code: "CYS", lat: 41.1557, lon: -104.8120, landingFeePerKlb: 2.90,  gateFeeNarrowbody: 290,  gateFeeWidebody: 600,  groundStopsPerMonth: 4.0),
        .init(code: "DSM", lat: 41.5340, lon: -93.6631,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 3.5),
        .init(code: "OKC", lat: 35.3931, lon: -97.6007,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 4.0),
        .init(code: "TUL", lat: 36.1984, lon: -95.8881,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 4.0),
        .init(code: "MEM", lat: 35.0424, lon: -89.9767,  landingFeePerKlb: 4.60,  gateFeeNarrowbody: 370,  gateFeeWidebody: 820,  groundStopsPerMonth: 3.5),
        .init(code: "HSV", lat: 34.6372, lon: -86.7751,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.0),
        .init(code: "BHM", lat: 33.5629, lon: -86.7535,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.5),
        .init(code: "JAN", lat: 32.3112, lon: -90.0759,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.5),
        .init(code: "MSN", lat: 43.1399, lon: -89.3375,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.5),
        .init(code: "GRR", lat: 42.8808, lon: -85.5228,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 3.5),
        .init(code: "BNA", lat: 36.1245, lon: -86.6782,  landingFeePerKlb: 4.40,  gateFeeNarrowbody: 360,  gateFeeWidebody: 800,  groundStopsPerMonth: 3.0),
        .init(code: "SDF", lat: 38.1744, lon: -85.7360,  landingFeePerKlb: 4.00,  gateFeeNarrowbody: 340,  gateFeeWidebody: 720,  groundStopsPerMonth: 3.0),
        .init(code: "LEX", lat: 38.0365, lon: -84.6059,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.0),
        .init(code: "PWM", lat: 43.6462, lon: -70.3093,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 3.5),
        .init(code: "BGR", lat: 44.8074, lon: -68.8281,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 4.0),
        .init(code: "RNO", lat: 39.4991, lon: -119.7681, landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 2.5),
        .init(code: "MKE", lat: 42.9472, lon: -87.8966,  landingFeePerKlb: 3.90,  gateFeeNarrowbody: 340,  gateFeeWidebody: 720,  groundStopsPerMonth: 3.5),
        .init(code: "BTV", lat: 44.4719, lon: -73.1533,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 4.0),
        .init(code: "MHT", lat: 42.9326, lon: -71.4357,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 3.5),
        .init(code: "LIT", lat: 34.7294, lon: -92.2243,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.5),
        .init(code: "FAR", lat: 46.9207, lon: -96.8158,  landingFeePerKlb: 3.20,  gateFeeNarrowbody: 300,  gateFeeWidebody: 640,  groundStopsPerMonth: 4.0),
        .init(code: "FSD", lat: 43.5820, lon: -96.7419,  landingFeePerKlb: 3.20,  gateFeeNarrowbody: 300,  gateFeeWidebody: 640,  groundStopsPerMonth: 3.5),
        .init(code: "BTR", lat: 30.5332, lon: -91.1496,  landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.0),
        .init(code: "CHS", lat: 32.8986, lon: -80.0405,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.0),
        .init(code: "RIC", lat: 37.5052, lon: -77.3197,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.0),
        .init(code: "ORF", lat: 36.8946, lon: -76.2012,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 3.0),
        .init(code: "CRW", lat: 38.3731, lon: -81.5932,  landingFeePerKlb: 3.20,  gateFeeNarrowbody: 300,  gateFeeWidebody: 640,  groundStopsPerMonth: 3.5),
        .init(code: "BDL", lat: 41.9389, lon: -72.6832,  landingFeePerKlb: 4.20,  gateFeeNarrowbody: 350,  gateFeeWidebody: 760,  groundStopsPerMonth: 3.5),
        .init(code: "PVD", lat: 41.7267, lon: -71.4325,  landingFeePerKlb: 3.90,  gateFeeNarrowbody: 340,  gateFeeWidebody: 720,  groundStopsPerMonth: 3.5),
        .init(code: "EUG", lat: 44.1246, lon: -123.2119, landingFeePerKlb: 3.40,  gateFeeNarrowbody: 310,  gateFeeWidebody: 660,  groundStopsPerMonth: 3.0),
        .init(code: "GEG", lat: 47.6199, lon: -117.5338, landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 3.5),
        .init(code: "BUF", lat: 42.9405, lon: -78.7322,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330,  gateFeeWidebody: 700,  groundStopsPerMonth: 4.0),
        .init(code: "ROC", lat: 43.1189, lon: -77.6724,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 4.0),
        .init(code: "SYR", lat: 43.1112, lon: -76.1063,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320,  gateFeeWidebody: 680,  groundStopsPerMonth: 4.0),

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
        .init(code: "CZM", lat: 20.5224, lon: -86.9256,  landingFeePerKlb: 1.80, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 2.5),

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

        // Caribbean — LEISURE destinations (designer request; primary airport
        // per territory). Fee/ground-stop figures are tier-based ESTIMATES;
        // ground stops lean 2-2.5 for hurricane season. NOTE: SBH (2,119 ft)
        // and EIS (4,642 ft) have REAL runways below every game type's minimum
        // — turboprop-only fields in reality; they render and host background
        // flavor but no game jet can serve them until a turboprop type exists.
        .init(code: "NAS", lat: 25.0390, lon: -77.4662,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 330, gateFeeWidebody: 660, groundStopsPerMonth: 2.5),
        .init(code: "PLS", lat: 21.7736, lon: -72.2659,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 330, gateFeeWidebody: 660, groundStopsPerMonth: 2.0),
        .init(code: "GCM", lat: 19.2928, lon: -81.3577,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 330, gateFeeWidebody: 660, groundStopsPerMonth: 2.0),
        .init(code: "EIS", lat: 18.4448, lon: -64.5430,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.0),
        .init(code: "AXA", lat: 18.2048, lon: -63.0551,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.0),
        .init(code: "SXM", lat: 18.0410, lon: -63.1089,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 340, gateFeeWidebody: 700, groundStopsPerMonth: 2.5),
        .init(code: "SBH", lat: 17.9044, lon: -62.8436,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 2.0),
        .init(code: "ANU", lat: 17.1367, lon: -61.7927,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 2.0),
        .init(code: "SKB", lat: 17.3112, lon: -62.7187,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 2.0),
        .init(code: "DOM", lat: 15.5470, lon: -61.3000,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.5),
        .init(code: "UVF", lat: 13.7332, lon: -60.9526,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 2.5),
        .init(code: "SVD", lat: 13.1564, lon: -61.1493,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.0),
        .init(code: "GND", lat: 12.0042, lon: -61.7862,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.0),
        .init(code: "BGI", lat: 13.0746, lon: -59.4925,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 340, gateFeeWidebody: 700, groundStopsPerMonth: 2.0),
        .init(code: "AUA", lat: 12.5014, lon: -70.0152,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 340, gateFeeWidebody: 700, groundStopsPerMonth: 1.5),
        .init(code: "CUR", lat: 12.1889, lon: -68.9598,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 330, gateFeeWidebody: 660, groundStopsPerMonth: 1.5),
        .init(code: "BON", lat: 12.1310, lon: -68.2685,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 1.5),
        .init(code: "POS", lat: 10.5954, lon: -61.3372,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 2.5),
        // Bermuda (mid-Atlantic leisure) — real single 9,713 ft runway; grouped
        // with the western-Atlantic leisure islands.
        .init(code: "BDA", lat: 32.3640, lon: -64.6787,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 340, gateFeeWidebody: 700, groundStopsPerMonth: 2.5),

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
        // South America expansion (designer: next 10 by size) — real lat/lon;
        // fees are tier ESTIMATES calibrated to the existing SA entries.
        .init(code: "FOR", lat: -3.7763,  lon: -38.5326, landingFeePerKlb: 1.95, gateFeeNarrowbody: 265, gateFeeWidebody: 530, groundStopsPerMonth: 2.8),
        .init(code: "CWB", lat: -25.5285, lon: -49.1758, landingFeePerKlb: 1.95, gateFeeNarrowbody: 265, gateFeeWidebody: 530, groundStopsPerMonth: 3.4),
        .init(code: "FLN", lat: -27.6702, lon: -48.5525, landingFeePerKlb: 1.90, gateFeeNarrowbody: 255, gateFeeWidebody: 510, groundStopsPerMonth: 3.2),
        .init(code: "BEL", lat: -1.3792,  lon: -48.4763, landingFeePerKlb: 1.90, gateFeeNarrowbody: 255, gateFeeWidebody: 510, groundStopsPerMonth: 3.6),
        .init(code: "CCS", lat: 10.6013,  lon: -66.9911, landingFeePerKlb: 2.10, gateFeeNarrowbody: 275, gateFeeWidebody: 560, groundStopsPerMonth: 2.6),
        .init(code: "MAO", lat: -3.0386,  lon: -60.0497, landingFeePerKlb: 1.90, gateFeeNarrowbody: 255, gateFeeWidebody: 510, groundStopsPerMonth: 3.8),
        .init(code: "CUZ", lat: -13.5357, lon: -71.9388, landingFeePerKlb: 2.00, gateFeeNarrowbody: 270, gateFeeWidebody: 540, groundStopsPerMonth: 3.4),
        .init(code: "VIX", lat: -20.2581, lon: -40.2864, landingFeePerKlb: 1.85, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 3.0),
        .init(code: "CGB", lat: -15.6529, lon: -56.1167, landingFeePerKlb: 1.85, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 3.0),
        .init(code: "BAQ", lat: 10.8896,  lon: -74.7808, landingFeePerKlb: 1.95, gateFeeNarrowbody: 265, gateFeeWidebody: 530, groundStopsPerMonth: 2.6),
        .init(code: "GYE", lat: -2.1574,  lon: -79.8836,  landingFeePerKlb: 2.40, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 2.8),

        // Canada (top 20). Same tier-based fee ESTIMATES as the LatAm set;
        // ground-stops lean high for the winter/Atlantic-weather airports.
        // NOTE: Kelowna is YLW (the requested "YKA" is actually Kamloops).
        .init(code: "YYZ", lat: 43.6777, lon: -79.6248,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 380, gateFeeWidebody: 850, groundStopsPerMonth: 5.5),
        .init(code: "YVR", lat: 49.1967, lon: -123.1815, landingFeePerKlb: 3.40, gateFeeNarrowbody: 370, gateFeeWidebody: 820, groundStopsPerMonth: 3.5),
        .init(code: "YUL", lat: 45.4706, lon: -73.7408,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 350, gateFeeWidebody: 760, groundStopsPerMonth: 5.0),
        .init(code: "YYC", lat: 51.1315, lon: -114.0106, landingFeePerKlb: 2.70, gateFeeNarrowbody: 330, gateFeeWidebody: 680, groundStopsPerMonth: 4.5),
        .init(code: "YEG", lat: 53.3097, lon: -113.5801, landingFeePerKlb: 2.40, gateFeeNarrowbody: 310, gateFeeWidebody: 640, groundStopsPerMonth: 4.8),
        .init(code: "YOW", lat: 45.3225, lon: -75.6692,  landingFeePerKlb: 2.30, gateFeeNarrowbody: 300, gateFeeWidebody: 620, groundStopsPerMonth: 4.5),
        .init(code: "YWG", lat: 49.9100, lon: -97.2399,  landingFeePerKlb: 2.20, gateFeeNarrowbody: 300, gateFeeWidebody: 600, groundStopsPerMonth: 5.0),
        .init(code: "YHZ", lat: 44.8808, lon: -63.5086,  landingFeePerKlb: 2.30, gateFeeNarrowbody: 300, gateFeeWidebody: 620, groundStopsPerMonth: 4.5),
        .init(code: "YTZ", lat: 43.6275, lon: -79.3962,  landingFeePerKlb: 2.60, gateFeeNarrowbody: 320, gateFeeWidebody: 640, groundStopsPerMonth: 4.0),
        .init(code: "YLW", lat: 49.9561, lon: -119.3778, landingFeePerKlb: 1.90, gateFeeNarrowbody: 260, gateFeeWidebody: 520, groundStopsPerMonth: 3.0),
        .init(code: "YYJ", lat: 48.6469, lon: -123.4258, landingFeePerKlb: 1.90, gateFeeNarrowbody: 260, gateFeeWidebody: 520, groundStopsPerMonth: 2.8),
        .init(code: "YYT", lat: 47.6186, lon: -52.7519,  landingFeePerKlb: 1.80, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 5.5),
        .init(code: "YXE", lat: 52.1708, lon: -106.6997, landingFeePerKlb: 1.85, gateFeeNarrowbody: 255, gateFeeWidebody: 510, groundStopsPerMonth: 4.5),
        .init(code: "YQR", lat: 50.4319, lon: -104.6658, landingFeePerKlb: 1.85, gateFeeNarrowbody: 255, gateFeeWidebody: 510, groundStopsPerMonth: 4.5),
        .init(code: "YQM", lat: 46.1122, lon: -64.6786,  landingFeePerKlb: 1.75, gateFeeNarrowbody: 245, gateFeeWidebody: 490, groundStopsPerMonth: 4.0),
        .init(code: "YSJ", lat: 45.3161, lon: -65.8903,  landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 4.0),
        .init(code: "YQG", lat: 42.2756, lon: -82.9556,  landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 3.0),
        .init(code: "YFC", lat: 45.8689, lon: -66.5372,  landingFeePerKlb: 1.70, gateFeeNarrowbody: 240, gateFeeWidebody: 480, groundStopsPerMonth: 3.5),
        .init(code: "YQT", lat: 48.3719, lon: -89.3239,  landingFeePerKlb: 1.75, gateFeeNarrowbody: 245, gateFeeWidebody: 490, groundStopsPerMonth: 4.0),
        .init(code: "YMM", lat: 56.6533, lon: -111.2223, landingFeePerKlb: 1.80, gateFeeNarrowbody: 250, gateFeeWidebody: 500, groundStopsPerMonth: 4.5),

        // ── Europe (top 46). Real lat/lon; fee/ground-stop figures are the same
        // TIER-BASED ESTIMATES as the LatAm/Canada sets (no per-airport sourced
        // signatory rates). Ground-stops lean higher for northern/winter airports
        // (OSL/ARN/CPH/SVO/DME/LED/KEF), lower for Mediterranean ones. No European
        // carriers in the roster yet — background traffic on these legs draws the
        // US-weighted roster until a Europe region is added.
        .init(code: "LHR", lat: 51.4700, lon: -0.4543,  landingFeePerKlb: 11.00, gateFeeNarrowbody: 620, gateFeeWidebody: 1600, groundStopsPerMonth: 5.0),
        .init(code: "IST", lat: 41.2753, lon: 28.7519,  landingFeePerKlb: 6.50,  gateFeeNarrowbody: 450, gateFeeWidebody: 1100, groundStopsPerMonth: 4.0),
        .init(code: "CDG", lat: 49.0097, lon: 2.5479,   landingFeePerKlb: 9.00,  gateFeeNarrowbody: 560, gateFeeWidebody: 1450, groundStopsPerMonth: 4.5),
        .init(code: "AMS", lat: 52.3105, lon: 4.7683,   landingFeePerKlb: 8.50,  gateFeeNarrowbody: 540, gateFeeWidebody: 1400, groundStopsPerMonth: 5.0),
        .init(code: "MAD", lat: 40.4719, lon: -3.5626,  landingFeePerKlb: 7.00,  gateFeeNarrowbody: 480, gateFeeWidebody: 1200, groundStopsPerMonth: 2.5),
        .init(code: "FRA", lat: 50.0379, lon: 8.5622,   landingFeePerKlb: 9.50,  gateFeeNarrowbody: 570, gateFeeWidebody: 1480, groundStopsPerMonth: 4.5),
        .init(code: "BCN", lat: 41.2974, lon: 2.0833,   landingFeePerKlb: 6.20,  gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 2.2),
        .init(code: "FCO", lat: 41.8003, lon: 12.2389,  landingFeePerKlb: 6.80,  gateFeeNarrowbody: 460, gateFeeWidebody: 1120, groundStopsPerMonth: 3.0),
        .init(code: "SVO", lat: 55.9726, lon: 37.4146,  landingFeePerKlb: 5.50,  gateFeeNarrowbody: 420, gateFeeWidebody: 1000, groundStopsPerMonth: 6.5),
        .init(code: "LGW", lat: 51.1537, lon: -0.1821,  landingFeePerKlb: 7.50,  gateFeeNarrowbody: 490, gateFeeWidebody: 1250, groundStopsPerMonth: 4.5),
        .init(code: "MUC", lat: 48.3538, lon: 11.7861,  landingFeePerKlb: 7.80,  gateFeeNarrowbody: 500, gateFeeWidebody: 1300, groundStopsPerMonth: 4.5),
        .init(code: "SAW", lat: 40.8986, lon: 29.3092,  landingFeePerKlb: 5.00,  gateFeeNarrowbody: 400, gateFeeWidebody: 900,  groundStopsPerMonth: 3.5),
        .init(code: "LIS", lat: 38.7742, lon: -9.1342,  landingFeePerKlb: 5.20,  gateFeeNarrowbody: 400, gateFeeWidebody: 920,  groundStopsPerMonth: 2.0),
        .init(code: "DUB", lat: 53.4213, lon: -6.2701,  landingFeePerKlb: 5.80,  gateFeeNarrowbody: 430, gateFeeWidebody: 980,  groundStopsPerMonth: 4.0),
        .init(code: "PMI", lat: 39.5517, lon: 2.7388,   landingFeePerKlb: 4.20,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 1.5),
        .init(code: "ORY", lat: 48.7233, lon: 2.3794,   landingFeePerKlb: 7.00,  gateFeeNarrowbody: 470, gateFeeWidebody: 1150, groundStopsPerMonth: 4.0),
        .init(code: "MAN", lat: 53.3537, lon: -2.2750,  landingFeePerKlb: 5.60,  gateFeeNarrowbody: 420, gateFeeWidebody: 960,  groundStopsPerMonth: 4.5),
        .init(code: "STN", lat: 51.8850, lon: 0.2350,   landingFeePerKlb: 5.00,  gateFeeNarrowbody: 390, gateFeeWidebody: 880,  groundStopsPerMonth: 4.0),
        .init(code: "DME", lat: 55.4088, lon: 37.9063,  landingFeePerKlb: 5.30,  gateFeeNarrowbody: 410, gateFeeWidebody: 960,  groundStopsPerMonth: 6.5),
        .init(code: "CPH", lat: 55.6180, lon: 12.6508,  landingFeePerKlb: 6.00,  gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 5.5),
        .init(code: "MXP", lat: 45.6306, lon: 8.7281,   landingFeePerKlb: 5.80,  gateFeeNarrowbody: 430, gateFeeWidebody: 990,  groundStopsPerMonth: 3.5),
        .init(code: "ATH", lat: 37.9364, lon: 23.9445,  landingFeePerKlb: 5.20,  gateFeeNarrowbody: 400, gateFeeWidebody: 920,  groundStopsPerMonth: 2.0),
        .init(code: "AYT", lat: 36.8987, lon: 30.8005,  landingFeePerKlb: 4.00,  gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 1.8),
        .init(code: "VIE", lat: 48.1103, lon: 16.5697,  landingFeePerKlb: 6.20,  gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 4.5),
        .init(code: "OSL", lat: 60.1939, lon: 11.1004,  landingFeePerKlb: 6.00,  gateFeeNarrowbody: 440, gateFeeWidebody: 1020, groundStopsPerMonth: 6.5),
        .init(code: "BRU", lat: 50.9014, lon: 4.4844,   landingFeePerKlb: 6.40,  gateFeeNarrowbody: 450, gateFeeWidebody: 1080, groundStopsPerMonth: 4.5),
        .init(code: "ARN", lat: 59.6519, lon: 17.9186,  landingFeePerKlb: 5.80,  gateFeeNarrowbody: 430, gateFeeWidebody: 1000, groundStopsPerMonth: 6.5),
        .init(code: "HEL", lat: 60.3172, lon: 24.9633,  landingFeePerKlb: 5.60,  gateFeeNarrowbody: 430, gateFeeWidebody: 1000, groundStopsPerMonth: 6.5),
        // Central & Eastern Europe + the Baltics.
        .init(code: "WAW", lat: 52.1657, lon: 20.9671,  landingFeePerKlb: 5.50,  gateFeeNarrowbody: 420, gateFeeWidebody: 950,  groundStopsPerMonth: 4.5),
        .init(code: "BUD", lat: 47.4369, lon: 19.2556,  landingFeePerKlb: 5.00,  gateFeeNarrowbody: 400, gateFeeWidebody: 900,  groundStopsPerMonth: 4.0),
        .init(code: "BTS", lat: 48.1702, lon: 17.2127,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 4.0),
        .init(code: "BEG", lat: 44.8184, lon: 20.3091,  landingFeePerKlb: 4.20,  gateFeeNarrowbody: 350, gateFeeWidebody: 760,  groundStopsPerMonth: 4.0),
        .init(code: "KBP", lat: 50.3450, lon: 30.8947,  landingFeePerKlb: 4.00,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 4.5),
        .init(code: "RIX", lat: 56.9236, lon: 23.9711,  landingFeePerKlb: 4.20,  gateFeeNarrowbody: 350, gateFeeWidebody: 760,  groundStopsPerMonth: 5.0),
        .init(code: "VNO", lat: 54.6341, lon: 25.2858,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 5.0),
        .init(code: "TLL", lat: 59.4133, lon: 24.8328,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 5.5),
        .init(code: "MSQ", lat: 53.8825, lon: 28.0307,  landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 5.0),
        .init(code: "ZAG", lat: 45.7429, lon: 16.0688,  landingFeePerKlb: 4.00,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 4.0),
        .init(code: "SOF", lat: 42.6952, lon: 23.4062,  landingFeePerKlb: 4.00,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 4.0),
        .init(code: "SJJ", lat: 43.8246, lon: 18.3315,  landingFeePerKlb: 3.60,  gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 4.0),
        // Atlantic islands — lone dots (110m basemap drops islands this small).
        // LPA (Canary Islands) sits off the Moroccan coast → Africa carrier region
        // + Africa map hue; PDL (Azores) is Portuguese Atlantic → Europe region/hue.
        .init(code: "LPA", lat: 27.9319, lon: -15.3866, landingFeePerKlb: 4.50,  gateFeeNarrowbody: 360, gateFeeWidebody: 820,  groundStopsPerMonth: 2.0),
        .init(code: "PDL", lat: 37.7412, lon: -25.6979, landingFeePerKlb: 3.80,  gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 4.0),
        .init(code: "LED", lat: 59.8003, lon: 30.2625,  landingFeePerKlb: 4.80,  gateFeeNarrowbody: 380, gateFeeWidebody: 840,  groundStopsPerMonth: 6.5),
        .init(code: "BER", lat: 52.3667, lon: 13.5033,  landingFeePerKlb: 6.20,  gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 4.5),
        .init(code: "ZRH", lat: 47.4647, lon: 8.5492,   landingFeePerKlb: 7.50,  gateFeeNarrowbody: 490, gateFeeWidebody: 1250, groundStopsPerMonth: 4.0),
        .init(code: "DUS", lat: 51.2895, lon: 6.7668,   landingFeePerKlb: 6.00,  gateFeeNarrowbody: 440, gateFeeWidebody: 1020, groundStopsPerMonth: 4.5),
        .init(code: "AGP", lat: 36.6749, lon: -4.4991,  landingFeePerKlb: 4.20,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 1.5),
        .init(code: "VCE", lat: 45.5053, lon: 12.3519,  landingFeePerKlb: 5.20,  gateFeeNarrowbody: 400, gateFeeWidebody: 900,  groundStopsPerMonth: 3.5),
        .init(code: "OTP", lat: 44.5711, lon: 26.0850,  landingFeePerKlb: 4.60,  gateFeeNarrowbody: 370, gateFeeWidebody: 800,  groundStopsPerMonth: 3.5),
        .init(code: "GVA", lat: 46.2381, lon: 6.1090,   landingFeePerKlb: 6.80,  gateFeeNarrowbody: 460, gateFeeWidebody: 1120, groundStopsPerMonth: 4.0),
        .init(code: "HAM", lat: 53.6304, lon: 9.9882,   landingFeePerKlb: 5.60,  gateFeeNarrowbody: 420, gateFeeWidebody: 960,  groundStopsPerMonth: 4.5),
        .init(code: "NCE", lat: 43.6584, lon: 7.2159,   landingFeePerKlb: 5.40,  gateFeeNarrowbody: 410, gateFeeWidebody: 940,  groundStopsPerMonth: 2.0),
        .init(code: "NAP", lat: 40.8860, lon: 14.2908,  landingFeePerKlb: 4.80,  gateFeeNarrowbody: 380, gateFeeWidebody: 840,  groundStopsPerMonth: 2.5),
        .init(code: "EDI", lat: 55.9500, lon: -3.3725,  landingFeePerKlb: 5.20,  gateFeeNarrowbody: 400, gateFeeWidebody: 900,  groundStopsPerMonth: 5.0),
        .init(code: "PRG", lat: 50.1008, lon: 14.2600,  landingFeePerKlb: 5.00,  gateFeeNarrowbody: 390, gateFeeWidebody: 880,  groundStopsPerMonth: 4.0),
        .init(code: "KEF", lat: 63.9850, lon: -22.6056, landingFeePerKlb: 4.60,  gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 6.0),
        .init(code: "VKO", lat: 55.5915, lon: 37.2615,  landingFeePerKlb: 4.80,  gateFeeNarrowbody: 380, gateFeeWidebody: 840,  groundStopsPerMonth: 6.5),
        .init(code: "BRS", lat: 51.3827, lon: -2.7191,  landingFeePerKlb: 4.20,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 4.5),
        .init(code: "OPO", lat: 41.2481, lon: -8.6814,  landingFeePerKlb: 4.40,  gateFeeNarrowbody: 350, gateFeeWidebody: 760,  groundStopsPerMonth: 2.5),
        .init(code: "BGY", lat: 45.6739, lon: 9.7042,   landingFeePerKlb: 4.20,  gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 3.5),
        .init(code: "ALC", lat: 38.2822, lon: -0.5582,  landingFeePerKlb: 4.00,  gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 1.5),

        // ── Africa (top 25). Real lat/lon; fee/ground-stop figures are the same
        // TIER-BASED ESTIMATES as the LatAm/Canada/Europe sets. Ground-stops lean
        // low (less weather disruption; occasional sand/haze). No African carriers
        // in the roster yet — see africaRoster (added alongside this).
        .init(code: "CAI", lat: 30.1219, lon: 31.4056,  landingFeePerKlb: 5.00, gateFeeNarrowbody: 400, gateFeeWidebody: 950, groundStopsPerMonth: 2.5),
        .init(code: "JNB", lat: -26.1392, lon: 28.2460, landingFeePerKlb: 5.20, gateFeeNarrowbody: 410, gateFeeWidebody: 1000, groundStopsPerMonth: 3.0),
        .init(code: "ADD", lat: 8.9779,  lon: 38.7993,  landingFeePerKlb: 4.20, gateFeeNarrowbody: 360, gateFeeWidebody: 820, groundStopsPerMonth: 2.5),
        .init(code: "CMN", lat: 33.3675, lon: -7.5900,  landingFeePerKlb: 4.00, gateFeeNarrowbody: 350, gateFeeWidebody: 780, groundStopsPerMonth: 2.0),
        .init(code: "CPT", lat: -33.9715, lon: 18.6021, landingFeePerKlb: 4.40, gateFeeNarrowbody: 370, gateFeeWidebody: 820, groundStopsPerMonth: 3.0),
        .init(code: "HRG", lat: 27.1783, lon: 33.7994,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 1.5),
        .init(code: "NBO", lat: -1.3192, lon: 36.9278,  landingFeePerKlb: 4.20, gateFeeNarrowbody: 360, gateFeeWidebody: 820, groundStopsPerMonth: 2.5),
        .init(code: "RAK", lat: 31.6069, lon: -8.0363,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 1.8),
        .init(code: "LOS", lat: 6.5774,  lon: 3.3212,   landingFeePerKlb: 4.00, gateFeeNarrowbody: 350, gateFeeWidebody: 780, groundStopsPerMonth: 2.8),
        .init(code: "ALG", lat: 36.6910, lon: 3.2154,   landingFeePerKlb: 3.60, gateFeeNarrowbody: 330, gateFeeWidebody: 720, groundStopsPerMonth: 2.2),
        .init(code: "TUN", lat: 36.8510, lon: 10.2272,  landingFeePerKlb: 3.40, gateFeeNarrowbody: 320, gateFeeWidebody: 680, groundStopsPerMonth: 2.0),
        .init(code: "DUR", lat: -29.6144, lon: 31.1197, landingFeePerKlb: 3.40, gateFeeNarrowbody: 320, gateFeeWidebody: 680, groundStopsPerMonth: 2.8),
        .init(code: "ABJ", lat: 5.2614,  lon: -3.9263,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 2.5),
        .init(code: "ACC", lat: 5.6052,  lon: -0.1668,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 2.5),
        .init(code: "ABV", lat: 9.0068,  lon: 7.2632,   landingFeePerKlb: 3.30, gateFeeNarrowbody: 315, gateFeeWidebody: 670, groundStopsPerMonth: 2.5),
        .init(code: "DSS", lat: 14.6710, lon: -17.0733, landingFeePerKlb: 3.10, gateFeeNarrowbody: 305, gateFeeWidebody: 650, groundStopsPerMonth: 2.2),
        .init(code: "SSH", lat: 27.9773, lon: 34.3950,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 1.5),
        .init(code: "MRU", lat: -20.4302, lon: 57.6836, landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 2.5),
        // Indian Ocean island LEISURE destinations (designer request; estimates).
        .init(code: "SEZ", lat: -4.6743,  lon: 55.5218, landingFeePerKlb: 3.40, gateFeeNarrowbody: 340, gateFeeWidebody: 700, groundStopsPerMonth: 1.5),
        .init(code: "RBA", lat: 34.0515, lon: -6.7515,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 280, gateFeeWidebody: 580, groundStopsPerMonth: 1.8),
        .init(code: "KGL", lat: -1.9686, lon: 30.1395,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 2.5),
        .init(code: "EBB", lat: 0.0424,  lon: 32.4435,  landingFeePerKlb: 3.10, gateFeeNarrowbody: 305, gateFeeWidebody: 650, groundStopsPerMonth: 2.8),
        // Africa expansion (designer list, top-40 pass) — real lat/lon; fees are
        // tier ESTIMATES calibrated to the existing Africa entries.
        .init(code: "ZNZ", lat: -6.2220, lon: 39.2249,  landingFeePerKlb: 2.90, gateFeeNarrowbody: 290, gateFeeWidebody: 620, groundStopsPerMonth: 2.2),
        .init(code: "FIH", lat: -4.3858, lon: 15.4446,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 3.0),
        .init(code: "MPM", lat: -25.9208, lon: 32.5726, landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 2.4),
        .init(code: "HRE", lat: -17.9319, lon: 31.0928, landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 2.3),
        .init(code: "MIR", lat: 35.7581, lon: 10.7547,  landingFeePerKlb: 2.90, gateFeeNarrowbody: 290, gateFeeWidebody: 620, groundStopsPerMonth: 1.8),
        .init(code: "TNR", lat: -18.7969, lon: 47.4788, landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 2.6),
        .init(code: "DJE", lat: 33.8750, lon: 10.7755,  landingFeePerKlb: 2.90, gateFeeNarrowbody: 290, gateFeeWidebody: 620, groundStopsPerMonth: 1.8),
        .init(code: "BFN", lat: -29.0927, lon: 26.3024, landingFeePerKlb: 2.70, gateFeeNarrowbody: 270, gateFeeWidebody: 580, groundStopsPerMonth: 2.0),
        .init(code: "LUN", lat: -15.3308, lon: 28.4526, landingFeePerKlb: 3.10, gateFeeNarrowbody: 305, gateFeeWidebody: 650, groundStopsPerMonth: 2.5),
        .init(code: "LBV", lat: 0.4586,  lon: 9.4123,   landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 2.7),
        .init(code: "KAN", lat: 12.0476, lon: 8.5246,   landingFeePerKlb: 2.90, gateFeeNarrowbody: 290, gateFeeWidebody: 620, groundStopsPerMonth: 2.2),
        .init(code: "CKY", lat: 9.5770,  lon: -13.6120, landingFeePerKlb: 2.90, gateFeeNarrowbody: 290, gateFeeWidebody: 620, groundStopsPerMonth: 2.6),
        .init(code: "PLZ", lat: -33.9850, lon: 25.6173, landingFeePerKlb: 2.70, gateFeeNarrowbody: 270, gateFeeWidebody: 580, groundStopsPerMonth: 2.2),
        .init(code: "EDL", lat: 0.4045,  lon: 35.2389,  landingFeePerKlb: 2.60, gateFeeNarrowbody: 260, gateFeeWidebody: 560, groundStopsPerMonth: 2.2),
        .init(code: "BSK", lat: 34.7933, lon: 5.7382,   landingFeePerKlb: 2.60, gateFeeNarrowbody: 260, gateFeeWidebody: 560, groundStopsPerMonth: 1.8),
        .init(code: "SID", lat: 16.7414, lon: -22.9494, landingFeePerKlb: 2.90, gateFeeNarrowbody: 290, gateFeeWidebody: 620, groundStopsPerMonth: 2.0),
        .init(code: "DZA", lat: -12.8047, lon: 45.2811, landingFeePerKlb: 2.80, gateFeeNarrowbody: 280, gateFeeWidebody: 600, groundStopsPerMonth: 2.4),
        // South Asia trio (designer request: largest in Bangladesh / Nepal / Bhutan).
        // PBH's high ground-stop rate is deliberate — Paro is a real daylight/
        // VFR-only valley approach, one of the world's most restricted fields.
        .init(code: "DAC", lat: 23.8433, lon: 90.3978,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 330, gateFeeWidebody: 720, groundStopsPerMonth: 3.0),
        .init(code: "KTM", lat: 27.6966, lon: 85.3591,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 3.2),
        .init(code: "PBH", lat: 27.4032, lon: 89.4246,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 280, gateFeeWidebody: 600, groundStopsPerMonth: 3.5),
        .init(code: "LAD", lat: -8.8584, lon: 13.2312,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 330, gateFeeWidebody: 720, groundStopsPerMonth: 2.5),
        .init(code: "DAR", lat: -6.8781, lon: 39.2026,  landingFeePerKlb: 3.20, gateFeeNarrowbody: 310, gateFeeWidebody: 660, groundStopsPerMonth: 2.8),
        .init(code: "AGA", lat: 30.3250, lon: -9.4131,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 280, gateFeeWidebody: 580, groundStopsPerMonth: 1.8),
        .init(code: "TNG", lat: 35.7269, lon: -5.9169,  landingFeePerKlb: 2.80, gateFeeNarrowbody: 280, gateFeeWidebody: 580, groundStopsPerMonth: 2.0),

        // ── Asia + Middle East (top 50). Real lat/lon; fee/ground-stop figures
        // are the same TIER-BASED ESTIMATES as the other overseas sets. Ground-
        // stops lean high for China (ATC flow control) and typhoon/monsoon
        // airports, low for the Gulf. NE classifies the Middle East as Asia, so
        // these all sit on the taupe Asia outline. See asiaRoster.
        // East Asia & Southeast Asia
        .init(code: "PEK", lat: 40.0801, lon: 116.5846, landingFeePerKlb: 7.50, gateFeeNarrowbody: 500, gateFeeWidebody: 1300, groundStopsPerMonth: 6.5),
        .init(code: "HND", lat: 35.5494, lon: 139.7798, landingFeePerKlb: 8.50, gateFeeNarrowbody: 540, gateFeeWidebody: 1400, groundStopsPerMonth: 3.5),
        .init(code: "PVG", lat: 31.1443, lon: 121.8083, landingFeePerKlb: 7.50, gateFeeNarrowbody: 500, gateFeeWidebody: 1300, groundStopsPerMonth: 6.5),
        .init(code: "CAN", lat: 23.3924, lon: 113.2988, landingFeePerKlb: 7.00, gateFeeNarrowbody: 480, gateFeeWidebody: 1200, groundStopsPerMonth: 6.0),
        .init(code: "SIN", lat: 1.3644,  lon: 103.9915, landingFeePerKlb: 8.00, gateFeeNarrowbody: 520, gateFeeWidebody: 1350, groundStopsPerMonth: 2.5),
        .init(code: "ICN", lat: 37.4602, lon: 126.4407, landingFeePerKlb: 7.50, gateFeeNarrowbody: 500, gateFeeWidebody: 1300, groundStopsPerMonth: 3.5),
        .init(code: "BKK", lat: 13.6900, lon: 100.7501, landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 4.0),
        .init(code: "HKG", lat: 22.3080, lon: 113.9185, landingFeePerKlb: 8.50, gateFeeNarrowbody: 540, gateFeeWidebody: 1400, groundStopsPerMonth: 4.5),
        .init(code: "KUL", lat: 2.7456,  lon: 101.7099, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 3.5),
        .init(code: "SZX", lat: 22.6393, lon: 113.8107, landingFeePerKlb: 7.00, gateFeeNarrowbody: 480, gateFeeWidebody: 1200, groundStopsPerMonth: 6.0),
        .init(code: "CTU", lat: 30.5785, lon: 103.9471, landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 6.0),
        .init(code: "TPE", lat: 25.0777, lon: 121.2328, landingFeePerKlb: 6.80, gateFeeNarrowbody: 470, gateFeeWidebody: 1150, groundStopsPerMonth: 4.0),
        .init(code: "MNL", lat: 14.5086, lon: 121.0197, landingFeePerKlb: 5.50, gateFeeNarrowbody: 420, gateFeeWidebody: 960,  groundStopsPerMonth: 4.5),
        .init(code: "KIX", lat: 34.4273, lon: 135.2440, landingFeePerKlb: 7.00, gateFeeNarrowbody: 480, gateFeeWidebody: 1200, groundStopsPerMonth: 3.0),
        .init(code: "CGK", lat: -6.1256, lon: 106.6559, landingFeePerKlb: 5.80, gateFeeNarrowbody: 430, gateFeeWidebody: 1000, groundStopsPerMonth: 4.0),
        .init(code: "KMG", lat: 25.1019, lon: 102.9291, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 5.5),
        .init(code: "XIY", lat: 34.4471, lon: 108.7516, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 5.5),
        .init(code: "HGH", lat: 30.2295, lon: 120.4344, landingFeePerKlb: 6.20, gateFeeNarrowbody: 450, gateFeeWidebody: 1080, groundStopsPerMonth: 5.5),
        .init(code: "NRT", lat: 35.7720, lon: 140.3929, landingFeePerKlb: 7.50, gateFeeNarrowbody: 500, gateFeeWidebody: 1300, groundStopsPerMonth: 3.5),
        // Japan expansion (designer: Japan is big enough for 10) — real lat/lon;
        // fees calibrated to the existing HND/NRT/KIX tier (Japan runs high).
        .init(code: "FUK", lat: 33.5859, lon: 130.4510, landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 3.2),
        .init(code: "CTS", lat: 42.7752, lon: 141.6923, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 4.5),
        .init(code: "OKA", lat: 26.1958, lon: 127.6460, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 3.8),
        .init(code: "ITM", lat: 34.7855, lon: 135.4382, landingFeePerKlb: 6.20, gateFeeNarrowbody: 450, gateFeeWidebody: 1080, groundStopsPerMonth: 2.8),
        .init(code: "NGO", lat: 34.8584, lon: 136.8049, landingFeePerKlb: 6.20, gateFeeNarrowbody: 450, gateFeeWidebody: 1080, groundStopsPerMonth: 3.0),
        .init(code: "KOJ", lat: 31.8034, lon: 130.7194, landingFeePerKlb: 5.40, gateFeeNarrowbody: 400, gateFeeWidebody: 950, groundStopsPerMonth: 3.2),
        .init(code: "SDJ", lat: 38.1397, lon: 140.9170, landingFeePerKlb: 5.20, gateFeeNarrowbody: 390, gateFeeWidebody: 920, groundStopsPerMonth: 3.4),
        // Central Asia (designer: largest in Turkmenistan / Uzbekistan / Kazakhstan).
        .init(code: "ASB", lat: 37.9868, lon: 58.3610,  landingFeePerKlb: 3.00, gateFeeNarrowbody: 300, gateFeeWidebody: 640, groundStopsPerMonth: 2.0),
        .init(code: "TAS", lat: 41.2579, lon: 69.2812,  landingFeePerKlb: 3.40, gateFeeNarrowbody: 320, gateFeeWidebody: 700, groundStopsPerMonth: 2.4),
        .init(code: "ALA", lat: 43.3521, lon: 77.0405,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 330, gateFeeWidebody: 720, groundStopsPerMonth: 3.0),
        .init(code: "CKG", lat: 29.7192, lon: 106.6417, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 5.5),
        .init(code: "WUH", lat: 30.7838, lon: 114.2081, landingFeePerKlb: 5.60, gateFeeNarrowbody: 420, gateFeeWidebody: 960,  groundStopsPerMonth: 5.5),
        .init(code: "SGN", lat: 10.8188, lon: 106.6520, landingFeePerKlb: 5.40, gateFeeNarrowbody: 410, gateFeeWidebody: 940,  groundStopsPerMonth: 3.5),
        .init(code: "SUB", lat: -7.3798, lon: 112.7869, landingFeePerKlb: 4.20, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 3.0),
        .init(code: "HAN", lat: 21.2212, lon: 105.8072, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 3.5),
        .init(code: "PNH", lat: 11.5466, lon: 104.8441, landingFeePerKlb: 4.50, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 3.0),
        .init(code: "RGN", lat: 16.9073, lon: 96.1332,  landingFeePerKlb: 4.20, gateFeeNarrowbody: 350, gateFeeWidebody: 760,  groundStopsPerMonth: 3.5),
        .init(code: "NYT", lat: 19.6234, lon: 96.2010,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 3.0),
        .init(code: "BWN", lat: 4.9442,  lon: 114.9283, landingFeePerKlb: 4.00, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 3.0),
        // South Asia
        .init(code: "DEL", lat: 28.5562, lon: 77.1000,  landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 4.0),
        // Maldives — LEISURE destination (designer request; estimates).
        .init(code: "MLE", lat: 4.1918,   lon: 73.5291,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 360, gateFeeWidebody: 760,  groundStopsPerMonth: 2.0),
        .init(code: "BOM", lat: 19.0887, lon: 72.8679,  landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 4.5),
        .init(code: "BLR", lat: 13.1986, lon: 77.7066,  landingFeePerKlb: 5.20, gateFeeNarrowbody: 400, gateFeeWidebody: 900,  groundStopsPerMonth: 2.5),
        .init(code: "HYD", lat: 17.2403, lon: 78.4294,  landingFeePerKlb: 4.80, gateFeeNarrowbody: 380, gateFeeWidebody: 840,  groundStopsPerMonth: 2.5),
        .init(code: "MAA", lat: 12.9941, lon: 80.1709,  landingFeePerKlb: 4.60, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 3.0),
        .init(code: "CCU", lat: 22.6547, lon: 88.4467,  landingFeePerKlb: 4.40, gateFeeNarrowbody: 360, gateFeeWidebody: 800,  groundStopsPerMonth: 3.5),
        .init(code: "AMD", lat: 23.0772, lon: 72.6347,  landingFeePerKlb: 4.00, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 2.5),
        .init(code: "COK", lat: 10.1520, lon: 76.4019,  landingFeePerKlb: 3.80, gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 3.0),
        .init(code: "PNQ", lat: 18.5793, lon: 73.9089,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 2.5),
        .init(code: "GOI", lat: 15.3808, lon: 73.8314,  landingFeePerKlb: 3.40, gateFeeNarrowbody: 310, gateFeeWidebody: 660,  groundStopsPerMonth: 2.5),
        .init(code: "KHI", lat: 24.9065, lon: 67.1608,  landingFeePerKlb: 4.80, gateFeeNarrowbody: 380, gateFeeWidebody: 840,  groundStopsPerMonth: 2.5),
        .init(code: "LHE", lat: 31.5216, lon: 74.4036,  landingFeePerKlb: 4.40, gateFeeNarrowbody: 360, gateFeeWidebody: 800,  groundStopsPerMonth: 2.5),
        .init(code: "ISB", lat: 33.5490, lon: 72.8256,  landingFeePerKlb: 4.60, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 2.5),
        // Middle East
        .init(code: "DXB", lat: 25.2532, lon: 55.3657,  landingFeePerKlb: 8.00, gateFeeNarrowbody: 520, gateFeeWidebody: 1400, groundStopsPerMonth: 1.5),
        .init(code: "DOH", lat: 25.2731, lon: 51.6081,  landingFeePerKlb: 7.50, gateFeeNarrowbody: 500, gateFeeWidebody: 1350, groundStopsPerMonth: 1.5),
        .init(code: "JED", lat: 21.6796, lon: 39.1565,  landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 1.5),
        .init(code: "RUH", lat: 24.9576, lon: 46.6988,  landingFeePerKlb: 5.80, gateFeeNarrowbody: 430, gateFeeWidebody: 1000, groundStopsPerMonth: 1.5),
        .init(code: "AUH", lat: 24.4330, lon: 54.6511,  landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1150, groundStopsPerMonth: 1.5),
        .init(code: "MCT", lat: 23.5933, lon: 58.2844,  landingFeePerKlb: 4.80, gateFeeNarrowbody: 380, gateFeeWidebody: 840,  groundStopsPerMonth: 1.5),
        .init(code: "KWI", lat: 29.2266, lon: 47.9689,  landingFeePerKlb: 4.60, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 1.8),
        .init(code: "BAH", lat: 26.2708, lon: 50.6336,  landingFeePerKlb: 4.60, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 1.8),
        .init(code: "DMM", lat: 26.4712, lon: 49.7979,  landingFeePerKlb: 4.60, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 1.8),
        .init(code: "SHJ", lat: 25.3286, lon: 55.5172,  landingFeePerKlb: 4.20, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 1.5),
        .init(code: "TLV", lat: 32.0114, lon: 34.8867,  landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 2.0),
        .init(code: "MED", lat: 24.5534, lon: 39.7051,  landingFeePerKlb: 4.40, gateFeeNarrowbody: 360, gateFeeWidebody: 800,  groundStopsPerMonth: 1.5),
        .init(code: "AMM", lat: 31.7226, lon: 35.9932,  landingFeePerKlb: 4.40, gateFeeNarrowbody: 360, gateFeeWidebody: 800,  groundStopsPerMonth: 2.0),
        .init(code: "BEY", lat: 33.8209, lon: 35.4884,  landingFeePerKlb: 4.20, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 2.2),
        .init(code: "MHD", lat: 36.2352, lon: 59.6410,  landingFeePerKlb: 3.60, gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 2.0),
        .init(code: "IKA", lat: 35.4161, lon: 51.1522,  landingFeePerKlb: 4.00, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 2.0),
        .init(code: "THR", lat: 35.6892, lon: 51.3134,  landingFeePerKlb: 4.00, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 2.0),

        // ── Oceania & South Pacific. Real lat/lon; tier-based fee/ground-stop
        // ESTIMATES (cyclone/tropical airports lean high). Australia/NZ sit on the
        // teal Oceania outline; the small islands (Fiji/Tahiti/New Caledonia/PNG)
        // are lone dots — NE 110m drops islands that small, same as Mauritius.
        // PPT (Tahiti) is stored at +210.4 (real −149.6 + 360) to cross the
        // antimeridian and render near Fiji rather than wrapping west. GUM (Guam)
        // is a US territory / United hub, so it's left in the US carrier region
        // (not oceaniaCodes) — its Asia/Pacific legs correctly draw United.
        .init(code: "SYD", lat: -33.9461, lon: 151.1772, landingFeePerKlb: 7.50, gateFeeNarrowbody: 500, gateFeeWidebody: 1300, groundStopsPerMonth: 2.0),
        .init(code: "MEL", lat: -37.6690, lon: 144.8410, landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 2.0),
        .init(code: "BNE", lat: -27.3842, lon: 153.1175, landingFeePerKlb: 6.00, gateFeeNarrowbody: 440, gateFeeWidebody: 1050, groundStopsPerMonth: 2.5),
        .init(code: "AKL", lat: -37.0082, lon: 174.7850, landingFeePerKlb: 6.50, gateFeeNarrowbody: 460, gateFeeWidebody: 1100, groundStopsPerMonth: 2.5),
        .init(code: "PER", lat: -31.9403, lon: 115.9669, landingFeePerKlb: 5.50, gateFeeNarrowbody: 420, gateFeeWidebody: 1000, groundStopsPerMonth: 1.8),
        .init(code: "ADL", lat: -34.9450, lon: 138.5306, landingFeePerKlb: 4.60, gateFeeNarrowbody: 370, gateFeeWidebody: 820,  groundStopsPerMonth: 2.0),
        .init(code: "CHC", lat: -43.4894, lon: 172.5322, landingFeePerKlb: 4.40, gateFeeNarrowbody: 360, gateFeeWidebody: 800,  groundStopsPerMonth: 2.5),
        .init(code: "OOL", lat: -28.1644, lon: 153.5047, landingFeePerKlb: 4.00, gateFeeNarrowbody: 340, gateFeeWidebody: 720,  groundStopsPerMonth: 2.5),
        .init(code: "WLG", lat: -41.3272, lon: 174.8053, landingFeePerKlb: 4.20, gateFeeNarrowbody: 350, gateFeeWidebody: 760,  groundStopsPerMonth: 3.5),
        .init(code: "CNS", lat: -16.8858, lon: 145.7553, landingFeePerKlb: 3.80, gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 3.5),
        .init(code: "NAN", lat: -17.7554, lon: 177.4434, landingFeePerKlb: 3.60, gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 3.5),
        .init(code: "HBA", lat: -42.8361, lon: 147.5103, landingFeePerKlb: 3.60, gateFeeNarrowbody: 320, gateFeeWidebody: 680,  groundStopsPerMonth: 2.5),
        .init(code: "DRW", lat: -12.4147, lon: 130.8767, landingFeePerKlb: 3.80, gateFeeNarrowbody: 330, gateFeeWidebody: 700,  groundStopsPerMonth: 3.5),
        .init(code: "ZQN", lat: -45.0211, lon: 168.7392, landingFeePerKlb: 3.40, gateFeeNarrowbody: 310, gateFeeWidebody: 660,  groundStopsPerMonth: 3.5),
        .init(code: "PPT", lat: -17.5537, lon: 210.4340, landingFeePerKlb: 3.40, gateFeeNarrowbody: 310, gateFeeWidebody: 660,  groundStopsPerMonth: 2.5),
        .init(code: "TSV", lat: -19.2526, lon: 146.7651, landingFeePerKlb: 3.40, gateFeeNarrowbody: 310, gateFeeWidebody: 660,  groundStopsPerMonth: 3.0),
        .init(code: "LST", lat: -41.5453, lon: 147.2140, landingFeePerKlb: 3.20, gateFeeNarrowbody: 300, gateFeeWidebody: 640,  groundStopsPerMonth: 2.5),
        .init(code: "NOU", lat: -22.0146, lon: 166.2130, landingFeePerKlb: 3.40, gateFeeNarrowbody: 310, gateFeeWidebody: 660,  groundStopsPerMonth: 2.5),
        .init(code: "CBR", lat: -35.3069, lon: 149.1950, landingFeePerKlb: 4.20, gateFeeNarrowbody: 350, gateFeeWidebody: 760,  groundStopsPerMonth: 2.5),
        .init(code: "POM", lat: -9.4433,  lon: 147.2200, landingFeePerKlb: 3.40, gateFeeNarrowbody: 310, gateFeeWidebody: 660,  groundStopsPerMonth: 3.0),
        .init(code: "GUM", lat: 13.4834,  lon: 144.7960, landingFeePerKlb: 4.50, gateFeeNarrowbody: 380, gateFeeWidebody: 850,  groundStopsPerMonth: 3.0),
    ]

    /// Two distinct random airports — ported from randomRoutePair().
    static func randomPair() -> (Airport, Airport) {
        let a = all.randomElement()!
        var b = all.randomElement()!
        while b === a { b = all.randomElement()! }
        return (a, b)
    }

    /// Great-circle distance to another airport, in nautical miles. Longitude
    /// delta is normalized to [-180,180] so it's correct even for PPT (Tahiti),
    /// which is stored at +210° across the antimeridian.
    func greatCircleNM(to other: Airport) -> Double {
        let r = 3440.065
        let lat1 = lat * .pi / 180, lat2 = other.lat * .pi / 180
        var dLonDeg = other.lon - lon
        while dLonDeg > 180 { dLonDeg -= 360 }
        while dLonDeg < -180 { dLonDeg += 360 }
        let dLat = (other.lat - lat) * .pi / 180
        let dLon = dLonDeg * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
