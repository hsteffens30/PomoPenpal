//
//  Item.swift
//  PomoPenpal
//
//  Created by Hailey S on 5/7/26.
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
