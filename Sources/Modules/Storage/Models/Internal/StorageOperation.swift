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
