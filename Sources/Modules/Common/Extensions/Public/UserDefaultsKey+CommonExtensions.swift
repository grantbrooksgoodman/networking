//
//  UserDefaultsKey+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// An enumeration of user defaults keys used by the
/// networking module.
///
/// Pass a case to ``UserDefaultsKey/networking(_:)`` to
/// obtain the corresponding `UserDefaultsKey`:
///
/// ```swift
/// let key = UserDefaultsKey.networking(
///     .networkEnvironment
/// )
/// ```
public extension UserDefaultsKey {
    // MARK: - Types

    enum NetworkingDefaultsKey: String {
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

    /// Returns the user defaults key for the specified
    /// networking key.
    ///
    /// - Parameter key: The networking defaults key.
    ///
    /// - Returns: A `UserDefaultsKey` for the specified
    ///   key.
    static func networking(_ key: NetworkingDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
}
