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

public struct TranslationReference: Codable, Equatable {
    // MARK: - Types

    public enum `Type`: Codable, Equatable {
        /* MARK: Cases */

        case archived(_ hash: String, value: String? = nil)
        case idempotent(_ encodedValue: String)

        /* MARK: Properties */

        public var key: String {
            switch self {
            case let .archived(hash, value: _):
                return hash

            case let .idempotent(encodedValue):
                return encodedValue
            }
        }

        public var value: String? {
            switch self {
            case let .archived(_, value: value):
                return value

            case .idempotent:
                return nil
            }
        }
    }

    // MARK: - Properties

    public let languagePair: LanguagePair
    public let type: `Type`

    // MARK: - Computed Properties

    public var hostingKey: String {
        "\(languagePair.isIdempotent ? "\(TranslationConstants.idempotentPrefix)\(languagePair.from)" : languagePair.string) | \(type.key)"
    }

    // MARK: - Init

    public init(languagePair: LanguagePair, type: Type) {
        self.languagePair = languagePair
        self.type = type
    }

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
