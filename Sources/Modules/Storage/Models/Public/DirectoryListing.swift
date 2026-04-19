//
//  DirectoryListing.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseStorage

/// A snapshot of the files and subdirectories at a given
/// path in hosted storage.
///
/// You receive a `DirectoryListing` from
/// ``StorageDelegate/getDirectoryListing(at:firstResultOnly:prependingEnvironment:timeout:)``.
/// Inspect its properties to discover what exists at a
/// storage path:
///
/// ```swift
/// let getDirectoryListingResult = await storage.getDirectoryListing(
///     at: "images"
/// )
///
/// switch getDirectoryListingResult {
/// case let .success(directoryListing):
///     print(listing.filePaths)
///     print(listing.subdirectories)
///
/// case let .failure(exception):
///     // Handle failure.
/// }
/// ```
public struct DirectoryListing: Sendable {
    // MARK: - Properties

    /// The paths of all files in the directory.
    public let filePaths: Set<String>

    /// The paths of all subdirectories in the directory.
    public let subdirectories: Set<String>

    // MARK: - Init

    init(
        filePaths: Set<String>,
        subdirectories: Set<String>
    ) {
        self.filePaths = filePaths
        self.subdirectories = subdirectories
    }

    init(_ storageListResult: StorageListResult) {
        self.init(
            filePaths: .init(
                storageListResult
                    .items
                    .compactMap(\.fullPath)
            ),
            subdirectories: .init(
                storageListResult
                    .prefixes
                    .compactMap(\.fullPath)
            )
        )
    }
}
