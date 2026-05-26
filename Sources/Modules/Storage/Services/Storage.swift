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

    // MARK: - Prewarming

    func prewarm() {
        coreStorage.prewarm()
    }

    // MARK: - Data Upload

    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreStorage.performOperation(
            .upload(
                data,
                metadata: metadata
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    // MARK: - Deletion

    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreStorage.performOperation(
            .deleteAllItems(
                atPath: path,
                includeItemsInSubdirectories: includeItemsInSubdirectories
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreStorage.performOperation(
            .deleteItem(
                atPath: path
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    // MARK: - Download

    // swiftlint:disable:next function_parameter_count
    func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreStorage.performOperation(
            .downloadAllItems(
                atPath: path,
                toDirectory: localDirectory,
                includeItemsInSubdirectories: includeItemsInSubdirectories,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreStorage.performOperation(
            .downloadItem(
                atPath: path,
                toLocalPath: localPath,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    // MARK: - Enumeration

    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Set<String> {
        guard let emptyDirectories = try await coreStorage.performOperation(
            .enumerateEmptyDirectories(
                startingAt: path
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) as? Set<String> else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        return emptyDirectories
    }

    func getDirectoryListing(
        at path: String,
        firstResultOnly: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> DirectoryListing {
        guard let directoryListing = try await coreStorage.performOperation(
            .getDirectoryListing(
                atPath: path,
                firstResultOnly: firstResultOnly
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) as? DirectoryListing else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        return directoryListing
    }

    func itemExists(
        as itemType: HostedItemType,
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception) -> Bool {
        guard let itemExists = try await coreStorage.performOperation(
            .itemExists(
                asItemType: itemType,
                atPath: path,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) as? Bool else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        return itemExists
    }

    func sizeInKilobytes(
        ofItemAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Int {
        guard let sizeInKilobytes = try await coreStorage.performOperation(
            .sizeInKilobytes(ofItemAtPath: path),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) as? Int else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        return sizeInKilobytes
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
