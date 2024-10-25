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
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .upload(
                    data,
                    metadata: metadata
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case .success: continuation.resume(returning: nil)
                case let .failure(exception): continuation.resume(returning: exception)
                }
            }
        }
    }

    // MARK: - Deletion

    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .deleteAllItems(
                    atPath: path,
                    includeItemsInSubdirectories: includeItemsInSubdirectories
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case .success: continuation.resume(returning: nil)
                case let .failure(exception): continuation.resume(returning: exception)
                }
            }
        }
    }

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .deleteItem(
                    atPath: path
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration,
            ) { callback in
                switch callback {
                case .success: continuation.resume(returning: nil)
                case let .failure(exception): continuation.resume(returning: exception)
                }
            }
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
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .downloadAllItems(
                    atPath: path,
                    toDirectory: localDirectory,
                    includeItemsInSubdirectories: includeItemsInSubdirectories,
                    cacheStrategy: cacheStrategy
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case .success: continuation.resume(returning: nil)
                case let .failure(exception): continuation.resume(returning: exception)
                }
            }
        }
    }

    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Exception? {
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .downloadItem(
                    atPath: path,
                    toLocalPath: localPath,
                    cacheStrategy: cacheStrategy
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case .success: continuation.resume(returning: nil)
                case let .failure(exception): continuation.resume(returning: exception)
                }
            }
        }
    }

    // MARK: - Enumeration

    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Callback<Set<String>, Exception> {
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .enumerateEmptyDirectories(
                    startingAt: path
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case let .success(emptyDirectories):
                    guard let emptyDirectories = emptyDirectories as? Set<String> else {
                        return continuation.resume(returning: .failure(
                            .init(metadata: [self, #file, #function, #line])
                        ))
                    }

                    continuation.resume(returning: .success(emptyDirectories))

                case let .failure(exception):
                    continuation.resume(returning: .failure(exception))
                }
            }
        }
    }

    func itemExists(
        as itemType: HostedItemType,
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Bool, Exception> {
        await withCheckedContinuation { continuation in
            coreStorage.performOperation(
                .itemExists(
                    asItemType: itemType,
                    atPath: path,
                    cacheStrategy: cacheStrategy
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case let .success(itemExists):
                    guard let itemExists = itemExists as? Bool else {
                        return continuation.resume(returning: .failure(
                            .init(metadata: [self, #file, #function, #line])
                        ))
                    }

                    continuation.resume(returning: .success(itemExists))

                case let .failure(exception):
                    continuation.resume(returning: .failure(exception))
                }
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
