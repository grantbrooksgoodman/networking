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

    private nonisolated(unsafe) static let lock: UnsafeMutablePointer<os_unfair_lock> = {
        let pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
        return pointer
    }()

    private nonisolated(unsafe) static var store = [String: DataSample]()

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
        os_unfair_lock_lock(lock)
        store[key] = value
        os_unfair_lock_unlock(lock)
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
        os_unfair_lock_lock(lock)
        store.merge(values) { _, new in new }
        os_unfair_lock_unlock(lock)
    }

    /// Removes all cached data samples from the store.
    public static func clearStore() {
        os_unfair_lock_lock(lock)
        store.removeAll()
        os_unfair_lock_unlock(lock)
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
        os_unfair_lock_lock(lock)
        store = store.filter { isIncluded($0) }
        os_unfair_lock_unlock(lock)
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
        os_unfair_lock_lock(lock)

        guard let sample = store[key],
              !sample.isExpired,
              !(sample.data is NSNull) else {
            store[key] = nil
            os_unfair_lock_unlock(lock)
            return nil
        }

        let data = sample.data
        os_unfair_lock_unlock(lock)

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
        os_unfair_lock_lock(lock)
        store[key] = nil
        os_unfair_lock_unlock(lock)
    }
}

final class CoreDatabase: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.build.isOnline) private var isOnline: Bool

    // MARK: - Properties

    private static let coalescer = KeyedCoalescer<String, Callback<Any?, Exception>>()

    private let _globalCacheStrategy = LockIsolated<CacheStrategy?>(nil)

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

    // MARK: - Prewarming

    func prewarm() {
        Logger.log(
            "Prewarming database connection.",
            domain: .Networking.database,
            sender: self
        )

        firebaseDatabase
            .child(".info/connected")
            .observeSingleEvent(of: .value) { _ in }
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

    // MARK: - Atomic Increment

    func increment(
        at path: String,
        by delta: Int,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) {
        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path

        guard Networking.isReadWriteEnabled else {
            throw .Networking.readWriteAccessDisabled(
                .init(sender: self)
            )
        }

        guard isOnline else {
            throw .internetConnectionOffline(
                metadata: .init(sender: self)
            )
        }

        Logger.log(
            "Incrementing value at path \"\(path)\" by \(delta).",
            domain: .Networking.database,
            sender: self
        )

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                @LockIsolated var didResume = false
                var canResume: Bool {
                    $didResume.withValue {
                        guard !$0 else { return false }
                        $0 = true
                        return true
                    }
                }

                let timeout = Timeout(after: duration) {
                    guard canResume else { return }
                    continuation.resume(
                        throwing: Exception.timedOut(
                            metadata: .init(sender: self)
                        )
                    )
                }

                firebaseDatabase.child(path).setValue(
                    ServerValue.increment(NSNumber(value: delta)),
                    withCompletionBlock: { error, _ in
                        timeout.cancel()
                        guard canResume else { return }

                        if let error {
                            continuation.resume(
                                throwing: Exception(
                                    error,
                                    metadata: .init(sender: self)
                                )
                            )
                        } else {
                            continuation.resume()
                        }
                    }
                )
            }
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        // Server-side increment produces an unknown local
        // result; invalidate the cache so the next read
        // fetches fresh.
        CoreDatabaseStore.removeValue(forKey: path)
    }

    // MARK: - Observation

    func observe(
        path: String,
        prependingEnvironment: Bool
    ) -> AsyncThrowingStream<Any, any Error> {
        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path
        let (stream, continuation) = AsyncThrowingStream<Any, any Error>.makeStream(
            bufferingPolicy: .unbounded
        )

        guard Networking.isReadWriteEnabled else {
            continuation.finish(
                throwing: Exception.Networking.readWriteAccessDisabled(
                    .init(sender: self)
                )
            )
            return stream
        }

        Logger.log(
            "Started observing values at path \"\(path)\".",
            domain: .Networking.database,
            sender: self
        )

        let databaseReference = firebaseDatabase.child(path)
        let observerHandle = databaseReference.observe(.value) { snapshot in
            guard !self.isEmpty(snapshot.value),
                  let value = snapshot.value else {
                return continuation.finish(
                    throwing: Exception(
                        "No value exists at the specified key path.",
                        userInfo: ["Path": path],
                        metadata: .init(sender: self)
                    )
                )
            }

            CoreDatabaseStore.addValue(
                .init(
                    data: value,
                    expiresAfter: .milliseconds(
                        Networking.cacheExpiryMilliseconds(for: .now)
                    )
                ),
                forKey: path
            )

            continuation.yield(value)
        } withCancel: { error in
            continuation.finish(
                throwing: Exception(
                    error,
                    metadata: .init(sender: self)
                )
            )
        }

        let _databaseReference = LockIsolated(databaseReference)
        continuation.onTermination = { _ in
            Logger.log(
                "Stopped observing values at path \"\(path)\".",
                domain: .Networking.database,
                sender: self
            )

            _databaseReference
                .wrappedValue
                .removeObserver(
                    withHandle: observerHandle
                )
        }

        return stream
    }

    // MARK: - Perform Operation

    func performOperation(
        _ operation: DatabaseOperation,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Any? {
        try await Self.coalescer(
            String.fromCurrentEditorContext(
                sender: self
            ) + "/" + (
                operation.encodedHash
                    + (globalCacheStrategy?.rawValue ?? "")
                    + prependingEnvironment.description
                    + duration.description
            ).encodedHash
        ) { [weak self] in
            guard let self else {
                return .failure(Exception(
                    "Service has been deallocated.",
                    metadata: .init(sender: Self.self)
                ))
            }

            return await withCheckedContinuation { continuation in
                self._performOperation(
                    operation,
                    prependingEnvironment: prependingEnvironment,
                    timeout: duration
                ) { result in
                    switch result {
                    case let .success(value):
                        continuation.resume(returning: .success(value))
                    case let .failure(exception):
                        continuation.resume(returning: .failure(exception))
                    }
                }
            }
        }.get()
    }

    private func _performOperation(
        _ operation: DatabaseOperation,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (Result<Any?, Exception>) -> Void
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
            do throws(Exception) {
                let result: Any? = switch operation {
                case let .getValues(
                    atPath: path,
                    cacheStrategy: cacheStrategy
                ):
                    try await getValues(
                        at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                        cacheStrategy: globalCacheStrategy ?? cacheStrategy
                    )

                case let .queryValues(
                    atPath: path,
                    strategy: strategy,
                    cacheStrategy: cacheStrategy
                ):
                    try await queryValues(
                        at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                        strategy: strategy,
                        cacheStrategy: globalCacheStrategy ?? cacheStrategy
                    )

                case let .setValue(
                    value,
                    forKey: key
                ):
                    try await setValue(
                        value,
                        forKey: prependingEnvironment ? key.prependingCurrentEnvironment : key
                    )

                case let .updateChildValues(
                    forKey: key,
                    withData: data
                ):
                    try await updateChildValues(
                        forKey: prependingEnvironment ? key.prependingCurrentEnvironment : key,
                        with: data
                    )
                }

                timeout.cancel()
                completion(.success(result))
            } catch {
                timeout.cancel()
                completion(.failure(error))
            }
        }
    }

    // MARK: - Transaction

    // swiftlint:disable:next function_body_length
    func runTransaction(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        _ block: @Sendable @escaping (Any?) -> Any?
    ) async throws(Exception) -> Any? {
        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path

        guard Networking.isReadWriteEnabled else {
            throw .Networking.readWriteAccessDisabled(
                .init(sender: self)
            )
        }

        guard isOnline else {
            throw .internetConnectionOffline(
                metadata: .init(sender: self)
            )
        }

        Logger.log(
            "Running transaction at path \"\(path)\".",
            domain: .Networking.database,
            sender: self
        )

        do {
            return try await withCheckedThrowingContinuation { continuation in
                @LockIsolated var didResume = false
                var canResume: Bool {
                    $didResume.withValue {
                        guard !$0 else { return false }
                        $0 = true
                        return true
                    }
                }

                let timeout = Timeout(after: duration) {
                    guard canResume else { return }
                    continuation.resume(
                        throwing: Exception.timedOut(
                            metadata: .init(sender: self)
                        )
                    )
                }

                firebaseDatabase.child(path).runTransactionBlock { mutableData in
                    let currentValue = self.isEmpty(mutableData.value) ? nil : mutableData.value
                    mutableData.value = block(currentValue) as Any
                    return .success(withValue: mutableData)
                } andCompletionBlock: { error, _, snapshot in
                    timeout.cancel()
                    guard canResume else { return }

                    if let error {
                        continuation.resume(
                            throwing: Exception(
                                error,
                                metadata: .init(sender: self)
                            )
                        )

                        return
                    }

                    let committedValue = self.isEmpty(snapshot?.value) ? nil : snapshot?.value
                    if let committedValue {
                        CoreDatabaseStore.addValue(
                            .init(
                                data: committedValue,
                                expiresAfter: .milliseconds(
                                    Networking.cacheExpiryMilliseconds(for: .now)
                                )
                            ),
                            forKey: path
                        )
                    } else {
                        CoreDatabaseStore.removeValue(forKey: path)
                    }

                    continuation.resume(returning: committedValue)
                }
            }
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    // MARK: - Value Retrieval

    private func getValues(
        at path: String,
        cacheStrategy: CacheStrategy
    ) async throws(Exception) -> Any? {
        var cachedValue: Any? {
            CoreDatabaseStore.getValue(forKey: path)
        }

        if cacheStrategy == .returnCacheFirst,
           let cachedValue {
            return cachedValue
        }

        Logger.log(
            "Getting values at path \"\(path)\".",
            domain: .Networking.database,
            sender: self
        )

        let getValuesStartDate = Date.now
        do {
            let values = try await _getValues(at: path)

            CoreDatabaseStore.addValue(
                .init(
                    data: values,
                    expiresAfter: .milliseconds(
                        Networking.cacheExpiryMilliseconds(for: getValuesStartDate)
                    )
                ),
                forKey: path
            )

            return values
        } catch {
            if cacheStrategy == .returnCacheOnFailure,
               let cachedValue {
                return cachedValue
            }

            throw error
        }
    }

    private func _getValues(at path: String) async throws(Exception) -> Any {
        do {
            return try await withCheckedThrowingContinuation { continuation in
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
                        return continuation.resume(throwing: Exception(
                            "No value exists at the specified key path.",
                            userInfo: ["Path": path],
                            metadata: .init(sender: self)
                        ))
                    }

                    guard canResume else { return }
                    continuation.resume(returning: value)
                } withCancel: { error in
                    guard canResume else { return }
                    continuation.resume(throwing: Exception(
                        error,
                        metadata: .init(sender: self)
                    ))
                }
            }
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func queryValues(
        at path: String,
        strategy: QueryStrategy,
        cacheStrategy: CacheStrategy
    ) async throws(Exception) -> Any? {
        var cachedValue: Any? {
            CoreDatabaseStore.getValue(forKey: path)
        }

        if cacheStrategy == .returnCacheFirst,
           let cachedValue {
            return cachedValue
        }

        Logger.log(
            "Querying values at path \"\(path)\".",
            domain: .Networking.database,
            sender: self
        )

        let queryValuesStartDate = Date.now
        let reference = firebaseDatabase.child(path)
        let query: DatabaseQuery! = switch strategy {
        case let .first(limit): reference.queryLimited(toFirst: .init(limit))
        case let .last(limit): reference.queryLimited(toLast: .init(limit))
        }

        do {
            let getDataResult = try await query.getData()
            guard !isEmpty(getDataResult.value),
                  let value = getDataResult.value else {
                throw Exception(
                    "No value exists at the specified key path.",
                    userInfo: ["Path": path],
                    metadata: .init(sender: self)
                )
            }

            CoreDatabaseStore.addValue(
                .init(
                    data: value,
                    expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: queryValuesStartDate))
                ),
                forKey: path
            )

            return value
        } catch let error as Exception {
            guard cacheStrategy == .returnCacheOnFailure,
                  let cachedValue else { throw error }

            Logger.log(error, domain: .Networking.database)
            return cachedValue
        } catch {
            let exception = Exception(
                error,
                metadata: .init(sender: self)
            )

            guard cacheStrategy == .returnCacheOnFailure,
                  let cachedValue else { throw exception }

            Logger.log(exception, domain: .Networking.database)
            return cachedValue
        }
    }

    // MARK: - Value Setting

    private func setValue(
        _ value: Any,
        forKey key: String
    ) async throws(Exception) -> Any? {
        guard isEncodable(value) else {
            throw .Networking.invalidType(
                value: value,
                .init(sender: self)
            )
        }

        Logger.log(
            "Setting value \"\(value)\" for key \"\(key)\".",
            domain: .Networking.database,
            sender: self
        )

        do {
            _ = try await firebaseDatabase
                .child(key)
                .setValue(value)
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        CoreDatabaseStore.addValue(
            .init(
                data: value,
                expiresAfter: .milliseconds(
                    Networking.cacheExpiryMilliseconds(for: .now)
                )
            ),
            forKey: key
        )

        return nil
    }

    private func updateChildValues(
        forKey key: String,
        with data: [String: Any]
    ) async throws(Exception) -> Any? {
        guard data.values.allSatisfy({ isEncodable($0) }) else {
            throw .Networking.invalidType(
                value: data,
                .init(sender: self)
            )
        }

        Logger.log(
            "Updating child values for key \"\(key)\" with \"\(data)\".",
            domain: .Networking.database,
            sender: self
        )

        do {
            _ = try await firebaseDatabase
                .child(key)
                .updateChildValues(data)
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        // When data keys contain "/" the payload is a multi-path
        // update (e.g. a fan-out anchored at the environment root).
        // Caching the partial dict at the anchor key would poison
        // reads for the entire subtree. Cache each resolved leaf
        // path individually instead.
        let isMultiPath = data.keys.contains(where: { $0.contains("/") })
        if isMultiPath {
            let expiryMilliseconds = Networking.cacheExpiryMilliseconds(for: .now)
            var resolved = [String: DataSample]()
            for (childKey, value) in data where !(value is NSNull) {
                resolved["\(key)/\(childKey)"] = .init(
                    data: value,
                    expiresAfter: .milliseconds(expiryMilliseconds)
                )
            }

            CoreDatabaseStore.addValues(resolved)
        } else {
            CoreDatabaseStore.addValue(
                .init(
                    data: data,
                    expiresAfter: .milliseconds(
                        Networking.cacheExpiryMilliseconds(for: .now)
                    )
                ),
                forKey: key
            )
        }

        return nil
    }

    // MARK: - Auxiliary

    private func isEmpty(_ value: Any?) -> Bool {
        value is NSNull
    }
}

// swiftlint:enable file_length type_body_length
