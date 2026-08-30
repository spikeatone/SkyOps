//
//  Currency.swift
//  Airline Architect — the displayed currency symbol.
//
//  The game's economy is USD-denominated internally (all Int amounts are dollars),
//  but the German build DISPLAYS money in euros — a DACH-market expectation. This
//  is a pure PRESENTATION swap of the symbol on the amounts already computed; no
//  FX conversion (the numbers stay the same, only "$" becomes "€"). Keeping it a
//  symbol-only swap avoids a moving exchange rate and keeps every balance/invariant
//  identical to the English build.
//
//  ONE source of truth read by every view-layer money formatter. The Sim layer has
//  its own copy in Sim/Localization.swift (it must stay framework-free), kept in
//  sync with this — both key off the same language code.
//

import Foundation

enum Currency {
    /// The symbol to prefix money with, by the app's current language. Euro for
    /// German; dollar everywhere else. Read at format time so it follows a forced
    /// `-AppleLanguages` launch too.
    static var symbol: String {
        (Locale.current.language.languageCode?.identifier == "de") ? "€" : "$"
    }
}
