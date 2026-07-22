//
//  NetworkHealthService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import Network

/* Proprietary */
import AppSubsystem

// MARK: - NetworkHealthService

final class NetworkHealthService: NetworkHealthDelegate, @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.build.isOnline) private var isOnline: Bool

    // MARK: - Properties

    nonisolated static let shared = NetworkHealthService()

    private let _health = LockIsolated<NetworkHealth>(.unknown)
    private let _pathMonitor = LockIsolated<NWPathMonitor?>(nil)
    private let _pathState = LockIsolated<PathState>(.init())
    private let estimator = HealthEstimator()
    private let monitorQueue = DispatchQueue(label: "com.neotechnica.networking.health")

    // MARK: - Computed Properties

    var health: NetworkHealth {
        _health.wrappedValue
    }

    // MARK: - Init

    private nonisolated init() {}

    // MARK: - NetworkHealthDelegate Conformance

    func recordCensoredLatencySample(seconds: TimeInterval) {
        Task {
            let updated = await estimator.recordCensoredLatency(
                seconds: seconds,
                isOnline: isOnline,
                pathState: _pathState.wrappedValue,
                configuration: Networking.config.networkHealthConfiguration
            )

            publish(updated)
        }
    }

    func recordLatencySample(seconds: TimeInterval) {
        Task {
            let updated = await estimator.recordLatency(
                seconds: seconds,
                isOnline: isOnline,
                pathState: _pathState.wrappedValue,
                configuration: Networking.config.networkHealthConfiguration
            )

            publish(updated)
        }
    }

    func recordThroughputSample(
        bytes: Int,
        seconds: TimeInterval
    ) {
        Task {
            let updated = await estimator.recordThroughput(
                bytes: bytes,
                seconds: seconds,
                isOnline: isOnline,
                pathState: _pathState.wrappedValue,
                configuration: Networking.config.networkHealthConfiguration
            )

            publish(updated)
        }
    }

    func startMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }

        monitor.start(queue: monitorQueue)
        _pathMonitor.wrappedValue = monitor
    }

    func stopMonitoring() {
        _pathMonitor.wrappedValue?.cancel()
        _pathMonitor.wrappedValue = nil
    }

    // MARK: - Methods

    func debugSummary() async -> String {
        let configuration = Networking.config.networkHealthConfiguration
        let summary = await estimator.debugSummary(
            halfLife: configuration.halfLife,
            pathState: _pathState.wrappedValue
        )

        let scoreDescription = health.score.map { String(format: "%.2f", $0) } ?? "unknown"
        let tierDescription = health.tier?.rawValue ?? "unknown"

        return """
        Score: \(scoreDescription)
        Tier: \(tierDescription)
        \(summary)
        """
    }

    // MARK: - Auxiliary

    private func handlePathUpdate(_ path: NWPath) {
        let newState = PathState(
            interfaceType: path.availableInterfaces.first?.type,
            isConstrained: path.isConstrained,
            isExpensive: path.isExpensive
        )

        let previousInterfaceType = _pathState.wrappedValue.interfaceType
        _pathState.wrappedValue = newState

        // Reset channel confidence on interface transitions
        // (e.g. Wi-Fi → cellular). Previous samples are not
        // representative of the new path.
        guard previousInterfaceType != nil,
              previousInterfaceType != newState.interfaceType else {
            return
        }

        Task {
            await estimator.resetConfidence()

            let updated = await estimator.computeHealth(
                isOnline: isOnline,
                pathState: newState,
                configuration: Networking.config.networkHealthConfiguration
            )

            publish(updated)
        }
    }

    private func publish(_ health: NetworkHealth) {
        let previousTier = _health.wrappedValue.tier
        _health.wrappedValue = health
        Observables.networkHealth.value = health

        guard previousTier != health.tier else { return }

        Logger.log(
            "Network health transitioned from \(previousTier?.rawValue ?? "unknown") to \(health.tier?.rawValue ?? "unknown").",
            domain: .Networking.health,
            sender: self
        )
    }
}

// MARK: - HealthEstimator

private actor HealthEstimator {
    // MARK: - Properties

    private var latencyChannel = HealthChannel()
    private var throughputChannel = HealthChannel()

    // MARK: - Methods

    func computeHealth(
        isOnline: Bool,
        pathState: PathState,
        configuration: NetworkHealthConfiguration
    ) -> NetworkHealth {
        guard isOnline else {
            return .measured(
                score: 0,
                tier: .poor
            )
        }

        let now = Date.now

        let latencyConfidence = latencyChannel.decayedWeight(
            at: now,
            halfLife: configuration.halfLife
        )

        let throughputConfidence = throughputChannel.decayedWeight(
            at: now,
            halfLife: configuration.halfLife
        )

        let weightedLatencyConfidence = latencyConfidence * configuration.channelWeightLatency
        let weightedThroughputConfidence = throughputConfidence * configuration.channelWeightThroughput
        let totalConfidence = weightedLatencyConfidence + weightedThroughputConfidence

        guard totalConfidence >= configuration.minimumConfidence else {
            return .unknown
        }

        let latencyScore = channelScore(
            mean: latencyChannel.mean,
            floor: configuration.latencyFloor,
            ceiling: configuration.latencyCeiling,
            inverted: true
        )

        let throughputScore = channelScore(
            mean: throughputChannel.mean,
            floor: configuration.throughputFloor,
            ceiling: configuration.throughputCeiling,
            inverted: false
        )

        let blendedLatency = latencyScore * weightedLatencyConfidence
        let blendedThroughput = throughputScore * weightedThroughputConfidence

        var score = (blendedLatency + blendedThroughput) / totalConfidence

        if pathState.isConstrained {
            score *= configuration.constrainedPenalty
        }

        if pathState.isExpensive {
            score *= configuration.expensivePenalty
        }

        score = min(max(score, 0), 1)

        return .measured(
            score: score,
            tier: configuration.tier(for: score)
        )
    }

    func debugSummary(
        halfLife: TimeInterval,
        pathState: PathState
    ) -> String {
        let now = Date.now

        let latencyMean = latencyChannel.mean
        let latencyConfidence = latencyChannel.decayedWeight(
            at: now,
            halfLife: halfLife
        )

        let throughputMean = throughputChannel.mean
        let throughputConfidence = throughputChannel.decayedWeight(
            at: now,
            halfLife: halfLife
        )

        return String(
            format: "Latency – mean: %.3fs, confidence: %.2f\nThroughput – mean: %.1f (log₂ B/s), confidence: %.2f\nConstrained: %@, Expensive: %@",
            latencyMean,
            latencyConfidence,
            throughputMean,
            throughputConfidence,
            pathState.isConstrained.description,
            pathState.isExpensive.description
        )
    }

    func recordCensoredLatency(
        seconds: TimeInterval,
        isOnline: Bool,
        pathState: PathState,
        configuration: NetworkHealthConfiguration
    ) -> NetworkHealth {
        latencyChannel.record(
            sample: seconds,
            at: .now,
            halfLife: configuration.halfLife
        )

        return computeHealth(
            isOnline: isOnline,
            pathState: pathState,
            configuration: configuration
        )
    }

    func recordLatency(
        seconds: TimeInterval,
        isOnline: Bool,
        pathState: PathState,
        configuration: NetworkHealthConfiguration
    ) -> NetworkHealth {
        latencyChannel.record(
            sample: seconds,
            at: .now,
            halfLife: configuration.halfLife
        )

        return computeHealth(
            isOnline: isOnline,
            pathState: pathState,
            configuration: configuration
        )
    }

    func recordThroughput(
        bytes: Int,
        seconds: TimeInterval,
        isOnline: Bool,
        pathState: PathState,
        configuration: NetworkHealthConfiguration
    ) -> NetworkHealth {
        guard bytes >= configuration.minimumThroughputSampleBytes else {
            return computeHealth(
                isOnline: isOnline,
                pathState: pathState,
                configuration: configuration
            )
        }

        let bytesPerSecond = Double(bytes) / max(seconds, 0.001)
        throughputChannel.record(
            sample: log2(bytesPerSecond),
            at: .now,
            halfLife: configuration.halfLife
        )

        return computeHealth(
            isOnline: isOnline,
            pathState: pathState,
            configuration: configuration
        )
    }

    func resetConfidence() {
        latencyChannel.reset()
        throughputChannel.reset()
    }

    // MARK: - Auxiliary

    /// Maps a channel mean to [0, 1] via a piecewise-linear ramp.
    ///
    /// When `inverted` is true (latency channel), lower values
    /// map to higher scores. When false (throughput channel),
    /// higher values map to higher scores.
    private func channelScore(
        mean: Double,
        floor: Double,
        ceiling: Double,
        inverted: Bool
    ) -> Double {
        guard ceiling > floor else { return 0.5 }

        let normalized = (mean - floor) / (ceiling - floor)
        let clamped = min(max(normalized, 0), 1)
        return inverted ? 1.0 - clamped : clamped
    }
}
