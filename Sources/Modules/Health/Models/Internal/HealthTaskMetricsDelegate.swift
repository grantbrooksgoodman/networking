//
//  HealthTaskMetricsDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// An allocation-cheap per-task delegate that converts
/// URLSession transaction metrics into health evidence.
///
/// Attach one instance per request through the per-task
/// delegate parameter of `URLSession.data(for:delegate:)`.
/// From the request's final network-load transaction, a fresh
/// connection's DNS-plus-connect handshake contributes a
/// latency sample, and the response body contributes a
/// throughput sample subject to the estimator's minimum
/// sample size.
///
/// Total request duration is never recorded – for requests
/// whose round-trip time is dominated by server-side work
/// (for example, model inference), it would poison the
/// latency estimate.
///
/// Metrics are stashed when collection finishes and processed
/// on task completion, where the task's error is
/// authoritative. The delegate never throws or blocks;
/// collection failures degrade to silence.
final class HealthTaskMetricsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    // MARK: - Properties

    private let _collectedMetrics = LockIsolated<URLSessionTaskMetrics?>(nil)

    // MARK: - URLSessionTaskDelegate Conformance

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        processCollectedMetrics(taskError: error)
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        _collectedMetrics.projectedValue.withValue { $0 = metrics }
    }

    // MARK: - Auxiliary

    private func processCollectedMetrics(taskError: (any Error)?) {
        guard Networking.config.networkHealthConfiguration.isURLSessionMetricsEnabled else { return }

        let metrics = _collectedMetrics.projectedValue.withValue { metrics -> URLSessionTaskMetrics? in
            let collected = metrics
            metrics = nil
            return collected
        }

        guard let transaction = metrics?.transactionMetrics.last(where: {
            $0.resourceFetchType == .networkLoad
        }) else { return }

        recordHandshakeSampleIfAvailable(
            from: transaction,
            taskError: taskError
        )

        recordThroughputSampleIfAvailable(from: transaction)
    }

    private func recordHandshakeSampleIfAvailable(
        from transaction: URLSessionTaskTransactionMetrics,
        taskError: (any Error)?
    ) {
        guard !transaction.isReusedConnection else { return }

        var handshakeSeconds: TimeInterval = 0
        var hasComponent = false

        if let domainLookupStart = transaction.domainLookupStartDate,
           let domainLookupEnd = transaction.domainLookupEndDate {
            handshakeSeconds += domainLookupEnd.timeIntervalSince(domainLookupStart)
            hasComponent = true
        }

        if let connectStart = transaction.connectStartDate,
           let connectEnd = transaction.connectEndDate {
            handshakeSeconds += connectEnd.timeIntervalSince(connectStart)
            hasComponent = true
        }

        guard hasComponent,
              handshakeSeconds > 0 else { return }

        // A slow handshake on a successful task is precisely
        // the evidence we want; skip absurd values only when
        // the task also failed.
        if taskError != nil,
           handshakeSeconds > Networking.config.networkHealthConfiguration.latencyCeiling {
            return
        }

        Networking.config.healthDelegate.record(
            .handshake(seconds: handshakeSeconds)
        )
    }

    private func recordThroughputSampleIfAvailable(
        from transaction: URLSessionTaskTransactionMetrics
    ) {
        guard let responseStart = transaction.responseStartDate,
              let responseEnd = transaction.responseEndDate else { return }

        let bytes = Int(transaction.countOfResponseBodyBytesReceived)
        let seconds = responseEnd.timeIntervalSince(responseStart)

        guard bytes > 0,
              seconds > 0 else { return }

        Networking.config.healthDelegate.recordThroughputSample(
            bytes: bytes,
            seconds: seconds
        )
    }
}
