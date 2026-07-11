//
//  Item.swift
//  PowerTrack
//
//  Created by ethan ruders on 11/07/2026.
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
