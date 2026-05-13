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
/// For types that require custom transforms, dependency
/// injection, or nested ``Serializable`` decoding, write
/// the conformance manually.
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
