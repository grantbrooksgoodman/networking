//
//  NetworkHealthService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
#if canImport(CoreTelephony) && !os(macOS)
import CoreTelephony
#endif
import Foundation
import Network

/* Proprietary */
import AppSubsystem

// MARK: - NetworkHealthService

final class NetworkHealthService: NetworkHealthDelegate, @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    nonisolated static let shared = NetworkHealthService()

    private let estimator = HealthEstimator()
    private let monitorQueue = DispatchQueue(label: "com.neotechnica.networking.health")
    private let _connectionStabilityObserver = LockIsolated<ConnectionStabilityObserver?>(nil)
    private let _health = LockIsolated<NetworkHealth>(.unknown)
    private let _pathMonitor = LockIsolated<NWPathMonitor?>(nil)
    private let _pathState = LockIsolated<PathState>(.init())
    private let _prober = LockIsolated<NetworkHealthProber?>(nil)
    private let _radioTechnologyObserver = LockIsolated<(any NSObjectProtocol)?>(nil)

    // MARK: - Computed Properties

    var health: NetworkHealth {
        let health = _health.wrappedValue

        // Probing exists to fill the idle-confidence gap: an
        // unknown read is the demand signal. The read itself
        // stays synchronous and non-blocking.
        if health.isUnknown {
            maybeProbe()
        }

        return health
    }

    private var estimatorContext: EstimatorContext {
        .init(
            configuration: Networking.config.networkHealthConfiguration,
            isOnline: isOnline,
            pathState: _pathState.wrappedValue
        )
    }

    // MARK: - Init

    private nonisolated init() {}

    // MARK: - NetworkHealthDelegate Conformance

    func record(_ event: NetworkHealthEvent) {
        if case let .connectionRestored(afterSeconds) = event {
            Logger.log(
                "Connection restored after \(String(format: "%.1f", afterSeconds)) seconds.",
                domain: .Networking.health,
                sender: self
            )
        }

        updateHealth { estimator, context in
            await estimator.record(
                event: event,
                context: context
            )
        }
    }

    func recordCensoredLatencySample(seconds: TimeInterval) {
        startConnectionStabilityMonitoringIfNeeded()
        submitLatencySample(
            seconds: seconds,
            isCensored: true
        )
    }

    func recordLatencySample(seconds: TimeInterval) {
        startConnectionStabilityMonitoringIfNeeded()
        submitLatencySample(seconds: seconds)
    }

    func recordThroughputSample(
        bytes: Int,
        seconds: TimeInterval
    ) {
        updateHealth { estimator, context in
            await estimator.recordThroughput(
                bytes: bytes,
                seconds: seconds,
                context: context
            )
        }
    }

    func startMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }

        monitor.start(queue: monitorQueue)
        _pathMonitor.wrappedValue = monitor
        registerRadioTechnologyObserver()
    }

    func stopMonitoring() {
        _pathMonitor.wrappedValue?.cancel()
        _pathMonitor.wrappedValue = nil

        let connectionStabilityObserver = _connectionStabilityObserver.projectedValue.withValue { observer -> ConnectionStabilityObserver? in
            let current = observer
            observer = nil
            return current
        }

        connectionStabilityObserver?.stop()
        removeRadioTechnologyObserver()
    }

    // MARK: - Methods

    func debugSummary() async -> String {
        let configuration = Networking.config.networkHealthConfiguration
        let summary = await estimator.debugSummary(context: estimatorContext)

        let scoreDescription = health.score.map { String(format: "%.2f", $0) } ?? "unknown"
        let tierDescription = health.tier?.rawValue ?? "unknown"

        let socketDescription: String
        if let connectionStabilityObserver = _connectionStabilityObserver.wrappedValue {
            let reconnectDescription = connectionStabilityObserver.lastReconnectDuration.map {
                String(format: "%.1fs", $0)
            } ?? "none"

            socketDescription = "Socket – connected: \(connectionStabilityObserver.connectedStateDescription), last reconnect: \(reconnectDescription)"
        } else {
            socketDescription = "Socket – unattached"
        }

        let probeDescription = if configuration.probeConfiguration == nil {
            "Probing: disabled"
        } else if let prober = _prober.wrappedValue {
            "Probing: \(prober.statsDescription)"
        } else {
            "Probing: enabled, no attempts"
        }

        return """
        Score: \(scoreDescription)
        Tier: \(tierDescription)
        \(summary)
        \(socketDescription)
        \(probeDescription)
        """
    }

    // MARK: - Auxiliary

    private func handlePathUpdate(_ path: NWPath) {
        let newState = PathState(
            interfaceType: path.availableInterfaces.first?.type,
            isConstrained: path.isConstrained,
            isExpensive: path.isExpensive,
            radioTechnology: RadioTechnology.current
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

        updateHealth { estimator, context in
            await estimator.resetConfidence()
            return await estimator.computeHealth(context: context)
        }

        // Give the new path a moment to settle before probing
        // to rebuild confidence on it.
        maybeProbe(afterDelay: .seconds(2))
    }

    private func handleRadioTechnologyChange() {
        let radioTechnology = RadioTechnology.current
        let didChange: Bool = _pathState.projectedValue.withValue { pathState in
            guard pathState.radioTechnology != radioTechnology else { return false }
            pathState.radioTechnology = radioTechnology
            return true
        }

        guard didChange else { return }

        updateHealth { estimator, context in
            await estimator.computeHealth(context: context)
        }
    }

    /// Fire-and-forget probe trigger; bails immediately when
    /// probing is unconfigured so unconfigured behavior is
    /// identical to baseline.
    private func maybeProbe(afterDelay delay: Duration? = nil) {
        guard Networking.config.networkHealthConfiguration.probeConfiguration != nil else { return }
        let prober = proberCreatingIfNeeded()
        Task {
            if let delay {
                try? await Task.sleep(for: delay)
            }

            await prober.maybeProbe()
        }
    }

    private func proberCreatingIfNeeded() -> NetworkHealthProber {
        _prober.projectedValue.withValue { prober in
            if let prober { return prober }

            let created = NetworkHealthProber(
                onEvent: { [weak self] event in
                    self?.record(event)
                },
                onLatencySample: { [weak self] seconds in
                    self?.submitLatencySample(seconds: seconds)
                },
                pathStateProvider: { [weak self] in
                    self?._pathState.wrappedValue ?? .init()
                }
            )

            prober = created
            return created
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

    private func registerRadioTechnologyObserver() {
        #if canImport(CoreTelephony) && !os(macOS)
        let observer = notificationCenter.addObserver(
            forName: .CTServiceRadioAccessTechnologyDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleRadioTechnologyChange()
        }

        _radioTechnologyObserver.wrappedValue = observer
        #endif
    }

    private func removeRadioTechnologyObserver() {
        #if canImport(CoreTelephony) && !os(macOS)
        let observer = _radioTechnologyObserver.projectedValue.withValue { observer -> (any NSObjectProtocol)? in
            let current = observer
            observer = nil
            return current
        }

        guard let observer else { return }
        notificationCenter.removeObserver(observer)
        #endif
    }

    /// Lazily attaches the connection stability observer on the
    /// first database latency sample – evidence the app actually
    /// uses the realtime database. An observer attached eagerly
    /// would itself keep the realtime connection alive.
    private func startConnectionStabilityMonitoringIfNeeded() {
        guard Networking.config.networkHealthConfiguration.isConnectionStabilityMonitoringEnabled else { return }

        let connectionStabilityObserver = _connectionStabilityObserver.projectedValue.withValue { observer -> ConnectionStabilityObserver? in
            guard observer == nil else { return nil }

            let created = ConnectionStabilityObserver { [weak self] event in
                self?.record(event)
            }

            observer = created
            return created
        }

        connectionStabilityObserver?.start()
    }

    /// Feeds a latency sample into the estimator without the
    /// connection-stability attach trigger – probe round-trips
    /// are not evidence of realtime database use.
    private func submitLatencySample(
        seconds: TimeInterval,
        isCensored: Bool = false
    ) {
        updateHealth { estimator, context in
            await estimator.recordLatency(
                seconds: seconds,
                isCensored: isCensored,
                context: context
            )
        }
    }

    /// Runs an estimator update off the caller's thread –
    /// recording stays fire-and-forget – and publishes the
    /// resulting health value.
    private func updateHealth(_ update: @escaping @Sendable (HealthEstimator, EstimatorContext) async -> NetworkHealth) {
        Task {
            await publish(update(estimator, estimatorContext))
        }
    }
}

// MARK: - HealthEstimator

private actor HealthEstimator {
    // MARK: - Properties

    private var failureChannel = HealthChannel()
    private var flapChannel = HealthChannel()
    private var lastTransferBytesPerSecond: Double?
    private var latencyChannel = HealthChannel()
    private var stallCount = 0
    private var throughputChannel = HealthChannel()

    // MARK: - Computed Properties

    /// The latency channel's coefficient of variation – the
    /// standard deviation of its samples relative to their mean.
    private var latencyDispersion: Double {
        latencyChannel.standardDeviation / max(latencyChannel.mean, 0.001)
    }

    /// The throughput channel's standard deviation, in
    /// log₂(bytes per second) units, which are already relative.
    private var throughputDispersion: Double {
        throughputChannel.standardDeviation
    }

    // MARK: - Methods

    func computeHealth(context: EstimatorContext) -> NetworkHealth {
        let configuration = context.configuration
        let pathState = context.pathState

        guard context.isOnline else {
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
            mean: log2(max(latencyChannel.mean, 0.001)),
            floor: log2(configuration.latencyFloor),
            ceiling: log2(configuration.latencyCeiling),
            inverted: true,
            dispersion: latencyDispersion,
            jitterCeiling: configuration.latencyJitterCeiling,
            jitterPenaltyWeight: configuration.jitterPenaltyWeight
        )

        let throughputScore = channelScore(
            mean: throughputChannel.mean,
            floor: configuration.throughputFloor,
            ceiling: configuration.throughputCeiling,
            inverted: false,
            dispersion: throughputDispersion,
            jitterCeiling: configuration.throughputJitterCeiling,
            jitterPenaltyWeight: configuration.jitterPenaltyWeight
        )

        let blendedLatency = latencyScore * weightedLatencyConfidence
        let blendedThroughput = throughputScore * weightedThroughputConfidence

        var score = (blendedLatency + blendedThroughput) / totalConfidence

        score *= 1 - failureRatePenalty(
            at: now,
            configuration: configuration
        )

        score *= 1 - stabilityPenalty(
            at: now,
            configuration: configuration
        )

        if pathState.isConstrained {
            score *= configuration.constrainedPenalty
        }

        if pathState.isExpensive {
            score *= configuration.expensivePenalty
        }

        score = min(max(score, 0), 1)

        // A prior, never a boost: measurements always speak
        // first; the cap only stops a starved estimator from
        // over-reporting on legacy cellular technology.
        if configuration.isRadioTechnologyPriorEnabled,
           pathState.interfaceType == .cellular {
            switch pathState.radioTechnology {
            case .intermediate:
                score = min(score, configuration.intermediateRadioScoreCap)
            case .legacy:
                score = min(score, configuration.legacyRadioScoreCap)
            case .modern,
                 .unknown:
                break
            }
        }

        return .measured(
            score: score,
            tier: configuration.tier(for: score)
        )
    }

    func debugSummary(context: EstimatorContext) -> String {
        let halfLife = context.configuration.halfLife
        let now = Date.now
        let pathState = context.pathState

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

        let failureFraction = failureChannel.mean
        let failureConfidence = failureChannel.decayedWeight(
            at: now,
            halfLife: halfLife
        )

        let decayedFlapCount = flapChannel.decayedWeight(
            at: now,
            halfLife: halfLife
        )

        let lastTransferDescription = lastTransferBytesPerSecond.map {
            String(format: "%.1f KB/s", $0 / 1024)
        } ?? "none"

        return String(
            format: "Latency – mean: %.3fs, dispersion: %.2f, confidence: %.2f\nThroughput – mean: %.1f (log₂ B/s), dispersion: %.2f, confidence: %.2f\nFailure – fraction: %.2f, confidence: %.2f\nFlaps – decayed count: %.2f\nLast transfer: %@, Stalls: %d\nConstrained: %@, Expensive: %@, Radio: %@",
            latencyMean,
            latencyDispersion,
            latencyConfidence,
            throughputMean,
            throughputDispersion,
            throughputConfidence,
            failureFraction,
            failureConfidence,
            decayedFlapCount,
            lastTransferDescription,
            stallCount,
            pathState.isConstrained.description,
            pathState.isExpensive.description,
            pathState.radioTechnology.rawValue
        )
    }

    func record(
        event: NetworkHealthEvent,
        context: EstimatorContext
    ) -> NetworkHealth {
        let halfLife = context.configuration.halfLife

        switch event {
        case .connectionFlap:
            flapChannel.record(
                sample: 1,
                at: .now,
                halfLife: halfLife
            )

        case .connectionRestored:
            // Informational only – reconnect timing reflects
            // backoff scheduling, not network quality.
            break

        case let .handshake(seconds):
            latencyChannel.record(
                sample: seconds,
                at: .now,
                halfLife: halfLife
            )

        case let .probeFailure(timeoutSeconds):
            failureChannel.record(
                sample: 1,
                at: .now,
                halfLife: halfLife
            )

            latencyChannel.record(
                sample: timeoutSeconds,
                at: .now,
                halfLife: halfLife
            )

        case .transferStall:
            stallCount += 1

            failureChannel.record(
                sample: 1,
                at: .now,
                halfLife: halfLife
            )
        }

        return computeHealth(context: context)
    }

    func recordLatency(
        seconds: TimeInterval,
        isCensored: Bool,
        context: EstimatorContext
    ) -> NetworkHealth {
        let halfLife = context.configuration.halfLife

        latencyChannel.record(
            sample: seconds,
            at: .now,
            halfLife: halfLife
        )

        // A timeout is the failure signal; a completed
        // round-trip is a success.
        failureChannel.record(
            sample: isCensored ? 1 : 0,
            at: .now,
            halfLife: halfLife
        )

        return computeHealth(context: context)
    }

    func recordThroughput(
        bytes: Int,
        seconds: TimeInterval,
        context: EstimatorContext
    ) -> NetworkHealth {
        guard bytes >= context.configuration.minimumThroughputSampleBytes else {
            return computeHealth(context: context)
        }

        let bytesPerSecond = Double(bytes) / max(seconds, 0.001)
        lastTransferBytesPerSecond = bytesPerSecond

        throughputChannel.record(
            sample: log2(bytesPerSecond),
            at: .now,
            halfLife: context.configuration.halfLife
        )

        return computeHealth(context: context)
    }

    func resetConfidence() {
        failureChannel.reset()
        flapChannel.reset()
        latencyChannel.reset()
        throughputChannel.reset()
    }

    // MARK: - Auxiliary

    /// Maps a channel mean to [0, 1] via a piecewise-linear ramp,
    /// then reduces the result in proportion to the channel's
    /// normalized sample dispersion (jitter).
    ///
    /// When `inverted` is true (latency channel), lower values
    /// map to higher scores. When false (throughput channel),
    /// higher values map to higher scores.
    private func channelScore(
        mean: Double,
        floor: Double,
        ceiling: Double,
        inverted: Bool,
        dispersion: Double,
        jitterCeiling: Double,
        jitterPenaltyWeight: Double
    ) -> Double {
        guard ceiling > floor else { return 0.5 }

        let normalized = (mean - floor) / (ceiling - floor)
        let clamped = min(max(normalized, 0), 1)
        let rampScore = inverted ? 1.0 - clamped : clamped

        let normalizedDispersion = min(dispersion / max(jitterCeiling, 0.001), 1)
        let jitterPenalty = min(max(jitterPenaltyWeight * normalizedDispersion, 0), 1)

        return rampScore * (1 - jitterPenalty)
    }

    /// Returns the failure-rate penalty in [0, 1] – the penalty
    /// weight multiplied by the decayed failure fraction, scaled
    /// by the failure channel's decayed weight so a single stale
    /// failure cannot dominate the score.
    private func failureRatePenalty(
        at time: Date,
        configuration: NetworkHealthConfiguration
    ) -> Double {
        let decayedWeight = failureChannel.decayedWeight(
            at: time,
            halfLife: configuration.halfLife
        )

        let penalty = configuration.failureRatePenaltyWeight *
            failureChannel.mean *
            min(decayedWeight, 1)

        return min(max(penalty, 0), 1)
    }

    /// Returns the stability penalty in [0, 1] – the penalty
    /// weight multiplied by the decayed flap count's fraction of
    /// the flap ceiling, at which the penalty saturates.
    private func stabilityPenalty(
        at time: Date,
        configuration: NetworkHealthConfiguration
    ) -> Double {
        let decayedFlapCount = flapChannel.decayedWeight(
            at: time,
            halfLife: configuration.halfLife
        )

        let penalty = configuration.stabilityPenaltyWeight *
            min(decayedFlapCount / max(configuration.stabilityFlapCeiling, 0.001), 1)

        return min(max(penalty, 0), 1)
    }
}

// MARK: - EstimatorContext

/// A point-in-time snapshot of the estimator's inputs,
/// captured when an update executes.
private struct EstimatorContext {
    // MARK: - Properties

    let configuration: NetworkHealthConfiguration
    let isOnline: Bool
    let pathState: PathState
}
