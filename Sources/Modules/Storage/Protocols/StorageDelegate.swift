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

// swiftlint:disable:next class_delegate_protocol
public protocol StorageDelegate {
    func clearStore()

    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?

    // swiftlint:disable:next function_parameter_count
    func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Exception?

    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Exception?

    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Callback<Set<String>, Exception>

    func itemExists(
        as itemType: HostedItemType,
        at path: String,
        prependingEnvironment: Bool,
        cacheStrategy: CacheStrategy,
        timeout duration: Duration
    ) async -> Callback<Bool, Exception>

    /// Overrides the `CacheStrategy` for all `Storage` methods. Pass `nil` to revert the override.
    func setGlobalCacheStrategy(_ globalCacheStrategy: CacheStrategy?)

    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool,
        timeout duration: Duration
    ) async -> Exception?
}

public extension StorageDelegate {
    func deleteAllItems(
        at path: String,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        await deleteAllItems(
            at: path,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func deleteItem(
        at path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        await deleteItem(
            at: path,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func downloadAllItems(
        at path: String,
        toDirectory localDirectory: URL,
        includeItemsInSubdirectories: Bool,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10),
    ) async -> Exception? {
        await downloadAllItems(
            at: path,
            toDirectory: localDirectory,
            includeItemsInSubdirectories: includeItemsInSubdirectories,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    func downloadItem(
        at path: String,
        to localPath: URL,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        await downloadItem(
            at: path,
            to: localPath,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    func enumerateEmptyDirectories(
        startingAt path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Set<String>, Exception> {
        await enumerateEmptyDirectories(
            startingAt: path,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }

    func itemExists(
        as itemType: HostedItemType = .file,
        at path: String,
        prependingEnvironment: Bool = true,
        cacheStrategy: CacheStrategy = .returnCacheFirst,
        timeout duration: Duration = .seconds(10)
    ) async -> Callback<Bool, Exception> {
        await itemExists(
            as: itemType,
            at: path,
            prependingEnvironment: prependingEnvironment,
            cacheStrategy: cacheStrategy,
            timeout: duration
        )
    }

    func upload(
        _ data: Data,
        metadata: HostedItemMetadata,
        prependingEnvironment: Bool = true,
        timeout duration: Duration = .seconds(10)
    ) async -> Exception? {
        await upload(
            data,
            metadata: metadata,
            prependingEnvironment: prependingEnvironment,
            timeout: duration
        )
    }
}
