//
//  Favorite.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//

import Foundation
import SwiftData

@Model
final class Favorite {
    var stopId: String
    var stopName: String
    var addedDate: Date
    var usageCount: Int

    init(stopId: String, stopName: String, addedDate: Date = Date(), usageCount: Int = 0) {
        self.stopId = stopId
        self.stopName = stopName
        self.addedDate = addedDate
        self.usageCount = usageCount
    }
}
