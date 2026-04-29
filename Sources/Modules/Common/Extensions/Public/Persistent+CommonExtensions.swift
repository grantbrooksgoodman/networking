//
//  Persistent+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Persistent {
    /// Creates a persistent value backed by the specified
    /// networking storage key.
    ///
    /// This convenience initializer is equivalent to
    /// calling `init(.networking(networkingKey))`.
    ///
    /// - Parameter networkingKey: The networking storage
    ///   key to use for persistence.
    convenience init(
        _ networkingKey: PersistentStorageKey.NetworkingStorageKey
    ) {
        self.init(.networking(networkingKey))
    }
}
