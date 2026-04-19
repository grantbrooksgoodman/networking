//
//  HostedTranslationDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Translator

/// An interface for translating strings through the
/// hosted translation service.
///
/// Use `HostedTranslationDelegate` to translate strings
/// between languages, with optional AI enhancement and
/// HUD presentation:
///
/// ```swift
/// @Dependency(\.networking.hostedTranslation) var translator: HostedTranslationDelegate
///
/// let translateResult = await translator.translate(
///     .init("Hello"),
///     with: LanguagePair(from: "en", to: "es")
/// )
/// ```
///
/// Translations are automatically archived for future
/// lookups. Use
/// ``findArchivedTranslation(id:languagePair:)`` to
/// retrieve a previously translated value by its hash.
///
/// A default implementation is provided automatically.
/// To supply a custom conformance, register it with
/// ``Networking/Config/registerHostedTranslationDelegate(_:)``.
// swiftlint:disable:next class_delegate_protocol
public protocol HostedTranslationDelegate: AlertKit.TranslationDelegate, Sendable {
    /// Retrieves a previously archived translation by
    /// its encoded hash.
    ///
    /// - Parameters:
    ///   - inputValueEncodedHash: The encoded hash of the
    ///     translation input value.
    ///   - languagePair: The language pair for the
    ///     translation.
    ///
    /// - Returns: On success, the archived translation.
    func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception>

    /// Translates multiple inputs for the specified
    /// language pair.
    ///
    /// - Parameters:
    ///   - inputs: The translation inputs to translate.
    ///   - languagePair: The language pair for the
    ///     translations.
    ///   - hudConfig: An optional HUD configuration
    ///     specifying how long to wait before showing
    ///     the HUD and whether it is modal.
    ///   - enhancementConfig: An optional configuration
    ///     for AI-enhanced translation.
    ///
    /// - Returns: On success, an array of translations
    ///   corresponding to the inputs.
    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<[Translation], Exception>

    /// Resolves a set of translatable label strings and
    /// returns their output maps.
    ///
    /// Use this method to translate all strings declared
    /// by a `TranslatedLabelStrings` conformance at once.
    ///
    /// - Parameter strings: The `TranslatedLabelStrings`
    ///   type to resolve.
    ///
    /// - Returns: On success, an array of translation
    ///   output maps.
    func resolve(_ strings: TranslatedLabelStrings.Type) async -> Callback<[TranslationOutputMap], Exception>

    /// Translates a single input for the specified
    /// language pair.
    ///
    /// - Parameters:
    ///   - input: The translation input to translate.
    ///   - languagePair: The language pair for the
    ///     translation.
    ///   - hudConfig: An optional HUD configuration
    ///     specifying how long to wait before showing
    ///     the HUD and whether it is modal.
    ///   - enhancementConfig: An optional configuration
    ///     for AI-enhanced translation.
    ///
    /// - Returns: On success, the translated value.
    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<Translation, Exception>
}

public extension HostedTranslationDelegate {
    /// Translates multiple inputs for the specified
    /// language pair.
    ///
    /// This method calls
    /// ``getTranslations(for:languagePair:hud:enhance:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - inputs: The translation inputs to translate.
    ///   - languagePair: The language pair for the
    ///     translations.
    ///   - hudConfig: An optional HUD configuration.
    ///     The default is `nil`.
    ///   - enhancementConfig: An optional configuration
    ///     for AI-enhanced translation. The default is
    ///     `nil`.
    ///
    /// - Returns: On success, an array of translations
    ///   corresponding to the inputs.
    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil,
        enhance enhancementConfig: EnhancementConfiguration? = nil
    ) async -> Callback<[Translation], Exception> {
        await getTranslations(
            for: inputs,
            languagePair: languagePair,
            hud: hudConfig,
            enhance: enhancementConfig
        )
    }

    /// Translates a single input for the specified
    /// language pair.
    ///
    /// This method calls
    /// ``translate(_:with:hud:enhance:)``
    /// with default parameter values.
    ///
    /// - Parameters:
    ///   - input: The translation input to translate.
    ///   - languagePair: The language pair for the
    ///     translation.
    ///   - hudConfig: An optional HUD configuration.
    ///     The default is `nil`.
    ///   - enhancementConfig: An optional configuration
    ///     for AI-enhanced translation. The default is
    ///     `nil`.
    ///
    /// - Returns: On success, the translated value.
    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil,
        enhance enhancementConfig: EnhancementConfiguration? = nil
    ) async -> Callback<Translation, Exception> {
        await translate(
            input,
            with: languagePair,
            hud: hudConfig,
            enhance: enhancementConfig
        )
    }
}
