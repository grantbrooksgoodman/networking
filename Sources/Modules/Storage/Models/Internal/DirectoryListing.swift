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

struct DirectoryListing {
    // MARK: - Properties

    let filePaths: Set<String>
    let subdirectories: Set<String>

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
