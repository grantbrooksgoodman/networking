//
//  DatabaseDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// swiftlint:disable:next class_delegate_protocol
public protocol DatabaseDelegate {
    func generateKey(for path: String) -> String?

    func getValues(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception>

    func isEncodable(_ value: Any) -> Bool

    func queryValues(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception>

    /// Overrides the `CacheStrategy` for all `Database` methods. Pass `nil` to revert the override.
    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?)

    func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?

    func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?
}

public extension DatabaseDelegate {
    func getValues(
        at path: String,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Any, Exception> {
        await getValues(
            at: path,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    func queryValues(
        at path: String,
        strategy: QueryStrategy = .first(10),
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Any, Exception> {
        await queryValues(
            at: path,
            strategy: strategy,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        await setValue(
            value,
            forKey: key,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        await updateChildValues(
            forKey: key,
            with: data,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }
}
