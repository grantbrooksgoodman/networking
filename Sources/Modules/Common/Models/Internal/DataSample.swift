//
//  DataSample.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

final class DataSample {
    // MARK: - Properties

    let data: Any
    let date: Date
    let expiryThreshold: Duration

    // MARK: - Computed Properties

    var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    init(
        _ date: Date,
        data: Any,
        expiresAfter expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }
}
