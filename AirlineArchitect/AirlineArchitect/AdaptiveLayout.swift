//
//  AdaptiveLayout.swift
//  Airline Architect — shared iPad/iPhone layout helper.
//
//  Regular width (iPad) vs. compact (iPhone) drives the layout forks: full-width
//  showcase cards, the landscape Network side-dock, and the Fleet list+detail
//  split. One predicate, used everywhere, keeps the branch consistent.
//

import SwiftUI

enum PadLayout {
    static func isPad(_ hSize: UserInterfaceSizeClass?) -> Bool { hSize == .regular }
}
