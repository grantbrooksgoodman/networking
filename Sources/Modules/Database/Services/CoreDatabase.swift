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

public enum CoreDatabaseStore {
    // MARK: - Properties

    @LockIsolated private static var storedDataSamples = [String: DataSample]()

    // MARK: - Methods

    public static func addValue(_ value: DataSample, forKey key: String) {
        storedDataSamples[key] = value
    }

    public static func clearStore() {
        storedDataSamples = [:]
    }

    public static func filter(_ isIncluded: (Dictionary<String, DataSample>.Element) -> Bool) {
        storedDataSamples = storedDataSamples.filter { isIncluded($0) }
    }

    public static func getValue(forKey key: String) -> Any? {
        guard let storedDataSample = storedDataSamples[key],
              !storedDataSample.isExpired,
              !(storedDataSample.data is NSNull) else {
            storedDataSamples[key] = nil
            return nil
        }

        Logger.log(
            "Returning stored value for data at path \"\(key)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return storedDataSample.data
    }

    public static func removeValue(forKey key: String) {
        storedDataSamples[key] = nil
    }
}

final class CoreDatabase {
    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.build.isOnline) private var isOnline: Bool

    // MARK: - Properties

    private var globalCacheStrategy: CacheStrategy?

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
                .Networking.readWriteAccessDisabled([self, #file, #function, #line])
            ))
        }

        guard isOnline else {
            return completion(.failure(
                .internetConnectionOffline([self, #file, #function, #line])
            ))
        }

        Networking.config.activityIndicatorDelegate.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            Networking.config.activityIndicatorDelegate.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(
                .timedOut([self, #file, #function, #line])
            ))
        }

        switch operation {
        case let .getValues(
            atPath: path,
            cacheStrategy: cacheStrategy
        ):
            Task {
                let getValuesResult = await getValues(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(getValuesResult)
            }

        case let .queryValues(
            atPath: path,
            strategy: strategy,
            cacheStrategy: cacheStrategy
        ):
            Task {
                let queryValuesResult = await queryValues(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    strategy: strategy,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(queryValuesResult)
            }

        case let .setValue(
            value,
            forKey: key
        ):
            Task {
                let setValueResult = await setValue(
                    value,
                    forKey: prependingEnvironment ? key.prependingCurrentEnvironment : key
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(setValueResult)
            }

        case let .updateChildValues(
            forKey: key,
            withData: data
        ):
            Task {
                let updateChildValuesResult = await updateChildValues(
                    forKey: prependingEnvironment ? key.prependingCurrentEnvironment : key,
                    with: data
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(updateChildValuesResult)
            }
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
            metadata: [self, #file, #function, #line]
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
            var didResume = false
            var canResume: Bool {
                guard !didResume else { return false }
                didResume = true
                return true
            }

            firebaseDatabase.child(path).observeSingleEvent(of: .value) { snapshot in
                guard !self.isEmpty(snapshot.value),
                      let value = snapshot.value else {
                    guard canResume else { return }
                    return continuation.resume(returning: .failure(.init(
                        "No value exists at the specified key path.",
                        userInfo: ["Path": path],
                        metadata: [self, #file, #function, #line]
                    )))
                }

                guard canResume else { return }
                continuation.resume(returning: .success(value))
            } withCancel: { error in
                guard canResume else { return }
                continuation.resume(returning: .failure(.init(
                    error,
                    metadata: [self, #file, #function, #line]
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
            metadata: [self, #file, #function, #line]
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
        var query: DatabaseQuery!
        switch strategy {
        case let .first(limit): query = reference.queryLimited(toFirst: .init(limit))
        case let .last(limit): query = reference.queryLimited(toLast: .init(limit))
        }

        do {
            let getDataResult = try await query.getData()
            guard isEmpty(getDataResult.value),
                  let value = getDataResult.value else {
                return .failure(.init(
                    "No value exists at the specified key path.",
                    userInfo: ["Path": path],
                    metadata: [self, #file, #function, #line]
                ))
            }

            return .success(value)
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
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
                [self, #file, #function, #line]
            ))
        }

        Logger.log(
            "Setting value \"\(value)\" for key \"\(key)\".",
            domain: .Networking.database,
            metadata: [self, #file, #function, #line]
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
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    private func updateChildValues(
        forKey key: String,
        with data: [String: Any]
    ) async -> Callback<Any?, Exception> {
        guard data.values.allSatisfy({ isEncodable($0) }) else {
            return .failure(.Networking.invalidType(
                value: data,
                [self, #file, #function, #line]
            ))
        }

        Logger.log(
            "Updating child values for key \"\(key)\" with \"\(data)\".",
            domain: .Networking.database,
            metadata: [self, #file, #function, #line]
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
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Auxiliary

    private func isEmpty(_ value: Any?) -> Bool { value is NSNull }
}

// swiftlint:enable file_length type_body_length
