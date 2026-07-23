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

    /// The score at or above which health is classified as
    /// ``NetworkHealthTier/fair``.
    ///
    /// Default value is `0.3`.
    public var fairTierThreshold: Double

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

    /// The latency, in seconds, at or above which the latency
    /// channel maps to a score of approximately zero.
    ///
    /// Default value is `5` seconds.
    public var latencyCeiling: TimeInterval

    /// The latency, in seconds, at or below which the latency
    /// channel maps to a score of approximately one.
    ///
    /// Default value is `0.25` seconds.
    public var latencyFloor: TimeInterval

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
        fairTierThreshold: Double = 0.3,
        goodTierThreshold: Double = 0.7,
        halfLife: TimeInterval = 30,
        latencyCeiling: TimeInterval = 5,
        latencyFloor: TimeInterval = 0.25,
        minimumConfidence: Double = 0.5,
        minimumThroughputSampleBytes: Int = 51200,
        throughputCeiling: Double = 22,
        throughputFloor: Double = 13
    ) {
        self.adaptiveScoreThreshold = adaptiveScoreThreshold
        self.channelWeightLatency = channelWeightLatency
        self.channelWeightThroughput = channelWeightThroughput
        self.constrainedPenalty = constrainedPenalty
        self.expensivePenalty = expensivePenalty
        self.fairTierThreshold = fairTierThreshold
        self.goodTierThreshold = goodTierThreshold
        self.halfLife = halfLife
        self.latencyCeiling = latencyCeiling
        self.latencyFloor = latencyFloor
        self.minimumConfidence = minimumConfidence
        self.minimumThroughputSampleBytes = minimumThroughputSampleBytes
        self.throughputCeiling = throughputCeiling
        self.throughputFloor = throughputFloor
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
