//
//  Item.swift
//  PortBar
//
//  Created by Rizwaan Bana on 7/19/26.
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
