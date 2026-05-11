//
//  RemotelyUpdatableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A type whose individual properties can be written to
/// the server by serialization key.
///
/// Adopt `RemotelyUpdatable` when a model needs to push
/// property changes to the database without re-encoding
/// the entire record. `RemotelyUpdatable` refines
/// ``Serializable``, so conforming types must also provide
/// encoding and decoding.
///
/// ```swift
/// let updated = try await user.updateValue(
///     writing: true,
///     forKey: .aiEnhancedTranslationsEnabled
/// )
/// ```
///
/// When multiple properties need to change together, use
/// ``updateValues(with:)`` to apply them in a single
/// atomic write:
///
/// ```swift
/// let updated = try await user.updateValues(with: [
///     .aiEnhancedTranslationsEnabled: true,
///     .languageCode: "es",
/// ])
/// ```
///
/// Each conformer declares its updatable keys in the
/// ``exposedKeys`` property, and provides a
/// ``networkPath`` and ``identifier`` so the default
/// implementation can construct the database key path
/// automatically (for example,
/// `"users/<identifier>/aiEnhancedTranslationsEnabled"`).
///
/// The default ``updateValue(writing:forKey:)``
/// implementation performs four steps:
///
/// 1. **Local modification** – calls
///    ``modifyKey(_:withValue:)`` to produce an in-memory
///    copy of the model with the property changed.
/// 2. **Pre-write hook** – calls
///    ``willWrite(_:forKey:updating:)`` to allow custom
///    encoding or early handling.
/// 3. **Encoding and writing** – encodes the value using
///    an encoding ladder (``Serializable``, array of
///    ``Serializable``, or raw Foundation type) and writes
///    it to the database.
/// 4. **Post-write hook** – calls
///    ``didWrite(_:forKey:)`` to perform any side effects.
///
/// Conformers can customize the write by overriding two
/// hooks:
///
/// - ``willWrite(_:forKey:updating:)`` – Return a
///   ``WriteAction`` to override encoding, handle the
///   write entirely, or abort by throwing.
/// - ``didWrite(_:forKey:)`` – Perform side effects after
///   a successful write, such as clearing a cache.
public protocol RemotelyUpdatable: Serializable {
    // MARK: - Associated Types

    /// The type used to identify individual serialization
    /// keys.
    ///
    /// Typically an enum whose raw values match the
    /// database field names for the conforming type.
    associatedtype SerializableKey: Hashable & RawRepresentable where SerializableKey.RawValue == String

    // MARK: - Properties

    /// The serialization keys whose values can be updated
    /// remotely.
    ///
    /// ``updateValue(writing:forKey:)`` validates that the
    /// requested key appears in this array before
    /// proceeding.
    var exposedKeys: [SerializableKey] { get }

    /// The identifier used in database key path
    /// construction.
    ///
    /// Combined with ``networkPath`` and the key's raw
    /// value to form the full path for a write – for
    /// example, `"users/<identifier>/<key>"`.
    var identifier: String { get }

    /// The base network path for records of this type.
    var networkPath: NetworkPath { get }

    /// Whether `database.setValue` prepends the current
    /// environment to the key path.
    ///
    /// The default value is `true`.
    var networkPathPrependsCurrentEnvironment: Bool { get }

    // MARK: - Methods

    /// Returns a modified in-memory copy of the receiver
    /// with the specified key set to the given value, or
    /// `nil` if the value cannot be applied.
    ///
    /// This method performs local copy construction only.
    /// It does not write to the database. If the value
    /// cannot be cast to the expected type for the key,
    /// return `nil` to signal a type mismatch.
    ///
    /// - Parameters:
    ///   - key: The serialization key to modify.
    ///   - value: The new value for the key.
    ///
    /// - Returns: A modified copy with the property
    ///   changed, or `nil` if the value's type does not
    ///   match the property.
    func modifyKey(
        _ key: SerializableKey,
        withValue value: Any
    ) -> Self?

    /// Writes the value for the specified key to the
    /// server and returns the updated instance.
    ///
    /// The default implementation:
    ///
    /// 1. Validates that `key` is in ``exposedKeys``.
    /// 2. Calls ``modifyKey(_:withValue:)`` to produce a
    ///    local copy with the property changed.
    /// 3. Calls ``willWrite(_:forKey:updating:)`` to
    ///    allow custom encoding or early handling.
    /// 4. Encodes and writes the value to the database
    ///    using the encoding ladder.
    /// 5. Calls ``didWrite(_:forKey:)`` for post-write
    ///    side effects.
    ///
    /// The encoding ladder in step 4 tries, in order:
    /// ``Serializable`` (single value), array of
    /// ``Serializable`` (substituting
    /// ``Array/bangQualifiedEmpty`` for empty arrays to
    /// prevent key deletion), and finally raw Foundation
    /// types.
    ///
    /// - Parameters:
    ///   - value: The new value to write.
    ///   - key: The serialization key to update.
    ///
    /// - Returns: The updated instance.
    ///
    /// - Throws: An `Exception` if the update fails.
    func updateValue(
        writing value: Any,
        forKey key: SerializableKey // swiftformat:disable all
    ) async throws(Exception) -> Self // swiftformat:enable all

    /// Writes values for the specified keys to the server
    /// and returns the updated instance.
    ///
    /// Use this method to apply multiple property changes
    /// in a single atomic write rather than calling
    /// ``updateValue(writing:forKey:)`` for each key
    /// individually.
    ///
    /// A default implementation is provided when
    /// ``Representation`` is `[String: Any]`. It validates
    /// each key against ``exposedKeys``, applies
    /// ``modifyKey(_:withValue:)`` to produce a locally
    /// updated copy, and writes only the changed fields
    /// to the database.
    ///
    /// This method does not invoke the
    /// ``willWrite(_:forKey:updating:)`` or
    /// ``didWrite(_:forKey:)`` hooks. Override it directly
    /// to customize batch-write behavior.
    ///
    /// - Parameter data: A dictionary mapping
    ///   serialization keys to their new values.
    ///
    /// - Returns: The updated instance.
    ///
    /// - Throws: An `Exception` if a key is not in
    ///   ``exposedKeys``, if a value's type does not match
    ///   the property, or if the database write fails.
    func updateValues(
        with data: [SerializableKey: Any] // swiftformat:disable all
    ) async throws(Exception) -> Self // swiftformat:enable all

    /// Called before the database write to allow custom
    /// encoding or to handle the write entirely.
    ///
    /// Return ``WriteAction/proceed`` to use the standard
    /// encoding ladder, ``WriteAction/encoded(_:)`` to
    /// write a pre-encoded value, or
    /// ``WriteAction/handled(_:)`` if the conformer has
    /// already performed the write. To abort the update,
    /// throw an `Exception`.
    ///
    /// The default implementation returns
    /// ``WriteAction/proceed``.
    ///
    /// - Parameters:
    ///   - value: The raw value being written.
    ///   - key: The serialization key being updated.
    ///   - updated: The locally modified instance produced
    ///     by ``modifyKey(_:withValue:)``.
    ///
    /// - Returns: The action the default `updateValue`
    ///   implementation should take.
    ///
    /// - Throws: An `Exception` to abort the update.
    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Self // swiftformat:disable all
    ) async throws(Exception) -> WriteAction<Self> // swiftformat:enable all

    /// Called after a successful database write to perform
    /// any post-update side effects.
    ///
    /// The default implementation returns `updated`
    /// unchanged.
    ///
    /// - Parameters:
    ///   - updated: The locally modified instance produced
    ///     by ``modifyKey(_:withValue:)``, or the instance
    ///     returned by ``WriteAction/handled(_:)``.
    ///   - key: The serialization key that was updated.
    ///
    /// - Returns: The final updated instance.
    ///
    /// - Throws: An `Exception` if post-update processing
    ///   fails.
    func didWrite(
        _ updated: Self,
        forKey key: SerializableKey // swiftformat:disable all
    ) async throws(Exception) -> Self // swiftformat:enable all
}

public extension RemotelyUpdatable {
    // MARK: - Properties

    var networkPathPrependsCurrentEnvironment: Bool { true }

    // MARK: - Methods

    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Self // swiftformat:disable all
    ) async throws(Exception) -> WriteAction<Self> { // swiftformat:enable all
        .proceed
    }

    func didWrite(
        _ updated: Self,
        forKey key: SerializableKey // swiftformat:disable all
    ) async throws(Exception) -> Self { // swiftformat:enable all
        updated
    }

    func updateValue(
        writing value: Any,
        forKey key: SerializableKey // swiftformat:disable all
    ) async throws(Exception) -> Self { // swiftformat:enable all
        @Dependency(\.networking.database) var database: DatabaseDelegate

        guard exposedKeys.contains(key) else {
            throw .Networking.notRemotelyUpdatable(
                key: key,
                .init(sender: self)
            )
        }

        guard let newValue = modifyKey(
            key,
            withValue: value
        ) else {
            throw .Networking.typeMismatch(
                key: key,
                type: type(of: value),
                .init(sender: self)
            )
        }

        let valueKeyPath = [
            networkPath.rawValue,
            identifier,
            key.rawValue,
        ].joined(separator: "/")

        switch try await willWrite(
            value,
            forKey: key,
            updating: newValue
        ) {
        case let .encoded(value):
            if let exception = await database.setValue(
                value,
                forKey: valueKeyPath,
                prependingEnvironment: networkPathPrependsCurrentEnvironment
            ) {
                throw exception
            }

        case let .handled(updated):
            return try await didWrite(
                updated,
                forKey: key
            )

        case .proceed:
            if let serializable = value as? any Serializable {
                if let exception = await database.setValue(
                    serializable.encoded,
                    forKey: valueKeyPath,
                    prependingEnvironment: networkPathPrependsCurrentEnvironment
                ) {
                    throw exception
                }
            } else if let serializable = value as? [any Serializable] { // swiftformat:disable all
                let encoded = serializable.map { $0.encoded } // swiftformat:enable all
                if let exception = await database.setValue(
                    encoded.isEmpty ? Array.bangQualifiedEmpty : encoded,
                    forKey: valueKeyPath,
                    prependingEnvironment: networkPathPrependsCurrentEnvironment
                ) {
                    throw exception
                }
            } else if database.isEncodable(value) {
                if let exception = await database.setValue(
                    value,
                    forKey: valueKeyPath,
                    prependingEnvironment: networkPathPrependsCurrentEnvironment
                ) {
                    throw exception
                }
            } else {
                throw .Networking.notSerialized(
                    data: [key.rawValue: value],
                    .init(sender: self)
                )
            }
        }

        return try await didWrite(
            newValue,
            forKey: key
        )
    }
}

public extension RemotelyUpdatable where Representation == [String: Any] {
    func updateValues(
        with data: [SerializableKey: Any] // swiftformat:disable all
    ) async throws(Exception) -> Self { // swiftformat:enable all
        @Dependency(\.networking.database) var database: DatabaseDelegate

        var updated = self
        for keyPair in data {
            guard exposedKeys.contains(keyPair.key) else {
                throw .Networking.notRemotelyUpdatable(
                    key: keyPair.key,
                    .init(sender: self)
                )
            }

            guard let modified = updated.modifyKey(
                keyPair.key,
                withValue: keyPair.value
            ) else {
                throw .Networking.typeMismatch(
                    key: keyPair.key,
                    type: type(of: keyPair.value),
                    .init(sender: self)
                )
            }

            updated = modified
        }

        let parentKeyPath = [
            networkPath.rawValue,
            identifier,
        ].joined(separator: "/")

        let changedKeys = Set(data.keys.map(\.rawValue))
        if let exception = await database.updateChildValues(
            forKey: parentKeyPath,
            with: updated.encoded.filter { changedKeys.contains($0.key) },
            prependingEnvironment: networkPathPrependsCurrentEnvironment
        ) {
            throw exception
        }

        return updated
    }
}
