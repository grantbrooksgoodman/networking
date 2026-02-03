//
//  HostedTranslationService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Translator

final class HostedTranslationService: HostedTranslationDelegate {
    // MARK: - Types

    private enum ArchiveTreatment {
        case addToBothArchives
        case addToHostedArchive
        case addToLocalArchive
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.languageRecognitionService) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate
    @Dependency(\.translationService) private var translator: TranslationService

    // MARK: - Properties

    static let shared = HostedTranslationService()

    @LockIsolated var geminiCataloguedTranslationInputs = Set<String>() {
        didSet {
            @Persistent(.geminiCataloguedTranslationInputs) var persistedArchive: Set<String>?
            persistedArchive = geminiCataloguedTranslationInputs.isEmpty ? nil : geminiCataloguedTranslationInputs
        }
    }

    private let archiver = HostedTranslationArchiver()

    // MARK: - Init

    private init() {}

    // MARK: - Find Archived Translation

    func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        await archiver.findArchivedTranslation(
            id: inputValueEncodedHash,
            languagePair: languagePair
        )
    }

    // MARK: - Label String Resolution

    func resolve(_ strings: TranslatedLabelStrings.Type) async -> Callback<[TranslationOutputMap], Exception> {
        guard LanguagePair.system.isWellFormed,
              !LanguagePair.system.isIdempotent else {
            return .success(strings.defaultOutputMap)
        }

        let shouldEnhanceTranslation = core
            .utils
            .isEnhancedDialogTranslationEnabled && strings.keyPairs.count <= 5

        let getTranslationsResult = await getTranslations(
            for: strings.keyPairs.map(\.input),
            languagePair: .system,
            enhance: shouldEnhanceTranslation ? .init(
                additionalContext: getAdditionalContext(for: nil)
            ) : nil
        )

        switch getTranslationsResult {
        case let .success(translations):
            let outputs = strings.keyPairs.reduce(into: [TranslationOutputMap]()) { partialResult, keyPair in
                if let translation = translations.first(where: {
                    $0.input.value == keyPair.input.value
                }) {
                    partialResult.append(.init(
                        key: keyPair.key,
                        value: translation.output
                    ))
                } else {
                    partialResult.append(keyPair.defaultOutputMap)
                }
            }

            return .success(outputs)

        case let .failure(error):
            return .failure(error)
        }
    }

    // MARK: - Translation

    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<[Translation], Exception> {
        var translations = [Translation]()

        for input in inputs {
            let translateResult = await translate(
                input,
                with: languagePair,
                hud: hudConfig,
                enhance: enhancementConfig
            )

            switch translateResult {
            case let .success(translation): translations.append(translation)
            case let .failure(exception): return .failure(exception)
            }
        }

        guard translations.count == inputs.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: .init(sender: self)
            ))
        }

        return .success(translations)
    }

    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<Translation, Exception> {
        let prevalidateInputResult = await prevalidateInput(
            input,
            languagePair: languagePair
        )

        if let prevalidateInputResult {
            return prevalidateInputResult
        }

        Networking.config.activityIndicatorDelegate.show()
        defer { Networking.config.activityIndicatorDelegate.hide() }

        let checkHostedArchiveResult = await checkHostedArchive(
            for: input,
            languagePair: languagePair,
            enhancementConfig: enhancementConfig
        )

        if let checkHostedArchiveResult {
            return checkHostedArchiveResult
        }

        let sourceLanguageName = languagePair.from.englishLanguageName ?? languagePair.from.uppercased()
        let targetLanguageName = languagePair.to.englishLanguageName ?? languagePair.to.uppercased()

        Logger.log(
            .init(
                "Translating text from \(sourceLanguageName) to \(targetLanguageName).",
                isReportable: false,
                userInfo: [
                    "InputValue": input.value,
                    "LanguagePair": languagePair.string,
                ],
                metadata: .init(sender: self)
            ),
            domain: .Networking.hostedTranslation
        )

        let translateResult = await translator.translate(
            .init(
                input.value.trimmingTrailingWhitespace,
                alternate: input.alternate?.trimmingTrailingWhitespace
            ),
            languagePair: languagePair,
            hud: hudConfig,
            timeout: (.seconds(10), false)
        )

        switch translateResult {
        case let .success(translation):
            return await postProcess(
                translation,
                enhancementConfig: enhancementConfig,
                archiveTreatment: .addToBothArchives
            )

        case let .failure(exception):
            guard exception.isEqual(toAny: [
                .Networking.Translation.exhaustedAvailablePlatforms,
                .Networking.Translation.sameTranslationInputOutput,
            ]) else {
                return .failure(exception)
            }

            return await postProcess(
                .init(
                    input: input,
                    output: input.value.sanitized,
                    languagePair: languagePair
                ),
                enhancementConfig: enhancementConfig,
                archiveTreatment: .addToBothArchives
            )
        }
    }

    // MARK: - Auxiliary

    private func checkHostedArchive(
        for input: TranslationInput,
        languagePair: LanguagePair,
        enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<Translation, Exception>? {
        let findArchivedTranslationResult = await archiver.findArchivedTranslation(
            input: input,
            languagePair: languagePair
        )

        switch findArchivedTranslationResult {
        case let .success(translation):
            if TranslationValidator.validate(
                translation: translation,
                metadata: .init(sender: self)
            ) != nil || translation.input.value == translation.output {
                if let exception = await archiver.removeArchivedTranslation(
                    for: input,
                    languagePair: languagePair
                ) {
                    return .failure(exception)
                }

                return nil
            }

            return await postProcess(
                translation,
                enhancementConfig: nil,
                archiveTreatment: .addToLocalArchive
            )

        case let .failure(exception):
            guard exception.isEqual(toAny: [
                .Networking.Database.noValueExists,
                .Networking.Translation.translationDerivationFailed,
            ]) else {
                return .failure(exception)
            }

            return nil
        }
    }

    private func postProcess(
        _ translation: Translation,
        enhancementConfig: EnhancementConfiguration?,
        archiveTreatment: ArchiveTreatment?
    ) async -> Callback<Translation, Exception> {
        var translation = translation

        if let enhancementConfig,
           archiveTreatment != nil,
           core.utils.isEnhancedDialogTranslationEnabled,
           !geminiCataloguedTranslationInputs.contains(translation.input.value),
           Networking.config.geminiAPIKeyDelegate?.apiKey.isBlank == false,
           translation.isEligibleForAIEnhancement {
            let enhanceResult = await GeminiService.shared.enhance(
                translation,
                using: enhancementConfig
            )

            geminiCataloguedTranslationInputs.insert(
                translation.input.value
            )

            if let enhanceResult {
                switch enhanceResult {
                case let .success(enhancedTranslation):
                    Logger.log(.init(
                        "Successfully AI-enhanced translation.",
                        isReportable: false,
                        userInfo: [
                            "OriginalOutput": translation.output,
                            "EnhancedOutput": enhancedTranslation.output,
                        ],
                        metadata: .init(sender: self)
                    ), domain: .Networking.hostedTranslation)

                    if build.milestone != .generalRelease,
                       core.utils.enhancedTranslationStatusVerbosity == .successAndErrors ||
                       core.utils.enhancedTranslationStatusVerbosity == .successOnly {
                        Toast.show(.init(
                            .banner(style: .success),
                            title: "Successfully AI-enhanced translation.",
                            message: "Changed \"\(translation.output)\" to \"\(enhancedTranslation.output.sanitized)\"."
                        ))
                    }

                    translation = enhancedTranslation

                case let .failure(exception):
                    Logger.log(
                        exception,
                        domain: .Networking.hostedTranslation
                    )

                    if build.milestone != .generalRelease,
                       core.utils.enhancedTranslationStatusVerbosity == .errorsOnly ||
                       core.utils.enhancedTranslationStatusVerbosity == .successAndErrors {
                        Toast.show(.init(
                            .capsule(style: .warning),
                            message: exception.userFacingDescriptor,
                            perpetuation: .ephemeral(.seconds(3))
                        ))
                    }
                }
            }
        }

        if let exception = TranslationValidator.validate(
            translation: translation,
            metadata: .init(sender: self)
        ) {
            return .failure(exception)
        }

        if archiveTreatment == .addToBothArchives ||
            archiveTreatment == .addToHostedArchive,
            let exception = await archiver.addToHostedArchive(translation) {
            return .failure(exception)
        }

        guard translation.input.value != translation.output,
              archiveTreatment == .addToBothArchives ||
              archiveTreatment == .addToLocalArchive else { return .success(translation) }

        localTranslationArchiver.addValue(translation)
        return .success(translation)
    }

    private func prevalidateInput(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception>? {
        if let exception = TranslationValidator.validate(
            inputs: [input],
            languagePair: languagePair,
            metadata: .init(sender: self)
        ) {
            return .failure(exception)
        }

        // If language pair is idempotent, return original input.

        if languagePair.isIdempotent {
            let translation: Translation = .init(
                input: input,
                output: input.value.sanitized,
                languagePair: languagePair
            )

            return await postProcess(
                translation,
                enhancementConfig: nil,
                archiveTreatment: nil
            )
        }

        // Attempt to find a suitable locally archived translation.

        if let archivedTranslation = localTranslationArchiver.getValue(
            inputValueEncodedHash: input.value.encodedHash,
            languagePair: languagePair
        ) {
            if TranslationValidator.validate(
                translation: archivedTranslation,
                metadata: .init(sender: self)
            ) != nil || archivedTranslation.input.value == archivedTranslation.output {
                localTranslationArchiver.removeValue(
                    inputValueEncodedHash: input.value.encodedHash,
                    languagePair: languagePair
                )
                return nil
            }

            return await postProcess(
                archivedTranslation,
                enhancementConfig: nil,
                archiveTreatment: nil
            )
        }

        // If no letters or input is already in target language, return original input.

        let hasUnicodeLetters = input.value.containsLetters
        let sameInputOutputLanguage = await languageRecognitionService.matchConfidence(
            for: input.value,
            inLanguage: languagePair.to
        ) > 0.8

        if !hasUnicodeLetters || sameInputOutputLanguage {
            return await postProcess(
                Translation(
                    input: input,
                    output: input.value.sanitized,
                    languagePair: languagePair
                ),
                enhancementConfig: nil,
                archiveTreatment: .addToBothArchives
            )
        }

        return nil
    }
}

extension HostedTranslationService: AlertKit.TranslationDelegate {
    func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: AlertKit.HUDConfig?,
        timeout timeoutConfig: AlertKit.TranslationTimeoutConfig
    ) async -> Result<[Translation], TranslationError> {
        await withCheckedContinuation { continuation in
            getTranslations(
                inputs,
                languagePair: languagePair,
                hud: hudConfig,
                timeout: timeoutConfig
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func getAdditionalContext(
        for translations: [Translation]?
    ) -> String {
        var concatenatedOutputs: String? {
            translations?.reduce(into: [String]()) { partialResult, translation in
                partialResult.append("'\(translation.output)'")
            }.joined(separator: "\n").sanitized
        }

        let dynamicContextSuffix = [
            build.finalName,
            build.codeName,
        ].first { !$0.isBlank }.map { " for an app called \($0)." } ?? "."

        var additionalContext = """
        You are translating text as part of standard, user-facing system dialogs\(dynamicContextSuffix)
        Be sure to use an appropriate, respectful, and neutral tone.
        Ensure consistency in pronoun usage and grammatical correctness. 
        Use infinitive forms for user actions where it makes sense (e.g., use 'Cerrar' in place of 'Cierra' for Spanish).
        """

        if let concatenatedOutputs,
           !concatenatedOutputs.isBlank {
            additionalContext += "\nHere is what else has been translated in this batch so far – separated by newlines – for additional context:\n"
            additionalContext += concatenatedOutputs
        }

        return additionalContext
    }

    private func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: AlertKit.HUDConfig?,
        timeout timeoutConfig: AlertKit.TranslationTimeoutConfig,
        completion: @escaping (Result<[Translation], TranslationError>) -> Void
    ) {
        var didComplete = false

        if let hudConfig {
            core.gcd.after(hudConfig.appearsAfter) {
                guard !didComplete else { return }
                self.core.hud.showProgress(isModal: hudConfig.isModal)
            }
        }

        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            guard hudConfig != nil else { return true }
            core.hud.hide()
            return true
        }

        var exceptions = [Exception]()
        var translations = [Translation]()

        func handleExceptionAndComplete() {
            let exception = exceptions.compiledException ?? .init(metadata: .init(sender: self))
            guard timeoutConfig.returnsInputsOnFailure else {
                return completion(.failure(
                    .unknown(exception.descriptor)
                ))
            }

            Logger.log(
                exception,
                domain: .Networking.hostedTranslation
            )

            return completion(.success(translations))
        }

        func handleTimeout() {
            guard canComplete else { return }
            translations.append(contentsOf: inputs
                .filter { !translations.map(\.input).contains($0) }
                .map {
                    Translation(
                        input: $0,
                        output: $0.original.sanitized,
                        languagePair: languagePair
                    )
                }
            )

            guard exceptions.isEmpty else { return handleExceptionAndComplete() }
            guard translations.count == inputs.count else {
                return completion(.failure(
                    .unknown("Mismatched ratio returned.")
                ))
            }

            guard timeoutConfig.returnsInputsOnFailure else {
                return completion(.failure(.timedOut))
            }

            Logger.log(
                .timedOut(metadata: .init(sender: self)),
                domain: .Networking.hostedTranslation
            )

            completion(.success(translations))
        }

        var timeout = Timeout(after: timeoutConfig.duration) { handleTimeout() }

        Task {
            for input in inputs {
                // Purposefully ignoring HUD config argument so it can be handled here.
                let translateResult = await translate(
                    input,
                    with: languagePair,
                    enhance: core.utils.isEnhancedDialogTranslationEnabled ? .init(
                        additionalContext: getAdditionalContext(for: translations)
                    ) : nil
                )

                timeout.cancel()
                timeout = Timeout(after: timeoutConfig.duration) { handleTimeout() }

                switch translateResult {
                case let .success(translation): translations.append(translation)
                case let .failure(exception): exceptions.append(exception)
                }
            }

            guard canComplete else { return }
            guard exceptions.isEmpty else { return handleExceptionAndComplete() }
            guard translations.count == inputs.count else {
                return completion(.failure(
                    .unknown("Mismatched ratio returned.")
                ))
            }

            completion(.success(translations))
        }
    }
}

private extension Translation {
    var isEligibleForAIEnhancement: Bool {
        guard !isAIEnhanced,
              input.value != output,
              !input.value.containsAnyCharacter(in: "⁂⌘※"),
              !languagePair.isIdempotent,
              !output.containsAnyCharacter(in: "⁂⌘※"),
              output.count <= 200 else { return false }
        return true
    }
}

// swiftlint:enable file_length type_body_length
