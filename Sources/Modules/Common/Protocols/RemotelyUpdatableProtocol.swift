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
/// the server by key path.
///
/// Adopt `RemotelyUpdatable` when a model needs to push
/// property changes to the database without re-encoding
/// the entire record. `RemotelyUpdatable` refines
/// ``Serializable``, so conforming types must also
/// provide encoding and decoding.
///
/// Update a single property using ``update(_:to:)``:
///
/// ```swift
/// let updated = try await user.update(
///     \.languageCode,
///     to: "es"
/// )
/// ```
///
/// The compiler enforces that the value matches the
/// property's type, so type mismatches are caught at
/// build time rather than at runtime. Types that use
/// the `@RemotelyUpdatable` and `@Updatable` macros
/// receive the key-path mapping automatically.
///
/// When multiple properties need to change together,
/// pass an ``AssignBuilder`` closure to
/// ``update(_:)`` to apply them in a single atomic
/// write:
///
/// ```swift
/// let updated = try await user.update {
///     Assign(\.isSignedIn, to: true)
///     Assign(\.languageCode, to: "es")
/// }
/// ```
///
/// Each conformer provides a ``networkPath`` and
/// ``identifier`` so the default implementation can
/// construct the database key path automatically (for
/// example, `"users/<identifier>/languageCode"`).
///
/// ## Write Lifecycle
///
/// The default ``update(_:to:)`` implementation
/// performs four steps:
///
/// 1. **Local modification** – calls
///    ``modifyKey(_:withValue:)`` to produce an
///    in-memory copy with the property changed.
/// 2. **Pre-write hook** – calls
///    ``willWrite(_:forKey:updating:)`` to allow custom
///    encoding or early handling.
/// 3. **Encoding and writing** – encodes the value
///    using an encoding ladder (``Serializable``, array
///    of ``Serializable``, or raw Foundation type) and
///    writes it to the database.
/// 4. **Post-write hook** – calls
///    ``didWrite(_:forKey:)`` to perform any side
///    effects.
///
/// > Important: The builder-based ``update(_:)`` does
/// > not invoke the lifecycle hooks. Only the
/// > single-property ``update(_:to:)`` method calls
/// > ``willWrite(_:forKey:updating:)`` and
/// > ``didWrite(_:forKey:)``.
///
/// Conformers can customize the single-property write
/// by overriding two hooks:
///
/// - ``willWrite(_:forKey:updating:)`` – Return a
///   ``WriteAction`` to override encoding, handle the
///   write entirely, or abort by throwing.
/// - ``didWrite(_:forKey:)`` – Perform side effects
///   after a successful write, such as clearing a
///   cache.
public protocol RemotelyUpdatable: Serializable {
    // MARK: - Associated Types

    /// The type used to identify individual serialization
    /// keys.
    ///
    /// Typically an enum whose raw values match the
    /// database field names for the conforming type.
    associatedtype SerializableKey: Hashable & RawRepresentable where SerializableKey.RawValue == String

    // MARK: - Properties

    /// The identifier used in database key path
    /// construction.
    ///
    /// Combined with ``networkPath`` and the key's raw
    /// value to form the full path for a write – for
    /// example, `"users/<identifier>/<key>"`.
    var identifier: String { get }

    /// The base network path for records of this type.
    ///
    /// This value forms the first segment of the database
    /// key path. For a type whose records are stored under
    /// `"documents"`, the property returns
    /// `NetworkPath("documents")`, and a write to the
    /// `revision` key produces the path
    /// `"documents/<identifier>/revision"`.
    ///
    /// The default implementation derives the path by
    /// lowercasing the type name and appending `"s"` – for
    /// example, `User` produces `NetworkPath("users")`.
    /// Override this property when the backend path does
    /// not follow that convention.
    var networkPath: NetworkPath { get }

    /// Whether `database.setValue` prepends the current
    /// environment to the key path.
    ///
    /// The default value is `true`.
    var networkPathPrependsCurrentEnvironment: Bool { get }

    // MARK: - Methods

    /// Returns the serialization key corresponding to the
    /// given key path, or `nil` if the key path does not
    /// map to an updatable property.
    ///
    /// The default implementation returns `nil`. Types
    /// annotated with `@RemotelyUpdatable` and `@Updatable`
    /// receive a generated implementation that maps each
    /// updatable property's key path to its
    /// ``SerializableKey`` case.
    ///
    /// Manual conformers can override this method to
    /// enable the type-safe ``update(_:to:)`` API.
    ///
    /// - Parameter keyPath: A key path rooted in the
    ///   conforming type.
    ///
    /// - Returns: The corresponding serialization key, or
    ///   `nil` if the key path is not updatable.
    static func serializableKey(
        for keyPath: PartialKeyPath<Self>
    ) -> SerializableKey?

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
    /// - Returns: The action the default ``update(_:to:)``
    ///   implementation should take.
    ///
    /// - Throws: An `Exception` to abort the update.
    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Self
    ) async throws(Exception) -> WriteAction<Self>

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
        forKey key: SerializableKey
    ) async throws(Exception) -> Self
}

public extension RemotelyUpdatable {
    // MARK: - Properties

    var networkPath: NetworkPath {
        NetworkPath(
            String(describing: Self.self)
                .lowercased() + "s"
        )
    }

    var networkPathPrependsCurrentEnvironment: Bool {
        true
    }

    // MARK: - Methods

    static func serializableKey(
        for keyPath: PartialKeyPath<Self>
    ) -> SerializableKey? {
        nil
    }

    /// Writes the value for the property at the given key
    /// path to the server and returns the updated instance.
    ///
    /// The compiler ensures that `value` matches the
    /// property's type at compile time, so type mismatches
    /// are caught during compilation rather than at
    /// runtime.
    ///
    /// ```swift
    /// let updated = try await document.update(
    ///     \.revision,
    ///     to: 2
    /// )
    /// ```
    ///
    /// The method resolves the key path to its
    /// ``SerializableKey`` via ``serializableKey(for:)``
    /// and then performs the four-step write lifecycle
    /// described in the protocol overview.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the property to update.
    ///   - value: The new value for the property.
    ///
    /// - Returns: The updated instance.
    ///
    /// - Throws: An `Exception` if the key path does not
    ///   correspond to an updatable property, or if the
    ///   underlying write fails.
    func update<Value>(
        _ keyPath: KeyPath<Self, Value>,
        to value: Value
    ) async throws(Exception) -> Self {
        guard let key = Self.serializableKey(for: keyPath) else {
            throw .Networking.notRemotelyUpdatable(
                key: keyPath,
                .init(sender: self)
            )
        }

        return try await updateValue(
            writing: value,
            forKey: key
        )
    }

    func willWrite(
        _ value: Any,
        forKey key: SerializableKey,
        updating updated: Self
    ) async throws(Exception) -> WriteAction<Self> {
        .proceed
    }

    func didWrite(
        _ updated: Self,
        forKey key: SerializableKey
    ) async throws(Exception) -> Self {
        updated
    }
}

extension RemotelyUpdatable where Representation == [String: Any] {
    /// Writes multiple properties to the server in a
    /// single atomic operation and returns the updated
    /// instance.
    ///
    /// Use this method when two or more properties need
    /// to change together. Each ``Assign`` value pairs a
    /// key path with a new value, and the compiler
    /// enforces that every value matches its property's
    /// type at build time:
    ///
    /// ```swift
    /// let updated = try await user.update {
    ///     Assign(\.isSignedIn, to: true)
    ///     Assign(\.languageCode, to: "es")
    /// }
    /// ```
    ///
    /// All changed fields are written in a single
    /// `updateChildValues` call. This method does not
    /// invoke the ``willWrite(_:forKey:updating:)`` or
    /// ``didWrite(_:forKey:)`` lifecycle hooks.
    ///
    /// - Parameter build: A closure that returns one or
    ///   more ``Assign`` values.
    ///
    /// - Returns: The updated instance.
    ///
    /// - Throws: An `Exception` if a key path does not
    ///   correspond to an updatable property, if a
    ///   value's type does not match the property, or
    ///   if the database write fails.
    public func update(
        @AssignBuilder<Self> _ build: sending () -> [Assign<Self>]
    ) async throws(Exception) -> Self {
        var data: [PartialKeyPath<Self>: Any] = [:]
        for assignment in build() {
            data[assignment.keyPath] = assignment.value
        }
        return try await updateValues(with: data)
    }

    func updateValues(
        with data: [PartialKeyPath<Self>: Any]
    ) async throws(Exception) -> Self {
        @Dependency(\.networking.database) var database: DatabaseDelegate

        var updated = self
        var changedKeys = Set<String>()

        for (keyPath, value) in data {
            guard let key = Self.serializableKey(for: keyPath) else {
                throw .Networking.notRemotelyUpdatable(
                    key: keyPath,
                    .init(sender: self)
                )
            }

            guard let modified = updated.modifyKey(
                key,
                withValue: value
            ) else {
                throw .Networking.typeMismatch(
                    key: key,
                    type: type(of: value),
                    .init(sender: self)
                )
            }

            updated = modified
            changedKeys.insert(key.rawValue)
        }

        let parentKeyPath = [
            networkPath.rawValue,
            identifier,
        ].joined(separator: "/")

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

extension RemotelyUpdatable {
    func updateValue(
        writing value: Any,
        forKey key: SerializableKey
    ) async throws(Exception) -> Self {
        @Dependency(\.networking.database) var database: DatabaseDelegate

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
            } else if let serializable = value as? [any Serializable] {
                // swiftformat:disable all
                let encoded = serializable.map { $0.encoded }
                // swiftformat:enable all
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
