//
//  PersistentStorageKey+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// An enumeration of persistent storage keys used by the
/// networking module.
///
/// Pass a case to ``PersistentStorageKey/networking(_:)`` to
/// obtain the corresponding `PersistentStorageKey`:
///
/// ```swift
/// let key = PersistentStorageKey.networking(
///     .networkEnvironment
/// )
/// ```
public extension PersistentStorageKey {
    // MARK: - Types

    enum NetworkingStorageKey: String {
        /// The key for catalogued Gemini translation
        /// inputs.
        case geminiCataloguedTranslationInputs

        /// The key for the network activity indicator
        /// enabled state.
        case isNetworkActivityIndicatorEnabled

        /// The key for the active network environment.
        case networkEnvironment
    }

    // MARK: - Methods

    /// Returns the persistent storage key for the specified
    /// networking key.
    ///
    /// - Parameter key: The networking storage key.
    ///
    /// - Returns: A `PersistentStorageKey` for the specified
    ///   key.
    static func networking(
        _ key: NetworkingStorageKey
    ) -> PersistentStorageKey {
        .init(key.rawValue)
    }
}
