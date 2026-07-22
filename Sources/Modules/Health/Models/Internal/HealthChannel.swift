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
/// Each channel tracks a single signal (latency or throughput)
/// with no fixed-count window. The decayed `weight` doubles as
/// the channel's confidence – long idle periods degrade
/// confidence without requiring new samples.
struct HealthChannel {
    // MARK: - Properties

    private(set) var lastUpdate: Date?
    private(set) var mean: Double = 0
    private(set) var weight: Double = 0

    // MARK: - Methods

    /// Returns the channel's weight decayed to the given point
    /// in time, reflecting current confidence in the estimate.
    func decayedWeight(
        at time: Date,
        halfLife: TimeInterval
    ) -> Double {
        guard let lastUpdate, halfLife > 0 else { return 0 }
        let elapsed = time.timeIntervalSince(lastUpdate)
        let w = pow(2, -elapsed / halfLife)
        return weight * w
    }

    /// Records a new sample, applying time-based decay to
    /// previous state before incorporating it.
    mutating func record(
        sample: Double,
        at time: Date,
        halfLife: TimeInterval
    ) {
        guard let lastUpdate, halfLife > 0 else {
            mean = sample
            weight = 1
            lastUpdate = time
            return
        }

        let elapsed = time.timeIntervalSince(lastUpdate)
        let w = pow(2, -elapsed / halfLife)
        let decayedWeight = weight * w

        mean = (mean * decayedWeight + sample) / (decayedWeight + 1)
        weight = decayedWeight + 1
        self.lastUpdate = time
    }

    /// Resets the channel to its initial state, discarding all
    /// accumulated history and confidence.
    mutating func reset() {
        lastUpdate = nil
        mean = 0
        weight = 0
    }
}
