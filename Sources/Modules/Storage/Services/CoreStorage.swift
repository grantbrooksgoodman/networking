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

    // MARK: - Perform Operation

    // swiftlint:disable:next function_body_length
    func performOperation(
        _ operation: StorageOperation,
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
        case let .deleteAllItems(
            atPath: path,
            includeItemsInSubdirectories: includeItemsInSubdirectories
        ):
            Task {
                let deleteAllItemsResult = await deleteAllItems(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    includeItemsInSubdirectories: includeItemsInSubdirectories
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(deleteAllItemsResult)
            }

        case let .deleteItem(
            atPath: path
        ):
            Task {
                let deleteItemResult = await deleteItem(at: prependingEnvironment ? path.prependingCurrentEnvironment : path)

                timeout.cancel()
                guard canComplete else { return }
                completion(deleteItemResult)
            }

        case let .downloadAllItems(
            atPath: path,
            toDirectory: localDirectory,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            cacheStrategy: cacheStrategy
        ):
            Task {
                let downloadAllItemsResult = await downloadAllItems(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    toDirectory: localDirectory,
                    includeItemsInSubdirectories: includeItemsInSubdirectories,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(downloadAllItemsResult)
            }

        case let .downloadItem(
            atPath: path,
            toLocalPath: localPath,
            cacheStrategy: cacheStrategy
        ):
            Task {
                let downloadItemResult = await downloadItem(
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    to: localPath,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(downloadItemResult)
            }

        case let .enumerateEmptyDirectories(
            startingAt: path
        ):
            Task {
                let enumerateEmptyDirectoriesResult = await enumerateEmptyDirectories(
                    startingAt: prependingEnvironment ? path.prependingCurrentEnvironment : path
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(enumerateEmptyDirectoriesResult)
            }

        case let .itemExists(
            asItemType: itemType,
            atPath: path,
            cacheStrategy: cacheStrategy
        ):
            Task {
                let itemExistsResult = await itemExists(
                    as: itemType,
                    at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                    cacheStrategy: globalCacheStrategy ?? cacheStrategy
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(itemExistsResult)
            }

        case let .upload(
            data,
            metadata: metadata
        ):
            Task {
                let uploadResult = await upload(
                    data,
                    metadata: metadata,
                    prependingEnvironment: prependingEnvironment
                )

                timeout.cancel()
                guard canComplete else { return }
                completion(uploadResult)
            }
        }
    }

    // MARK: - Data Upload

    private func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool
    ) async -> Callback<Any?, Exception> {
        Logger.log(
            "Uploading data to path \"\(metadata.filePath)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        storedDownloadItemResults[metadata.filePath] = nil
        storedItemExistsResults[metadata.filePath] = nil

        if let exception = await _upload(
            data,
            metadata: metadata,
            prependingEnvironment: prependingEnvironment
        ) {
            return .failure(exception)
        }

        return .success(nil)
    }

    private func _upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool
    ) async -> Exception? {
        do {
            _ = try await firebaseStorage.putDataAsync(
                data,
                metadata: metadata.asStorageMetadata(prependingEnvironment: prependingEnvironment)
            )

            return nil
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Deletion

    private func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool
    ) async -> Callback<Any?, Exception> {
        Logger.log(
            "Deleting all items at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        if let exception = await _deleteAllItems(
            at: path,
            includeItemsInSubdirectories: includeItemsInSubdirectories
        ) {
            return .failure(exception)
        }

        return .success(nil)
    }

    private func deleteItem(at path: String) async -> Callback<Any?, Exception> {
        if let exception = await _itemExists(
            as: .file,
            at: path,
            returnCacheOnFailure: false
        ) {
            return .failure(exception)
        }

        Logger.log(
            "Deleting item at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        storedDownloadItemResults[path] = nil
        storedItemExistsResults[path] = nil

        if let exception = await _deleteItem(at: path) {
            return .failure(exception)
        }

        return .success(nil)
    }

    private func _deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        exceptions: [Exception] = []
    ) async -> Exception? {
        var exceptions = exceptions

        storedDownloadItemResults[path] = nil
        storedItemExistsResults[path] = nil

        Networking.config.activityIndicatorDelegate.show()
        let getDirectoryListingResult = await getDirectoryListing(at: path)

        switch getDirectoryListingResult {
        case let .success(directoryListing):
            for filePath in directoryListing.filePaths {
                let deleteItemResult = await deleteItem(at: filePath)

                switch deleteItemResult {
                case let .failure(exception): exceptions.append(exception)
                default: continue
                }
            }

            guard includeItemsInSubdirectories else { return exceptions.compiledException }

            for subdirectory in directoryListing.subdirectories {
                if let exception = await _deleteAllItems(
                    at: subdirectory,
                    includeItemsInSubdirectories: includeItemsInSubdirectories,
                    exceptions: exceptions
                ) {
                    exceptions.append(exception)
                }
            }

            return exceptions.compiledException

        case let .failure(exception):
            guard let underlyingException = exceptions.compiledException else { return exception }
            return exception.appending(underlyingException: underlyingException)
        }
    }

    private func _deleteItem(at path: String) async -> Exception? {
        do {
            try await firebaseStorage.child(path).delete()
            return nil
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Download

    private func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        cacheStrategy: CacheStrategy
    ) async -> Callback<Any?, Exception> {
        Logger.log(
            "Downloading all items at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        if let exception = await _downloadAllItems(
            at: path,
            toDirectory: localDirectory,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            cacheStrategy: cacheStrategy
        ) {
            return .failure(exception)
        }

        return .success(nil)
    }

    private func downloadItem(
        at path: String,
        to localPath: URL,
        cacheStrategy: CacheStrategy
    ) async -> Callback<Any?, Exception> {
        if cacheStrategy == .returnCacheFirst,
           storedDownloadItemResultIsValid(
               localPath: localPath,
               networkPath: path
           ) {
            return .success(nil)
        }

        Logger.log(
            "Downloading item at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        let downloadItemStartDate = Date.now
        if let exception = await _downloadItem(
            at: path,
            to: localPath
        ) {
            guard cacheStrategy == .returnCacheOnFailure,
                  storedDownloadItemResultIsValid(
                      localPath: localPath,
                      networkPath: path
                  ) else { return .failure(exception) }

            Logger.log(exception, domain: .Networking.storage)
            return .success(nil)
        }

        storedDownloadItemResults[path] = .init(
            data: localPath,
            expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: downloadItemStartDate))
        )

        return .success(nil)
    }

    private func _downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        cacheStrategy: CacheStrategy,
        exceptions: [Exception] = []
    ) async -> Exception? {
        var exceptions = exceptions

        Networking.config.activityIndicatorDelegate.show()
        let getDirectoryListingResult = await getDirectoryListing(at: path)

        switch getDirectoryListingResult {
        case let .success(directoryListing):
            for filePath in directoryListing.filePaths {
                guard let fileName = filePath.fileName else {
                    exceptions.append(.init(
                        "Failed to resolve file name.",
                        extraParams: ["FilePath": filePath],
                        metadata: [self, #file, #function, #line]
                    ))
                    continue
                }

                let downloadItemResult = await downloadItem(
                    at: filePath,
                    to: localDirectory.appending(path: "/\(path)/\(fileName)"),
                    cacheStrategy: cacheStrategy
                )

                switch downloadItemResult {
                case let .failure(exception): exceptions.append(exception)
                default: continue
                }
            }

            guard includeItemsInSubdirectories else { return exceptions.compiledException }

            for subdirectory in directoryListing.subdirectories {
                if let exception = await _downloadAllItems(
                    at: subdirectory,
                    toDirectory: localDirectory,
                    includeItemsInSubdirectories: includeItemsInSubdirectories,
                    cacheStrategy: cacheStrategy,
                    exceptions: exceptions
                ) {
                    exceptions.append(exception)
                }
            }

            return exceptions.compiledException

        case let .failure(exception):
            guard let underlyingException = exceptions.compiledException else { return exception }
            return exception.appending(underlyingException: underlyingException)
        }
    }

    private func _downloadItem(
        at path: String,
        to localPath: URL,
    ) async -> Exception? {
        do {
            _ = try await firebaseStorage.child(path).writeAsync(toFile: localPath)
            return nil
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Enumeration

    private func enumerateEmptyDirectories(startingAt path: String) async -> Callback<Any?, Exception> {
        Logger.log(
            "Enumerating empty directories, starting at \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        let enumerateEmptyDirectoriesResult = await _enumerateEmptyDirectories(startingAt: path)

        switch enumerateEmptyDirectoriesResult {
        case let .success(emptyDirectories): return .success(emptyDirectories)
        case let .failure(exception): return .failure(exception)
        }
    }

    private func itemExists(
        as itemType: HostedItemType,
        at path: String,
        cacheStrategy: CacheStrategy
    ) async -> Callback<Any?, Exception> {
        if cacheStrategy == .returnCacheFirst,
           storedItemExistsResultIsValid(
               itemType: itemType,
               path: path
           ) {
            return .success(true)
        }

        Logger.log(
            "Checking item exists at path \"\(path)\".",
            domain: .Networking.storage,
            metadata: [self, #file, #function, #line]
        )

        let exception = await _itemExists(
            as: itemType,
            at: path,
            returnCacheOnFailure: cacheStrategy == .returnCacheOnFailure
        )

        if let exception {
            Logger.log(
                exception,
                domain: .Networking.storage
            )
        }

        return .success(exception == nil)
    }

    private func _enumerateEmptyDirectories(
        startingAt path: String,
        with emptyDirectories: Set<String> = .init(),
        exceptions: [Exception] = []
    ) async -> Callback<Set<String>, Exception> {
        var emptyDirectories = emptyDirectories
        var exceptions = exceptions

        Networking.config.activityIndicatorDelegate.show()
        let getDirectoryListingResult = await getDirectoryListing(at: path)

        switch getDirectoryListingResult {
        case let .success(directoryListing):
            for subdirectory in directoryListing.subdirectories {
                let enumerateEmptySubdirectoriesResult = await _enumerateEmptyDirectories(
                    startingAt: subdirectory,
                    with: emptyDirectories,
                    exceptions: exceptions
                )

                switch enumerateEmptySubdirectoriesResult {
                case let .success(emptySubdirectories): emptyDirectories.formUnion(emptySubdirectories)
                case let .failure(exception): exceptions.append(exception)
                }
            }

        case let .failure(exception):
            if exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) {
                emptyDirectories.insert(path)
            } else {
                guard let underlyingException = exceptions.compiledException else { return .failure(exception) }
                return .failure(exception.appending(underlyingException: underlyingException))
            }
        }

        if let exception = exceptions.compiledException {
            return .failure(exception)
        }

        return .success(emptyDirectories)
    }

    private func _itemExists(
        as itemType: HostedItemType,
        at path: String,
        returnCacheOnFailure: Bool
    ) async -> Exception? { // swiftlint:disable:next identifier_name
        func _itemExists(as itemType: HostedItemType) async -> Bool {
            let startDate = Date.now
            var exception: Exception?
            var cacheExpiryMilliseconds = 100

            if itemType == .directory {
                let getDirectoryListingResult = await getDirectoryListing(
                    at: path,
                    firstResultOnly: true
                )

                cacheExpiryMilliseconds = Networking.cacheExpiryMilliseconds(for: startDate)

                switch getDirectoryListingResult {
                case let .failure(getDirectoryListingException): exception = getDirectoryListingException
                default: ()
                }

            } else {
                let getFileMetadataResult = await getFileMetadata(at: path)

                cacheExpiryMilliseconds = Networking.cacheExpiryMilliseconds(for: startDate)

                switch getFileMetadataResult {
                case let .failure(getFileMetadataException): exception = getFileMetadataException
                default: ()
                }
            }

            guard let exception else {
                storedItemExistsResults[path] = .init(
                    data: itemType == .directory ? HostedItemType.directory : .file,
                    expiresAfter: .milliseconds(cacheExpiryMilliseconds)
                )

                return true
            }

            if !exception.isEqual(toAny: [
                .Networking.Storage.genericStorageError,
                .Networking.Storage.storageItemDoesNotExist,
            ]) {
                Logger.log(
                    exception,
                    domain: .Networking.storage
                )
            }

            if returnCacheOnFailure,
               storedItemExistsResultIsValid(
                   itemType: itemType,
                   path: path
               ) {
                return true
            }

            return false
        }

        let existsAsFile = await _itemExists(as: .file)

        if existsAsFile,
           itemType == .file {
            return nil
        }

        let existsAsDirectory = await _itemExists(as: .directory)

        if existsAsDirectory,
           itemType == .directory {
            return nil
        }

        if existsAsDirectory,
           itemType == .file {
            return .Networking.hostedItemTypeMismatch(
                at: path,
                type: .file,
                [self, #file, #function, #line]
            )
        } else if existsAsFile,
                  itemType == .directory {
            return .Networking.hostedItemTypeMismatch(
                at: path,
                type: .directory,
                [self, #file, #function, #line]
            )
        } else if !existsAsDirectory,
                  !existsAsFile {
            return .Networking.hostedItemTypeMismatch(
                at: path,
                type: nil,
                [self, #file, #function, #line]
            )
        }

        return nil // Should never execute.
    }

    // MARK: - Clear Store

    func clearStore() {
        storedDownloadItemResults = .init()
        storedItemExistsResults = .init()
    }

    // MARK: - Auxiliary

    private func getDirectoryListing(
        at path: String,
        firstResultOnly: Bool = false,
    ) async -> Callback<DirectoryListing, Exception> {
        do {
            var listResult: StorageListResult!

            if firstResultOnly {
                listResult = try await firebaseStorage.child(path).list(maxResults: 1)
            } else {
                listResult = try await firebaseStorage.child(path).listAll()
            }

            let directoryListing = DirectoryListing(listResult)

            if directoryListing.filePaths.isEmpty,
               directoryListing.subdirectories.isEmpty {
                return .failure(.Networking.hostedItemTypeMismatch(
                    at: path,
                    type: nil,
                    [self, #file, #function, #line]
                ))
            }

            return .success(directoryListing)
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    private func getFileMetadata(at path: String) async -> Callback<StorageMetadata, Exception> {
        do {
            let getMetadataResult = try await firebaseStorage.child(path).getMetadata()
            return .success(getMetadataResult)
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    private func storedDownloadItemResultIsValid(
        localPath: URL,
        networkPath: String
    ) -> Bool {
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

    private func storedItemExistsResultIsValid(
        itemType: HostedItemType,
        path: String
    ) -> Bool {
        guard let storedDataSample = storedItemExistsResults[path] else { return false }

        guard !storedDataSample.isExpired,
              let storedItemExistsResult = storedDataSample.data as? HostedItemType,
              storedItemExistsResult == itemType else {
            storedItemExistsResults[path] = nil
            return false
        }

        Logger.log(
            "Returning stored item exists result for network path \"\(path)\".",
            domain: .caches,
            metadata: [self, #file, #function, #line]
        )

        return true
    }
}

// swiftlint:enable file_length type_body_length
