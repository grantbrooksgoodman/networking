//
//  StorageDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// An interface for managing files and directories in
/// hosted storage.
///
/// Use `StorageDelegate` to upload, download, delete, and
/// inspect files in the backend storage system. Operations
/// support caching, environment-scoped paths, and
/// configurable timeouts:
///
/// ```swift
/// @Dependency(\.networking.storage) var storage: StorageDelegate
///
/// // Upload data.
/// try await storage.upload(
///     imageData,
///     metadata: HostedItemMetadata("images/photo.png")
/// )
///
/// // Download a file.
/// try await storage.downloadItem(
///     at: "images/photo.png",
///     to: localFileURL
/// )
/// ```
///
/// By default, paths are prefixed with the active
/// ``NetworkEnvironment`` to isolate data across
/// environments. Pass `false` for `prependingEnvironment`
/// to use a raw path.
///
/// A default implementation backed by Firebase Cloud
/// Storage is provided automatically. The default
/// implementation coalesces identical concurrent
/// operations – when multiple callers perform the same
/// operation at the same time, only one network request is
/// made and all callers receive the same result. To supply
/// a custom conformance, register it with
/// ``Networking/Config/registerStorageDelegate(_:)``.
// swiftlint:disable:next class_delegate_protocol
public protocol StorageDelegate: Sendable {
    /// Removes all locally cached storage data.
    func clearStore()

    /// Deletes all items at the specified path.
    ///
    /// - Parameters:
    ///   - path: The storage path from which to delete.
    ///   - includeItemsInSubdirectories: A Boolean value
    ///     that determines whether items in nested
    ///     subdirectories are also deleted.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Throws: An ``Exception`` if the deletion fails.
    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception)

    /// Deletes the item at the specified path.
    ///
    /// - Parameters:
    ///   - path: The storage path of the item to delete.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Throws: An ``Exception`` if the deletion fails.
    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception)

    /// Downloads all items at the specified path to a
    /// local directory.
    ///
    /// - Parameters:
    ///   - path: The storage path from which to download.
    ///   - localDirectory: The local directory URL to
    ///     write files to.
    ///   - includeItemsInSubdirectories: A Boolean value
    ///     that determines whether items in nested
    ///     subdirectories are also downloaded.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Throws: An ``Exception`` if the download fails.
    // swiftlint:disable:next function_parameter_count
    func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception)

    /// Downloads the item at the specified path to a
    /// local file URL.
    ///
    /// - Parameters:
    ///   - path: The storage path of the item to
    ///     download.
    ///   - localPath: The local file URL to write to.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Throws: An ``Exception`` if the download fails.
    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception)

    /// Recursively finds all empty directories starting
    /// at the specified path.
    ///
    /// - Parameters:
    ///   - path: The storage path at which to begin the
    ///     enumeration.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: A set of paths to empty directories.
    ///
    /// - Throws: An ``Exception`` if the enumeration
    ///   fails.
    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Set<String>

    /// Returns the contents of the directory at the
    /// specified path.
    ///
    /// - Parameters:
    ///   - path: The storage path to list.
    ///   - firstResultOnly: A Boolean value that
    ///     determines whether only the first result
    ///     is returned.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: A ``DirectoryListing`` describing the
    ///   directory's contents.
    ///
    /// - Throws: An ``Exception`` if the listing fails.
    func getDirectoryListing(
        at path: String,
        firstResultOnly: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> DirectoryListing

    /// Checks whether an item of the specified type
    /// exists at the given path.
    ///
    /// - Parameters:
    ///   - itemType: The kind of item to check for.
    ///   - path: The storage path to inspect.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - cacheStrategy: The caching behavior for this
    ///     operation.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: `true` if an item of the specified type
    ///   exists; otherwise, `false`.
    ///
    /// - Throws: An ``Exception`` if the check fails.
    func itemExists(
        as itemType: HostedItemType,
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async throws(Exception) -> Bool

    /// Establishes the underlying connection to hosted
    /// storage without performing a data operation.
    ///
    /// Call this method early in the app lifecycle to
    /// overlap connection setup with other
    /// initialization work. The method returns
    /// immediately; connection establishment proceeds
    /// in the background.
    func prewarm()

    /// Overrides the cache strategy for all storage
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

    /// Returns the size of the item at the specified
    /// path, in kilobytes.
    ///
    /// - Parameters:
    ///   - path: The storage path of the item to
    ///     measure.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Returns: The size of the item in kilobytes.
    ///
    /// - Throws: An ``Exception`` if the measurement
    ///   fails.
    func sizeInKilobytes(
        ofItemAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception) -> Int

    /// Uploads data to hosted storage with the specified
    /// metadata.
    ///
    /// - Parameters:
    ///   - data: The data to upload.
    ///   - metadata: The metadata describing the
    ///     destination path and optional HTTP headers.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the metadata's file path.
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///
    /// - Throws: An ``Exception`` if the upload fails.
    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async throws(Exception)
}

public extension StorageDelegate {
    /// Deletes all items at the specified path.
    ///
    /// This method calls
    /// ``deleteAllItems(at:includeItemsInSubdirectories:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path from which to delete.
    ///   - includeItemsInSubdirectories: A Boolean value
    ///     that determines whether items in nested
    ///     subdirectories are also deleted.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Throws: An ``Exception`` if the deletion fails.
    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) {
        try await deleteAllItems(
            at: path,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    /// Deletes the item at the specified path.
    ///
    /// This method calls
    /// ``deleteItem(at:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path of the item to delete.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Throws: An ``Exception`` if the deletion fails.
    func deleteItem(
        at path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) {
        try await deleteItem(
            at: path,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    /// Downloads all items at the specified path to a
    /// local directory.
    ///
    /// This method calls
    /// ``downloadAllItems(at:toDirectory:includeItemsInSubdirectories:prependingEnvironment:cacheStrategy:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path from which to download.
    ///   - localDirectory: The local directory URL to
    ///     write files to.
    ///   - includeItemsInSubdirectories: A Boolean value
    ///     that determines whether items in nested
    ///     subdirectories are also downloaded.
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
    /// - Throws: An ``Exception`` if the download fails.
    func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) {
        try await downloadAllItems(
            at: path,
            toDirectory: localDirectory,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    /// Downloads the item at the specified path to a
    /// local file URL.
    ///
    /// This method calls
    /// ``downloadItem(at:to:prependingEnvironment:cacheStrategy:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path of the item to
    ///     download.
    ///   - localPath: The local file URL to write to.
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
    /// - Throws: An ``Exception`` if the download fails.
    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) {
        try await downloadItem(
            at: path,
            to: localPath,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    /// Recursively finds all empty directories starting
    /// at the specified path.
    ///
    /// This method calls
    /// ``enumerateEmptyDirectories(startingAt:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path at which to begin the
    ///     enumeration.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: A set of paths to empty directories.
    ///
    /// - Throws: An ``Exception`` if the enumeration
    ///   fails.
    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) -> Set<String> {
        try await enumerateEmptyDirectories(
            startingAt: path,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    /// Returns the contents of the directory at the
    /// specified path.
    ///
    /// This method calls
    /// ``getDirectoryListing(at:firstResultOnly:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path to list.
    ///   - firstResultOnly: A Boolean value that
    ///     determines whether only the first result
    ///     is returned. The default is `false`.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: A ``DirectoryListing`` describing the
    ///   directory's contents.
    ///
    /// - Throws: An ``Exception`` if the listing fails.
    func getDirectoryListing(
        at path: String,
        firstResultOnly: Bool = false,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) -> DirectoryListing {
        try await getDirectoryListing(
            at: path,
            firstResultOnly: firstResultOnly,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    /// Checks whether an item of the specified type
    /// exists at the given path.
    ///
    /// This method calls
    /// ``itemExists(as:at:prependingEnvironment:cacheStrategy:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - itemType: The kind of item to check for. The
    ///     default is ``HostedItemType/file``.
    ///   - path: The storage path to inspect.
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
    /// - Returns: `true` if an item of the specified type
    ///   exists; otherwise, `false`.
    ///
    /// - Throws: An ``Exception`` if the check fails.
    func itemExists(
        as itemType: HostedItemType = .file,
        at path: String,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) -> Bool {
        try await itemExists(
            as: itemType,
            at: path,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    /// Returns the size of the item at the specified
    /// path, in kilobytes.
    ///
    /// This method calls
    /// ``sizeInKilobytes(ofItemAt:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - path: The storage path of the item to
    ///     measure.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the path. The default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Returns: The size of the item in kilobytes.
    ///
    /// - Throws: An ``Exception`` if the measurement
    ///   fails.
    func sizeInKilobytes(
        ofItemAt path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) -> Int {
        try await sizeInKilobytes(
            ofItemAt: path,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    /// Uploads data to hosted storage with the specified
    /// metadata.
    ///
    /// This method calls
    /// ``upload(_:metadata:prependingEnvironment:timeout:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - data: The data to upload.
    ///   - metadata: The metadata describing the
    ///     destination path and optional HTTP headers.
    ///   - prependingEnvironment: A Boolean value that
    ///     determines whether the active environment is
    ///     prepended to the metadata's file path. The
    ///     default is `true`.
    ///   - duration: The maximum time to wait before the
    ///     operation times out. The default is 10
    ///     seconds.
    ///
    /// - Throws: An ``Exception`` if the upload fails.
    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async throws(Exception) {
        try await upload(
            data,
            metadata: metadata,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }
}
