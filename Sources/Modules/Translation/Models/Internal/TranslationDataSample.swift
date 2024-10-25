//
//  TranslationDataSample.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct TranslationDataSample: Equatable {
    // MARK: - Properties

    static let empty: TranslationDataSample = .init(
        .init(timeIntervalSince1970: 0),
        data: .init(),
        expiresAfter: .zero
    )

    let data: [String: [String: Any]]
    let date: Date
    let expiryThreshold: Duration

    // MARK: - Computed Properties

    var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    init(
        _ date: Date = .now,
        data: [String: [String: Any]],
        expiresAfter expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }

    // MARK: - Equatable Conformance

    static func == (left: TranslationDataSample, right: TranslationDataSample) -> Bool {
        let sameDataCount = left.data.count == right.data.count
        let sameDataKeys = left.data.keys == right.data.keys
        let sameDataValueKeys = left.data.values.map(\.keys) == right.data.values.map(\.keys)
        let sameDate = left.date == right.date
        let sameExpiryThreshold = left.expiryThreshold == right.expiryThreshold

        guard sameDataCount,
              sameDataKeys,
              sameDataValueKeys,
              sameDate,
              sameExpiryThreshold else { return false }

        return true
    }
}
