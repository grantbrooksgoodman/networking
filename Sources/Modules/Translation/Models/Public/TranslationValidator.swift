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
/// service. The method returns `nil` when all provided
/// arguments pass validation:
///
/// ```swift
/// if let exception = TranslationValidator.validate(
///     inputs: inputs,
///     languagePair: pair,
///     metadata: .init(sender: self)
/// ) {
///     // Handle invalid input.
/// }
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
    /// - Returns: An exception describing the validation
    ///   failure, or `nil` if all arguments are valid.
    public static func validate(
        inputs: [TranslationInput]? = nil,
        languagePair: LanguagePair? = nil,
        translation: Translation? = nil,
        metadata: ExceptionMetadata
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
