//
//  HealthEvidence.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Centralized classifier for network operation outcomes.
///
/// All call sites funnel through this type to determine what,
/// if anything, to record as a health sample. Keeping the
/// classification logic in one place prevents it from drifting
/// across instrumentation seams.
enum HealthEvidence {
    // MARK: - Cases

    /// The operation completed a network round-trip; the elapsed
    /// time is a valid latency observation.
    case latency(seconds: TimeInterval)

    /// The operation's outcome carries no evidence about network
    /// quality (pre-network guard, validation error, etc.).
    case noEvidence

    // MARK: - Methods

    /// Determines the evidence type for a given operation outcome.
    ///
    /// - Parameters:
    ///   - error: The exception thrown by the inner call, or
    ///     `nil` on success.
    ///   - elapsed: Wall-clock seconds from seam entry to
    ///     completion.
    /// - Returns: The classified evidence.
    static func classify(
        error: Exception?,
        elapsed: TimeInterval
    ) -> HealthEvidence {
        guard let error else {
            return .latency(seconds: elapsed)
        }

        // "No value exists" and "item does not exist" mean the
        // server responded – the round-trip completed
        // successfully from a network perspective.
        if error.isEqual(toAny: [
            AppException.Networking.Database.noValueExists,
            AppException.Networking.Storage.storageItemDoesNotExist,
        ]) {
            return .latency(seconds: elapsed)
        }

        return .noEvidence
    }

    /// Measures a single network round-trip, recording the
    /// appropriate health sample for its outcome and rethrowing
    /// any failure.
    ///
    /// Wrap only the network call itself – classification treats
    /// the elapsed time as a round-trip latency observation, so
    /// local pre- and post-processing should stay outside the
    /// operation closure.
    ///
    /// - Parameters:
    ///   - token: The once-only recording guard for this
    ///     operation. Omit to use a fresh token, recording at
    ///     most one sample per call.
    ///   - delegate: The health delegate to receive the sample.
    ///   - operation: The network call to measure.
    ///
    /// - Returns: The operation's result.
    ///
    /// - Throws: The operation's `Exception`, after recording.
    static func measure<T>(
        token: HealthSampleToken = .init(),
        delegate: any NetworkHealthDelegate = Networking.config.healthDelegate,
        _ operation: () async throws(Exception) -> T
    ) async throws(Exception) -> T {
        let startTime = Date.now

        do {
            let value = try await operation()

            record(
                error: nil,
                startTime: startTime,
                token: token,
                delegate: delegate
            )

            return value
        } catch {
            record(
                error: error,
                startTime: startTime,
                token: token,
                delegate: delegate
            )

            throw error
        }
    }

    /// Classifies the outcome of a network operation and records
    /// the appropriate sample through the health delegate.
    ///
    /// This is the single entry point for seam-level recording.
    /// Both the token claim and the delegate call happen here so
    /// that call sites cannot diverge on classification logic.
    ///
    /// - Parameters:
    ///   - error: The exception produced by the operation, or
    ///     `nil` on success.
    ///   - startTime: The wall-clock time captured immediately
    ///     before the network call began.
    ///   - token: The once-only recording guard for this
    ///     operation.
    ///   - delegate: The health delegate to receive the sample.
    static func record(
        error: Exception?,
        startTime: Date,
        token: HealthSampleToken,
        delegate: any NetworkHealthDelegate = Networking.config.healthDelegate
    ) {
        guard token.claim() else { return }
        let elapsed = Date.now.timeIntervalSince(startTime)

        switch classify(
            error: error,
            elapsed: elapsed
        ) {
        case let .latency(seconds): delegate.recordLatencySample(seconds: seconds)
        case .noEvidence: break
        }
    }
}
