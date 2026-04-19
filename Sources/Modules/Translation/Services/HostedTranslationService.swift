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

final class HostedTranslationService: HostedTranslationDelegate, @unchecked Sendable {
    // MARK: - Types

    private enum ArchiveTreatment {
        case addToBothArchives
        case addToHostedArchive
        case addToLocalArchive
    }

    private enum PreprocessingResult: Sendable {
        case archiveHit(Translation)
        case archiveMiss
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.languageRecognitionService) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate
    @Dependency(\.translationService) private var translator: TranslationService

    // MARK: - Properties

    nonisolated static let shared = HostedTranslationService()

    @LockIsolated var geminiCataloguedTranslationInputs = Set<String>()

    private let archiver = HostedTranslationArchiver()

    // MARK: - Computed Properties

    private var additionalContext: String {
        let dynamicContextSuffix = [
            build.finalName,
            build.codeName,
        ].first { !$0.isBlank }.map { " for an app called \($0)." } ?? "."

        return """
        You are translating text as part of standard, user-facing system dialogs\(dynamicContextSuffix)
        Be sure to use an appropriate, respectful, and neutral tone.
        Ensure consistency in pronoun usage and grammatical correctness.
        Use infinitive forms for user actions where it makes sense (e.g., use 'cerrar' in place of 'cierra' for Spanish).
        """
    }

    // MARK: - Init

    private nonisolated init() {}

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

        let getTranslationsResult = await getTranslations(
            for: strings.keyPairs.map(\.input),
            languagePair: .system,
            enhance: Networking.config.isEnhancedDialogTranslationEnabled ? .init(
                additionalContext: additionalContext
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

    // swiftlint:disable:next function_body_length
    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?,
        enhance enhancementConfig: EnhancementConfiguration?
    ) async -> Callback<[Translation], Exception> {
        var archiveMisses = [(
            index: Int,
            input: TranslationInput
        )]()

        var resolvedTranslations: [Translation?] = Array(
            repeating: nil,
            count: inputs.count
        )

        var preprocessingException: Exception?

        await withTaskGroup(of: (Int, Callback<PreprocessingResult, Exception>).self) { taskGroup in
            for (index, input) in inputs.enumerated() {
                taskGroup.addTask {
                    if let prevalidateInputResult = await self.prevalidateInput(
                        input,
                        languagePair: languagePair
                    ) {
                        switch prevalidateInputResult {
                        case let .success(translation):
                            return (index, .success(.archiveHit(translation)))

                        case let .failure(exception):
                            return (index, .failure(exception))
                        }
                    }

                    if let checkHostedArchiveResult = await self.checkHostedArchive(
                        for: input,
                        languagePair: languagePair,
                        enhancementConfig: enhancementConfig
                    ) {
                        switch checkHostedArchiveResult {
                        case let .success(translation):
                            return (index, .success(.archiveHit(translation)))

                        case let .failure(exception):
                            return (index, .failure(exception))
                        }
                    }

                    return (index, .success(.archiveMiss))
                }
            }

            for await(index, result) in taskGroup {
                guard preprocessingException == nil else { continue }

                switch result {
                case let .success(preprocessingResult):
                    switch preprocessingResult {
                    case let .archiveHit(translation):
                        resolvedTranslations[index] = translation

                    case .archiveMiss:
                        archiveMisses.append((
                            index,
                            inputs[index]
                        ))
                    }

                case let .failure(exception):
                    preprocessingException = exception
                    taskGroup.cancelAll()
                }
            }
        }

        if let preprocessingException {
            return .failure(preprocessingException)
        }

        if archiveMisses.isEmpty {
            return .success(resolvedTranslations.compactMap(\.self))
        }

        // TODO: Audit this.
        // Networking.config.activityIndicatorDelegate.show()
        // defer { Networking.config.activityIndicatorDelegate.hide() }

        let missedInputs = archiveMisses.map {
            TranslationInput(
                $0.input.value.trimmingTrailingWhitespace,
                alternate: $0.input.alternate?.trimmingTrailingWhitespace
            )
        }

        let getTranslationsResult = await translator.getTranslations(
            missedInputs,
            languagePair: languagePair
        )

        switch getTranslationsResult {
        case let .success(translations):
            guard translations.count == archiveMisses.count else {
                return .failure(.init(
                    "Mismatched ratio returned.",
                    metadata: .init(sender: self)
                ))
            }

            var exception: Exception?

            await withTaskGroup(of: (Int, Callback<Translation, Exception>).self) { taskGroup in
                for (slot, translation) in zip(archiveMisses, translations) {
                    let slotIndex = slot.index
                    taskGroup.addTask {
                        await(slotIndex, self.postProcess(
                            translation,
                            enhancementConfig: enhancementConfig,
                            archiveTreatment: .addToBothArchives
                        ))
                    }
                }

                for await(index, postProcessResult) in taskGroup {
                    switch postProcessResult {
                    case let .success(processedTranslation):
                        resolvedTranslations[index] = Translation(
                            input: inputs[index],
                            output: processedTranslation.output,
                            languagePair: processedTranslation.languagePair
                        )

                    // swiftlint:disable:next identifier_name
                    case let .failure(_exception):
                        exception = _exception
                        taskGroup.cancelAll()
                    }
                }
            }

            if let exception {
                return .failure(exception)
            }

            let finalTranslations = resolvedTranslations.compactMap(\.self)
            guard finalTranslations.count == inputs.count else {
                return .failure(.init(
                    "Mismatched ratio returned.",
                    metadata: .init(sender: self)
                ))
            }

            return .success(finalTranslations)

        case let .failure(error):
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
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

    private func persistCataloguedInputs() {
        @Persistent(.geminiCataloguedTranslationInputs) var persistedArchive: Set<String>?
        $geminiCataloguedTranslationInputs.withValue {
            persistedArchive = $0.isEmpty ? nil : $0
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
           Networking.config.isEnhancedDialogTranslationEnabled,
           !$geminiCataloguedTranslationInputs.contains(translation.input.value),
           Networking.config.geminiAPIKeyDelegate?.apiKey.isBlank == false,
           translation.isEligibleForAIEnhancement {
            let enhanceResult = await GeminiService.shared.enhance(
                translation,
                using: enhancementConfig
            )

            $geminiCataloguedTranslationInputs.insert(translation.input.value)
            persistCataloguedInputs()

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
                       Networking.config.enhancedTranslationStatusVerbosity == .successAndErrors ||
                       Networking.config.enhancedTranslationStatusVerbosity == .successOnly {
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
                       Networking.config.enhancedTranslationStatusVerbosity == .errorsOnly ||
                       Networking.config.enhancedTranslationStatusVerbosity == .successAndErrors {
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
    // MARK: - Types

    private enum GetTranslationsResult: @unchecked Sendable {
        case completed(Callback<[Translation], Exception>)
        case timedOut
    }

    // MARK: - Methods

    func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: AlertKit.HUDConfig?,
        timeout timeoutConfig: AlertKit.TranslationTimeoutConfig
    ) async -> Result<[Translation], TranslationError> {
        let hudTask: Task<Void, Never>? = hudConfig.map { hudConfig in
            Task {
                try? await Task.sleep(for: hudConfig.appearsAfter)
                guard !Task.isCancelled else { return }
                core.hud.showProgress(isModal: hudConfig.isModal)
            }
        }

        defer {
            hudTask?.cancel()
            if hudConfig != nil {
                core.hud.hide()
            }
        }

        let getTranslationsResult: GetTranslationsResult = await withTaskGroup(
            of: GetTranslationsResult.self
        ) { taskGroup in
            taskGroup.addTask {
                let getTranslationsResult = await self.getTranslations(
                    for: inputs,
                    languagePair: languagePair,
                    hud: nil,
                    enhance: Networking.config.isEnhancedDialogTranslationEnabled ? .init(
                        additionalContext: self.additionalContext
                    ) : nil
                )

                return .completed(getTranslationsResult)
            }

            taskGroup.addTask {
                try? await Task.sleep(for: timeoutConfig.duration)
                return .timedOut
            }

            for await getTranslationsResult in taskGroup {
                taskGroup.cancelAll()
                return getTranslationsResult
            }

            return .timedOut
        }

        let fallbackTranslations = inputs.map {
            Translation(
                input: $0,
                output: $0.original.sanitized,
                languagePair: languagePair
            )
        }

        switch getTranslationsResult {
        case let .completed(getTranslationsResult):
            switch getTranslationsResult {
            case let .success(translations):
                guard translations.count == inputs.count else {
                    return .failure(.unknown(
                        "Mismatched ratio returned."
                    ))
                }

                return .success(translations)

            case let .failure(exception):
                guard timeoutConfig.returnsInputsOnFailure else {
                    return .failure(.unknown(exception.descriptor))
                }

                Logger.log(
                    exception,
                    domain: .Networking.hostedTranslation
                )

                return .success(fallbackTranslations)
            }

        case .timedOut:
            guard timeoutConfig.returnsInputsOnFailure else {
                return .failure(.timedOut)
            }

            Logger.log(
                .timedOut(metadata: .init(sender: self)),
                domain: .Networking.hostedTranslation
            )

            return .success(fallbackTranslations)
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
