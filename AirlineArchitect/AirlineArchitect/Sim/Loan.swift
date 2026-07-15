//
//  Loan.swift
//  Airline Architect — the loan / financing mechanic (Finance tab)
//
//  The player can borrow to expand faster than cash flow allows, at the cost of
//  interest and a fixed monthly debt-service payment. An amortizing loan: each
//  month pays interest on the remaining balance plus a slice of principal, until
//  it's paid off. Borrowing is capped against a base credit line + the fleet's
//  resale value (collateral), so it can't be abused to infinity.
//

import Foundation

/// An active amortizing loan.
struct Loan: Identifiable {
    let id: Int
    let originalPrincipal: Int
    var remainingPrincipal: Double     // Double for clean amortization
    let monthlyRate: Double            // APR / 12
    let monthlyPayment: Int
    let termMonths: Int
    let takenTick: Int
}

/// A borrowing product offered under Finance (tap to draw the funds).
struct LoanOffer: Identifiable {
    let id: String
    let name: String
    let principal: Int
    let termMonths: Int
    let apr: Double

    var monthlyRate: Double { apr / 12 }
    /// Standard amortized monthly payment: P·r / (1 − (1+r)^−n).
    var monthlyPayment: Int {
        let r = monthlyRate, n = Double(termMonths), p = Double(principal)
        guard r > 0 else { return Int((p / n).rounded()) }
        return Int((p * r / (1 - pow(1 + r, -n))).rounded())
    }
    /// Total interest paid over the loan's life.
    var totalInterest: Int { monthlyPayment * termMonths - principal }

    // Bigger loans run longer terms + higher rates (real aviation financing).
    static let all: [LoanOffer] = [
        .init(id: "small",  name: "Short-term line", principal:  5_000_000, termMonths: 24, apr: 0.08),
        .init(id: "medium", name: "Fleet loan",      principal: 15_000_000, termMonths: 48, apr: 0.10),
        .init(id: "large",  name: "Expansion loan",  principal: 40_000_000, termMonths: 72, apr: 0.12),
    ]
}
