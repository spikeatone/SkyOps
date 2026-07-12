//
//  Item.swift
//  SkyOps
//
//  Created by Michael Stevens on 7/12/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
