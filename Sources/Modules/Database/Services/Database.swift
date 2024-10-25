//
//  Database.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct Database: DatabaseDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreDatabase) private var coreDatabase: CoreDatabase

    // MARK: - Data Integrity Validation

    func isEncodable(_ value: Any) -> Bool {
        coreDatabase.isEncodable(value)
    }

    // MARK: - ID Key Generation

    func generateKey(for path: String) -> String? {
        coreDatabase.generateKey(for: path)
    }

    // MARK: - Global Cache Strategy

    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        coreDatabase.setGlobalCacheStrategy(globalCacheStrategy)
    }

    // MARK: - Value Retrieval

    /**
     Gets the hosted values at the given path.

     - Parameter path: The hosting path at which to retrieve values.
     - Parameter prependingEnvironment: Pass `true` to prepend the current network environment to the given `path`.
     - Parameter cacheStrategy: The caching strategy to use; defaults to `.returnCacheFirst`.
     - Parameter timeout: An optional timeout `Duration` for the operation; defaults to `.seconds(10)`.

     - Returns: A `Callback` type composed of the data value at the given path or an `Exception`.
     */
    func getValues(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception> {
        await withCheckedContinuation { continuation in
            coreDatabase.performOperation(
                .getValues(
                    atPath: path,
                    cacheStrategy: cacheStrategy
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case let .success(values):
                    guard let values else {
                        return continuation.resume(returning: .failure(
                            .init(metadata: [self, #file, #function, #line])
                        ))
                    }

                    continuation.resume(returning: .success(values))

                case let .failure(exception):
                    continuation.resume(returning: .failure(exception))
                }
            }
        }
    }

    func queryValues(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception> {
        await withCheckedContinuation { continuation in
            coreDatabase.performOperation(
                .queryValues(
                    atPath: path,
                    strategy: strategy,
                    cacheStrategy: cacheStrategy
                ),
                prependingEnvironment: prependingEnvironment,
                timeout: duration
            ) { callback in
                switch callback {
                case let .success(values):
                    guard let values else {
                        return continuation.resume(returning: .failure(
                            .init(metadata: [self, #file, #function, #line])
                        ))
                    }

                    continuation.resume(returning: .success(values))

                case let .failure(exception):
                    continuation.resume(returning: .failure(exception))
                }
            }
        }
    }

    // MARK: - Value Setting

    func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        await withCheckedContinuation { continuation in
            coreDatabase.performOperation(
                .setValue(
                    value,
                    forKey: key
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

    func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception? {
        await withCheckedContinuation { continuation in
            coreDatabase.performOperation(
                .updateChildValues(
                    forKey: key,
                    withData: data
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
}

/* MARK: CoreDatabase Dependency */

private enum CoreDatabaseDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> CoreDatabase {
        .init()
    }
}

private extension DependencyValues {
    var coreDatabase: CoreDatabase {
        get { self[CoreDatabaseDependency.self] }
        set { self[CoreDatabaseDependency.self] = newValue }
    }
}
