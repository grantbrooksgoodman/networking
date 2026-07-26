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

    // MARK: - Methods

    /// Returns a copy with any ``CacheStrategy/adaptive``
    /// cache strategy resolved to a concrete value based
    /// on the current network health.
    func resolvingAdaptiveCacheStrategy() -> DatabaseOperation {
        switch self {
        case let .getValues(
            atPath: path,
            cacheStrategy: cacheStrategy
        ):
            guard cacheStrategy == .adaptive else { return self }
            return .getValues(
                atPath: path,
                cacheStrategy: NetworkHealthResolver.resolve(
                    health: Networking.config.healthDelegate.health,
                    configuration: Networking.config.networkHealthConfiguration
                )
            )

        case let .queryValues(
            atPath: path,
            strategy: strategy,
            cacheStrategy: cacheStrategy
        ):
            guard cacheStrategy == .adaptive else { return self }
            return .queryValues(
                atPath: path,
                strategy: strategy,
                cacheStrategy: NetworkHealthResolver.resolve(
                    health: Networking.config.healthDelegate.health,
                    configuration: Networking.config.networkHealthConfiguration
                )
            )

        case .setValue,
             .updateChildValues:
            return self
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
