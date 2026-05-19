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
    ) async -> Exception? {
        switch await coreStorage.performOperation(
            .upload(
                data,
                metadata: metadata
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case .success: nil
        case let .failure(exception): exception
        }
    }

    // MARK: - Deletion

    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        switch await coreStorage.performOperation(
            .deleteAllItems(
                atPath: path,
                includeItemsInSubdirectories: includeItemsInSubdirectories
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case .success: nil
        case let .failure(exception): exception
        }
    }

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        switch await coreStorage.performOperation(
            .deleteItem(
                atPath: path
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case .success: nil
        case let .failure(exception): exception
        }
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
    ) async -> Exception? {
        switch await coreStorage.performOperation(
            .downloadAllItems(
                atPath: path,
                toDirectory: localDirectory,
                includeItemsInSubdirectories: includeItemsInSubdirectories,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case .success: nil
        case let .failure(exception): exception
        }
    }

    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Exception? {
        switch await coreStorage.performOperation(
            .downloadItem(
                atPath: path,
                toLocalPath: localPath,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case .success: nil
        case let .failure(exception): exception
        }
    }

    // MARK: - Enumeration

    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Callback<Set<String>, Exception> {
        switch await coreStorage.performOperation(
            .enumerateEmptyDirectories(
                startingAt: path
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case let .success(emptyDirectories):
            guard let emptyDirectories = emptyDirectories as? Set<String> else {
                return .failure(.init(
                    metadata: .init(sender: self)
                ))
            }

            return .success(emptyDirectories)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    func getDirectoryListing(
        at path: String,
        firstResultOnly: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Callback<DirectoryListing, Exception> {
        switch await coreStorage.performOperation(
            .getDirectoryListing(
                atPath: path,
                firstResultOnly: firstResultOnly
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case let .success(directoryListing):
            guard let directoryListing = directoryListing as? DirectoryListing else {
                return .failure(.init(
                    metadata: .init(sender: self)
                ))
            }

            return .success(directoryListing)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    func itemExists(
        as itemType: HostedItemType,
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Bool, Exception> {
        switch await coreStorage.performOperation(
            .itemExists(
                asItemType: itemType,
                atPath: path,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case let .success(itemExists):
            guard let itemExists = itemExists as? Bool else {
                return .failure(.init(
                    metadata: .init(sender: self)
                ))
            }

            return .success(itemExists)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    func sizeInKilobytes(
        ofItemAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Callback<Int, Exception> {
        switch await coreStorage.performOperation(
            .sizeInKilobytes(ofItemAtPath: path),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case let .success(sizeInKilobytes):
            guard let sizeInKilobytes = sizeInKilobytes as? Int else {
                return .failure(.init(
                    metadata: .init(sender: self)
                ))
            }

            return .success(sizeInKilobytes)

        case let .failure(exception):
            return .failure(exception)
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
