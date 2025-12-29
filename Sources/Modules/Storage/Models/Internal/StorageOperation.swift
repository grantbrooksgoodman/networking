//
//  StorageOperation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum StorageOperation {
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
}
