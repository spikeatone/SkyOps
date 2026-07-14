//
//  AirportInfo.swift
//  Airline Architect — reference facts shown on the airport info card (tap an
//  airport on the map). Helps the player judge an airport's value to their
//  network: full name/location, annual aircraft operations, runway count +
//  longest runway, metro-area population (the underlying market) and annual
//  passengers (actual air-travel demand). Ground stops/month come from the
//  Airport model itself.
//
//  DATA CONFIDENCE: the 48 U.S. airports below carry REAL published figures,
//  rounded, ~2023–24 (FAA ATADS operations, airport-reported passengers, AirNav
//  runway data, Census MSA population). They're game-grade "real, rounded", not
//  survey-grade — spot-check a specific value before treating it as exact. The
//  Latin American + Canadian airports are NOT populated yet (the card degrades
//  gracefully to name/ground-stops for those) — a follow-up pass adds them.
//

import Foundation

struct AirportInfo {
    let name: String            // full airport name
    let city: String            // "Atlanta, GA" / "Toronto, ON"
    let operationsPerYear: Int  // annual aircraft movements (takeoffs + landings)
    let runways: Int
    let longestRunwayFt: Int
    let metroPopulation: Int    // metro / catchment population
    let annualPassengers: Int   // total annual passengers
}

extension Airport {
    /// This airport's reference facts, if populated (nil = not yet sourced).
    var info: AirportInfo? { Airport.infoByCode[code] }

    /// Real-ish reference data keyed by IATA code. U.S. airports populated;
    /// international pending (see file header).
    static let infoByCode: [String: AirportInfo] = [
        "ATL": .init(name: "Hartsfield–Jackson Atlanta International", city: "Atlanta, GA", operationsPerYear: 700_000, runways: 5, longestRunwayFt: 12_390, metroPopulation: 6_300_000, annualPassengers: 104_700_000),
        "ORD": .init(name: "O'Hare International", city: "Chicago, IL", operationsPerYear: 715_000, runways: 8, longestRunwayFt: 13_000, metroPopulation: 9_400_000, annualPassengers: 73_900_000),
        "DFW": .init(name: "Dallas/Fort Worth International", city: "Dallas, TX", operationsPerYear: 650_000, runways: 7, longestRunwayFt: 13_401, metroPopulation: 7_900_000, annualPassengers: 81_800_000),
        "DEN": .init(name: "Denver International", city: "Denver, CO", operationsPerYear: 640_000, runways: 6, longestRunwayFt: 16_000, metroPopulation: 2_980_000, annualPassengers: 77_800_000),
        "LAX": .init(name: "Los Angeles International", city: "Los Angeles, CA", operationsPerYear: 640_000, runways: 4, longestRunwayFt: 12_091, metroPopulation: 12_900_000, annualPassengers: 75_000_000),
        "LAS": .init(name: "Harry Reid International", city: "Las Vegas, NV", operationsPerYear: 545_000, runways: 4, longestRunwayFt: 14_515, metroPopulation: 2_340_000, annualPassengers: 57_600_000),
        "CLT": .init(name: "Charlotte Douglas International", city: "Charlotte, NC", operationsPerYear: 525_000, runways: 4, longestRunwayFt: 10_000, metroPopulation: 2_760_000, annualPassengers: 53_400_000),
        "MIA": .init(name: "Miami International", city: "Miami, FL", operationsPerYear: 420_000, runways: 4, longestRunwayFt: 13_016, metroPopulation: 6_140_000, annualPassengers: 52_300_000),
        "PHX": .init(name: "Phoenix Sky Harbor International", city: "Phoenix, AZ", operationsPerYear: 440_000, runways: 3, longestRunwayFt: 11_489, metroPopulation: 5_000_000, annualPassengers: 48_700_000),
        "JFK": .init(name: "John F. Kennedy International", city: "New York, NY", operationsPerYear: 460_000, runways: 4, longestRunwayFt: 14_511, metroPopulation: 20_100_000, annualPassengers: 62_500_000),
        "IAH": .init(name: "George Bush Intercontinental", city: "Houston, TX", operationsPerYear: 410_000, runways: 5, longestRunwayFt: 12_001, metroPopulation: 7_300_000, annualPassengers: 45_300_000),
        "SEA": .init(name: "Seattle–Tacoma International", city: "Seattle, WA", operationsPerYear: 425_000, runways: 3, longestRunwayFt: 11_901, metroPopulation: 4_020_000, annualPassengers: 50_900_000),
        "MCO": .init(name: "Orlando International", city: "Orlando, FL", operationsPerYear: 350_000, runways: 4, longestRunwayFt: 12_005, metroPopulation: 2_700_000, annualPassengers: 57_700_000),
        "SFO": .init(name: "San Francisco International", city: "San Francisco, CA", operationsPerYear: 380_000, runways: 4, longestRunwayFt: 11_870, metroPopulation: 4_700_000, annualPassengers: 50_200_000),
        "EWR": .init(name: "Newark Liberty International", city: "Newark, NJ", operationsPerYear: 415_000, runways: 3, longestRunwayFt: 11_000, metroPopulation: 20_100_000, annualPassengers: 49_100_000),
        "MSP": .init(name: "Minneapolis–Saint Paul International", city: "Minneapolis, MN", operationsPerYear: 400_000, runways: 4, longestRunwayFt: 11_006, metroPopulation: 3_690_000, annualPassengers: 36_400_000),
        "BOS": .init(name: "Boston Logan International", city: "Boston, MA", operationsPerYear: 390_000, runways: 6, longestRunwayFt: 10_083, metroPopulation: 4_900_000, annualPassengers: 40_700_000),
        "DTW": .init(name: "Detroit Metropolitan Wayne County", city: "Detroit, MI", operationsPerYear: 355_000, runways: 6, longestRunwayFt: 12_003, metroPopulation: 4_340_000, annualPassengers: 31_900_000),
        "FLL": .init(name: "Fort Lauderdale–Hollywood International", city: "Fort Lauderdale, FL", operationsPerYear: 300_000, runways: 2, longestRunwayFt: 9_000, metroPopulation: 6_140_000, annualPassengers: 35_100_000),
        "LGA": .init(name: "LaGuardia", city: "New York, NY", operationsPerYear: 370_000, runways: 2, longestRunwayFt: 7_003, metroPopulation: 20_100_000, annualPassengers: 30_900_000),
        "PHL": .init(name: "Philadelphia International", city: "Philadelphia, PA", operationsPerYear: 380_000, runways: 4, longestRunwayFt: 12_000, metroPopulation: 6_240_000, annualPassengers: 30_400_000),
        "SLC": .init(name: "Salt Lake City International", city: "Salt Lake City, UT", operationsPerYear: 330_000, runways: 4, longestRunwayFt: 12_003, metroPopulation: 1_260_000, annualPassengers: 26_400_000),
        "BWI": .init(name: "Baltimore/Washington International", city: "Baltimore, MD", operationsPerYear: 270_000, runways: 3, longestRunwayFt: 10_502, metroPopulation: 2_840_000, annualPassengers: 26_600_000),
        "SAN": .init(name: "San Diego International", city: "San Diego, CA", operationsPerYear: 240_000, runways: 1, longestRunwayFt: 9_401, metroPopulation: 3_290_000, annualPassengers: 25_000_000),
        "IAD": .init(name: "Washington Dulles International", city: "Washington, DC", operationsPerYear: 300_000, runways: 4, longestRunwayFt: 11_500, metroPopulation: 6_380_000, annualPassengers: 25_000_000),
        "MDW": .init(name: "Chicago Midway International", city: "Chicago, IL", operationsPerYear: 250_000, runways: 5, longestRunwayFt: 6_522, metroPopulation: 9_400_000, annualPassengers: 20_600_000),
        "AUS": .init(name: "Austin–Bergstrom International", city: "Austin, TX", operationsPerYear: 240_000, runways: 2, longestRunwayFt: 12_250, metroPopulation: 2_420_000, annualPassengers: 22_000_000),
        "DAL": .init(name: "Dallas Love Field", city: "Dallas, TX", operationsPerYear: 220_000, runways: 3, longestRunwayFt: 8_800, metroPopulation: 7_900_000, annualPassengers: 16_700_000),
        "PDX": .init(name: "Portland International", city: "Portland, OR", operationsPerYear: 220_000, runways: 3, longestRunwayFt: 11_000, metroPopulation: 2_510_000, annualPassengers: 19_300_000),
        "TPA": .init(name: "Tampa International", city: "Tampa, FL", operationsPerYear: 200_000, runways: 3, longestRunwayFt: 11_002, metroPopulation: 3_240_000, annualPassengers: 24_800_000),
        "STL": .init(name: "St. Louis Lambert International", city: "St. Louis, MO", operationsPerYear: 190_000, runways: 4, longestRunwayFt: 11_019, metroPopulation: 2_800_000, annualPassengers: 15_900_000),
        "HOU": .init(name: "William P. Hobby", city: "Houston, TX", operationsPerYear: 200_000, runways: 4, longestRunwayFt: 7_602, metroPopulation: 7_300_000, annualPassengers: 14_900_000),
        "RDU": .init(name: "Raleigh–Durham International", city: "Raleigh, NC", operationsPerYear: 210_000, runways: 3, longestRunwayFt: 10_000, metroPopulation: 1_510_000, annualPassengers: 14_600_000),
        "SMF": .init(name: "Sacramento International", city: "Sacramento, CA", operationsPerYear: 160_000, runways: 2, longestRunwayFt: 8_605, metroPopulation: 2_420_000, annualPassengers: 13_000_000),
        "SJC": .init(name: "Norman Y. Mineta San José International", city: "San Jose, CA", operationsPerYear: 190_000, runways: 2, longestRunwayFt: 11_000, metroPopulation: 2_000_000, annualPassengers: 12_300_000),
        "MCI": .init(name: "Kansas City International", city: "Kansas City, MO", operationsPerYear: 180_000, runways: 3, longestRunwayFt: 10_801, metroPopulation: 2_190_000, annualPassengers: 11_600_000),
        "SNA": .init(name: "John Wayne Airport", city: "Santa Ana, CA", operationsPerYear: 300_000, runways: 2, longestRunwayFt: 5_701, metroPopulation: 3_180_000, annualPassengers: 11_800_000),
        "IND": .init(name: "Indianapolis International", city: "Indianapolis, IN", operationsPerYear: 150_000, runways: 3, longestRunwayFt: 11_200, metroPopulation: 2_110_000, annualPassengers: 9_400_000),
        "CVG": .init(name: "Cincinnati/Northern Kentucky International", city: "Cincinnati, OH", operationsPerYear: 180_000, runways: 4, longestRunwayFt: 12_000, metroPopulation: 2_260_000, annualPassengers: 9_000_000),
        "PIT": .init(name: "Pittsburgh International", city: "Pittsburgh, PA", operationsPerYear: 140_000, runways: 4, longestRunwayFt: 11_500, metroPopulation: 2_370_000, annualPassengers: 9_100_000),
        "CMH": .init(name: "John Glenn Columbus International", city: "Columbus, OH", operationsPerYear: 130_000, runways: 2, longestRunwayFt: 10_125, metroPopulation: 2_140_000, annualPassengers: 8_900_000),
        "MSY": .init(name: "Louis Armstrong New Orleans International", city: "New Orleans, LA", operationsPerYear: 130_000, runways: 3, longestRunwayFt: 10_104, metroPopulation: 1_270_000, annualPassengers: 13_900_000),
        "CLE": .init(name: "Cleveland Hopkins International", city: "Cleveland, OH", operationsPerYear: 140_000, runways: 3, longestRunwayFt: 9_956, metroPopulation: 2_060_000, annualPassengers: 9_900_000),
        "RSW": .init(name: "Southwest Florida International", city: "Fort Myers, FL", operationsPerYear: 110_000, runways: 1, longestRunwayFt: 12_000, metroPopulation: 830_000, annualPassengers: 10_900_000),
        "OAK": .init(name: "Oakland International", city: "Oakland, CA", operationsPerYear: 190_000, runways: 4, longestRunwayFt: 10_000, metroPopulation: 4_700_000, annualPassengers: 11_500_000),
        "SAT": .init(name: "San Antonio International", city: "San Antonio, TX", operationsPerYear: 180_000, runways: 3, longestRunwayFt: 8_505, metroPopulation: 2_660_000, annualPassengers: 10_400_000),
        "ANC": .init(name: "Ted Stevens Anchorage International", city: "Anchorage, AK", operationsPerYear: 280_000, runways: 3, longestRunwayFt: 12_400, metroPopulation: 400_000, annualPassengers: 5_000_000),
        "HNL": .init(name: "Daniel K. Inouye International", city: "Honolulu, HI", operationsPerYear: 300_000, runways: 4, longestRunwayFt: 12_300, metroPopulation: 1_000_000, annualPassengers: 21_200_000),
    ]
}
