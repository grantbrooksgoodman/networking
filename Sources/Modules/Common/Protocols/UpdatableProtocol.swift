//
//  UpdatableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A type whose individual properties can be updated
/// remotely by serialization key.
///
/// Adopt `Updatable` alongside ``Serializable`` to support
/// granular, key-based updates to a type's properties:
///
/// ```swift
/// let result = await model.updateValue(
///     newValue,
///     forKey: .displayName
/// )
/// ```
///
/// Conforming types specify which keys support updates
/// through the ``updatableKeys`` property.
public protocol Updatable {
    // MARK: - Associated Types

    /// The type used to identify individual properties
    /// for serialization.
    associatedtype SerializationKey

    /// The serializable type returned after an update.
    associatedtype U: Serializable

    // MARK: - Properties

    /// The keys whose values can be updated.
    var updatableKeys: [SerializationKey] { get }

    // MARK: - Methods

    /// Returns a modified copy of the receiver with the
    /// specified key set to the given value, or `nil` if
    /// the modification fails.
    ///
    /// - Parameters:
    ///   - key: The serialization key to modify.
    ///   - value: The new value for the key.
    ///
    /// - Returns: A modified copy, or `nil` if the key
    ///   cannot be modified locally.
    func modifyKey(
        _ key: SerializationKey,
        withValue value: Any
    ) -> U?

    /// Updates the value for the specified key on the
    /// server and returns the updated instance.
    ///
    /// - Parameters:
    ///   - value: The new value to set.
    ///   - key: The serialization key to update.
    ///
    /// - Returns: On success, the updated instance.
    func updateValue(
        _ value: Any,
        forKey key: SerializationKey
    ) async -> Callback<U, Exception>
}
