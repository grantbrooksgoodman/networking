//
//  HostedTranslationService.swift
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

struct HostedTranslationService: HostedTranslationDelegate {
    // MARK: - Dependencies

    @Dependency(\.languageRecognitionService) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate
    @Dependency(\.translationService) private var translator: TranslationService

    // MARK: - Properties

    private let archiver = HostedTranslationArchiver()

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

        let getTranslationsResult = await getTranslations(for: strings.keyPairs.map(\.input), languagePair: .system)

        switch getTranslationsResult {
        case let .success(translations):
            let outputs = strings.keyPairs.reduce(into: [TranslationOutputMap]()) { partialResult, keyPair in
                if let translation = translations.first(where: { $0.input.value == keyPair.input.value }) {
                    partialResult.append(.init(key: keyPair.key, value: translation.output))
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
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?
    ) async -> Callback<[Translation], Exception> {
        if let exception = TranslationValidator.validate(
            inputs: inputs,
            languagePair: languagePair,
            metadata: .init(sender: self)
        ) {
            return .failure(exception)
        }

        var translations = [Translation]()

        for input in inputs {
            let translateResult = await translate(
                input,
                with: languagePair,
                hud: hudConfig
            )

            switch translateResult {
            case let .success(translation):
                translations.append(translation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard translations.count == inputs.count else {
            return .failure(.init("Mismatched ratio returned.", metadata: .init(sender: self)))
        }

        return .success(translations)
    }

    // swiftlint:disable:next function_body_length
    func translate( // TODO: Tidy this method up; split it into parts.
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<Translation, Exception> {
        if let exception = TranslationValidator.validate(
            inputs: [input],
            languagePair: languagePair,
            metadata: .init(sender: self)
        ) {
            return .failure(exception)
        }

        if languagePair.isIdempotent {
            let translation: Translation = .init(
                input: input,
                output: input.value.sanitized,
                languagePair: languagePair
            )

            return .success(translation)
        }

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
                return await translate(
                    input,
                    with: languagePair,
                    hud: hudConfig
                )
            }

            return .success(archivedTranslation)
        }

        let hasUnicodeLetters = input.value.containsLetters
        let sameInputOutputLanguage = await languageRecognitionService.matchConfidence(for: input.value, inLanguage: languagePair.to) > 0.8

        if !hasUnicodeLetters || sameInputOutputLanguage {
            let translation: Translation = .init(
                input: input,
                output: input.value.sanitized,
                languagePair: languagePair
            )

            if let exception = await archiver.addToHostedArchive(translation) {
                return .failure(exception)
            }

            localTranslationArchiver.addValue(translation)
            return .success(translation)
        }

        Networking.config.activityIndicatorDelegate.show()
        defer { Networking.config.activityIndicatorDelegate.hide() }

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
                if let exception = await archiver.removeArchivedTranslation(for: input, languagePair: languagePair) {
                    return .failure(exception)
                }

                return await translate(
                    input,
                    with: languagePair,
                    hud: hudConfig
                )
            }

            guard translation.input.value != translation.output else { return .success(translation) }
            localTranslationArchiver.addValue(translation)
            return .success(translation)

        case let .failure(exception):
            guard exception.isEqual(toAny: [
                .Networking.Database.noValueExists,
                .Networking.Translation.translationDerivationFailed,
            ]) else {
                return .failure(exception)
            }

            let sourceLanguageName = languagePair.from.englishLanguageName ?? languagePair.from.uppercased()
            let targetLanguageName = languagePair.to.englishLanguageName ?? languagePair.to.uppercased()
            Logger.log(
                .init(
                    "Translating text from \(sourceLanguageName) to \(targetLanguageName).",
                    isReportable: false,
                    userInfo: ["InputValue": input.value,
                               "LanguagePair": languagePair.string],
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
                var translation: Translation = .init(
                    input: input,
                    output: translation.output,
                    languagePair: translation.languagePair
                )

                if let enhancementConfig {
                    let enhanceResult = await GeminiService.shared.enhance(
                        translation,
                        using: enhancementConfig
                    )

                    switch enhanceResult {
                    case let .success(enhancedTranslation): translation = enhancedTranslation
                    case let .failure(exception): return .failure(exception)
                    }
                }

                if let exception = TranslationValidator.validate(
                    translation: translation,
                    metadata: .init(sender: self)
                ) {
                    return .failure(exception)
                }

                if let exception = await archiver.addToHostedArchive(translation) {
                    return .failure(exception)
                }

                guard translation.input.value != translation.output else { return .success(translation) }
                localTranslationArchiver.addValue(translation)
                return .success(translation)

            case let .failure(exception):
                guard exception.isEqual(toAny: [
                    .Networking.Translation.exhaustedAvailablePlatforms,
                    .Networking.Translation.sameTranslationInputOutput,
                ]) else {
                    return .failure(exception)
                }

                let translation: Translation = .init(
                    input: input,
                    output: input.value.sanitized,
                    languagePair: languagePair
                )

                if let exception = await archiver.addToHostedArchive(translation) {
                    return .failure(exception)
                }

                guard translation.input.value != translation.output else { return .success(translation) }
                localTranslationArchiver.addValue(translation)
                return .success(translation)
            }
        }
    }
}

extension HostedTranslationService: AlertKit.TranslationDelegate {
    public func getTranslations(
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

    private func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: AlertKit.HUDConfig?,
        timeout timeoutConfig: AlertKit.TranslationTimeoutConfig,
        completion: @escaping (Result<[Translation], TranslationError>) -> Void
    ) {
        @Dependency(\.coreKit) var core: CoreKit
        var didComplete = false

        if let hudConfig {
            core.gcd.after(hudConfig.appearsAfter) {
                guard !didComplete else { return }
                core.hud.showProgress(isModal: hudConfig.isModal)
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
            guard timeoutConfig.returnsInputsOnFailure else { return completion(.failure(.unknown(exception.descriptor))) }

            Logger.log(exception, domain: .Networking.hostedTranslation)
            return completion(.success(translations))
        }

        func handleTimeout() {
            guard canComplete else { return }
            translations.append(contentsOf: inputs.filter { !translations.map(\.input).contains($0) }.map {
                Translation(
                    input: $0,
                    output: $0.original.sanitized,
                    languagePair: languagePair
                )
            })

            guard exceptions.isEmpty else { return handleExceptionAndComplete() }
            guard translations.count == inputs.count else { return completion(.failure(.unknown("Mismatched ratio returned."))) }
            guard timeoutConfig.returnsInputsOnFailure else { return completion(.failure(.timedOut)) }

            Logger.log(.timedOut(metadata: .init(sender: self)), domain: .Networking.hostedTranslation)
            completion(.success(translations))
        }

        var timeout = Timeout(after: timeoutConfig.duration) { handleTimeout() }

        Task {
            for input in inputs {
                // Purposefully ignoring HUD config argument so it can be handled here.
                let translateResult = await translate(
                    input,
                    with: languagePair
                )

                timeout.cancel()
                timeout = Timeout(after: timeoutConfig.duration) { handleTimeout() }

                switch translateResult {
                case let .success(translation):
                    translations.append(translation)

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }

            guard canComplete else { return }
            guard exceptions.isEmpty else { return handleExceptionAndComplete() }
            guard translations.count == inputs.count else { return completion(.failure(.unknown("Mismatched ratio returned."))) }

            completion(.success(translations))
        }
    }
}
