//
//  StorageTransferProgress.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A snapshot of a storage transfer's progress.
///
/// Progress-reporting storage operations yield a new
/// snapshot each time the underlying transfer advances:
///
/// ```swift
/// for try await progress in storage.uploadWithProgress(
///     imageData,
///     metadata: HostedItemMetadata("images/photo.png")
/// ) {
///     progressView.progress = Float(progress.fractionCompleted)
/// }
/// ```
///
/// Snapshots are immutable values; each one reflects the
/// state of the transfer at the moment it was reported.
public struct StorageTransferProgress: Equatable, Sendable {
    // MARK: - Properties

    /// The number of bytes transferred so far.
    public let completedBytes: Int64

    /// The total number of bytes expected to be
    /// transferred.
    ///
    /// This value may be `0` or negative before the
    /// transfer's size is known.
    public let totalBytes: Int64

    // MARK: - Computed Properties

    /// The fraction of the transfer that has completed,
    /// in the range `[0.0, 1.0]`.
    ///
    /// Returns `0` when ``totalBytes`` is not yet known.
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        return min(
            max(Double(completedBytes) / Double(totalBytes), 0),
            1
        )
    }

    // MARK: - Init

    /// Creates a progress snapshot.
    ///
    /// - Parameters:
    ///   - completedBytes: The number of bytes
    ///     transferred so far.
    ///   - totalBytes: The total number of bytes expected
    ///     to be transferred.
    public init(
        completedBytes: Int64,
        totalBytes: Int64
    ) {
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }
}
