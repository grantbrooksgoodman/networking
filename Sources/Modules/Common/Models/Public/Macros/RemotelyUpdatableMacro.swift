//
//  RemotelyUpdatableMacro.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Generates copy-construction helpers and, optionally,
/// ``RemotelyUpdatable`` boilerplate for the attached type.
///
/// Apply `@RemotelyUpdatable` to a model type to generate a
/// `copying(paramName:)` method for each initializer
/// parameter. Each method returns a new instance with
/// that single property replaced and all others
/// preserved:
///
/// ```swift
/// @RemotelyUpdatable
/// struct Document {
///     @Serialized let content: String
///     let identifier: String
///     @Serialized @Updatable let revision: Int
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
///
/// // Generated:
/// // func copying(content: String) -> Document
/// // func copying(revision: Int) -> Document
/// ```
///
/// When one or more stored properties are also annotated
/// with ``Updatable(nilIf:)``, the macro generates
/// ``RemotelyUpdatable/exposedKeys`` and
/// ``RemotelyUpdatable/modifyKey(_:withValue:)`` as well,
/// eliminating the switch-based boilerplate that
/// ``RemotelyUpdatable`` conformance would otherwise require.
///
/// The macro reads the type's first initializer to
/// determine parameter names, labels, and types. It
/// must be present and non-failable. If the type
/// declares more than one initializer, the macro emits
/// a warning and uses the first.
///
/// - Parameter keyType: The name of the
///   `RawRepresentable<String>` enum used as the
///   conformer's ``RemotelyUpdatable/SerializableKey``
///   type. The generated `exposedKeys` and `modifyKey`
///   signatures reference this type by name. Defaults
///   to `"SerializableKey"`.
@attached(
    extension,
    names: named(copying),
    named(exposedKeys),
    named(modifyKey)
)
public macro RemotelyUpdatable(
    keyType: String = "SerializableKey"
) = #externalMacro(
    module: "NetworkingMacros",
    type: "RemotelyUpdatableMacro"
)

/// A condition that controls when the generated
/// ``RemotelyUpdatable/modifyKey(_:withValue:)`` implementation
/// sets a property to `nil` on the local copy.
///
/// When the condition evaluates to `true` for a given
/// value, the generated code passes `nil` to the
/// corresponding `copying(propertyName:)` method. This
/// affects only the in-memory copy returned by
/// `modifyKey`; it does not change what is written to
/// the server. The ``RemotelyUpdatable`` protocol's default
/// ``RemotelyUpdatable/updateValue(writing:forKey:)``
/// implementation encodes and writes the original value
/// you provide – the nil condition only governs how the
/// local model is reconstructed.
///
/// Use a predefined case for common collection checks,
/// or ``custom(_:)`` for arbitrary expressions:
///
/// ```swift
/// @Updatable(nilIf: .isBangQualifiedEmpty)
/// let blockedUserIDs: [String]?
///
/// @Updatable(nilIf: .custom("$0 == .init(timeIntervalSince1970: 0)"))
/// let lastSignedIn: Date?
/// ```
///
/// - Important: The ``custom(_:)`` case requires a
///   *string literal*. The macro reads the expression
///   from source at compile time, so passing a variable
///   or computed property reference will not work.
public enum NilCondition {
    /// Evaluates an arbitrary condition expressed as a
    /// string literal. Use `$0` to refer to the incoming
    /// value.
    ///
    /// The macro inserts the string verbatim into the
    /// generated code, so the expression must be valid
    /// Swift that returns `Bool`:
    ///
    /// ```swift
    /// @Updatable(nilIf: .custom("$0 == .init(timeIntervalSince1970: 0)"))
    /// let lastSignedIn: Date?
    /// ```
    ///
    /// - Warning: You must pass a string *literal*. The
    ///   macro cannot resolve references to variables or
    ///   computed properties.
    case custom(String)

    /// Sets the property to `nil` when the value
    /// satisfies `isBangQualifiedEmpty`.
    ///
    /// Use this condition for `[String]?` properties
    /// whose server representation uses the
    /// bang-qualified empty convention (`["!"]`).
    /// When the incoming array is empty or contains only
    /// bang-qualified empty strings, the local copy
    /// stores `nil` instead.
    case isBangQualifiedEmpty

    /// Sets the property to `nil` when the value is
    /// empty.
    ///
    /// Use this condition for optional collection
    /// properties that should be represented as `nil`
    /// locally when they contain no elements.
    case isEmpty
}

/// Marks a stored property as a remotely updatable
/// serialization key.
///
/// This macro generates no code on its own. It serves as
/// a marker that ``RemotelyUpdatable()`` reads when generating
/// ``RemotelyUpdatable/exposedKeys`` and
/// ``RemotelyUpdatable/modifyKey(_:withValue:)``.
///
/// Properties annotated with `@Updatable` must
/// correspond to a case on the conformer's
/// ``RemotelyUpdatable/SerializableKey`` type with a matching
/// name.
///
/// - Parameter nilIf: An optional ``NilCondition``
///   that controls when the generated
///   ``RemotelyUpdatable/modifyKey(_:withValue:)`` sets this
///   property to `nil` on the local copy. This does not
///   affect the value written to the server.
@attached(peer)
public macro Updatable(
    nilIf: NilCondition? = nil
) = #externalMacro(
    module: "NetworkingMacros",
    type: "UpdatableMacro"
)
