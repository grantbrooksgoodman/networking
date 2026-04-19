//
//  Translation+Serializable.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

/// The ``Serializable`` conformance for `Translation`.
///
/// This conformance uses ``TranslationReference`` as the
/// serialized representation. Encoding produces a compact
/// reference, and decoding resolves it back into a
/// `Translation` – either from an inline value, the local
/// archive, or the hosted archive.
extension Translation: Serializable {
    // MARK: - Type Aliases

    /// The decoded type.
    public typealias T = Translation

    // MARK: - Properties

    /// The serialized representation of this translation.
    public var encoded: TranslationReference { .init(self) }

    // MARK: - Methods

    /// Returns `true` for all translation references.
    public static func canDecode(from data: TranslationReference) -> Bool { true }

    /// Decodes a translation from the specified
    /// reference.
    ///
    /// The decoding strategy depends on the reference
    /// type:
    ///
    /// - **Archived with inline value**: Decoded directly
    ///   without a network request.
    /// - **Archived without value**: Resolved from the
    ///   local archive first, then from the hosted
    ///   archive if needed.
    /// - **Idempotent**: Decoded directly from the
    ///   Base64-encoded input.
    ///
    /// - Parameter data: The translation reference to
    ///   decode.
    ///
    /// - Returns: On success, the decoded translation.
    public static func decode(from data: TranslationReference) async -> Callback<Translation, Exception> {
        @Dependency(\.translationArchiverDelegate) var localTranslationArchiver: TranslationArchiverDelegate

        func addToArchive(_ translation: Translation) {
            guard translation.input.value != translation.output else { return }
            localTranslationArchiver.addValue(translation)
        }

        switch data.type {
        case let .archived(hash, value: value):
            if let value {
                guard let components = value.decodedTranslationComponents else {
                    return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
                }

                let decoded: Translation = .init(
                    input: .init(components.input),
                    output: components.output,
                    languagePair: data.languagePair
                )

                addToArchive(decoded)
                return .success(decoded)
            }

            if let archivedTranslation = localTranslationArchiver.getValue(
                inputValueEncodedHash: hash,
                languagePair: data.languagePair
            ) {
                return .success(archivedTranslation)
            }

            let findArchivedTranslationResult = await Networking
                .config
                .hostedTranslationDelegate
                .findArchivedTranslation(
                    id: hash,
                    languagePair: data.languagePair
                )

            switch findArchivedTranslationResult {
            case let .success(translation):
                addToArchive(translation)
                return .success(translation)

            case let .failure(exception):
                return .failure(exception)
            }

        case let .idempotent(encodedValue):
            let decoded: Translation = .init(
                input: .init(encodedValue.base64Decoded),
                output: encodedValue.base64Decoded.sanitized,
                languagePair: data.languagePair
            )

            addToArchive(decoded)
            return .success(decoded)
        }
    }
}
