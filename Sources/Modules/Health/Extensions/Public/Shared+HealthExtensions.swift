//
//  Shared+HealthExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Proprietary */
import AppSubsystem

public extension Shared {
    /// The most recently published network health value.
    ///
    /// Observe the `changes` stream to react to changes in network
    /// quality. The stream yields the current value immediately upon
    /// subscription, then each subsequent change:
    ///
    /// ```swift
    /// for await health in Shared.networkHealth.changes {
    ///     // Handle health change
    /// }
    /// ```
    ///
    /// View models subscribe by mapping each value to a reducer action:
    ///
    /// ```swift
    /// viewModel.observing(Shared.networkHealth.changes) { .networkHealthChanged($0) }
    /// ```
    static let networkHealth = SharedState<NetworkHealth>(.unknown)
}
