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

/// Metadata that describes a file to upload to hosted
/// storage.
///
/// Create a `HostedItemMetadata` to specify the
/// destination path and optional HTTP metadata for an
/// upload:
///
/// ```swift
/// let metadata = HostedItemMetadata(
///     "images/photo.png",
///     contentType: "image/png"
/// )
///
/// let exception = await storage.upload(
///     imageData,
///     metadata: metadata
/// )
/// ```
public struct HostedItemMetadata: Sendable {
    // MARK: - Properties

    /// The destination path for the file in hosted
    /// storage.
    public let filePath: String

    /// The `Cache-Control` header for the file.
    public let cacheControl: String?

    /// The `Content-Disposition` header for the file.
    public let contentDisposition: String?

    /// The `Content-Encoding` header for the file.
    public let contentEncoding: String?

    /// The `Content-Language` header for the file.
    public let contentLanguage: String?

    /// The `Content-Type` header for the file, such as
    /// `"image/png"` or `"application/json"`.
    public let contentType: String?

    /// A dictionary of custom metadata key-value pairs
    /// to associate with the file.
    public let customValues: [String: String]?

    // MARK: - Init

    /// Creates metadata for a hosted storage upload.
    ///
    /// - Parameters:
    ///   - filePath: The destination path for the file
    ///     in hosted storage.
    ///   - cacheControl: The `Cache-Control` header.
    ///     The default is `nil`.
    ///   - contentDisposition: The `Content-Disposition`
    ///     header. The default is `nil`.
    ///   - contentEncoding: The `Content-Encoding`
    ///     header. The default is `nil`.
    ///   - contentLanguage: The `Content-Language`
    ///     header. The default is `nil`.
    ///   - contentType: The `Content-Type` header. The
    ///     default is `nil`.
    ///   - customValues: A dictionary of custom metadata
    ///     key-value pairs. The default is `nil`.
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
