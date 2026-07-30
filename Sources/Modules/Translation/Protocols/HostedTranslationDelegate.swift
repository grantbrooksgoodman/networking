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
/// let translation = try await translator.translate(
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
    /// - Returns: The archived translation.
    ///
    /// - Throws: An ``Exception`` if the translation
    ///   cannot be found.
    func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async throws(Exception) -> Translation

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
    /// - Returns: An array of translations corresponding
    ///   to the inputs.
    ///
    /// - Throws: An ``Exception`` if the translation
    ///   fails.
    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async throws(Exception) -> [Translation]

    /// Returns the database fan-out entry for archiving
    /// the specified translation, without writing it.
    ///
    /// Use this method with the
    /// ``ArchiveStrategy/deferred`` archive strategy to
    /// merge a translation's hosted-archive write into
    /// your own atomic ``DatabaseDelegate/commit(_:)``
    /// payload:
    ///
    /// ```swift
    /// let translation = try await translator.translate(
    ///     .init("Hello"),
    ///     with: languagePair,
    ///     archive: .deferred
    /// )
    ///
    /// if let entry = translator.hostedArchiveEntry(
    ///     for: translation
    /// ) {
    ///     updates[entry.key] = entry.value
    /// }
    /// ```
    ///
    /// The entry's key is an environment-relative path –
    /// for example, `"translations/en-es/<hash>"` –
    /// matching the convention
    /// ``DatabaseDelegate/commit(_:)`` expects.
    ///
    /// - Parameter translation: The translation to build
    ///   an archive entry for.
    ///
    /// - Returns: The archive entry's path and value, or
    ///   `nil` if the translation's language pair is
    ///   idempotent or the translation is invalid.
    func hostedArchiveEntry(
        for translation: Translation
    ) -> (key: String, value: Any)?

    /// Resolves a set of translatable label strings and
    /// returns their output maps.
    ///
    /// Use this method to translate all strings declared
    /// by a `TranslatedLabelStrings` conformance at once.
    ///
    /// - Parameter strings: The `TranslatedLabelStrings`
    ///   type to resolve.
    ///
    /// - Returns: An array of translation output maps.
    ///
    /// - Throws: An ``Exception`` if the resolution
    ///   fails.
    func resolve(
        _ strings: TranslatedLabelStrings.Type
    ) async throws(Exception) -> [TranslationOutputMap]

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
    ///   - archiveStrategy: The strategy that determines
    ///     when a newly retrieved translation is written
    ///     to the hosted archive.
    ///
    /// - Returns: The translated value.
    ///
    /// - Throws: An ``Exception`` if the translation
    ///   fails.
    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?,
        archive archiveStrategy: ArchiveStrategy
    ) async throws(Exception) -> Translation
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
    /// - Returns: An array of translations corresponding
    ///   to the inputs.
    ///
    /// - Throws: An ``Exception`` if the translation
    ///   fails.
    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil,
        enhance enhancementConfig: EnhancementConfiguration? = nil
    ) async throws(Exception) -> [Translation] {
        try await getTranslations(
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
    /// ``translate(_:with:hud:enhance:archive:)``
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
    ///   - archiveStrategy: The strategy that determines
    ///     when a newly retrieved translation is written
    ///     to the hosted archive. The default is
    ///     ``ArchiveStrategy/immediate``.
    ///
    /// - Returns: The translated value.
    ///
    /// - Throws: An ``Exception`` if the translation
    ///   fails.
    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil,
        enhance enhancementConfig: EnhancementConfiguration? = nil,
        archive archiveStrategy: ArchiveStrategy = .immediate
    ) async throws(Exception) -> Translation {
        try await translate(
            input,
            with: languagePair,
            hud: hudConfig,
            enhance: enhancementConfig,
            archive: archiveStrategy
        )
    }
}
