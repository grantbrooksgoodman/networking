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

    // MARK: - Global Cache Strategy

    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        coreDatabase.setGlobalCacheStrategy(globalCacheStrategy)
    }

    // MARK: - ID Key Generation

    func generateKey(for path: String) -> String? {
        coreDatabase.generateKey(for: path)
    }

    // MARK: - Observation

    func observe<T>(
        at path: String,
        prependingEnvironment: Bool
    ) -> AsyncThrowingStream<T, any Error> {
        let rawStream = coreDatabase.observe(
            at: path,
            prependingEnvironment: prependingEnvironment
        )

        let (stream, continuation) = AsyncThrowingStream<T, any Error>.makeStream(
            bufferingPolicy: .unbounded
        )

        let task = Task {
            do {
                for try await value in rawStream {
                    guard let value = value as? T else {
                        return continuation.finish(
                            throwing: Exception.Networking.typecastFailed(
                                String(T.self),
                                metadata: .init(sender: self)
                            )
                        )
                    }

                    continuation.yield(LockIsolated(value).wrappedValue)
                }

                continuation.finish()
            } catch let error as Exception {
                continuation.finish(throwing: error)
            } catch {
                continuation.finish(
                    throwing: Exception(
                        error,
                        metadata: .init(sender: self)
                    )
                )
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }

    // MARK: - Prewarming

    func prewarm() {
        coreDatabase.prewarm()
    }

    // MARK: - Value Retrieval

    func getValues<T>(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception) -> T {
        guard let values = try await coreDatabase.performOperation(
            .getValues(
                atPath: path,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        guard let values = values as? T else {
            throw .Networking.typecastFailed(
                String(T.self),
                metadata: .init(sender: self)
            )
        }

        return values
    }

    func queryValues<T>(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration // swiftformat:disable all
    ) async throws(Exception) -> T { // swiftformat:enable all
        guard let values = try await coreDatabase.performOperation(
            .queryValues(
                atPath: path,
                strategy: strategy,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) else {
            throw Exception(
                metadata: .init(sender: self)
            )
        }

        guard let values = values as? T else {
            throw .Networking.typecastFailed(
                String(T.self),
                metadata: .init(sender: self)
            )
        }

        return values
    }

    // MARK: - Value Setting

    func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreDatabase.performOperation(
            .setValue(
                value,
                forKey: key
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) {
        _ = try await coreDatabase.performOperation(
            .updateChildValues(
                forKey: key,
                withData: data
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
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
