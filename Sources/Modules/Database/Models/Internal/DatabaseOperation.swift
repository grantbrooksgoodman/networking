//
//  DatabaseOperation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum DatabaseOperation: EncodedHashable, @unchecked Sendable {
    // MARK: - Cases

    case getValues(
        atPath: String,
        cacheStrategy: CacheStrategy
    )

    case queryValues(
        atPath: String,
        strategy: QueryStrategy,
        cacheStrategy: CacheStrategy
    )

    case setValue(
        _ value: Any,
        forKey: String
    )

    case updateChildValues(
        forKey: String,
        withData: [String: Any]
    )

    // MARK: - Properties

    var hashFactors: [String] {
        switch self {
        case let .getValues(
            atPath: atPath,
            cacheStrategy: cacheStrategy
        ):
            [
                atPath,
                cacheStrategy.rawValue,
            ]

        case let .queryValues(
            atPath: atPath,
            strategy: strategy,
            cacheStrategy: cacheStrategy
        ):
            [
                atPath,
                strategy.rawValue,
                cacheStrategy.rawValue,
            ]

        case let .setValue(
            value,
            forKey: forKey
        ):
            [
                jsonIdentifier(for: value),
                forKey,
            ]

        case let .updateChildValues(
            forKey: forKey,
            withData: withData
        ):
            [
                forKey,
                jsonIdentifier(for: withData),
            ]
        }
    }

    // MARK: - JSON Identifier

    private func jsonIdentifier(
        for value: Any
    ) -> String {
        let jsonObject = JSONSerialization.isValidJSONObject(value) ? value : [value]
        guard let data = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: .sortedKeys
        ), let string = String(
            data: data,
            encoding: .utf8
        ) else { return "<invalid object>" }
        return string
    }
}
