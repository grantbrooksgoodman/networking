//
//  Assign.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that pairs a key path with a new value for
/// use in a builder-based update.
///
/// Use `Assign` inside the closure passed to
/// ``RemotelyUpdatable/update(_:)`` to express one or
/// more property changes with compile-time type safety:
///
/// ```swift
/// let updated = try await user.update {
///     Assign(\.isSignedIn, to: true)
///     Assign(\.languageCode, to: "es")
/// }
/// ```
///
/// The compiler infers `Value` from the key path and
/// rejects type mismatches at build time. The following
/// example does not compile because `Int` is not
/// `String`:
///
/// ```swift
/// Assign(\.languageCode, to: 42) // Compile-time error
/// ```
public struct Assign<Root> {
    // MARK: - Properties

    let keyPath: PartialKeyPath<Root>
    let value: Any

    // MARK: - Init

    /// Creates an assignment that pairs the given key path
    /// with a new value.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the property to update.
    ///   - value: The new value for the property.
    public init<Value>(
        _ keyPath: KeyPath<Root, Value>,
        to value: Value
    ) {
        self.keyPath = keyPath
        self.value = value
    }
}

// MARK: - AssignBuilder

/// A result builder that collects ``Assign`` values
/// into an array.
///
/// You don't use this builder directly. Instead, the
/// ``RemotelyUpdatable/update(_:)`` method applies it
/// to its closure parameter so that you can list
/// assignments using a declarative syntax.
///
/// The builder supports conditional assignments using
/// standard `if` and `if`/`else` control flow:
///
/// ```swift
/// let updated = try await user.update {
///     Assign(\.languageCode, to: "es")
///     if shouldEnableTranslations {
///         Assign(\.translationsEnabled, to: true)
///     }
/// }
/// ```
@resultBuilder
public enum AssignBuilder<Root> {
    public static func buildBlock(
        _ components: [Assign<Root>]...
    ) -> [Assign<Root>] {
        components.flatMap { $0 }
    }

    public static func buildEither(
        first component: [Assign<Root>]
    ) -> [Assign<Root>] {
        component
    }

    public static func buildEither(
        second component: [Assign<Root>]
    ) -> [Assign<Root>] {
        component
    }

    public static func buildExpression(
        _ expression: Assign<Root>
    ) -> [Assign<Root>] {
        [expression]
    }

    public static func buildOptional(
        _ component: [Assign<Root>]?
    ) -> [Assign<Root>] {
        component ?? []
    }
}
