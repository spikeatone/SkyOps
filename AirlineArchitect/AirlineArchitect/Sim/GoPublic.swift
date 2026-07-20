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
    var sharesOutstanding: Double // shrinks with buybacks (retired), grows with secondaries
    var playerShares: Double      // falls with secondary offerings, rises with buybacks

    var playerStake: Double { sharesOutstanding > 0 ? playerShares / sharesOutstanding : 1 }
    var floatShares: Double { sharesOutstanding - playerShares }
    var floatFraction: Double { sharesOutstanding > 0 ? floatShares / sharesOutstanding : 0 }
}

/// An activist investor pressing a listed airline whose price has slumped below
/// its IPO price. Persisted so the campaign survives save/load — the demand CARD
/// regenerates from it each month, the same way slot/hub offers do. `escalation`
/// (refusals so far) feeds the board-ouster trigger (step 4).
struct ActivistCampaign: Codable, Equatable {
    var stake: Double        // fraction of shares the activist has accumulated
    var escalation: Int      // refusals so far
    var startedTick: Int
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

    // MARK: - Levers (step 2): read-side option math for the UI
    //
    // The mutating actions (payDividend/buyBackShares/secondaryOffering) live in
    // Simulation.swift; these pure helpers let the Finance PUBLIC card show each
    // option's cost / proceeds / resulting stake before the player commits.

    /// The live per-share price the levers transact at (the eased display price).
    var currentSharePrice: Double { max(0.01, displaySharePrice) }

    /// Special-dividend yields offered in the UI (fraction of the share price).
    static let dividendYieldOptions: [Double] = [0.02, 0.05, 0.08]
    /// Cash cost of a special dividend at `yield` — paid on the PUBLIC float only
    /// (the player's own portion is a wash, so it never leaves the balance).
    func dividendCost(yield: Double) -> Int {
        guard let pc = publicCompany else { return 0 }
        return Int((currentSharePrice * max(0, yield) * pc.floatShares).rounded())
    }

    /// Buyback sizes offered in the UI (fraction of the current public float).
    static let buybackFloatOptions: [Double] = [0.10, 0.25, 0.50]
    /// Cash cost to repurchase `floatFraction` of the float at the current price.
    func buybackCost(floatFraction: Double) -> Int {
        guard let pc = publicCompany else { return 0 }
        return Int((pc.floatShares * max(0, min(1, floatFraction)) * currentSharePrice).rounded())
    }
    /// The player's stake after repurchasing `floatFraction` of the float (rises,
    /// because the retired shares shrink the denominator).
    func stakeAfterBuyback(floatFraction: Double) -> Double {
        guard let pc = publicCompany else { return 1 }
        let retired = pc.floatShares * max(0, min(1, floatFraction))
        let total = pc.sharesOutstanding - retired
        return total > 0 ? pc.playerShares / total : 1
    }

    /// Secondary-offering sizes offered in the UI (new shares as a fraction of the
    /// CURRENT shares outstanding).
    static let secondaryOptions: [Double] = [0.05, 0.10, 0.20]
    /// Cash a secondary raises by issuing `fraction` × current shares at the price.
    func secondaryProceeds(fraction: Double) -> Int {
        guard let pc = publicCompany else { return 0 }
        return Int((pc.sharesOutstanding * max(0, fraction) * currentSharePrice).rounded())
    }
    /// The player's stake after a `fraction` secondary (falls — dilution).
    func stakeAfterSecondary(fraction: Double) -> Double {
        guard let pc = publicCompany else { return 1 }
        let total = pc.sharesOutstanding * (1 + max(0, fraction))
        return total > 0 ? pc.playerShares / total : 1
    }
}
