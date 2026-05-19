//
//  SerializableMacro.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Generates ``Serializable`` conformance for the
/// attached type.
///
/// Apply `@Serializable` to a model type whose
/// serialized properties are annotated with
/// ``Serialized(_:)``. The macro generates a
/// `SerializableKey` enum, an ``Serializable/encoded``
/// dictionary, a ``Serializable/canDecode(from:)``
/// method, and an ``Serializable/init(from:)``
/// initializer:
///
/// ```swift
/// @Serializable
/// struct Document {
///     @Serialized let content: String
///     let identifier: String
///     @Serialized let revision: Int
///
///     init(
///         content: String,
///         revision: Int
///     ) {
///         self.content = content
///         self.revision = revision
///         identifier = UUID().uuidString
///     }
/// }
/// ```
///
/// Properties marked with ``Serialized(_:)`` become
/// serialization keys. Properties without the annotation
/// are excluded from serialization.
///
/// The macro reads the type's first initializer to
/// generate the ``Serializable/init(from:)``
/// initializer. Each ``Serialized(_:)`` property must have a
/// corresponding initializer parameter with the same
/// name. If the type declares more than one initializer,
/// the macro emits a warning and uses the first.
///
/// The generated conformance uses `[String: Any]` as its
/// ``Serializable/Representation``. Properties whose
/// types can be extracted from a dictionary using `as?`
/// – typically `String`, `Int`, `Bool`, `Double`, and
/// arrays or optionals thereof – work automatically.
/// Properties that require custom encoding or decoding
/// can supply `encode` and `decode` transforms through
/// ``Serialized(_:encodedAs:encode:decode:)``. For types
/// that require dependency injection or nested
/// ``Serializable`` decoding, write the conformance
/// manually.
@attached(
    extension,
    conformances: Serializable,
    names: named(canDecode),
    named(encoded),
    named(init),
    named(SerializableKey)
)
public macro Serializable() = #externalMacro(
    module: "NetworkingMacros",
    type: "SerializableMacro"
)

/// Marks a stored property for inclusion in the
/// generated ``Serializable`` conformance.
///
/// When ``Serializable()`` is applied to the enclosing
/// type, each `@Serialized` property produces a case in
/// the generated `SerializableKey` enum and
/// corresponding entries in ``Serializable/encoded``,
/// ``Serializable/canDecode(from:)``, and
/// ``Serializable/init(from:)``.
///
/// By default, the property name is used as the
/// serialization key. Pass a string literal to use a
/// custom key name:
///
/// ```swift
/// @Serialized("fromAccount") let fromAccountID: String
/// ```
///
/// To apply custom encode and decode transforms, use
/// ``Serialized(_:encodedAs:encode:decode:)``.
///
/// - Parameter keyName: An optional custom key name
///   used as the raw value of the generated
///   `SerializableKey` case. When `nil`, the property
///   name is used.
@attached(peer)
public macro Serialized(
    _ keyName: String? = nil
) = #externalMacro(
    module: "NetworkingMacros",
    type: "SerializedMacro"
)

/// Marks a stored property for inclusion in the
/// generated ``Serializable`` conformance, applying
/// custom encode and decode transforms.
///
/// Use this overload when the property's Swift type
/// differs from its serialized representation. The
/// `encodedAs` parameter specifies the type stored in
/// the database, and the `encode` and `decode` closures
/// convert between the two:
///
/// ```swift
/// @Serialized(
///     encodedAs: String.self,
///     encode: { DateFormatter.timestamp($0) },
///     decode: { DateFormatter.date(from: $0) }
/// )
/// let lastSignedIn: Date
/// ```
///
/// You can combine a custom key name with transforms:
///
/// ```swift
/// @Serialized(
///     "signed_in",
///     encodedAs: String.self,
///     encode: { DateFormatter.timestamp($0) },
///     decode: { DateFormatter.date(from: $0) }
/// )
/// let lastSignedIn: Date
/// ```
///
/// If `decode` returns `nil` for a non-optional
/// property, the generated initializer throws. For
/// optional properties, the property is set to `nil`.
///
/// - Parameters:
///   - keyName: An optional custom key name used as the
///     raw value of the generated `SerializableKey` case.
///     When `nil`, the property name is used.
///   - encodedAs: The metatype of the serialized
///     representation (for example, `String.self`).
///   - encode: A closure that converts from the property
///     type to the serialized type.
///   - decode: A closure that converts from the
///     serialized type back to the property type,
///     returning `nil` on failure.
@attached(peer)
public macro Serialized<Value, Encoded>(
    _ keyName: String? = nil,
    encodedAs: Encoded.Type,
    encode: @escaping (Value) -> Encoded,
    decode: @escaping (Encoded) -> Value?
) = #externalMacro(
    module: "NetworkingMacros",
    type: "SerializedMacro"
)
