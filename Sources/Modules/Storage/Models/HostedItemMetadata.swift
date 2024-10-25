//
//  HostedItemMetadata.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseStorage

public struct HostedItemMetadata {
    // MARK: - Properties

    public let filePath: String
    public let cacheControl: String?
    public let contentDisposition: String?
    public let contentEncoding: String?
    public let contentLanguage: String?
    public let contentType: String?
    public let customValues: [String: String]?

    // MARK: - Init

    public init(
        _ filePath: String,
        cacheControl: String? = nil,
        contentDisposition: String? = nil,
        contentEncoding: String? = nil,
        contentLanguage: String? = nil,
        contentType: String? = nil,
        customValues: [String: String]? = nil
    ) {
        self.filePath = filePath
        self.cacheControl = cacheControl
        self.contentDisposition = contentDisposition
        self.contentEncoding = contentEncoding
        self.contentLanguage = contentLanguage
        self.contentType = contentType
        self.customValues = customValues
    }

    // MARK: - As StorageMetadata

    func asStorageMetadata(prependingEnvironment: Bool = true) -> StorageMetadata {
        let filePath = prependingEnvironment ? filePath.prependingCurrentEnvironment : filePath
        let storageMetadata: StorageMetadata = .init(dictionary: ["name": filePath])
        storageMetadata.cacheControl = cacheControl
        storageMetadata.contentDisposition = contentDisposition
        storageMetadata.contentEncoding = contentEncoding
        storageMetadata.contentLanguage = contentLanguage
        storageMetadata.contentType = contentType
        storageMetadata.customMetadata = customValues
        return storageMetadata
    }
}
