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

public enum CoreDatabaseCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case dataSamples
    }

    // MARK: - Properties

    @Cached(CacheKey.dataSamples) private static var cachedDataSamples: [String: DataSample]?

    // MARK: - Methods

    public static func addValue(_ value: DataSample, forKey key: String) {
        var cachedDataSamples = cachedDataSamples ?? [:]
        cachedDataSamples[key] = value
        self.cachedDataSamples = cachedDataSamples
    }

    public static func clear() {
        cachedDataSamples = nil
    }

    public static func filter(_ isIncluded: (Dictionary<String, DataSample>.Element) -> Bool) {
        cachedDataSamples = cachedDataSamples?.filter { isIncluded($0) }
    }

    public static func getValue(forKey key: String) -> Any? {
        guard let cachedDataSample = cachedDataSamples?[key],
              !cachedDataSample.isExpired,
              !(cachedDataSample.data is NSNull) else {
            cachedDataSamples?[key] = nil
            return nil
        }

        Logger.log(
            "Returning cached value for data at path \"\(key)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return cachedDataSample.data
    }

    public static func removeValue(forKey key: String) {
        cachedDataSamples?[key] = nil
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

    // MARK: - Value Retrieval

    func getValues(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Any, Exception>) -> Void
    ) {
        let cacheStrategy = globalCacheStrategy ?? cacheStrategy
        guard isOnline else {
            completion(.failure(.internetConnectionOffline([self, #file, #function, #line])))
            return
        }

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            Networking.config.activityIndicatorDelegate.hide()
            return true
        }

        let path = prependingEnvironment ? path.prepended : path
        func completeWithCacheIfPresent() -> Bool {
            guard let cachedValue = CoreDatabaseCache.getValue(forKey: path),
                  canComplete else { return false }
            completion(.success(cachedValue))
            return true
        }

        if cacheStrategy == .returnCacheFirst,
           completeWithCacheIfPresent() {
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(.timedOut([self, #file, #function, #line])))
        }

        Logger.log(
            "Getting values at path \"\(path)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let observeSingleEventStartDate = Date.now
        Networking.config.activityIndicatorDelegate.show()

        firebaseDatabase.child(path).observeSingleEvent(of: .value) { snapshot in
            timeout.cancel()

            guard !self.isEmpty(snapshot.value),
                  let value = snapshot.value else {
                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {
                    return
                }

                guard canComplete else { return }
                completion(.failure(.init(
                    "No value exists at the specified key path.",
                    extraParams: ["Path": path],
                    metadata: [self, #file, #function, #line]
                )))
                return
            }

            CoreDatabaseCache.addValue(
                .init(
                    .now,
                    data: value,
                    expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: observeSingleEventStartDate))
                ),
                forKey: path
            )

            guard canComplete else { return }
            completion(.success(value))
        } withCancel: { error in
            timeout.cancel()
            if cacheStrategy == .returnCacheOnFailure,
               completeWithCacheIfPresent() {
                return
            }

            guard canComplete else { return }
            completion(.failure(.init(error, metadata: [self, #file, #function, #line])))
        }
    }

    // swiftlint:disable:next function_parameter_count
    func queryValues(
        at path: String,
        strategy: QueryStrategy,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Any, Exception>) -> Void
    ) {
        let cacheStrategy = globalCacheStrategy ?? cacheStrategy
        guard isOnline else {
            completion(.failure(.internetConnectionOffline([self, #file, #function, #line])))
            return
        }

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            Networking.config.activityIndicatorDelegate.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(.timedOut([self, #file, #function, #line])))
        }

        let path = prependingEnvironment ? path.prepended : path
        func completeWithCacheIfPresent() -> Bool {
            guard let cachedValue = CoreDatabaseCache.getValue(forKey: path),
                  canComplete else { return false }
            completion(.success(cachedValue))
            return true
        }

        func processReturnValues(_ error: Error?, _ snapshot: DataSnapshot?) {
            timeout.cancel()

            guard let snapshot else {
                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {
                    return
                }

                guard canComplete else { return }
                completion(.failure(.init(error, metadata: [self, #file, #function, #line])))
                return
            }

            guard !isEmpty(snapshot.value),
                  let value = snapshot.value else {
                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {
                    return
                }

                guard canComplete else { return }
                completion(.failure(.init(
                    "No value exists at the specified key path.",
                    extraParams: ["Path": path],
                    metadata: [self, #file, #function, #line]
                )))
                return
            }

            CoreDatabaseCache.addValue(
                .init(
                    .now,
                    data: value,
                    expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: queryLimitedStartDate))
                ),
                forKey: path
            )

            guard canComplete else { return }
            completion(.success(value))
        }

        if cacheStrategy == .returnCacheFirst,
           completeWithCacheIfPresent() {
            return
        }

        Logger.log(
            "Querying values at path \"\(path)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let reference = firebaseDatabase.child(path)
        let queryLimitedStartDate = Date.now
        Networking.config.activityIndicatorDelegate.show()

        switch strategy {
        case let .first(limit):
            reference.queryLimited(toFirst: .init(limit)).getData { error, snapshot in
                processReturnValues(error, snapshot)
            }

        case let .last(limit):
            reference.queryLimited(toLast: .init(limit)).getData { error, snapshot in
                processReturnValues(error, snapshot)
            }
        }
    }

    // MARK: - Value Setting

    func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
            return
        }

        Networking.config.activityIndicatorDelegate.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            Networking.config.activityIndicatorDelegate.hide()
            return true
        }

        guard isEncodable(value) else {
            guard canComplete else { return }
            completion(.invalidType(value: value, [self, #file, #function, #line]))
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Setting value \"\(value)\" for key \"\(key)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let key = prependingEnvironment ? key.prepended : key
        CoreDatabaseCache.removeValue(forKey: key)
        firebaseDatabase.child(key).setValue(value) { error, _ in
            timeout.cancel()
            guard canComplete else { return }
            completion(error == nil ? nil : .init(error, metadata: [self, #file, #function, #line]))
        }
    }

    func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
            return
        }

        Networking.config.activityIndicatorDelegate.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            Networking.config.activityIndicatorDelegate.hide()
            return true
        }

        guard data.values.allSatisfy({ isEncodable($0) }) else {
            guard canComplete else { return }
            completion(.invalidType(value: data, [self, #file, #function, #line]))
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Updating child values for key \"\(key)\" with \"\(data)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let key = prependingEnvironment ? key.prepended : key
        CoreDatabaseCache.removeValue(forKey: key)
        firebaseDatabase.child(key).updateChildValues(data) { error, _ in
            timeout.cancel()
            guard canComplete else { return }
            completion(error == nil ? nil : .init(error, metadata: [self, #file, #function, #line]))
        }
    }

    // MARK: - Auxiliary

    private func isEmpty(_ value: Any?) -> Bool { value is NSNull }
}

private extension String {
    var prepended: String {
        prependingCurrentEnvironment
    }
}

// swiftlint:enable file_length type_body_length
