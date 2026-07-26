//
//  HealthChannel.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Time-decayed exponentially weighted moving average (EWMA)
/// over irregularly spaced samples.
///
/// Each channel tracks a single signal (for example, latency
/// or throughput) with no fixed-count window. The decayed
/// `weight` doubles as the channel's confidence – long idle
/// periods degrade confidence without requiring new samples.
///
/// Alongside the mean, each channel maintains a second moment
/// decayed with the same factor, from which the variance and
/// standard deviation of the sample history are derived.
struct HealthChannel {
    // MARK: - Properties

    private(set) var lastUpdate: Date?
    private(set) var mean: Double = 0
    private(set) var secondMoment: Double = 0
    private(set) var weight: Double = 0

    // MARK: - Computed Properties

    /// The standard deviation of the channel's decayed sample
    /// history.
    var standardDeviation: Double {
        variance.squareRoot()
    }

    /// The variance of the channel's decayed sample history.
    ///
    /// Floating-point error can drive the raw second-moment
    /// difference slightly negative; the value is clamped to
    /// zero in that case.
    var variance: Double {
        max(secondMoment - mean * mean, 0)
    }

    // MARK: - Methods

    /// Returns the channel's weight decayed to the given point
    /// in time, reflecting current confidence in the estimate.
    func decayedWeight(
        at time: Date,
        halfLife: TimeInterval
    ) -> Double {
        guard let lastUpdate,
              halfLife > 0 else { return 0 }

        let elapsed = time.timeIntervalSince(lastUpdate)
        let decayFactor = pow(2, -elapsed / halfLife)
        return weight * decayFactor
    }

    /// Records a new sample, applying time-based decay to
    /// previous state before incorporating it.
    mutating func record(
        sample: Double,
        at time: Date,
        halfLife: TimeInterval
    ) {
        guard let lastUpdate,
              halfLife > 0 else {
            mean = sample
            secondMoment = sample * sample
            weight = 1
            return lastUpdate = time
        }

        let elapsed = time.timeIntervalSince(lastUpdate)
        let decayFactor = pow(2, -elapsed / halfLife)
        let decayedWeight = weight * decayFactor

        mean = (mean * decayedWeight + sample) / (decayedWeight + 1)
        secondMoment = (secondMoment * decayedWeight + sample * sample) / (decayedWeight + 1)
        weight = decayedWeight + 1
        self.lastUpdate = time
    }

    /// Resets the channel to its initial state, discarding all
    /// accumulated history and confidence.
    mutating func reset() {
        lastUpdate = nil
        mean = 0
        secondMoment = 0
        weight = 0
    }
}
