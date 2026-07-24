//
//  NetworkHealthConfiguration.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Configuration parameters for passive network health estimation.
///
/// All scoring constants – half-life, ramp anchors, channel weights,
/// penalties, trust gates, and tier boundaries – are collected in
/// this single value type. Modify the active configuration at
/// runtime through
/// ``Networking/Config/setNetworkHealthConfiguration(_:)``.
public struct NetworkHealthConfiguration: Codable, Equatable, Sendable {
    // MARK: - Properties

    /// The health score below which ``CacheStrategy/adaptive``
    /// resolves to ``CacheStrategy/returnCacheFirst``.
    ///
    /// Default value is `0.3`.
    public var adaptiveScoreThreshold: Double

    /// The relative weight of the latency channel when blending
    /// the final score.
    ///
    /// Default value is `0.6`.
    public var channelWeightLatency: Double

    /// The relative weight of the throughput channel when blending
    /// the final score.
    ///
    /// Default value is `0.4`.
    public var channelWeightThroughput: Double

    /// Multiplicative penalty applied to the score when the
    /// current network path is constrained (for example, Low Data
    /// Mode is active).
    ///
    /// Default value is `0.9`.
    public var constrainedPenalty: Double

    /// Multiplicative penalty applied to the score when the
    /// current network path is expensive (for example, a cellular
    /// or personal hotspot connection).
    ///
    /// Default value is `0.95`.
    public var expensivePenalty: Double

    /// The weight of the multiplicative penalty applied to the
    /// score as operations fail.
    ///
    /// The penalty is this weight multiplied by the decayed
    /// fraction of failed operations, scaled by the failure
    /// channel's confidence so a single stale failure cannot
    /// dominate. A value of `0` disables the penalty.
    ///
    /// Default value is `0.5`.
    public var failureRatePenaltyWeight: Double

    /// The score at or above which health is classified as
    /// ``NetworkHealthTier/fair``.
    ///
    /// Default value is `0.3`.
    public var fairTierThreshold: Double

    /// The duration, in seconds, after the app returns to the
    /// foreground during which realtime connection drops are
    /// not counted as flaps.
    ///
    /// The realtime client deliberately drops its socket in the
    /// background; reconnection churn around foregrounding is
    /// app lifecycle, not network evidence.
    ///
    /// Default value is `10` seconds.
    public var flapForegroundGraceSeconds: TimeInterval

    /// The score at or above which health is classified as
    /// ``NetworkHealthTier/good``.
    ///
    /// Default value is `0.7`.
    public var goodTierThreshold: Double

    /// The half-life, in seconds, of the exponentially weighted
    /// moving average used by both channels.
    ///
    /// Larger values make the estimator more conservative; smaller
    /// values make it more responsive to recent samples.
    ///
    /// Default value is `30` seconds.
    public var halfLife: TimeInterval

    /// A Boolean value that determines whether the realtime
    /// client's connection stability is monitored as health
    /// evidence.
    ///
    /// When enabled, the service passively observes the
    /// realtime client's connection state and penalizes the
    /// score when the socket drops unexpectedly. The observer
    /// attaches lazily – only after the first database
    /// operation produces a latency sample – because an active
    /// observer keeps the realtime connection alive. Apps that
    /// use only storage or authentication never attach it.
    ///
    /// Default value is `true`.
    public var isConnectionStabilityMonitoringEnabled: Bool

    /// A Boolean value that determines whether URLSession
    /// transaction metrics from the framework's own HTTPS
    /// requests contribute health evidence.
    ///
    /// When enabled, a fresh connection's DNS-plus-connect
    /// handshake contributes a latency sample, large responses
    /// contribute throughput samples, and network-level request
    /// failures contribute failure evidence. Total request
    /// duration is never recorded – for requests whose
    /// round-trip time is dominated by server-side work, it
    /// would poison the estimate. Disable to feed the estimator
    /// exclusively from Firebase traffic.
    ///
    /// Default value is `true`.
    public var isURLSessionMetricsEnabled: Bool

    /// The weight of the per-channel score reduction applied as
    /// sample dispersion (jitter) grows.
    ///
    /// Each channel's score is reduced by up to this fraction
    /// as its normalized dispersion approaches the channel's
    /// jitter ceiling. A value of `0` disables the reduction.
    ///
    /// Default value is `0.3`.
    public var jitterPenaltyWeight: Double

    /// The latency, in seconds, at or above which the latency
    /// channel maps to a score of approximately zero.
    ///
    /// Default value is `3` seconds.
    public var latencyCeiling: TimeInterval

    /// The latency, in seconds, at or below which the latency
    /// channel maps to a score of approximately one.
    ///
    /// Default value is `0.1` seconds.
    public var latencyFloor: TimeInterval

    /// The latency channel's coefficient of variation at or
    /// above which the jitter reduction saturates.
    ///
    /// A value of `1` saturates the reduction when the standard
    /// deviation of latency samples equals their mean.
    ///
    /// Default value is `1.0`.
    public var latencyJitterCeiling: Double

    /// The minimum aggregate channel confidence required to
    /// produce a ``NetworkHealth/measured(score:tier:)`` value.
    ///
    /// When confidence falls below this threshold the service
    /// reports ``NetworkHealth/unknown``.
    ///
    /// Default value is `0.5`.
    public var minimumConfidence: Double

    /// The minimum byte count for a storage transfer to be
    /// recorded as a throughput sample.
    ///
    /// Transfers below this threshold are discarded because they
    /// measure connection latency, not bandwidth.
    ///
    /// Default value is `51200` (50 KB).
    public var minimumThroughputSampleBytes: Int

    /// The decayed flap count at or above which the stability
    /// penalty saturates.
    ///
    /// Default value is `3` – three connection flaps within one
    /// half-life saturate the penalty.
    public var stabilityFlapCeiling: Double

    /// The weight of the multiplicative penalty applied to the
    /// score as the realtime connection flaps.
    ///
    /// The penalty is this weight multiplied by the decayed
    /// flap count's fraction of ``stabilityFlapCeiling``. A
    /// value of `0` disables the penalty.
    ///
    /// Default value is `0.4`.
    public var stabilityPenaltyWeight: Double

    /// The log₂(bytes per second) value at or above which the
    /// throughput channel maps to a score of approximately one.
    ///
    /// Default value is `22.0` (approximately 4 MB/s).
    public var throughputCeiling: Double

    /// The log₂(bytes per second) value at or below which the
    /// throughput channel maps to a score of approximately zero.
    ///
    /// Default value is `13.0` (approximately 8 KB/s).
    public var throughputFloor: Double

    /// The throughput channel's standard deviation, in
    /// log₂(bytes per second) units, at or above which the
    /// jitter reduction saturates.
    ///
    /// Default value is `2.0` (a spread of two doublings).
    public var throughputJitterCeiling: Double

    /// The interval, in seconds, at which an active storage
    /// transfer is checked for stalled progress.
    ///
    /// Default value is `2` seconds.
    public var transferStallCheckInterval: TimeInterval

    /// The duration, in seconds, without progress after which
    /// an active storage transfer is considered stalled.
    ///
    /// A stalled transfer contributes a single failure sample,
    /// degrading the score before the operation's timeout
    /// fires.
    ///
    /// Default value is `8` seconds.
    public var transferStallSeconds: TimeInterval

    // MARK: - Init

    /// Creates a configuration with the specified parameters.
    ///
    /// All parameters have sensible defaults; pass only the values
    /// you wish to customize.
    public init(
        adaptiveScoreThreshold: Double = 0.3,
        channelWeightLatency: Double = 0.6,
        channelWeightThroughput: Double = 0.4,
        constrainedPenalty: Double = 0.9,
        expensivePenalty: Double = 0.95,
        failureRatePenaltyWeight: Double = 0.5,
        fairTierThreshold: Double = 0.3,
        flapForegroundGraceSeconds: TimeInterval = 10,
        goodTierThreshold: Double = 0.7,
        halfLife: TimeInterval = 30,
        isConnectionStabilityMonitoringEnabled: Bool = true,
        isURLSessionMetricsEnabled: Bool = true,
        jitterPenaltyWeight: Double = 0.3,
        latencyCeiling: TimeInterval = 3,
        latencyFloor: TimeInterval = 0.1,
        latencyJitterCeiling: Double = 1,
        minimumConfidence: Double = 0.5,
        minimumThroughputSampleBytes: Int = 51200,
        stabilityFlapCeiling: Double = 3,
        stabilityPenaltyWeight: Double = 0.4,
        throughputCeiling: Double = 22,
        throughputFloor: Double = 13,
        throughputJitterCeiling: Double = 2,
        transferStallCheckInterval: TimeInterval = 2,
        transferStallSeconds: TimeInterval = 8
    ) {
        self.adaptiveScoreThreshold = adaptiveScoreThreshold
        self.channelWeightLatency = channelWeightLatency
        self.channelWeightThroughput = channelWeightThroughput
        self.constrainedPenalty = constrainedPenalty
        self.expensivePenalty = expensivePenalty
        self.failureRatePenaltyWeight = failureRatePenaltyWeight
        self.fairTierThreshold = fairTierThreshold
        self.flapForegroundGraceSeconds = flapForegroundGraceSeconds
        self.goodTierThreshold = goodTierThreshold
        self.halfLife = halfLife
        self.isConnectionStabilityMonitoringEnabled = isConnectionStabilityMonitoringEnabled
        self.isURLSessionMetricsEnabled = isURLSessionMetricsEnabled
        self.jitterPenaltyWeight = jitterPenaltyWeight
        self.latencyCeiling = latencyCeiling
        self.latencyFloor = latencyFloor
        self.latencyJitterCeiling = latencyJitterCeiling
        self.minimumConfidence = minimumConfidence
        self.minimumThroughputSampleBytes = minimumThroughputSampleBytes
        self.stabilityFlapCeiling = stabilityFlapCeiling
        self.stabilityPenaltyWeight = stabilityPenaltyWeight
        self.throughputCeiling = throughputCeiling
        self.throughputFloor = throughputFloor
        self.throughputJitterCeiling = throughputJitterCeiling
        self.transferStallCheckInterval = transferStallCheckInterval
        self.transferStallSeconds = transferStallSeconds
    }

    // MARK: - Methods

    /// Returns the tier classification for the given score.
    func tier(for score: Double) -> NetworkHealthTier {
        if score >= goodTierThreshold {
            return .good
        } else if score >= fairTierThreshold {
            return .fair
        }

        return .poor
    }
}

// MARK: - Constants

extension NetworkHealthConfiguration {
    static let `default` = NetworkHealthConfiguration()
}
