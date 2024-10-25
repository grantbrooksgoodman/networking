//
//  Storage.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct Storage: StorageDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreStorage) private var coreStorage: CoreStorage

    // MARK: - Global Cache Strategy

    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        coreStorage.setGlobalCacheStrategy(globalCacheStrategy)
    }

    // MARK: - Data Upload

    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreStorage.upload(
                data,
                metadata: metadata,
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Deletion

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreStorage.deleteItem(
                at: path,
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Download

    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreStorage.downloadItem(
                at: path,
                to: localPath,
                prependingEnvironment: prependingEnvironment,
                cacheStrategy: cacheStrategy,
                timeout: duration
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    // MARK: - Item Exists

    func itemExists(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Bool, Exception> {
        return await withCheckedContinuation { continuation in
            coreStorage.itemExists(
                at: path,
                prependingEnvironment: prependingEnvironment,
                cacheStrategy: cacheStrategy,
                timeout: duration
            ) { itemExistsResult in
                continuation.resume(returning: itemExistsResult)
            }
        }
    }

    // MARK: - Clear Store

    func clearStore() {
        coreStorage.clearStore()
    }
}

/* MARK: CoreStorage Dependency */

private enum CoreStorageDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> CoreStorage {
        .init()
    }
}

private extension DependencyValues {
    var coreStorage: CoreStorage {
        get { self[CoreStorageDependency.self] }
        set { self[CoreStorageDependency.self] = newValue }
    }
}
