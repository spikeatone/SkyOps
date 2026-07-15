//
//  OpsEvent.swift
//  Airline Architect — the Ops event log
//
//  A lightweight, capped feed of things that happened in the world / the
//  player's operation, grouped for the Ops tab (Figma 5:3458). Recorded from
//  the real sim mechanics that already exist — economic events (MARKET),
//  weather ground stops at the player's route airports (DISRUPTIONS), and
//  route opens/closes (STRUCTURAL). The flavour events in the Figma that have
//  no sim mechanic yet (ATC shortage, fare war, capacity expansion) are not
//  fabricated — the feed shows only real events.
//

import Foundation

struct OpsEvent: Identifiable {
    enum Category: String, CaseIterable {
        case disruption = "DISRUPTIONS"
        case market = "MARKET"
        case structural = "STRUCTURAL"
    }
    let id: Int
    let category: Category
    let title: String
    let subtitle: String
    let tick: Int
    /// A single airport this event is about (capacity expansion, ground stop) —
    /// lets the Ops feed offer "show on map". nil for events with no one airport.
    var airportCode: String? = nil
}
