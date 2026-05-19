//
//  HostedItemType.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that identifies the kind of item at a storage
/// path.
///
/// Pass a hosted item type to
/// ``StorageDelegate/itemExists(as:at:prependingEnvironment:cacheStrategy:timeout:)``
/// to check whether a file or directory exists at the
/// specified path.
public enum HostedItemType: Sendable {
    // MARK: - Cases

    /// A directory that may contain files or
    /// subdirectories.
    case directory

    /// A single file.
    case file

    // MARK: - Properties

    var rawValue: String {
        switch self {
        case .directory: "directory"
        case .file: "file"
        }
    }
}
