//
//  StorageOperation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import CryptoKit
import Foundation

/* Proprietary */
import AppSubsystem

enum StorageOperation: EncodedHashable {
    // MARK: - Cases

    case deleteAllItems(
        atPath: String,
        includeItemsInSubdirectories: Bool
    )

    case deleteItem(
        atPath: String
    )

    case downloadAllItems(
        atPath: String,
        toDirectory: URL,
        includeItemsInSubdirectories: Bool,
        cacheStrategy: CacheStrategy
    )

    case downloadItem(
        atPath: String,
        toLocalPath: URL,
        cacheStrategy: CacheStrategy
    )

    case enumerateEmptyDirectories(
        startingAt: String
    )

    case getDirectoryListing(
        atPath: String,
        firstResultOnly: Bool
    )

    case itemExists(
        asItemType: HostedItemType,
        atPath: String,
        cacheStrategy: CacheStrategy
    )

    case sizeInKilobytes(
        ofItemAtPath: String
    )

    case upload(
        _ data: Data,
        metadata: HostedItemMetadata
    )

    // MARK: - Methods

    /// Returns a copy with any ``CacheStrategy/adaptive``
    /// cache strategy resolved to a concrete value based
    /// on the current network health.
    func resolvingAdaptiveCacheStrategy() -> StorageOperation {
        switch self {
        case let .downloadAllItems(
            atPath: path,
            toDirectory: directory,
            includeItemsInSubdirectories: includeSubdirs,
            cacheStrategy: cacheStrategy
        ):
            guard cacheStrategy == .adaptive else { return self }
            return .downloadAllItems(
                atPath: path,
                toDirectory: directory,
                includeItemsInSubdirectories: includeSubdirs,
                cacheStrategy: NetworkHealthResolver.resolve(
                    health: Networking.config.healthDelegate.health,
                    configuration: Networking.config.networkHealthConfiguration
                )
            )

        case let .downloadItem(
            atPath: path,
            toLocalPath: localPath,
            cacheStrategy: cacheStrategy
        ):
            guard cacheStrategy == .adaptive else { return self }
            return .downloadItem(
                atPath: path,
                toLocalPath: localPath,
                cacheStrategy: NetworkHealthResolver.resolve(
                    health: Networking.config.healthDelegate.health,
                    configuration: Networking.config.networkHealthConfiguration
                )
            )

        case let .itemExists(
            asItemType: itemType,
            atPath: path,
            cacheStrategy: cacheStrategy
        ):
            guard cacheStrategy == .adaptive else { return self }
            return .itemExists(
                asItemType: itemType,
                atPath: path,
                cacheStrategy: NetworkHealthResolver.resolve(
                    health: Networking.config.healthDelegate.health,
                    configuration: Networking.config.networkHealthConfiguration
                )
            )

        case .deleteAllItems,
             .deleteItem,
             .enumerateEmptyDirectories,
             .getDirectoryListing,
             .sizeInKilobytes,
             .upload:
            return self
        }
    }

    // MARK: - Properties

    var hashFactors: [String] {
        switch self {
        case let .deleteAllItems(
            atPath,
            includeItemsInSubdirectories
        ):
            [
                atPath,
                includeItemsInSubdirectories.description,
            ]

        case let .deleteItem(atPath):
            [atPath]

        case let .downloadAllItems(
            atPath,
            toDirectory,
            includeItemsInSubdirectories,
            cacheStrategy
        ):
            [
                atPath,
                toDirectory.absoluteString,
                includeItemsInSubdirectories.description,
                cacheStrategy.rawValue,
            ]

        case let .downloadItem(
            atPath,
            toLocalPath,
            cacheStrategy
        ):
            [
                atPath,
                toLocalPath.absoluteString,
                cacheStrategy.rawValue,
            ]

        case let .enumerateEmptyDirectories(
            startingAt
        ):
            [startingAt]

        case let .getDirectoryListing(
            atPath,
            firstResultOnly
        ):
            [
                atPath,
                firstResultOnly.description,
            ]

        case let .itemExists(
            asItemType,
            atPath,
            cacheStrategy
        ):
            [
                asItemType.rawValue,
                atPath,
                cacheStrategy.rawValue,
            ]

        case let .sizeInKilobytes(
            ofItemAtPath
        ):
            [ofItemAtPath]

        case let .upload(
            data,
            metadata
        ):
            [
                data.encodedHash,
                metadata.encodedHash,
            ]
        }
    }
}

private extension Data {
    var encodedHash: String {
        SHA256.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
    }
}
