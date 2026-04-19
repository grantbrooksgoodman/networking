//
//  DataSample.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A time-stamped snapshot of data with a configurable
/// expiration threshold.
///
/// Use `DataSample` to wrap a piece of data alongside the
/// date it was captured and a duration after which the
/// sample is considered stale:
///
/// ```swift
/// let sample = DataSample(
///     data: responsePayload,
///     expiresAfter: .seconds(30)
/// )
///
/// if sample.isExpired {
///     // Fetch fresh data.
/// }
/// ```
public final class DataSample {
    // MARK: - Properties

    /// The captured data.
    public let data: Any

    /// The date the sample was captured.
    public let date: Date

    /// The duration after which the sample is considered
    /// expired.
    public let expiryThreshold: Duration

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the sample
    /// has exceeded its expiry threshold.
    public var isExpired: Bool {
        Double(abs(date.seconds(from: Date()) * 1000)) > expiryThreshold.milliseconds
    }

    // MARK: - Init

    /// Creates a data sample with the specified date,
    /// data, and expiry threshold.
    ///
    /// - Parameters:
    ///   - date: The date the sample was captured. The
    ///     default is the current date and time.
    ///   - data: The data to store in the sample.
    ///   - expiryThreshold: The duration after which the
    ///     sample is considered expired.
    public init(
        _ date: Date = .now,
        data: Any,
        expiresAfter expiryThreshold: Duration
    ) {
        self.date = date
        self.data = data
        self.expiryThreshold = expiryThreshold
    }
}
