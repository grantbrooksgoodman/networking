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

extension Translation: Serializable {
    // MARK: - Type Aliases

    public typealias T = Translation

    // MARK: - Properties

    public var encoded: TranslationReference { .init(self) }

    // MARK: - Methods

    public static func canDecode(from data: TranslationReference) -> Bool { true }

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
                    return .failure(.Networking.decodingFailed(data: data, [self, #file, #function, #line]))
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
