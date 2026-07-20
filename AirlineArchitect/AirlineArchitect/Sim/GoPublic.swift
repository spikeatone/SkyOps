//
//  GoPublic.swift
//  Airline Architect — taking the airline public (IPO)
//
//  GO_PUBLIC_SPEC.md, step 1: the stock price model, the IPO transaction, and the
//  ticker. A second capital route beside loans — no repayment, but you sell a
//  slice of the company and gain a market that watches every move.
//
//  Types + pure read-only logic live here; the mutating IPO/tick work is in
//  Simulation.swift ("Public company" MARK), because it touches private(set)
//  state — the same split as Acquisition.swift.
//
//  DESIGNER DECISIONS (locked): board can OUST you (step 4); the string is BOTH
//  growth and dividends (steps 2–3); unlock at $500M net worth; NO float cap —
//  dilution is self-priced (the ouster trigger accelerates as you dilute).
//
//  NET-WORTH NOTE: IPO proceeds are real cash and net worth carries NO offsetting
//  liability for the public's stake, so going public RAISES net worth and can move
//  a player toward the $1B acquisition gate. Intended (real airlines IPO to fund
//  acquisitions); the cost is permanent dilution + board risk. See the spec.
//

import Foundation

/// A listed airline. `playerShares / sharesOutstanding` is the founder's stake;
/// everything else is the public float.
struct PublicCompany: Codable, Equatable {
    let ticker: String
    let ipoTick: Int
    let ipoPrice: Double          // price per share at listing
    let sharesOutstanding: Double
    var playerShares: Double      // falls with secondary offerings, rises with buybacks

    var playerStake: Double { sharesOutstanding > 0 ? playerShares / sharesOutstanding : 1 }
    var floatShares: Double { sharesOutstanding - playerShares }
    var floatFraction: Double { sharesOutstanding > 0 ? floatShares / sharesOutstanding : 0 }
}

extension Simulation {

    // MARK: - Constants (DESIGNED pacing; the balance sweep settles them)

    /// Net worth at which the airline is substantial enough to list.
    static let goPublicNetWorthGate = 500_000_000
    /// A growing airline trades ABOVE book — market cap is a multiple of net worth.
    static let valuationMultiple = 1.8
    /// Reference IPO price for an airline listing right at the gate. A FIXED share
    /// count is derived from it (below), so a bigger company lists at a
    /// proportionally HIGHER price — the share price now reflects the size of the
    /// entity (designer), instead of every airline listing near a flat ~$50.
    static let ipoReferencePrice = 25.0
    /// Shares outstanding at IPO — a constant, so price = marketCap / shares scales
    /// with market cap. Anchored so an airline at the gate lists near the reference
    /// price: gateCap / refPrice.
    static var ipoShares: Double {
        (Double(goPublicNetWorthGate) * valuationMultiple / ipoReferencePrice).rounded()
    }
    /// A new issue's first year is turbulent and unforgiving — bigger swings and
    /// heightened sensitivity to performance, decaying to a seasoned stock by then.
    static let ipoVolatilityMonths = 12.0
    /// Sentiment clamps — the market's mood can roughly halve or 1.6× the fair value.
    static let sentimentFloor = 0.5
    static let sentimentCeiling = 1.6
    /// Reputation this game centres on; sentiment reads deviations from it.
    static var sentimentReputationAnchor: Double { reputationStart }
    /// How fast the displayed price eases toward its target (per sim-day).
    static let sharePriceEasing = 0.12

    // MARK: - Gate & pure valuation

    var isPublic: Bool { publicCompany != nil }
    var canGoPublic: Bool { !isPublic && netWorth >= Simulation.goPublicNetWorthGate }

    /// Market capitalisation — net worth × the multiple × the market's mood.
    var marketCap: Double { Double(netWorth) * Simulation.valuationMultiple * marketSentiment }

    /// Live per-share price target from the current market cap. `displaySharePrice`
    /// eases toward this each tick for a smooth ticker.
    var targetSharePrice: Double {
        guard let pc = publicCompany, pc.sharesOutstanding > 0 else { return 0 }
        return marketCap / pc.sharesOutstanding
    }

    /// Proceeds from selling `fraction` of the company at the current valuation.
    func ipoProceeds(floatFraction fraction: Double) -> Int {
        Int((marketCap * max(0, min(1, fraction))).rounded())
    }

    /// Player-facing read on how exposed a given post-IPO stake leaves them —
    /// drives the dilution warning, and (step 4) the board-ouster speed.
    enum ControlRisk: String {
        case controlling = "You keep control"       // > 50%
        case exposed = "Below majority — the board can act"   // 34–50%
        case vulnerable = "Minority — little protection"      // 15–34%
        case powerless = "You barely own your airline"        // < 15%
    }
    static func controlRisk(stake: Double) -> ControlRisk {
        switch stake {
        case 0.50...: return .controlling
        case 0.34..<0.50: return .exposed
        case 0.15..<0.34: return .vulnerable
        default: return .powerless
        }
    }
}
