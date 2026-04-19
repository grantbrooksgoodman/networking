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

/// An interface for reading and writing data in the
/// network database.
///
/// Use `DatabaseDelegate` to perform operations on the
/// backend database. Values can be read, written, queried,
/// and updated at key paths, with built-in caching and
/// configurable timeouts:
///
/// ```swift
/// @Dependency(\.networking.database) var database: DatabaseDelegate
///
/// // Read values at a path.
/// let getValuesResult = await database.getValues(at: "users/123")
///
/// // Write a value.
/// let exception = await database.setValue(
///     "Jane",
///     forKey: "users/123/name"
/// )
/// ```
///
/// By default, paths are prefixed with the active
/// ``NetworkEnvironment`` to isolate data across
/// environments. Pass `false` for `prependingEnvironment`
/// to use a raw path.
///
/// A default implementation backed by Firebase Realtime
/// Database is provided automatically. To supply a custom
/// conformance, register it with
/// ``Networking/Config/registerDatabaseDelegate(_:)``.
// swiftlint:disable:next class_delegate_protocol
public protocol DatabaseDelegate {
    /// Generates a unique key at the specified path.
    ///
    /// - Parameter path: The database path at which to
    ///   generate a new key.
    ///
    /// - Returns: A unique key string, or `nil` if
    ///   generation fails.
    func generateKey(for path: String) -> String?

    /// Reads the value stored at the specified path.
    ///
    /// - Parameters:
    ///   - path: The database path to read from.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: On success, the value stored at the
    ///   path.
    func getValues(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception>

    /// Returns a Boolean value that indicates whether
    /// the specified value can be stored in the database.
    ///
    /// Values must conform to `NSArray`,
    /// `NSDictionary`, `NSNull`, `NSNumber`, or
    /// `NSString` – including any nested elements within
    /// arrays or dictionaries.
    ///
    /// - Parameter value: The value to evaluate.
    ///
    /// - Returns: `true` if the value is encodable;
    ///   otherwise, `false`.
    func isEncodable(_ value: Any) -> Bool

    /// Queries a limited subset of values at the
    /// specified path.
    ///
    /// Use this method to retrieve a bounded number of
    /// results rather than all values at a path.
    ///
    /// - Parameters:
    ///   - path: The database path to query.
    ///   - strategy: The query strategy that determines
    ///     which results to return.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: On success, the queried values.
    func queryValues(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Any, Exception>

    /// Overrides the cache strategy for all database
    /// operations.
    ///
    /// When set, this strategy takes precedence over any
    /// per-operation cache strategy. Pass `nil` to revert
    /// to per-operation behavior.
    ///
    /// - Parameter globalCacheStrategy: The cache
    ///   strategy to apply globally, or `nil` to clear
    ///   the override.
    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?)

    /// Writes a value to the database at the specified
    /// key.
    ///
    /// The value must be encodable – use
    /// ``isEncodable(_:)`` to verify before calling this
    /// method.
    ///
    /// - Parameters:
    ///   - value: The value to write.
    ///   - key: The database key to write to.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the key.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: An exception if the write fails, or
    ///   `nil` on success.
    func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?

    /// Updates specific child values at the specified
    /// key without overwriting sibling data.
    ///
    /// Unlike
    /// ``setValue(_:forKey:prependingEnvironment:timeout:)``,
    /// this method merges the provided data into the
    /// existing value at the key path.
    ///
    /// - Parameters:
    ///   - key: The database key whose children to
    ///     update.
    ///   - data: A dictionary of child keys and their
    ///     new values.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the key.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: An exception if the update fails, or
    ///   `nil` on success.
    func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?
}

public extension DatabaseDelegate {
    /// Reads the value stored at the specified path.
    ///
    /// This method calls
    /// ``getValues(at:prependingEnvironment:cacheStrategy:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The database path to read from.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation. The default is
    ///     ``CacheStrategy/returnCacheFirst``.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: On success, the value stored at the
    ///   path.
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

    /// Queries a limited subset of values at the
    /// specified path.
    ///
    /// This method calls
    /// ``queryValues(at:strategy:prependingEnvironment:cacheStrategy:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The database path to query.
    ///   - strategy: The query strategy that determines
    ///     which results to return. The default is
    ///     ``QueryStrategy/first(_:)`` with a limit of
    ///     `10`.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation. The default is
    ///     ``CacheStrategy/returnCacheFirst``.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: On success, the queried values.
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

    /// Writes a value to the database at the specified
    /// key.
    ///
    /// This method calls
    /// ``setValue(_:forKey:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - value: The value to write.
    ///   - key: The database key to write to.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the key. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: An exception if the write fails, or
    ///   `nil` on success.
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

    /// Updates specific child values at the specified
    /// key without overwriting sibling data.
    ///
    /// This method calls
    /// ``updateChildValues(forKey:with:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - key: The database key whose children to
    ///     update.
    ///   - data: A dictionary of child keys and their
    ///     new values.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the key. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: An exception if the update fails, or
    ///   `nil` on success.
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
