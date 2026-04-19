//
//  TranslationReference.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Translator

/// A codable reference to a hosted translation.
///
/// A `TranslationReference` encodes a translation into a
/// compact, serializable form suitable for database
/// storage. References are either
/// ``Type-swift.enum/archived(_:value:)`` for translations
/// between different languages, or
/// ``Type-swift.enum/idempotent(_:)`` for same-language
/// translations.
///
/// Create a reference from an existing translation using
/// the ``Translation/reference`` property:
///
/// ```swift
/// let reference = translation.reference
/// let decodeResult = await Translation.decode(
///     from: reference
/// )
/// ```
public struct TranslationReference: Codable, Equatable, Sendable {
    // MARK: - Types

    /// The kind of translation reference.
    ///
    /// References are categorized by how the translation
    /// is stored and resolved:
    ///
    /// - ``archived(_:value:)``: A hash-based reference
    ///   to a translated value in the hosted archive.
    /// - ``idempotent(_:)``: A Base64-encoded reference
    ///   for translations where the input and output
    ///   languages are the same.
    public enum `Type`: Codable, Equatable, Sendable {
        /* MARK: Cases */

        /// A reference to an archived translation,
        /// identified by its hash.
        ///
        /// When `value` is provided, the translation can
        /// be decoded directly without a network lookup.
        case archived(_ hash: String, value: String? = nil)

        /// A reference to a same-language translation,
        /// identified by its Base64-encoded input.
        case idempotent(_ encodedValue: String)

        /* MARK: Properties */

        /// The identifying key for this reference.
        public var key: String {
            switch self {
            case let .archived(hash, value: _):
                hash

            case let .idempotent(encodedValue):
                encodedValue
            }
        }

        /// The inline encoded value, if available.
        ///
        /// Only ``archived(_:value:)`` references may
        /// contain an inline value. Idempotent references
        /// always return `nil`.
        public var value: String? {
            switch self {
            case let .archived(_, value: value):
                value

            case .idempotent:
                nil
            }
        }
    }

    // MARK: - Properties

    /// The language pair for this translation reference.
    public let languagePair: LanguagePair

    /// The type of reference, indicating how the
    /// translation is stored.
    public let type: `Type`

    // MARK: - Computed Properties

    /// The key used to store and retrieve this
    /// translation in the hosted archive.
    public var hostingKey: String {
        "\(languagePair.isIdempotent ? "\(TranslationConstants.idempotentPrefix)\(languagePair.from)" : languagePair.string) | \(type.key)"
    }

    // MARK: - Init

    /// Creates a translation reference with the specified
    /// language pair and type.
    ///
    /// - Parameters:
    ///   - languagePair: The language pair for the
    ///     translation.
    ///   - type: The kind of reference.
    public init(languagePair: LanguagePair, type: Type) {
        self.languagePair = languagePair
        self.type = type
    }

    /// Creates a translation reference by parsing the
    /// specified string.
    ///
    /// Returns `nil` if the string does not match a valid
    /// reference format.
    ///
    /// - Parameter string: The string to parse.
    public init?(_ string: String) {
        let isIdempotent = string.contains(TranslationConstants.idempotentPrefix)
        let components = string.components(separatedBy: " ")

        guard components.count == (isIdempotent ? 4 : 3),
              let languagePair = LanguagePair(components[isIdempotent ? 1 : 0]),
              let reference = components.last else { return nil }

        self.init(
            languagePair: languagePair,
            type: isIdempotent ? .idempotent(reference) : .archived(reference)
        )
    }

    /// Creates a translation reference from the specified
    /// translation.
    ///
    /// - Parameter translation: The translation to
    ///   reference.
    public init(_ translation: Translation) {
        let input = translation.input.value

        if translation.languagePair.isIdempotent {
            self.init(
                languagePair: translation.languagePair,
                type: .idempotent(input.base64Encoded)
            )
        } else {
            let outputValue = "\(input.alphaEncoded)–\(translation.output.alphaEncoded)"
            self.init(
                languagePair: translation.languagePair,
                type: .archived(input.encodedHash, value: outputValue)
            )
        }
    }
}
