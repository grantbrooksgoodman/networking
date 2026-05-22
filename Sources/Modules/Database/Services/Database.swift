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
        let getValuesResult = await getValues(
            at: path,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )

        switch getValuesResult {
        case let .success(values):
            guard let values = values as? T else {
                throw .Networking.typecastFailed(
                    String(T.self),
                    metadata: .init(sender: self)
                )
            }

            return values

        case let .failure(exception):
            throw exception
        }
    }

    private func getValues(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception> {
        switch await coreDatabase.performOperation(
            .getValues(
                atPath: path,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case let .success(values):
            guard let values else {
                return .failure(.init(
                    metadata: .init(sender: self)
                ))
            }

            return .success(values)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    func queryValues<T>(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration // swiftformat:disable all
    ) async throws(Exception) -> T { // swiftformat:enable all
        let queryValuesResult = await queryValues(
            at: path,
            strategy: strategy,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )

        switch queryValuesResult {
        case let .success(values):
            guard let values = values as? T else {
                throw .Networking.typecastFailed(
                    String(T.self),
                    metadata: .init(sender: self)
                )
            }

            return values

        case let .failure(exception):
            throw exception
        }
    }

    private func queryValues(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception> {
        switch await coreDatabase.performOperation(
            .queryValues(
                atPath: path,
                strategy: strategy,
                cacheStrategy: cacheStrategy
            ),
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        ) {
        case let .success(values):
            guard let values else {
                return .failure(.init(
                    metadata: .init(sender: self)
                ))
            }

            return .success(values)

        case let .failure(exception):
            return .failure(exception)
        }
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
        ).get()
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
        ).get()
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
