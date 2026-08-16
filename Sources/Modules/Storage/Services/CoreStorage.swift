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

final class CoreStorage: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.firebaseStorage) private var firebaseStorage: StorageReference

    // MARK: - Properties

    private static let coalescer = KeyedCoalescer<String, Callback<Any?, Exception>>()

    private let _globalCacheStrategy = LockIsolated<CacheStrategy?>(nil)

    @LockIsolated private var storedDownloadItemResults = [String: DataSample]()
    @LockIsolated private var storedItemExistsResults = [String: DataSample]()

    // MARK: - Computed Properties

    private var globalCacheStrategy: CacheStrategy? {
        get { _globalCacheStrategy.wrappedValue }
        set { _globalCacheStrategy.projectedValue.withValue { $0 = newValue } }
    }

    // MARK: - Global Cache Strategy

    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?) {
        self.globalCacheStrategy = globalCacheStrategy
    }

    // MARK: - Prewarming

    func prewarm() {
        Logger.log(
            "Prewarming storage connection.",
            domain: .Networking.storage,
            sender: self
        )

        Task {
            Networking.config.activityIndicatorDelegate.show()
            defer { Networking.config.activityIndicatorDelegate.hide() }

            _ = try? await firebaseStorage
                .child("prewarm")
                .getMetadata()
        }
    }

    // MARK: - Perform Operation

    func performOperation(
        _ operation: StorageOperation,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Any? {
        let resolvedOperation = operation.resolvingAdaptiveCacheStrategy()
        let resolvedGlobalRawValue = globalCacheStrategy.map(\.resolved.rawValue) ?? ""

        let callback = await Self.coalescer.submitUnlessCancelled(
            String.fromCurrentEditorContext(
                sender: self
            ) + "/" + (
                resolvedOperation.encodedHash
                    + resolvedGlobalRawValue
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

            do throws(Exception) {
                let result = try await _performOperation(
                    resolvedOperation,
                    prependingEnvironment: prependingEnvironment,
                    timeout: duration
                )

                return .success(result)
            } catch {
                return .failure(error)
            }
        }

        guard let callback else {
            throw .cancelled(
                metadata: .init(sender: self)
            )
        }

        return try callback.get()
    }

    private func _performOperation(
        _ operation: StorageOperation,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Any? {
        try await GuardedOperation.run(
            timeout: duration,
            recordsCensoredSampleOnTimeout: false,
            showsActivityIndicator: true,
            sender: self
        ) { _, settle in
            Task {
                do throws(Exception) {
                    let result: Any? = switch operation {
                    case let .deleteAllItems(
                        atPath: path,
                        includeItemsInSubdirectories: includeItemsInSubdirectories
                    ):
                        try await self.deleteAllItems(
                            at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                            includeItemsInSubdirectories: includeItemsInSubdirectories
                        )

                    case let .deleteItem(
                        atPath: path
                    ):
                        try await self.deleteItem(
                            at: prependingEnvironment ? path.prependingCurrentEnvironment : path
                        )

                    case let .downloadAllItems(
                        atPath: path,
                        toDirectory: localDirectory,
                        includeItemsInSubdirectories: includeItemsInSubdirectories,
                        cacheStrategy: cacheStrategy
                    ):
                        try await self.downloadAllItems(
                            at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                            toDirectory: localDirectory,
                            includeItemsInSubdirectories: includeItemsInSubdirectories,
                            cacheStrategy: (self.globalCacheStrategy ?? cacheStrategy).resolved
                        )

                    case let .downloadItem(
                        atPath: path,
                        toLocalPath: localPath,
                        cacheStrategy: cacheStrategy
                    ):
                        try await self.downloadItem(
                            at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                            to: localPath,
                            cacheStrategy: (self.globalCacheStrategy ?? cacheStrategy).resolved
                        )

                    case let .enumerateEmptyDirectories(
                        startingAt: path
                    ):
                        try await self.enumerateEmptyDirectories(
                            startingAt: prependingEnvironment ? path.prependingCurrentEnvironment : path
                        )

                    case let .getDirectoryListing(
                        atPath: path,
                        firstResultOnly: firstResultOnly
                    ):
                        try await self.getDirectoryListing(
                            at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                            firstResultOnly: firstResultOnly
                        )

                    case let .itemExists(
                        asItemType: itemType,
                        atPath: path,
                        cacheStrategy: cacheStrategy
                    ):
                        try await self.itemExists(
                            as: itemType,
                            at: prependingEnvironment ? path.prependingCurrentEnvironment : path,
                            cacheStrategy: (self.globalCacheStrategy ?? cacheStrategy).resolved
                        )

                    case let .sizeInKilobytes(
                        ofItemAtPath: path
                    ):
                        try await self.sizeInKilobytes(
                            ofItemAt: prependingEnvironment ? path.prependingCurrentEnvironment : path
                        )

                    case let .upload(
                        data,
                        metadata: metadata
                    ):
                        try await self.upload(
                            data,
                            metadata: metadata,
                            prependingEnvironment: prependingEnvironment
                        )

                    case let .uploadFile(
                        atURL: fileURL,
                        metadata: metadata
                    ):
                        try await self.uploadFile(
                            at: fileURL,
                            metadata: metadata,
                            prependingEnvironment: prependingEnvironment
                        )
                    }

                    settle(.success(result))
                } catch {
                    settle(.failure(error))
                }
            }
        }
    }

    // MARK: - Progress-Reporting Operations

    func downloadItemWithProgress(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) -> AsyncThrowingStream<StorageTransferProgress, any Error> {
        let path = prependingEnvironment ? path.prependingCurrentEnvironment : path
        let cacheStrategy = (globalCacheStrategy ?? cacheStrategy).resolved

        return transferProgressStream(timeout: duration) { service, onProgress async throws(Exception) in
            _ = try await service.downloadItem(
                at: path,
                to: localPath,
                cacheStrategy: cacheStrategy,
                onProgress: onProgress
            )
        }
    }

    func uploadWithProgress(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) -> AsyncThrowingStream<StorageTransferProgress, any Error> {
        transferProgressStream(timeout: duration) { service, onProgress async throws(Exception) in
            _ = try await service.upload(
                data,
                metadata: metadata,
                prependingEnvironment: prependingEnvironment,
                onProgress: onProgress
            )
        }
    }

    private func transferProgressStream(
        timeout duration: Duration,
        _ transfer: @escaping @Sendable (
            _ service: CoreStorage,
            _ onProgress: @escaping @Sendable (StorageTransferProgress) -> Void
        ) async throws(Exception) -> Void
    ) -> AsyncThrowingStream<StorageTransferProgress, any Error> {
        let (stream, continuation) = AsyncThrowingStream<StorageTransferProgress, any Error>.makeStream(
            bufferingPolicy: .unbounded
        )

        do throws(Exception) {
            try GuardedOperation.checkPreconditions(sender: self)
        } catch {
            continuation.finish(throwing: error)
            return stream
        }

        Networking.config.activityIndicatorDelegate.show()

        let timeout = Timeout(after: duration) {
            continuation.finish(
                throwing: Exception.timedOut(
                    metadata: .init(sender: self)
                )
            )
        }

        let task = Task { [weak self] in
            guard let self else {
                timeout.cancel()
                continuation.finish(
                    throwing: Exception(
                        "Service has been deallocated.",
                        metadata: .init(sender: Self.self)
                    )
                )

                return
            }

            do throws(Exception) {
                try await transfer(self) { continuation.yield($0) }
                timeout.cancel()
                continuation.finish()
            } catch {
                timeout.cancel()
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
            Networking.config.activityIndicatorDelegate.hide()
        }

        return stream
    }

    // MARK: - Data Upload

    private func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        onProgress: (@Sendable (StorageTransferProgress) -> Void)? = nil
    ) async throws(Exception) -> Any? {
        Logger.log(
            "Uploading data to path \"\(metadata.filePath)\".",
            domain: .Networking.storage,
            sender: self
        )

        $storedDownloadItemResults[metadata.filePath] = nil
        $storedItemExistsResults[metadata.filePath] = nil

        try await TransferProgressProbe.measure(
            totalBytes: data.count,
            onProgress: onProgress
        ) { onProgress async throws(Exception) in
            try await putDataObservingProgress(
                data,
                metadata: metadata.asStorageMetadata(
                    prependingEnvironment: prependingEnvironment
                ),
                onProgress: onProgress
            )
        }

        return nil
    }

    private func uploadFile(
        at fileURL: URL,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool
    ) async throws(Exception) -> Any? {
        Logger.log(
            "Uploading file to path \"\(metadata.filePath)\".",
            domain: .Networking.storage,
            sender: self
        )

        $storedDownloadItemResults[metadata.filePath] = nil
        $storedItemExistsResults[metadata.filePath] = nil

        try await TransferProgressProbe.measure(
            totalBytes: try? fileManager.attributesOfItem(
                atPath: fileURL.path()
            )[.size] as? Int,
            onProgress: nil
        ) { onProgress async throws(Exception) in
            try await putFileObservingProgress(
                at: fileURL,
                metadata: metadata.asStorageMetadata(
                    prependingEnvironment: prependingEnvironment
                ),
                onProgress: onProgress
            )
        }

        return nil
    }

    // MARK: - Deletion

    private func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool
    ) async throws(Exception) -> Any? {
        Logger.log(
            "Deleting all items at path \"\(path)\".",
            domain: .Networking.storage,
            sender: self
        )

        try await _deleteAllItems(
            at: path,
            includeItemsInSubdirectories: includeItemsInSubdirectories
        )

        return nil
    }

    private func deleteItem(at path: String) async throws(Exception) -> Any? {
        try await _itemExists(
            as: .file,
            at: path,
            returnCacheOnFailure: false
        )

        Logger.log(
            "Deleting item at path \"\(path)\".",
            domain: .Networking.storage,
            sender: self
        )

        $storedDownloadItemResults[path] = nil
        $storedItemExistsResults[path] = nil

        try await HealthEvidence.measure { () async throws(Exception) in
            do {
                try await firebaseStorage.child(path).delete()
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }
        }

        return nil
    }

    private func _deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        exceptions: [Exception] = []
    ) async throws(Exception) {
        var exceptions = exceptions

        $storedDownloadItemResults[path] = nil
        $storedItemExistsResults[path] = nil

        Networking.config.activityIndicatorDelegate.show()

        do throws(Exception) {
            let directoryListing = try await getDirectoryListing(at: path)

            await withTaskGroup(
                of: Exception?.self
            ) { taskGroup in
                for filePath in directoryListing.filePaths {
                    taskGroup.addTask {
                        do throws(Exception) {
                            _ = try await self.deleteItem(at: filePath)
                        } catch {
                            return error
                        }

                        return nil
                    }
                }

                for await exception in taskGroup {
                    if let exception { exceptions.append(exception) }
                }
            }

            if !includeItemsInSubdirectories {
                if let exception = exceptions.compiledException {
                    throw exception
                }

                return
            }

            for subdirectory in directoryListing.subdirectories {
                do {
                    try await _deleteAllItems(
                        at: subdirectory,
                        includeItemsInSubdirectories: includeItemsInSubdirectories,
                        exceptions: exceptions
                    )
                } catch {
                    exceptions.append(error)
                }
            }

            if let exception = exceptions.compiledException {
                throw exception
            }
        } catch {
            guard let underlyingException = exceptions.compiledException else {
                throw error
            }

            throw error.appending(
                underlyingException: underlyingException
            )
        }
    }

    // MARK: - Download

    private func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        cacheStrategy: CacheStrategy
    ) async throws(Exception) -> Any? {
        Logger.log(
            "Downloading all items at path \"\(path)\".",
            domain: .Networking.storage,
            sender: self
        )

        try await _downloadAllItems(
            at: path,
            toDirectory: localDirectory,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            cacheStrategy: cacheStrategy
        )

        return nil
    }

    private func downloadItem(
        at path: String,
        to localPath: URL,
        cacheStrategy: CacheStrategy,
        onProgress: (@Sendable (StorageTransferProgress) -> Void)? = nil
    ) async throws(Exception) -> Any? {
        if cacheStrategy == .returnCacheFirst,
           storedDownloadItemResultIsValid(
               localPath: localPath,
               networkPath: path
           ) {
            return nil
        }

        Logger.log(
            "Downloading item at path \"\(path)\".",
            domain: .Networking.storage,
            sender: self
        )

        let downloadItemStartDate = Date.now
        do {
            try await _downloadItem(
                at: path,
                to: localPath,
                onProgress: onProgress
            )
        } catch {
            guard cacheStrategy == .returnCacheOnFailure,
                  storedDownloadItemResultIsValid(
                      localPath: localPath,
                      networkPath: path
                  ) else { throw error }

            Logger.log(error, domain: .Networking.storage)
            return nil
        }

        $storedDownloadItemResults[path] = .init(
            data: localPath,
            expiresAfter: .milliseconds(Networking.cacheExpiryMilliseconds(for: downloadItemStartDate))
        )

        return nil
    }

    private func _downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        cacheStrategy: CacheStrategy,
        exceptions: [Exception] = []
    ) async throws(Exception) {
        var exceptions = exceptions

        Networking.config.activityIndicatorDelegate.show()

        do throws(Exception) {
            let directoryListing = try await getDirectoryListing(at: path)

            await withTaskGroup(
                of: Exception?.self
            ) { taskGroup in
                for filePath in directoryListing.filePaths {
                    guard let fileName = filePath.fileName else {
                        exceptions.append(.init(
                            "Failed to resolve file name.",
                            userInfo: ["FilePath": filePath],
                            metadata: .init(sender: self)
                        ))
                        continue
                    }

                    let destination = localDirectory.appending(path: "/\(path)/\(fileName)")
                    taskGroup.addTask {
                        do throws(Exception) {
                            _ = try await self.downloadItem(
                                at: filePath,
                                to: destination,
                                cacheStrategy: cacheStrategy
                            )
                        } catch {
                            return error
                        }

                        return nil
                    }
                }

                for await exception in taskGroup {
                    if let exception { exceptions.append(exception) }
                }
            }

            if !includeItemsInSubdirectories {
                if let exception = exceptions.compiledException {
                    throw exception
                }

                return
            }

            for subdirectory in directoryListing.subdirectories {
                do {
                    try await _downloadAllItems(
                        at: subdirectory,
                        toDirectory: localDirectory,
                        includeItemsInSubdirectories: includeItemsInSubdirectories,
                        cacheStrategy: cacheStrategy,
                        exceptions: exceptions
                    )
                } catch {
                    exceptions.append(error)
                }
            }

            if let exception = exceptions.compiledException {
                throw exception
            }
        } catch {
            guard let underlyingException = exceptions.compiledException else {
                throw error
            }

            throw error.appending(
                underlyingException: underlyingException
            )
        }
    }

    private func _downloadItem(
        at path: String,
        to localPath: URL,
        onProgress: (@Sendable (StorageTransferProgress) -> Void)? = nil
    ) async throws(Exception) {
        try await TransferProgressProbe.measure(
            totalBytes: try? fileManager.attributesOfItem(
                atPath: localPath.path()
            )[.size] as? Int,
            onProgress: onProgress
        ) { onProgress async throws(Exception) in
            try await writeFileObservingProgress(
                at: path,
                to: localPath,
                onProgress: onProgress
            )
        }
    }

    // MARK: - Enumeration

    private func enumerateEmptyDirectories(
        startingAt path: String
    ) async throws(Exception) -> Any? {
        Logger.log(
            "Enumerating empty directories, starting at \"\(path)\".",
            domain: .Networking.storage,
            sender: self
        )

        return try await _enumerateEmptyDirectories(startingAt: path)
    }

    private func getDirectoryListing(
        at path: String,
        firstResultOnly: Bool = false
    ) async throws(Exception) -> DirectoryListing {
        let listResult = try await HealthEvidence.measure { () async throws(Exception) -> StorageListResult in
            do {
                return if firstResultOnly {
                    try await firebaseStorage.child(path).list(maxResults: 1)
                } else {
                    try await firebaseStorage.child(path).listAll()
                }
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }
        }

        let directoryListing = DirectoryListing(listResult)

        if directoryListing.filePaths.isEmpty,
           directoryListing.subdirectories.isEmpty {
            throw .Networking.hostedItemTypeMismatch(
                at: path,
                type: nil,
                .init(sender: self)
            )
        }

        return directoryListing
    }

    private func itemExists(
        as itemType: HostedItemType,
        at path: String,
        cacheStrategy: CacheStrategy
    ) async throws(Exception) -> Any? {
        if cacheStrategy == .returnCacheFirst,
           storedItemExistsResultIsValid(
               itemType: itemType,
               path: path
           ) {
            return true
        }

        Logger.log(
            "Checking item exists at path \"\(path)\".",
            domain: .Networking.storage,
            sender: self
        )

        do {
            try await _itemExists(
                as: itemType,
                at: path,
                returnCacheOnFailure: cacheStrategy == .returnCacheOnFailure
            )

            return true
        } catch {
            Logger.log(
                error,
                domain: .Networking.storage
            )

            return false
        }
    }

    private func sizeInKilobytes(
        ofItemAt path: String
    ) async throws(Exception) -> Any? {
        try await Int(getFileMetadata(at: path).size / 1024)
    }

    private func _enumerateEmptyDirectories(
        startingAt path: String,
        with emptyDirectories: Set<String> = .init(),
        exceptions: [Exception] = []
    ) async throws(Exception) -> Set<String> {
        var emptyDirectories = emptyDirectories
        var exceptions = exceptions

        Networking.config.activityIndicatorDelegate.show()

        do {
            let directoryListing = try await getDirectoryListing(at: path)

            for subdirectory in directoryListing.subdirectories {
                do {
                    try await emptyDirectories.formUnion(
                        _enumerateEmptyDirectories(
                            startingAt: subdirectory,
                            with: emptyDirectories,
                            exceptions: exceptions
                        )
                    )
                } catch {
                    exceptions.append(error)
                }
            }
        } catch {
            if error.isEqual(
                to: .Networking.Storage.storageItemDoesNotExist
            ) {
                emptyDirectories.insert(path)
            } else {
                guard let underlyingException = exceptions.compiledException else {
                    throw error
                }

                throw error.appending(
                    underlyingException: underlyingException
                )
            }
        }

        if let exception = exceptions.compiledException {
            throw exception
        }

        return emptyDirectories
    }

    private func _itemExists(
        as itemType: HostedItemType,
        at path: String,
        returnCacheOnFailure: Bool
    ) async throws(Exception) { // swiftlint:disable:next identifier_name
        func _itemExists(as itemType: HostedItemType) async -> Bool {
            let startDate = Date.now
            var exception: Exception?
            var cacheExpiryMilliseconds = 100

            if itemType == .directory {
                do {
                    _ = try await getDirectoryListing(
                        at: path,
                        firstResultOnly: true
                    )
                } catch {
                    exception = error
                }

                cacheExpiryMilliseconds = Networking.cacheExpiryMilliseconds(for: startDate)
            } else {
                do {
                    _ = try await getFileMetadata(at: path)
                } catch {
                    exception = error
                }

                cacheExpiryMilliseconds = Networking.cacheExpiryMilliseconds(for: startDate)
            }

            guard let exception else {
                $storedItemExistsResults[path] = .init(
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
            return
        }

        let existsAsDirectory = await _itemExists(as: .directory)

        if existsAsDirectory,
           itemType == .directory {
            return
        }

        if existsAsDirectory,
           itemType == .file {
            throw .Networking.hostedItemTypeMismatch(
                at: path,
                type: .file,
                .init(sender: self)
            )
        } else if existsAsFile,
                  itemType == .directory {
            throw .Networking.hostedItemTypeMismatch(
                at: path,
                type: .directory,
                .init(sender: self)
            )
        } else if !existsAsDirectory,
                  !existsAsFile {
            throw .Networking.hostedItemTypeMismatch(
                at: path,
                type: nil,
                .init(sender: self)
            )
        }
    }

    // MARK: - Clear Store

    func clearStore() {
        storedDownloadItemResults = .init()
        storedItemExistsResults = .init()
    }

    // MARK: - Auxiliary

    private func awaitTransferCompletion(
        of task: StorageObservableTask,
        cancellingWith cancelTransfer: @escaping @Sendable () -> Void,
        onProgress: @escaping @Sendable (StorageTransferProgress) -> Void
    ) async throws(Exception) {
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    @LockIsolated var didResume = false
                    var canResume: Bool {
                        $didResume.withValue {
                            guard !$0 else { return false }
                            $0 = true
                            return true
                        }
                    }

                    task.observe(.progress) { snapshot in
                        guard let progress = snapshot.progress else { return }
                        onProgress(.init(
                            completedBytes: progress.completedUnitCount,
                            totalBytes: progress.totalUnitCount
                        ))
                    }

                    task.observe(.success) { _ in
                        guard canResume else { return }
                        continuation.resume()
                    }

                    task.observe(.failure) { snapshot in
                        guard canResume else { return }
                        continuation.resume(
                            throwing: snapshot.error ?? Exception(
                                "The transfer failed without an underlying error.",
                                metadata: .init(sender: self)
                            )
                        )
                    }
                }
            } onCancel: {
                cancelTransfer()
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

    private func getFileMetadata(
        at path: String
    ) async throws(Exception) -> StorageMetadata {
        try await HealthEvidence.measure { () async throws(Exception) -> StorageMetadata in
            do {
                return try await firebaseStorage.child(path).getMetadata()
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }
        }
    }

    private func putDataObservingProgress(
        _ data: Data,
        metadata: StorageMetadata,
        onProgress: @escaping @Sendable (StorageTransferProgress) -> Void
    ) async throws(Exception) {
        let uploadTask = firebaseStorage.putData(
            data,
            metadata: metadata
        )

        let _uploadTask = LockIsolated(uploadTask)
        try await awaitTransferCompletion(
            of: uploadTask,
            cancellingWith: { _uploadTask.wrappedValue.cancel() },
            onProgress: onProgress
        )
    }

    private func putFileObservingProgress(
        at fileURL: URL,
        metadata: StorageMetadata,
        onProgress: @escaping @Sendable (StorageTransferProgress) -> Void
    ) async throws(Exception) {
        let uploadTask = firebaseStorage.putFile(
            from: fileURL,
            metadata: metadata
        )

        let _uploadTask = LockIsolated(uploadTask)
        try await awaitTransferCompletion(
            of: uploadTask,
            cancellingWith: { _uploadTask.wrappedValue.cancel() },
            onProgress: onProgress
        )
    }

    private func storedDownloadItemResultIsValid(
        localPath: URL,
        networkPath: String
    ) -> Bool {
        guard let storedDataSample = $storedDownloadItemResults[networkPath] else { return false }

        guard !storedDataSample.isExpired,
              let storedLocalPath = storedDataSample.data as? URL,
              storedLocalPath == localPath,
              fileManager.fileExists(atPath: localPath.path()) || fileManager.fileExists(atPath: localPath.path(percentEncoded: false)) else {
            $storedDownloadItemResults[networkPath] = nil
            return false
        }

        Logger.log(
            "Returning stored download item result for network path \"\(networkPath)\".",
            domain: .caches,
            sender: self
        )

        return true
    }

    private func storedItemExistsResultIsValid(
        itemType: HostedItemType,
        path: String
    ) -> Bool {
        guard let storedDataSample = $storedItemExistsResults[path] else { return false }

        guard !storedDataSample.isExpired,
              let storedItemExistsResult = storedDataSample.data as? HostedItemType,
              storedItemExistsResult == itemType else {
            $storedItemExistsResults[path] = nil
            return false
        }

        Logger.log(
            "Returning stored item exists result for network path \"\(path)\".",
            domain: .caches,
            sender: self
        )

        return true
    }

    private func writeFileObservingProgress(
        at path: String,
        to localPath: URL,
        onProgress: @escaping @Sendable (StorageTransferProgress) -> Void
    ) async throws(Exception) {
        let downloadTask = firebaseStorage
            .child(path)
            .write(toFile: localPath)

        let _downloadTask = LockIsolated(downloadTask)
        try await awaitTransferCompletion(
            of: downloadTask,
            cancellingWith: { _downloadTask.wrappedValue.cancel() },
            onProgress: onProgress
        )
    }
}

// swiftlint:enable file_length type_body_length
