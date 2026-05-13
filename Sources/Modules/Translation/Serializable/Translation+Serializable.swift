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
/// This conformance uses ``TranslationReference`` as its
/// serialized ``Serializable/Representation``. Encoding
/// produces a compact reference, and decoding resolves it
/// back into a `Translation` – either from an inline
/// value, the local archive, or the hosted archive.
extension Translation: Serializable {
    // MARK: - Properties

    /// The serialized representation of this translation.
    public var encoded: TranslationReference { .init(self) }

    // MARK: - Methods

    /// Returns `true` for all translation references,
    /// because validity is determined during decoding
    /// rather than upfront inspection.
    public static func canDecode(from data: TranslationReference) -> Bool { true }

    /// Creates a translation by decoding from the
    /// specified reference.
    ///
    /// The decoding strategy depends on the reference type:
    ///
    /// - **Archived with inline value:** Decoded directly
    ///   without a network request.
    /// - **Archived without inline value:** Resolved from
    ///   the local archive first, falling back to the
    ///   hosted archive if needed.
    /// - **Idempotent:** Decoded directly from the
    ///   Base64-encoded input. No network request is
    ///   required because the input and output languages
    ///   are the same.
    ///
    /// Successfully decoded translations are added to the
    /// local archive for future lookups when their input
    /// and output differ.
    ///
    /// - Parameter data: The translation reference to
    ///   decode.
    ///
    /// - Throws: An `Exception` if decoding fails.
    public init(
        from data: TranslationReference // swiftformat:disable all
    ) async throws(Exception) { // swiftformat:enable all
        @Dependency(\.translationArchiverDelegate) var localTranslationArchiver: TranslationArchiverDelegate

        func addToArchive(_ translation: Translation) {
            guard translation.input.value != translation.output else { return }
            localTranslationArchiver.addValue(translation)
        }

        switch data.type {
        case let .archived(hash, value: value):
            if let value {
                guard let components = value.decodedTranslationComponents else {
                    throw .Networking.decodingFailed(
                        data: data,
                        .init(sender: Self.self)
                    )
                }

                let decoded: Translation = .init(
                    input: .init(components.input),
                    output: components.output,
                    languagePair: data.languagePair
                )

                addToArchive(decoded)
                self = decoded
                return
            }

            if let archivedTranslation = localTranslationArchiver.getValue(
                inputValueEncodedHash: hash,
                languagePair: data.languagePair
            ) {
                self = archivedTranslation
                return
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
                self = translation

            case let .failure(exception):
                throw exception
            }

        case let .idempotent(encodedValue):
            let decoded: Translation = .init(
                input: .init(encodedValue.base64Decoded),
                output: encodedValue.base64Decoded.sanitized,
                languagePair: data.languagePair
            )

            addToArchive(decoded)
            self = decoded
        }
    }
}
