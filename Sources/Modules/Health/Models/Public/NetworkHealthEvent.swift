//
//  NetworkHealthEvent.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A discrete network health signal.
///
/// Events complement the continuous latency and throughput
/// sample channels with one-shot evidence – connection flaps,
/// handshake timings, transfer stalls, and probe failures –
/// that no per-operation sample can capture. Report an event
/// through ``NetworkHealthDelegate/record(_:)``; the built-in
/// delegate folds it into the health estimate.
///
/// > Important: New event types may be added in future
/// > versions. Switch statements over this type should
/// > include a `default` clause.
public enum NetworkHealthEvent: Sendable {
    /// The realtime connection dropped unexpectedly while the
    /// device was otherwise online and active.
    case connectionFlap

    /// The realtime connection was reestablished after an
    /// outage of the given duration.
    ///
    /// This event is informational and does not affect the
    /// health score – reconnect timing reflects backoff
    /// scheduling, not network quality.
    ///
    /// - Parameter afterSeconds: The duration of the outage,
    ///   in seconds.
    case connectionRestored(afterSeconds: TimeInterval)

    /// A fresh connection handshake completed in the given
    /// duration.
    ///
    /// Handshake timing – DNS resolution plus connection
    /// establishment – is on the order of a light network
    /// round-trip and contributes to the latency channel.
    ///
    /// - Parameter seconds: The handshake duration, in
    ///   seconds.
    case handshake(seconds: TimeInterval)

    /// A network probe failed to complete within its timeout.
    ///
    /// Contributes a failure sample and a censored latency
    /// sample bounded by the probe's timeout.
    ///
    /// - Parameter timeoutSeconds: The probe's configured
    ///   timeout, in seconds.
    case probeFailure(timeoutSeconds: TimeInterval)

    /// An active transfer stopped making progress.
    ///
    /// Contributes a failure sample.
    case transferStall
}
