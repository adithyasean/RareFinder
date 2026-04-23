//
//  Item.swift
//  RareFinder
//
//  Created by Adithya Ekanayaka on 2026-04-24.
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
