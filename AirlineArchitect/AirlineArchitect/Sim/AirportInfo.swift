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
//  46 Latin American + 20 Canadian airports are also populated, but their
//  operations/passenger figures are lower-confidence best-effort values (fewer
//  authoritative English sources) — treat those as approximate, not exact.
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

        // ── Canada (best-effort ~2023–24) ──────────────────────────────────
        "YYZ": .init(name: "Toronto Pearson International", city: "Toronto, ON", operationsPerYear: 450_000, runways: 5, longestRunwayFt: 11_120, metroPopulation: 6_600_000, annualPassengers: 47_000_000),
        "YVR": .init(name: "Vancouver International", city: "Vancouver, BC", operationsPerYear: 310_000, runways: 3, longestRunwayFt: 11_500, metroPopulation: 2_600_000, annualPassengers: 26_000_000),
        "YUL": .init(name: "Montréal–Trudeau International", city: "Montreal, QC", operationsPerYear: 230_000, runways: 3, longestRunwayFt: 11_000, metroPopulation: 4_300_000, annualPassengers: 21_200_000),
        "YYC": .init(name: "Calgary International", city: "Calgary, AB", operationsPerYear: 230_000, runways: 4, longestRunwayFt: 14_000, metroPopulation: 1_600_000, annualPassengers: 18_000_000),
        "YEG": .init(name: "Edmonton International", city: "Edmonton, AB", operationsPerYear: 150_000, runways: 2, longestRunwayFt: 11_000, metroPopulation: 1_540_000, annualPassengers: 8_000_000),
        "YOW": .init(name: "Ottawa Macdonald–Cartier International", city: "Ottawa, ON", operationsPerYear: 110_000, runways: 3, longestRunwayFt: 10_000, metroPopulation: 1_490_000, annualPassengers: 5_000_000),
        "YWG": .init(name: "Winnipeg James Armstrong Richardson International", city: "Winnipeg, MB", operationsPerYear: 110_000, runways: 3, longestRunwayFt: 11_000, metroPopulation: 850_000, annualPassengers: 4_300_000),
        "YHZ": .init(name: "Halifax Stanfield International", city: "Halifax, NS", operationsPerYear: 80_000, runways: 2, longestRunwayFt: 10_500, metroPopulation: 480_000, annualPassengers: 4_100_000),
        "YTZ": .init(name: "Billy Bishop Toronto City", city: "Toronto, ON", operationsPerYear: 120_000, runways: 2, longestRunwayFt: 3_988, metroPopulation: 6_600_000, annualPassengers: 2_800_000),
        "YLW": .init(name: "Kelowna International", city: "Kelowna, BC", operationsPerYear: 65_000, runways: 1, longestRunwayFt: 8_900, metroPopulation: 220_000, annualPassengers: 2_000_000),
        "YYJ": .init(name: "Victoria International", city: "Victoria, BC", operationsPerYear: 120_000, runways: 2, longestRunwayFt: 7_000, metroPopulation: 400_000, annualPassengers: 1_900_000),
        "YYT": .init(name: "St. John's International", city: "St. John's, NL", operationsPerYear: 40_000, runways: 2, longestRunwayFt: 8_500, metroPopulation: 210_000, annualPassengers: 1_500_000),
        "YXE": .init(name: "Saskatoon John G. Diefenbaker International", city: "Saskatoon, SK", operationsPerYear: 50_000, runways: 2, longestRunwayFt: 8_300, metroPopulation: 320_000, annualPassengers: 1_500_000),
        "YQR": .init(name: "Regina International", city: "Regina, SK", operationsPerYear: 40_000, runways: 2, longestRunwayFt: 7_900, metroPopulation: 260_000, annualPassengers: 1_200_000),
        "YQM": .init(name: "Greater Moncton Roméo LeBlanc International", city: "Moncton, NB", operationsPerYear: 35_000, runways: 2, longestRunwayFt: 8_000, metroPopulation: 160_000, annualPassengers: 700_000),
        "YSJ": .init(name: "Saint John Airport", city: "Saint John, NB", operationsPerYear: 15_000, runways: 1, longestRunwayFt: 7_000, metroPopulation: 130_000, annualPassengers: 250_000),
        "YQG": .init(name: "Windsor International", city: "Windsor, ON", operationsPerYear: 25_000, runways: 2, longestRunwayFt: 9_000, metroPopulation: 340_000, annualPassengers: 400_000),
        "YFC": .init(name: "Fredericton International", city: "Fredericton, NB", operationsPerYear: 20_000, runways: 1, longestRunwayFt: 8_000, metroPopulation: 110_000, annualPassengers: 400_000),
        "YQT": .init(name: "Thunder Bay International", city: "Thunder Bay, ON", operationsPerYear: 40_000, runways: 2, longestRunwayFt: 7_300, metroPopulation: 120_000, annualPassengers: 700_000),
        "YMM": .init(name: "Fort McMurray International", city: "Fort McMurray, AB", operationsPerYear: 30_000, runways: 1, longestRunwayFt: 7_500, metroPopulation: 70_000, annualPassengers: 700_000),

        // ── Mexico (best-effort ~2023–24) ──────────────────────────────────
        "MEX": .init(name: "Mexico City International (Benito Juárez)", city: "Mexico City, Mexico", operationsPerYear: 450_000, runways: 2, longestRunwayFt: 12_966, metroPopulation: 21_800_000, annualPassengers: 45_000_000),
        "CUN": .init(name: "Cancún International", city: "Cancún, Mexico", operationsPerYear: 220_000, runways: 2, longestRunwayFt: 11_483, metroPopulation: 900_000, annualPassengers: 30_000_000),
        "GDL": .init(name: "Guadalajara International (Miguel Hidalgo)", city: "Guadalajara, Mexico", operationsPerYear: 160_000, runways: 1, longestRunwayFt: 13_120, metroPopulation: 5_200_000, annualPassengers: 16_000_000),
        "TIJ": .init(name: "Tijuana International (General Abelardo L. Rodríguez)", city: "Tijuana, Mexico", operationsPerYear: 90_000, runways: 1, longestRunwayFt: 9_678, metroPopulation: 2_200_000, annualPassengers: 12_000_000),
        "MTY": .init(name: "Monterrey International (General Mariano Escobedo)", city: "Monterrey, Mexico", operationsPerYear: 120_000, runways: 2, longestRunwayFt: 9_843, metroPopulation: 5_300_000, annualPassengers: 13_000_000),
        "SJD": .init(name: "Los Cabos International", city: "San José del Cabo, Mexico", operationsPerYear: 60_000, runways: 2, longestRunwayFt: 9_843, metroPopulation: 350_000, annualPassengers: 8_000_000),
        "PVR": .init(name: "Puerto Vallarta International (Gustavo Díaz Ordaz)", city: "Puerto Vallarta, Mexico", operationsPerYear: 55_000, runways: 1, longestRunwayFt: 10_171, metroPopulation: 380_000, annualPassengers: 6_000_000),
        "NLU": .init(name: "Felipe Ángeles International", city: "Mexico City, Mexico", operationsPerYear: 30_000, runways: 2, longestRunwayFt: 13_780, metroPopulation: 21_800_000, annualPassengers: 4_000_000),
        "MID": .init(name: "Mérida International (Manuel Crescencio Rejón)", city: "Mérida, Mexico", operationsPerYear: 40_000, runways: 1, longestRunwayFt: 10_663, metroPopulation: 1_200_000, annualPassengers: 3_000_000),
        "BJX": .init(name: "Del Bajío International (Guanajuato)", city: "León, Mexico", operationsPerYear: 40_000, runways: 1, longestRunwayFt: 11_483, metroPopulation: 1_600_000, annualPassengers: 2_500_000),
        "CUL": .init(name: "Culiacán International (Bachigualato)", city: "Culiacán, Mexico", operationsPerYear: 30_000, runways: 1, longestRunwayFt: 8_530, metroPopulation: 900_000, annualPassengers: 2_000_000),
        "VER": .init(name: "Veracruz International (General Heriberto Jara)", city: "Veracruz, Mexico", operationsPerYear: 25_000, runways: 1, longestRunwayFt: 7_874, metroPopulation: 800_000, annualPassengers: 1_500_000),
        "HMO": .init(name: "Hermosillo International (General Ignacio Pesqueira)", city: "Hermosillo, Mexico", operationsPerYear: 30_000, runways: 1, longestRunwayFt: 7_382, metroPopulation: 900_000, annualPassengers: 1_800_000),
        "OAX": .init(name: "Oaxaca International (Xoxocotlán)", city: "Oaxaca, Mexico", operationsPerYear: 20_000, runways: 1, longestRunwayFt: 8_858, metroPopulation: 700_000, annualPassengers: 1_200_000),
        "MZT": .init(name: "Mazatlán International (General Rafael Buelna)", city: "Mazatlán, Mexico", operationsPerYear: 25_000, runways: 1, longestRunwayFt: 8_858, metroPopulation: 500_000, annualPassengers: 2_000_000),
        "CZM": .init(name: "Cozumel International", city: "Cozumel, Mexico", operationsPerYear: 20_000, runways: 1, longestRunwayFt: 10_165, metroPopulation: 90_000, annualPassengers: 1_000_000),

        // ── Central America (best-effort ~2023–24) ─────────────────────────
        "PTY": .init(name: "Tocumen International", city: "Panama City, Panama", operationsPerYear: 120_000, runways: 2, longestRunwayFt: 10_006, metroPopulation: 1_900_000, annualPassengers: 16_000_000),
        "SJO": .init(name: "Juan Santamaría International", city: "San José, Costa Rica", operationsPerYear: 80_000, runways: 1, longestRunwayFt: 9_882, metroPopulation: 2_200_000, annualPassengers: 5_500_000),
        "SAL": .init(name: "El Salvador International (Óscar Romero)", city: "San Salvador, El Salvador", operationsPerYear: 40_000, runways: 1, longestRunwayFt: 10_500, metroPopulation: 1_800_000, annualPassengers: 3_500_000),
        "GUA": .init(name: "La Aurora International", city: "Guatemala City, Guatemala", operationsPerYear: 50_000, runways: 1, longestRunwayFt: 9_800, metroPopulation: 3_000_000, annualPassengers: 3_000_000),
        "LIR": .init(name: "Daniel Oduber Quirós International", city: "Liberia, Costa Rica", operationsPerYear: 15_000, runways: 1, longestRunwayFt: 9_200, metroPopulation: 60_000, annualPassengers: 1_200_000),
        "SAP": .init(name: "Ramón Villeda Morales International", city: "San Pedro Sula, Honduras", operationsPerYear: 20_000, runways: 1, longestRunwayFt: 9_100, metroPopulation: 800_000, annualPassengers: 1_200_000),
        "MGA": .init(name: "Augusto C. Sandino International", city: "Managua, Nicaragua", operationsPerYear: 20_000, runways: 1, longestRunwayFt: 8_000, metroPopulation: 1_000_000, annualPassengers: 1_400_000),
        "BZE": .init(name: "Philip S. W. Goldson International", city: "Belize City, Belize", operationsPerYear: 15_000, runways: 1, longestRunwayFt: 9_600, metroPopulation: 60_000, annualPassengers: 1_000_000),
        "XPL": .init(name: "Comayagua International (Palmerola)", city: "Comayagua, Honduras", operationsPerYear: 10_000, runways: 1, longestRunwayFt: 8_000, metroPopulation: 300_000, annualPassengers: 500_000),
        "RTB": .init(name: "Juan Manuel Gálvez International", city: "Roatán, Honduras", operationsPerYear: 10_000, runways: 1, longestRunwayFt: 7_300, metroPopulation: 100_000, annualPassengers: 500_000),

        // ── South America (best-effort ~2023–24) ───────────────────────────
        "BOG": .init(name: "El Dorado International", city: "Bogotá, Colombia", operationsPerYear: 350_000, runways: 2, longestRunwayFt: 12_467, metroPopulation: 11_000_000, annualPassengers: 35_000_000),
        "GRU": .init(name: "São Paulo/Guarulhos International", city: "São Paulo, Brazil", operationsPerYear: 250_000, runways: 2, longestRunwayFt: 12_140, metroPopulation: 22_000_000, annualPassengers: 38_000_000),
        "SCL": .init(name: "Arturo Merino Benítez International", city: "Santiago, Chile", operationsPerYear: 180_000, runways: 2, longestRunwayFt: 12_795, metroPopulation: 7_100_000, annualPassengers: 24_000_000),
        "LIM": .init(name: "Jorge Chávez International", city: "Lima, Peru", operationsPerYear: 180_000, runways: 2, longestRunwayFt: 11_506, metroPopulation: 10_000_000, annualPassengers: 22_000_000),
        "CGH": .init(name: "São Paulo/Congonhas", city: "São Paulo, Brazil", operationsPerYear: 180_000, runways: 2, longestRunwayFt: 6_365, metroPopulation: 22_000_000, annualPassengers: 21_000_000),
        "AEP": .init(name: "Aeroparque Jorge Newbery", city: "Buenos Aires, Argentina", operationsPerYear: 100_000, runways: 1, longestRunwayFt: 6_900, metroPopulation: 15_000_000, annualPassengers: 11_000_000),
        "GIG": .init(name: "Rio de Janeiro/Galeão International", city: "Rio de Janeiro, Brazil", operationsPerYear: 100_000, runways: 2, longestRunwayFt: 13_123, metroPopulation: 12_000_000, annualPassengers: 9_000_000),
        "VCP": .init(name: "Viracopos International", city: "Campinas, Brazil", operationsPerYear: 90_000, runways: 1, longestRunwayFt: 10_630, metroPopulation: 3_300_000, annualPassengers: 10_000_000),
        "MDE": .init(name: "José María Córdova International", city: "Medellín, Colombia", operationsPerYear: 80_000, runways: 1, longestRunwayFt: 11_483, metroPopulation: 4_000_000, annualPassengers: 9_000_000),
        "BSB": .init(name: "Brasília International (Juscelino Kubitschek)", city: "Brasília, Brazil", operationsPerYear: 120_000, runways: 2, longestRunwayFt: 10_499, metroPopulation: 4_800_000, annualPassengers: 15_000_000),
        "EZE": .init(name: "Ministro Pistarini International (Ezeiza)", city: "Buenos Aires, Argentina", operationsPerYear: 100_000, runways: 2, longestRunwayFt: 10_827, metroPopulation: 15_000_000, annualPassengers: 11_000_000),
        "UIO": .init(name: "Mariscal Sucre International", city: "Quito, Ecuador", operationsPerYear: 70_000, runways: 1, longestRunwayFt: 13_451, metroPopulation: 2_000_000, annualPassengers: 5_500_000),
        "SDU": .init(name: "Santos Dumont", city: "Rio de Janeiro, Brazil", operationsPerYear: 90_000, runways: 2, longestRunwayFt: 4_341, metroPopulation: 12_000_000, annualPassengers: 9_000_000),
        "CLO": .init(name: "Alfonso Bonilla Aragón International", city: "Cali, Colombia", operationsPerYear: 60_000, runways: 1, longestRunwayFt: 9_842, metroPopulation: 2_800_000, annualPassengers: 6_000_000),
        "CNF": .init(name: "Tancredo Neves International (Confins)", city: "Belo Horizonte, Brazil", operationsPerYear: 80_000, runways: 1, longestRunwayFt: 10_006, metroPopulation: 6_000_000, annualPassengers: 10_000_000),
        "CTG": .init(name: "Rafael Núñez International", city: "Cartagena, Colombia", operationsPerYear: 50_000, runways: 1, longestRunwayFt: 8_530, metroPopulation: 1_000_000, annualPassengers: 5_500_000),
        "POA": .init(name: "Salgado Filho International", city: "Porto Alegre, Brazil", operationsPerYear: 70_000, runways: 1, longestRunwayFt: 9_190, metroPopulation: 4_300_000, annualPassengers: 8_000_000),
        "REC": .init(name: "Recife/Guararapes International", city: "Recife, Brazil", operationsPerYear: 70_000, runways: 1, longestRunwayFt: 10_000, metroPopulation: 4_000_000, annualPassengers: 8_000_000),
        "SSA": .init(name: "Salvador International (Luís Eduardo Magalhães)", city: "Salvador, Brazil", operationsPerYear: 70_000, runways: 2, longestRunwayFt: 10_007, metroPopulation: 3_900_000, annualPassengers: 7_000_000),
        "GYE": .init(name: "José Joaquín de Olmedo International", city: "Guayaquil, Ecuador", operationsPerYear: 60_000, runways: 1, longestRunwayFt: 8_858, metroPopulation: 3_100_000, annualPassengers: 5_000_000),
    ]
}
