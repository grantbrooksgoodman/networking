//
//  CoreStorage.swift
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
import FirebaseStorage

final class CoreStorage {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.firebaseStorage) private var firebaseStorage: StorageReference
    @Dependency(\.build.isOnline) private var isOnline: Bool

    // MARK: - Properties

    // CacheStrategy
    private var globalCacheStrategy: CacheStrategy?

    // Dictionary
    @LockIsolated private var storedDownloadItemResults = [String: DataSample]()
    @LockIsolated private var storedItemExistsResults = [String: DataSample]()

    // MARK: - Global Cache Strategy

    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        self.globalCacheStrategy = globalCacheStrategy
    }

    // MARK: - Data Upload

    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard Networking.isReadWriteEnabled else {
            completion(.Networking.readWriteAccessDisabled([self, #file, #function, #line]))
            return
        }

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

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Uploading data to path \"\(metadata.filePath)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        storedDownloadItemResults[metadata.filePath] = nil
        storedItemExistsResults[metadata.filePath] = nil

        firebaseStorage.putData(
            data,
            metadata: metadata.asStorageMetadata(prependingEnvironment: prependingEnvironment)
        ) { putDataResult in
            timeout.cancel()
            guard canComplete else { return }

            switch putDataResult {
            case .success:
                completion(nil)

            case let .failure(error):
                completion(.init(error, metadata: [self, #file, #function, #line]))
            }
        }
    }

    // MARK: - Deletion

    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard Networking.isReadWriteEnabled else {
            completion(.Networking.readWriteAccessDisabled([self, #file, #function, #line]))
            return
        }

        guard isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
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
            completion(.timedOut([self, #file, #function, #line]))
        }

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path

        Logger.log(
            "Deleting all items at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        storedDownloadItemResults[path] = nil
        storedItemExistsResults[path] = nil

        Task {
            let deleteAllItemsResult = await _deleteAllItems(
                at: path,
                includeItemsInSubdirectories: includeItemsInSubdirectories
            )

            timeout.cancel()
            guard canComplete else { return }
            completion(deleteAllItemsResult)
        }
    }

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        guard Networking.isReadWriteEnabled else {
            completion(.Networking.readWriteAccessDisabled([self, #file, #function, #line]))
            return
        }

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

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path

        Logger.log(
            "Deleting item at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        storedDownloadItemResults[path] = nil
        storedItemExistsResults[path] = nil

        let itemReference = firebaseStorage.child(path)
        itemReference.delete { error in
            timeout.cancel()
            guard canComplete else { return }

            if let error {
                completion(.init(error, metadata: [self, #file, #function, #line]))
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Download

    // swiftlint:disable:next function_parameter_count
    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        let cacheStrategy = globalCacheStrategy ?? cacheStrategy
        guard Networking.isReadWriteEnabled else {
            completion(.Networking.readWriteAccessDisabled([self, #file, #function, #line]))
            return
        }

        guard isOnline else {
            completion(.internetConnectionOffline([self, #file, #function, #line]))
            return
        }

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            Networking.config.activityIndicatorDelegate.hide()
            return true
        }

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path
        func completeWithCacheIfPresent() -> Bool {
            guard storedDownloadItemResultIsValid(localPath: localPath, networkPath: path),
                  canComplete else { return false }
            completion(nil)
            return true
        }

        if cacheStrategy == .returnCacheFirst,
           completeWithCacheIfPresent() {
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Downloading item at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        let itemReference = firebaseStorage.child(path)
        let writeStartDate = Date.now
        Networking.config.activityIndicatorDelegate.show()

        itemReference.write(toFile: localPath) { writeResult in
            timeout.cancel()
            let cacheExpiry = Networking.cacheExpiryMilliseconds(for: writeStartDate)

            switch writeResult {
            case .success:
                self.storedDownloadItemResults[path] = .init(
                    data: localPath,
                    expiresAfter: .milliseconds(cacheExpiry)
                )

                guard canComplete else { return }
                completion(nil)

            case let .failure(error):
                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {
                    return
                }

                guard canComplete else { return }
                completion(.init(error, metadata: [self, #file, #function, #line]))
            }
        }
    }

    // MARK: - Enumeration

    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (Callback<Set<String>, Exception>) -> Void
    ) {
        guard Networking.isReadWriteEnabled else {
            completion(.failure(.Networking.readWriteAccessDisabled([self, #file, #function, #line])))
            return
        }

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

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path

        Logger.log(
            "Enumerating empty directories, starting at \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        Task {
            let enumerateEmptyDirectoriesResult = await _enumerateEmptyDirectories(startingAt: path)

            timeout.cancel()
            guard canComplete else { return }
            completion(enumerateEmptyDirectoriesResult)
        }
    }

    func itemExists(
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Bool, Exception>) -> Void
    ) {
        let cacheStrategy = globalCacheStrategy ?? cacheStrategy
        guard Networking.isReadWriteEnabled else {
            completion(.failure(.Networking.readWriteAccessDisabled([self, #file, #function, #line])))
            return
        }

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

        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path
        func completeWithCacheIfPresent() -> Bool {
            guard let storedItemExistsResult = storedItemExistsResult(path: path),
                  canComplete else { return false }
            completion(.success(storedItemExistsResult))
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
            "Checking item exists at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        let itemReference = firebaseStorage.child(path)
        let getMetadataStartDate = Date.now
        Networking.config.activityIndicatorDelegate.show()

        itemReference.getMetadata { getMetadataResult in
            timeout.cancel()
            let cacheExpiry = Networking.cacheExpiryMilliseconds(for: getMetadataStartDate)

            switch getMetadataResult {
            case .success:
                self.storedItemExistsResults[path] = .init(
                    data: true,
                    expiresAfter: .milliseconds(cacheExpiry)
                )

                guard canComplete else { return }
                completion(.success(true))

            case let .failure(error):
                let exception: Exception = .init(error, metadata: [self, #file, #function, #line])
                if !exception.isEqual(toAny: [
                    .Networking.Storage.genericStorageError,
                    .Networking.Storage.storageItemDoesNotExist,
                ]) {
                    Logger.log(exception)
                }

                if cacheStrategy == .returnCacheOnFailure,
                   completeWithCacheIfPresent() {
                    return
                }

                self.storedItemExistsResults[path] = .init(
                    data: false,
                    expiresAfter: .milliseconds(cacheExpiry)
                )

                guard canComplete else { return }
                completion(.success(false))
            }
        }
    }

    // MARK: - Clear Store

    func clearStore() {
        storedDownloadItemResults = .init()
        storedItemExistsResults = .init()
    }

    // MARK: - Auxiliary

    private func storedDownloadItemResultIsValid(localPath: URL, networkPath: String) -> Bool {
        guard let storedDataSample = storedDownloadItemResults[networkPath] else { return false }

        guard !storedDataSample.isExpired,
              let storedLocalPath = storedDataSample.data as? URL,
              storedLocalPath == localPath,
              fileManager.fileExists(atPath: localPath.path()) || fileManager.fileExists(atPath: localPath.path(percentEncoded: false)) else {
            storedDownloadItemResults[networkPath] = nil
            return false
        }

        Logger.log(
            "Returning stored download item result for network path \"\(networkPath)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return true
    }

    private func storedItemExistsResult(path: String) -> Bool? {
        guard let storedDataSample = storedItemExistsResults[path] else { return nil }

        guard !storedDataSample.isExpired,
              let storedItemExistsResult = storedDataSample.data as? Bool else {
            storedItemExistsResults[path] = nil
            return nil
        }

        Logger.log(
            "Returning stored item exists result for network path \"\(path)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return storedItemExistsResult
    }

    private func getDirectoryListing(
        at path: String
    ) async -> Callback<DirectoryListing, Exception> {
        await withCheckedContinuation { continuation in
            getDirectoryListing(at: path) { callback in
                continuation.resume(returning: callback)
            }
        }
    }

    private func getDirectoryListing(
        at path: String,
        completion: @escaping (Callback<DirectoryListing, Exception>) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        let directoryReference = firebaseStorage.child(path)
        directoryReference.listAll { listAllResult in
            switch listAllResult {
            case let .success(storageListResult):
                guard canComplete else { return }
                completion(.success(.init(storageListResult)))

            case let .failure(error):
                guard canComplete else { return }
                completion(.failure(.init(error, metadata: [self, #file, #function, #line])))
            }
        }
    }

    private func _deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool = true
    ) async -> Exception? {
        var exceptions = [Exception]()

        storedDownloadItemResults[path] = nil
        storedItemExistsResults[path] = nil

        Networking.config.activityIndicatorDelegate.show()
        let getDirectoryListingResult = await getDirectoryListing(at: path)

        switch getDirectoryListingResult {
        case let .success(directoryListing):
            for filePath in directoryListing.filePaths {
                Logger.log(
                    "Deleting item at path \"\(filePath)\".",
                    domain: .Networking.storage,
                    metadata: [self, #file, #function, #line]
                )

                storedDownloadItemResults[filePath] = nil
                storedItemExistsResults[filePath] = nil

                firebaseStorage.child(filePath).delete { error in
                    guard let error else { return }
                    exceptions.append(.init(error, metadata: [self, #file, #function, #line]))
                }
            }

            guard includeItemsInSubdirectories else { return exceptions.compiledException }
            for subdirectory in directoryListing.subdirectories {
                if let exception = await _deleteAllItems(
                    at: subdirectory,
                    includeItemsInSubdirectories: includeItemsInSubdirectories
                ) {
                    exceptions.append(exception)
                }
            }

            return exceptions.compiledException

        case let .failure(exception):
            return exception
        }
    }

    private func _enumerateEmptyDirectories(
        startingAt path: String,
        with emptyDirectories: Set<String> = .init()
    ) async -> Callback<Set<String>, Exception> {
        var emptyDirectories = emptyDirectories
        var exceptions = [Exception]()

        Networking.config.activityIndicatorDelegate.show()
        let getDirectoryListingResult = await getDirectoryListing(at: path)

        switch getDirectoryListingResult {
        case let .success(directoryListing):
            if directoryListing.filePaths.isEmpty,
               directoryListing.subdirectories.isEmpty {
                emptyDirectories.insert(path)
            }

            for subdirectory in directoryListing.subdirectories {
                let enumerateEmptySubdirectoriesResult = await _enumerateEmptyDirectories(
                    startingAt: subdirectory,
                    with: emptyDirectories
                )

                switch enumerateEmptySubdirectoriesResult {
                case let .success(emptySubdirectories):
                    emptyDirectories.formUnion(emptySubdirectories)

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }

        case let .failure(exception):
            return .failure(exception)
        }

        if let exception = exceptions.compiledException {
            return .failure(exception)
        }

        return .success(emptyDirectories)
    }
}

// swiftlint:enable file_length type_body_length
