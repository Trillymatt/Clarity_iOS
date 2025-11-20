//
//  Item.swift
//  Clarity
//
//  Created by Matthew Norman on 11/19/25.
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
