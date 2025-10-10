//
//  TranslationValidator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

public enum TranslationValidator {
    public static func validate(
        inputs: [TranslationInput]? = nil,
        languagePair: LanguagePair? = nil,
        translation: Translation? = nil,
        metadata: [Any]
    ) -> Exception? {
        assert(
            inputs != nil ||
                languagePair != nil ||
                translation != nil,
            "No arguments passed for validation."
        )

        typealias Exceptions = Exception.Networking

        var userInfo: [String: String] {
            var parameters = [String: String]()

            if let inputs {
                parameters["InputValues"] = inputs.map { $0.value }.joined(separator: ", ")
            }

            if let languagePair {
                parameters["LanguagePair"] = languagePair.string
            }

            if let translation {
                parameters["TranslationReferenceHostingKey"] = translation.reference.hostingKey
            }

            return parameters
        }

        if let inputs {
            guard inputs.isWellFormed else {
                return Exceptions.inputsFailValidation(userInfo: userInfo, metadata)
            }
        }

        if let languagePair {
            guard languagePair.isWellFormed else {
                return Exceptions.languagePairFailsValidation(userInfo: userInfo, metadata)
            }
        }

        if let translation {
            guard translation.isWellFormed else {
                return Exceptions.translationFailsValidation(userInfo: userInfo, metadata)
            }
        }

        return nil
    }
}
