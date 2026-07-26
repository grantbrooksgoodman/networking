//
//  Observables+HealthExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Proprietary */
import AppSubsystem

public extension Observables {
    /// The most recently published network health value.
    ///
    /// Observe this value to react to changes in network quality:
    ///
    /// ```swift
    /// var observedValues: [any ObservableProtocol] {
    ///     [Observables.networkHealth]
    /// }
    ///
    /// func onChange(of observable: Observable<Any>) {
    ///     switch observable {
    ///     case Observables.networkHealth:
    ///         // Handle health change
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    static let networkHealth = Observable<NetworkHealth>(.unknown)
}
