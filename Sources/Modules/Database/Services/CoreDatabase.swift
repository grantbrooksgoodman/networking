//
//  CoreDatabase.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseDatabase

/// An in-memory cache for database query results.
///
/// `CoreDatabaseStore` stores ``DataSample`` instances
/// keyed by their database path. Expired samples are
/// automatically discarded on retrieval.
///
/// The database implementation uses this store internally
/// to support ``CacheStrategy`` behavior. You can also
/// interact with the store directly to manage cached
/// data:
///
/// ```swift
/// // Remove a specific cached value.
/// CoreDatabaseStore.removeValue(forKey: "users/123")
///
/// // Clear all cached data.
/// CoreDatabaseStore.clearStore()
/// ```
public enum CoreDatabaseStore {
    // MARK: - Properties

    private nonisolated(unsafe) static let _lock: UnsafeMutablePointer<os_unfair_lock> = {
        let pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
        return pointer
    }()

    private nonisolated(unsafe) static var _store = [String: DataSample]()

    // MARK: - Methods

    /// Stores a data sample in the cache for the
    /// specified key.
    ///
    /// - Parameters:
    ///   - value: The data sample to store.
    ///   - key: The cache key, typically a database path.
    public static func addValue(
        _ value: DataSample,
        forKey key: String
    ) {
        os_unfair_lock_lock(_lock)
        _store[key] = value
        os_unfair_lock_unlock(_lock)
    }

    /// Stores multiple data samples in the cache in a
    /// single operation.
    ///
    /// - Parameter values: A dictionary of data samples
    ///   keyed by their cache keys.
    public static func addValues(
        _ values: [String: DataSample]
    ) {
        guard !values.isEmpty else { return }
        os_unfair_lock_lock(_lock)
        _store.merge(values) { _, new in new }
        os_unfair_lock_unlock(_lock)
    }

    /// Removes all cached data samples from the store.
    public static func clearStore() {
        os_unfair_lock_lock(_lock)
        _store.removeAll()
        os_unfair_lock_unlock(_lock)
    }

    /// Removes all data samples that do not satisfy the
    /// given predicate.
    ///
    /// - Parameter isIncluded: A closure that takes a
    ///   key-value pair and returns `true` if the pair
    ///   should remain in the store.
    public static func filter(
        _ isIncluded: (Dictionary<String, DataSample>.Element) -> Bool
    ) {
        os_unfair_lock_lock(_lock)
        _store = _store.filter { isIncluded($0) }
        os_unfair_lock_unlock(_lock)
    }

    /// Returns the cached data for the specified key, or
    /// `nil` if no unexpired sample exists.
    ///
    /// If the stored sample has expired, it is
    /// automatically removed from the store.
    ///
    /// - Parameter key: The cache key to look up.
    ///
    /// - Returns: The cached data, or `nil` if no valid
    ///   sample exists.
    public static func getValue(forKey key: String) -> Any? {
        os_unfair_lock_lock(_lock)

        guard let sample = _store[key],
              !sample.isExpired,
              !(sample.data is NSNull) else {
            _store[key] = nil
            os_unfair_lock_unlock(_lock)
            return nil
        }

        let data = sample.data
        os_unfair_lock_unlock(_lock)

        Logger.log(
            "Returning stored value for data at path \"\(key)\".",
            domain: .caches,
            sender: self
        )

        return data
    }

    /// Removes the cached data sample for the specified
    /// key.
    ///
    /// - Parameter key: The cache key to remove.
    public static func removeValue(forKey key: String) {
        os_unfair_lock_lock(_lock)
        _store[key] = nil
        os_unfair_lock_unlock(_lock)
    }
}

final class CoreDatabase: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.build.isOnline) private var isOnline: Bool

    // MARK: - Properties

    private let _globalCacheStrategy = LockIsolated<CacheStrategy?>(wrappedValue: nil)

    // MARK: - Computed Properties

    private var globalCacheStrategy: CacheStrategy? {
        get { _globalCacheStrategy.wrappedValue }
        set { _globalCacheStrategy.projectedValue.withValue { $0 = newValue } }
    }

    // MARK: - ID Key Generation

    func generateKey(for path: String) -> String? {
        // swiftformat:disable acronyms
        firebaseDatabase.child(path).childByAutoId().key
        // swiftformat:enable acronyms
    }

    // MARK: - Global Cache Strategy

    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        self.globalCacheStrategy = globalCacheStrategy
    }

    // MARK: - Data Integrity Validation

    func isEncodable(_ value: Any) -> Bool {
        let array = value as? [Any]
        let nsArray = value as? NSArray

        let dictionary = value as? [AnyHashable: Any]
        let nsDictionary = value as? NSDictionary

        let null = value as? NSNull

        let number = value as? Float
        let nsNumber = value as? NSNumber

        let string = value as? String
        let nsString = value as? NSString

        let compiled: [Any?] = [
            array,
            nsArray,
            dictionary,
            nsDictionary,
            null,
            number,
            nsNumber,
            string,
            nsString,
        ]

        if let array {
            guard array.allSatisfy({ isEncodable($0) }) else { return false }
        }

        if let nsArray {
            guard nsArray.allSatisfy({ isEncodable($0) }) else { return false }
        }

        if let dictionary {
            guard dictionary.values.allSatisfy({ isEncodable($0) }) else { return false }
        }

        if let nsDictionary {
            guard nsDictionary.allValues.allSatisfy({ isEncodable($0) }) else { return false }
        }

        return !compiled.allSatisfy { $0 == nil }
    }

    // MARK: - Perform Operation

    func performOperation(
        _ operation: DatabaseOperation,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (Callback<Any?, Exception>) -> Void
    ) {
        guard Networking.isReadWriteEnabled else {
            return completion(.failure(
                .Networking.readWriteAccessDisabled(.init(sender: self))
            ))
        }

        guard isOnline else {
            return completion(.failure(
                .internetConnectionOffline(metadata: .init(sender: self))
            ))
        }

        let completion = OperationCompletion(completion)
        let timeout = Timeout(after: duration) {
            completion(.failure(
                .timedOut(metadata: .init(sender: self))
            ))
        }

        Task {
            let result: Callback<Any?, Exception> = switch operation {
            case let .getValues(
                atPath: path,
                cacheStrategy: cacheStrategy
            ):
                await getValues(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

            case let .queryValues(
                atPath: path,
                strategy: strategy,
                cacheStrategy: cacheStrategy
            ):
                await queryValues(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    strategy: strategy,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

            case let .setValue(
                value,
                forKey: key
            ):
                await setValue(
                    value,
                    forKey: prependingEnvironment ? key.prependingCurrentEnvironment : key
                )

            case let .updateChildValues(
                forKey: key,
                withData: data
            ):
                await updateChildValues(
                    forKey: prependingEnvironment ? key.prependingCurrentEnvironment : key,
                    with: data
                )
            }

            timeout.cancel()
            completion(result)
        }
    }

    // MARK: - Value Retrieval

    private func getValues(
        at path: String,
        cacheStrategy: CacheStrategy
    ) async -> Callback<Any?, Exception> {
        var cachedValue: Any? { CoreDatabaseStore.getValue(forKey: path) }

        if cacheStrategy == .returnCacheFirst,
           let cachedValue {
            return .success(cachedValue)
        }

        Logger.log(
            "Getting values at path \"\(path)\".",
            domain: .Networking.database,
            sender: self
        )

        let getValuesStartDate = Date.now
        let getValuesResult = await _getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            CoreDatabaseStore.addValue(
                .init(
                    data: values,
                    expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: getValuesStartDate))
                ),
                forKey: path
            )

            return .success(values)

        case let .failure(exception):
            if cacheStrategy == .returnCacheOnFailure,
               let cachedValue {
                return .success(cachedValue)
            }

            return .failure(exception)
        }
    }

    private func _getValues(at path: String) async -> Callback<Any, Exception> {
        await withCheckedContinuation { continuation in
            @LockIsolated var didResume = false
            var canResume: Bool {
                $didResume.withValue {
                    guard !$0 else { return false }
                    $0 = true
                    return true
                }
            }

            firebaseDatabase.child(path).observeSingleEvent(of: .value) { snapshot in
                guard !self.isEmpty(snapshot.value),
                      let value = snapshot.value else {
                    guard canResume else { return }
                    return continuation.resume(returning: .failure(.init(
                        "No value exists at the specified key path.",
                        userInfo: ["Path": path],
                        metadata: .init(sender: self)
                    )))
                }

                guard canResume else { return }
                continuation.resume(returning: .success(value))
            } withCancel: { error in
                guard canResume else { return }
                continuation.resume(returning: .failure(.init(
                    error,
                    metadata: .init(sender: self)
                )))
            }
        }
    }

    private func queryValues(
        at path: String,
        strategy: QueryStrategy,
        cacheStrategy: CacheStrategy
    ) async -> Callback<Any?, Exception> {
        var cachedValue: Any? { CoreDatabaseStore.getValue(forKey: path) }

        if cacheStrategy == .returnCacheFirst,
           let cachedValue {
            return .success(cachedValue)
        }

        Logger.log(
            "Querying values at path \"\(path)\".",
            domain: .Networking.database,
            sender: self
        )

        let queryValuesStartDate = Date.now
        let queryValuesResult = await _queryValues(
            at: path,
            strategy: strategy
        )

        switch queryValuesResult {
        case let .success(values):
            CoreDatabaseStore.addValue(
                .init(
                    data: values,
                    expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: queryValuesStartDate))
                ),
                forKey: path
            )

            return .success(values)

        case let .failure(exception):
            guard cacheStrategy == .returnCacheOnFailure,
                  let cachedValue else { return .failure(exception) }

            Logger.log(exception, domain: .Networking.database)
            return .success(cachedValue)
        }
    }

    private func _queryValues(
        at path: String,
        strategy: QueryStrategy
    ) async -> Callback<Any, Exception> {
        let reference = firebaseDatabase.child(path)
        let query: DatabaseQuery! = switch strategy {
        case let .first(limit): reference.queryLimited(toFirst: .init(limit))
        case let .last(limit): reference.queryLimited(toLast: .init(limit))
        }

        do {
            let getDataResult = try await query.getData()
            guard !isEmpty(getDataResult.value),
                  let value = getDataResult.value else {
                return .failure(.init(
                    "No value exists at the specified key path.",
                    userInfo: ["Path": path],
                    metadata: .init(sender: self)
                ))
            }

            return .success(value)
        } catch {
            return .failure(.init(error, metadata: .init(sender: self)))
        }
    }

    // MARK: - Value Setting

    private func setValue(
        _ value: Any,
        forKey key: String
    ) async -> Callback<Any?, Exception> {
        guard isEncodable(value) else {
            return .failure(.Networking.invalidType(
                value: value,
                .init(sender: self)
            ))
        }

        Logger.log(
            "Setting value \"\(value)\" for key \"\(key)\".",
            domain: .Networking.database,
            sender: self
        )

        if let exception = await _setValue(value, forKey: key) {
            return .failure(exception)
        }

        CoreDatabaseStore.addValue(
            .init(
                data: value,
                expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: .now))
            ),
            forKey: key
        )

        return .success(nil)
    }

    private func _setValue(
        _ value: Any,
        forKey key: String
    ) async -> Exception? {
        do {
            _ = try await firebaseDatabase.child(key).setValue(value)
            return nil
        } catch {
            return .init(error, metadata: .init(sender: self))
        }
    }

    private func updateChildValues(
        forKey key: String,
        with data: [String: Any]
    ) async -> Callback<Any?, Exception> {
        guard data.values.allSatisfy({ isEncodable($0) }) else {
            return .failure(.Networking.invalidType(
                value: data,
                .init(sender: self)
            ))
        }

        Logger.log(
            "Updating child values for key \"\(key)\" with \"\(data)\".",
            domain: .Networking.database,
            sender: self
        )

        if let exception = await _updateChildValues(
            forKey: key,
            with: data
        ) {
            return .failure(exception)
        }

        CoreDatabaseStore.addValue(
            .init(
                data: data,
                expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: .now))
            ),
            forKey: key
        )

        return .success(nil)
    }

    private func _updateChildValues(
        forKey key: String,
        with data: [String: Any]
    ) async -> Exception? {
        do {
            _ = try await firebaseDatabase.child(key).updateChildValues(data)
            return nil
        } catch {
            return .init(error, metadata: .init(sender: self))
        }
    }

    // MARK: - Auxiliary

    private func isEmpty(_ value: Any?) -> Bool { value is NSNull }
}

// swiftlint:enable file_length type_body_length
