//
//  DataSample.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public final class DataSample {
    // MARK: - Properties

    public let data: Any
    public let date: Date
    public let expiryThreshold: Duration

    // MARK: - Computed Properties

    public var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    public init(
        _ date: Date = .now,
        data: Any,
        expiresAfter expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }
}
