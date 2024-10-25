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

    case itemExists(
        asItemType: HostedItemType,
        atPath: String,
        cacheStrategy: CacheStrategy
    )

    case upload(
        _ data: Data,
        metadata: HostedItemMetadata
    )
}
