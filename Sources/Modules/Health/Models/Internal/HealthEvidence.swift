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

/// Centralized classifier for database operation outcomes.
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

    /// Classifies the outcome of a database operation and records
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
        delegate: any NetworkHealthDelegate
    ) {
        guard token.claim() else { return }
        let elapsed = Date.now.timeIntervalSince(startTime)

        switch classify(
            error: error,
            elapsed: elapsed
        ) {
        case let .latency(seconds):
            delegate.recordLatencySample(seconds: seconds)
        case .noEvidence:
            break
        }
    }

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

        // "No value exists" means the server responded – the
        // round-trip completed successfully from a network
        // perspective.
        if error.isEqual(to: AppException.Networking.Database.noValueExists) {
            return .latency(seconds: elapsed)
        }

        return .noEvidence
    }
}
