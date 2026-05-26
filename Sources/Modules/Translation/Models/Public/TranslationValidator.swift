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

/// A utility for validating translation inputs, language
/// pairs, and translations.
///
/// Use `TranslationValidator` to check that values are
/// well-formed before passing them to the translation
/// service. The method throws when validation fails:
///
/// ```swift
/// try TranslationValidator.validate(
///     inputs: inputs,
///     languagePair: pair,
///     metadata: .init(sender: self)
/// )
/// ```
public enum TranslationValidator {
    /// Validates the specified inputs, language pair,
    /// and translation.
    ///
    /// At least one argument must be non-`nil`. Each
    /// non-`nil` argument is checked for well-formedness
    /// using the ``Validatable`` protocol.
    ///
    /// - Parameters:
    ///   - inputs: The translation inputs to validate.
    ///     The default is `nil`.
    ///   - languagePair: The language pair to validate.
    ///     The default is `nil`.
    ///   - translation: The translation to validate.
    ///     The default is `nil`.
    ///   - metadata: The exception metadata to attach
    ///     if validation fails.
    ///
    /// - Throws: An exception describing the validation
    ///   failure.
    public static func validate(
        inputs: [TranslationInput]? = nil,
        languagePair: LanguagePair? = nil,
        translation: Translation? = nil,
        metadata: ExceptionMetadata
    ) throws(Exception) {
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
                parameters["InputValues"] = inputs.map(\.value).joined(separator: ", ")
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
                throw Exceptions.inputsFailValidation(
                    userInfo: userInfo,
                    metadata
                )
            }
        }

        if let languagePair {
            guard languagePair.isWellFormed else {
                throw Exceptions.languagePairFailsValidation(
                    userInfo: userInfo,
                    metadata
                )
            }
        }

        if let translation {
            guard translation.isWellFormed else {
                throw Exceptions.translationFailsValidation(
                    userInfo: userInfo,
                    metadata
                )
            }
        }
    }
}
