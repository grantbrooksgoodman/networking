//
//  NetworkHealthDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// An interface for passive network quality estimation.
///
/// The framework's built-in implementation observes byte transfers
/// and operation round-trips to maintain a continuously updated
/// health score. Conform to this protocol to substitute a custom
/// estimator.
///
/// > Important: Only the framework's built-in Firebase-backed
/// > implementations are instrumented to produce samples. If you
/// > register a custom database or storage delegate, those
/// > operations will not feed the health estimator.
///
/// ## Accessing Health
///
/// Read the current value synchronously through the delegate's
/// ``health`` property, or observe changes through
/// `Observables.networkHealth`:
///
/// ```swift
/// @Dependency(\.networking.health) var health: NetworkHealthDelegate
/// let current = health.health
/// ```
///
/// ## Overriding the Default Delegate
///
/// ```swift
/// Networking.config.registerHealthDelegate(MyHealthService())
/// ```
public protocol NetworkHealthDelegate: Sendable {
    // MARK: - Properties

    /// The most recently computed network health value.
    ///
    /// This property is synchronous and safe to read from any
    /// context.
    var health: NetworkHealth { get }

    // MARK: - Methods

    /// Records a censored latency sample at the given duration.
    ///
    /// A censored sample indicates that the true latency is
    /// unknown but bounded below by the timeout value. This is
    /// the strongest single piece of negative evidence the
    /// latency channel receives.
    ///
    /// - Parameter seconds: The operation's configured timeout
    ///   duration, in seconds.
    func recordCensoredLatencySample(seconds: TimeInterval)

    /// Records a latency sample for a completed network
    /// round-trip.
    ///
    /// - Parameter seconds: The wall-clock duration of the
    ///   round-trip, in seconds.
    func recordLatencySample(seconds: TimeInterval)

    /// Records a throughput sample for a completed storage
    /// transfer.
    ///
    /// Samples below
    /// ``NetworkHealthConfiguration/minimumThroughputSampleBytes``
    /// are silently discarded by the built-in implementation.
    ///
    /// - Parameters:
    ///   - bytes: The number of bytes transferred.
    ///   - seconds: The wall-clock duration of the transfer,
    ///     in seconds.
    func recordThroughputSample(
        bytes: Int,
        seconds: TimeInterval
    )

    /// Begins monitoring for network interface transitions and
    /// path property changes.
    func startMonitoring()

    /// Stops monitoring and releases the underlying path monitor.
    func stopMonitoring()
}
