//
//  TransferProgressProbe.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A per-transfer health probe that converts storage transfer
/// progress into mid-flight throughput samples and stall
/// evidence.
///
/// Attach one probe to each transfer by composing its
/// ``handleProgress(_:)`` sink with the transfer's progress
/// callbacks. Whenever the accumulated progress since the last
/// sample reaches
/// ``NetworkHealthConfiguration/minimumThroughputSampleBytes``,
/// the probe records a throughput sample for that segment. A
/// watchdog reports a single
/// ``NetworkHealthEvent/transferStall`` if progress freezes for
/// ``NetworkHealthConfiguration/transferStallSeconds`` while
/// the transfer is active.
///
/// Call ``finish(totalBytes:)`` on success – the probe records
/// the final partial segment, or falls back to a single
/// whole-transfer sample when no segment was ever emitted – or
/// ``invalidate()`` on failure. Either call cancels the
/// watchdog and renders the probe inert.
struct TransferProgressProbe {
    // MARK: - Types

    private struct MutableState {
        /* MARK: Properties */

        var didEmitSegment = false
        var didReportStall = false
        var isFinished = false
        var lastCompletedBytes: Int64 = 0
        var lastProgressAt: Date
        var segmentBytes = 0
        var segmentStartedAt: Date
        var startedAt: Date
        var watchdogTask: Task<Void, Never>?

        /* MARK: Init */

        init(startedAt: Date = .now) {
            lastProgressAt = startedAt
            segmentStartedAt = startedAt
            self.startedAt = startedAt
        }
    }

    // MARK: - Properties

    private let state = LockIsolated(MutableState())

    // MARK: - Init

    init() {
        let watchdogTask = makeWatchdogTask()
        state.projectedValue.withValue { $0.watchdogTask = watchdogTask }
    }

    // MARK: - Methods

    /// Marks the transfer as successfully completed, recording
    /// the final partial segment – or, when no segment was ever
    /// emitted, a single whole-transfer sample for the given
    /// byte count.
    ///
    /// Samples below the minimum throughput sample size are
    /// discarded by the health estimator, preserving baseline
    /// behavior for small transfers.
    ///
    /// - Parameter totalBytes: The total number of bytes
    ///   transferred, or `nil` when unknown.
    func finish(totalBytes: Int?) {
        let now = Date.now

        let (watchdogTask, sample) = state.projectedValue.withValue { state -> (Task<Void, Never>?, (bytes: Int, seconds: TimeInterval)?) in
            guard !state.isFinished else { return (nil, nil) }
            state.isFinished = true

            let watchdogTask = state.watchdogTask
            state.watchdogTask = nil

            if state.didEmitSegment {
                guard state.segmentBytes > 0 else { return (watchdogTask, nil) }
                return (watchdogTask, (
                    state.segmentBytes,
                    now.timeIntervalSince(state.segmentStartedAt)
                ))
            }

            guard let totalBytes else { return (watchdogTask, nil) }
            return (watchdogTask, (
                totalBytes,
                now.timeIntervalSince(state.startedAt)
            ))
        }

        watchdogTask?.cancel()
        record(sample)
    }

    /// Incorporates a progress snapshot, recording a throughput
    /// sample whenever the accumulated segment reaches the
    /// minimum sample size.
    ///
    /// - Parameter progress: The transfer's latest progress
    ///   snapshot.
    func handleProgress(_ progress: StorageTransferProgress) {
        let minimumThroughputSampleBytes = Networking.config.networkHealthConfiguration.minimumThroughputSampleBytes
        let now = Date.now

        let sample: (bytes: Int, seconds: TimeInterval)? = state.projectedValue.withValue { state in
            guard !state.isFinished else { return nil }

            let deltaBytes = progress.completedBytes - state.lastCompletedBytes
            guard deltaBytes > 0 else { return nil }

            state.lastCompletedBytes = progress.completedBytes
            state.lastProgressAt = now
            state.segmentBytes += Int(deltaBytes)

            guard state.segmentBytes >= minimumThroughputSampleBytes else { return nil }

            let sample = (
                state.segmentBytes,
                now.timeIntervalSince(state.segmentStartedAt)
            )

            state.didEmitSegment = true
            state.segmentBytes = 0
            state.segmentStartedAt = now
            return sample
        }

        record(sample)
    }

    /// Marks the transfer as failed or abandoned, cancelling
    /// the watchdog without recording a completion sample.
    func invalidate() {
        let watchdogTask = state.projectedValue.withValue { state -> Task<Void, Never>? in
            guard !state.isFinished else { return nil }
            state.isFinished = true

            let watchdogTask = state.watchdogTask
            state.watchdogTask = nil
            return watchdogTask
        }

        watchdogTask?.cancel()
    }

    /// Runs a transfer with an attached probe, composing the
    /// probe's progress sink with the caller's, finishing the
    /// probe on success and invalidating it on failure.
    ///
    /// The `totalBytes` expression is evaluated only after the
    /// transfer succeeds, so it may reference artifacts the
    /// transfer produces – such as a downloaded file on disk.
    ///
    /// - Parameters:
    ///   - totalBytes: The total number of bytes transferred,
    ///     or `nil` when unknown.
    ///   - onProgress: The caller's progress sink, invoked
    ///     alongside the probe's for each snapshot.
    ///   - transfer: The transfer to run, given the composed
    ///     progress sink.
    ///
    /// - Throws: The transfer's `Exception`, after
    ///   invalidating the probe.
    static func measure(
        totalBytes: @autoclosure () -> Int?,
        onProgress: (@Sendable (StorageTransferProgress) -> Void)?,
        _ transfer: (
            _ onProgress: @escaping @Sendable (StorageTransferProgress) -> Void
        ) async throws(Exception) -> Void
    ) async throws(Exception) {
        let probe = TransferProgressProbe()

        do {
            try await transfer { progress in
                probe.handleProgress(progress)
                onProgress?(progress)
            }
        } catch {
            probe.invalidate()
            throw error
        }

        probe.finish(totalBytes: totalBytes())
    }

    // MARK: - Auxiliary

    private func makeWatchdogTask() -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                let checkInterval = Networking.config.networkHealthConfiguration.transferStallCheckInterval
                try? await Task.sleep(for: .seconds(checkInterval))

                guard !Task.isCancelled else { return }

                let transferStallSeconds = Networking.config.networkHealthConfiguration.transferStallSeconds
                let shouldReportStall = state.projectedValue.withValue { state in
                    guard !state.isFinished,
                          !state.didReportStall,
                          Date.now.timeIntervalSince(state.lastProgressAt) >= transferStallSeconds else {
                        return false
                    }

                    state.didReportStall = true
                    return true
                }

                guard shouldReportStall else { continue }
                Networking.config.healthDelegate.record(.transferStall)
                return
            }
        }
    }

    private func record(_ sample: (bytes: Int, seconds: TimeInterval)?) {
        guard let sample else { return }
        Networking.config.healthDelegate.recordThroughputSample(
            bytes: sample.bytes,
            seconds: sample.seconds
        )
    }
}
