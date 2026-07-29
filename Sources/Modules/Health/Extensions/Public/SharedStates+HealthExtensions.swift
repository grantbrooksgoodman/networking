//
//  SharedStates+HealthExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Proprietary */
import AppSubsystem

public extension SharedStates {
    /// The most recently published network health value.
    ///
    /// Observe the `changes` stream to react to changes in network
    /// quality. The stream yields the current value immediately upon
    /// subscription, then each subsequent change:
    ///
    /// ```swift
    /// @SharedState(\.networkHealth) private var networkHealth
    ///
    /// for await health in $networkHealth.changes {
    ///     // Handle health change
    /// }
    /// ```
    ///
    /// View models subscribe by mapping each value to a reducer action:
    ///
    /// ```swift
    /// viewModel.observing($networkHealth.changes) { .networkHealthChanged($0) }
    /// ```
    var networkHealth: StateStream<NetworkHealth> {
        state(.unknown)
    }
}
