//
//  SerializableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A type that can encode itself to and decode itself
/// from a serialized representation.
///
/// Conform to `Serializable` to define how a type
/// converts to and from a format suitable for network
/// storage:
///
/// ```swift
/// let encoded = model.encoded
/// let result = await MyModel.decode(from: encoded)
/// ```
///
/// Use ``canDecode(from:)`` to check whether a given
/// representation can be decoded before attempting
/// decoding.
public protocol Serializable {
    // MARK: - Associated Types

    /// The decoded type.
    associatedtype T

    /// The serialized format used for encoding and
    /// decoding.
    associatedtype Representation

    // MARK: - Properties

    /// The serialized representation of this instance.
    var encoded: Representation { get }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether
    /// the specified data can be decoded.
    ///
    /// - Parameter data: The serialized data to evaluate.
    ///
    /// - Returns: `true` if the data can be decoded;
    ///   otherwise, `false`.
    static func canDecode(from data: Representation) -> Bool

    /// Decodes an instance from the specified serialized
    /// data.
    ///
    /// - Parameter data: The serialized data to decode.
    ///
    /// - Returns: On success, the decoded instance.
    static func decode(from data: Representation) async -> Callback<T, Exception>
}
