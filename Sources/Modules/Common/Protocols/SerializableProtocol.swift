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

/// A type that can convert itself to and from a
/// serialized representation suitable for remote storage.
///
/// Conform to `Serializable` when a model needs to be
/// written to or read from the network database. Each
/// conformer specifies the format used for serialization
/// (``Representation`` – typically `[String: Any]` or
/// `String`):
///
/// ```swift
/// extension MyModel: Serializable {
///     typealias Representation = [String: Any]
///
///     var encoded: [String: Any] { /* ... */ }
///
///     static func canDecode(
///         from data: [String: Any]
///     ) -> Bool { /* ... */ }
///
///     static func decode(
///         from data: [String: Any]
///     ) async throws(Exception) -> MyModel { /* ... */ }
/// }
/// ```
///
/// Use ``canDecode(from:)`` to check whether a given
/// payload is structurally valid before attempting
/// decoding. This is useful for defensive validation
/// when processing data from an untrusted source.
public protocol Serializable {
    // MARK: - Associated Types

    /// The serialized format used for encoding and
    /// decoding – typically `[String: Any]` or `String`.
    associatedtype Representation

    // MARK: - Properties

    /// The serialized representation of this instance,
    /// suitable for writing to the database.
    var encoded: Representation { get }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether the
    /// specified data can be decoded into an instance of
    /// this type.
    ///
    /// Call this method to perform a lightweight
    /// structural check before committing to a full
    /// decode. The method does not perform network
    /// requests.
    ///
    /// - Parameter data: The serialized data to evaluate.
    ///
    /// - Returns: `true` if the data can be decoded;
    ///   otherwise, `false`.
    static func canDecode(
        from data: Representation
    ) -> Bool

    /// Decodes an instance from the specified serialized
    /// data.
    ///
    /// Decoding may involve network requests – for
    /// example, resolving nested references. Call this
    /// method in an asynchronous context.
    ///
    /// - Parameter data: The serialized data to decode.
    ///
    /// - Returns: The decoded instance.
    ///
    /// - Throws: An `Exception` if decoding fails.
    static func decode(
        from data: Representation // swiftformat:disable all
    ) async throws(Exception) -> Self // swiftformat:enable all
}
