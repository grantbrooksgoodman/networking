//
//  HostedTranslationArchiver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

// swiftlint:disable:next type_body_length
final class HostedTranslationArchiver: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate

    // MARK: - Types

    private struct State {
        var isPopulating = false
        var translationDataSample: TranslationDataSample = .empty
    }

    // MARK: - Properties

    @LockIsolated private var state = State()

    // MARK: - Init

    init() {
        Task.detached(priority: .utility) { [weak self] in
            guard let exception = await self?.populateTranslationDataSnapshot(
                expiryThreshold: .seconds(300)
            ) else {
                return Logger.log(
                    "Populated translation data snapshot.",
                    domain: .Networking.hostedTranslation,
                    sender: self ?? HostedTranslationArchiver.self
                )
            }

            Logger.log(
                exception,
                domain: .Networking.hostedTranslation
            )
        }
    }

    // MARK: - Add to Hosted Archive

    nonisolated(nonsending) func addToHostedArchive(
        _ translation: Translation
    ) async -> Exception? {
        if let exception = TranslationValidator.validate(
            translation: translation,
            metadata: .init(sender: self)
        ) {
            return exception
        }

        guard !translation.languagePair.isIdempotent,
              let referenceValue = translation.reference.type.value else {
            return .init(
                "Translation language pair is idempotent; ineligible for hosted archive.",
                metadata: .init(sender: self)
            )
        }

        if let exception = await database.updateChildValues(
            forKey: "\(NetworkPath.translations.rawValue)/\(translation.languagePair.string)",
            with: [translation.reference.type.key: referenceValue]
        ) {
            return exception
        }

        Logger.log(
            .init(
                "Added retrieved translation to hosted archive.",
                isReportable: false,
                userInfo: ["ReferenceHostingKey": translation.reference.hostingKey],
                metadata: .init(sender: self)
            ),
            domain: .Networking.hostedTranslation
        )

        return nil
    }

    // MARK: - Find Archived Translations

    nonisolated(nonsending) func findArchivedTranslation(
        input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        let findArchivedTranslationResult = await findArchivedTranslation(
            id: input.value.encodedHash,
            languagePair: languagePair
        )

        switch findArchivedTranslationResult {
        case let .success(translation):
            return .success(translation)

        case let .failure(exception):
            guard exception.isEqual(
                to: .Networking.Database.noValueExists
            ) else { return .failure(exception) }
            return await deriveTranslation(
                input: input,
                inputValueEncodedHash: input.value.encodedHash,
                languagePair: languagePair
            )
        }
    }

    nonisolated(nonsending) func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        let path = "\(NetworkPath.translations.rawValue)/\(languagePair.string)/\(inputValueEncodedHash)"
        let userInfo = ["Path": path]

        if let exception = TranslationValidator.validate(
            languagePair: languagePair,
            metadata: .init(sender: self)
        ) {
            return .failure(exception.appending(userInfo: userInfo))
        }

        if $state.translationDataSample != .empty,
           !$state.translationDataSample.isExpired,
           let dataForLanguagePair = $state
           .translationDataSample
           .data
           .first(where: { $0.key == languagePair.string })?
           .value as? [String: String],
           let components = dataForLanguagePair
           .first(where: { $0.key == inputValueEncodedHash })?
           .value
           .decodedTranslationComponents {
            // NIT: Theoretically, we should have these in the archive already.
            return .success(.init(
                input: .init(components.input),
                output: components.output,
                languagePair: languagePair
            ))
        }

        let getValuesResult = await database.getValues(at: path)

        switch getValuesResult {
        case let .success(values):
            guard let string = values as? String else {
                let exception: Exception = .Networking.typecastFailed(
                    "string",
                    userInfo: ["Value": values],
                    metadata: .init(sender: self)
                )
                return .failure(exception.appending(userInfo: userInfo))
            }

            guard let components = string.decodedTranslationComponents else {
                return .failure(
                    .Networking.decodingFailed(
                        data: string,
                        .init(sender: self)
                    ).appending(userInfo: userInfo)
                )
            }

            return .success(
                .init(
                    input: .init(components.input),
                    output: components.output,
                    languagePair: languagePair
                )
            )

        case let .failure(exception):
            guard exception.isEqual(
                to: .Networking.Database.noValueExists
            ) else { return .failure(exception.appending(userInfo: userInfo)) }
            return await deriveTranslation(
                input: nil,
                inputValueEncodedHash: inputValueEncodedHash,
                languagePair: languagePair
            )
        }
    }

    // MARK: - Remove Archived Translations

    nonisolated(nonsending) func removeArchivedTranslation(
        for input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Exception? {
        let path = "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(languagePair.string)"

        if let exception = await database.updateChildValues(
            forKey: path,
            with: [input.value.encodedHash: NSNull()],
            prependingEnvironment: false
        ) {
            return exception
        }

        CoreDatabaseStore.removeValue(forKey: "\(path)/\(input.value.encodedHash)")
        return nil
    }

    // MARK: - Auxiliary

    private nonisolated(nonsending) func deriveTranslation(
        input originalInput: TranslationInput?,
        inputValueEncodedHash originalInputHash: String,
        languagePair originalLanguagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        if let exception = await populateTranslationDataSnapshot(expiryThreshold: .seconds(120)) {
            return .failure(exception)
        }

        for (archivedLanguagePairData, archivedTranslationData) in $state.translationDataSample.data {
            guard let archivedLanguagePair = LanguagePair(archivedLanguagePairData),
                  let sourceLanguageTranslationData = archivedTranslationData as? [String: String],
                  let sourceLanguageTranslation = sourceLanguageTranslationData.first(where: { $0.key == originalInputHash }),
                  let sourceLanguageTranslationComponents = sourceLanguageTranslation.value.decodedTranslationComponents,
                  let targetLanguageTranslationData = $state.translationDataSample.data["\(archivedLanguagePair.to)-\(originalLanguagePair.to)"],
                  let targetLanguageTranslation = targetLanguageTranslationData[sourceLanguageTranslationComponents.output.encodedHash] as? String,
                  let targetLanguageTranslationComponents = targetLanguageTranslation.decodedTranslationComponents else { continue }

            let derivedTranslation = Translation(
                input: .init(originalInput?.value ?? sourceLanguageTranslationComponents.input),
                output: targetLanguageTranslationComponents.output,
                languagePair: originalLanguagePair
            )

            if !derivedTranslation.languagePair.isIdempotent,
               let exception = await addToHostedArchive(derivedTranslation) {
                return .failure(exception)
            }

            Logger.log(
                .init(
                    "Successfully derived translation from existing data.",
                    isReportable: false,
                    userInfo: [
                        "IntermediateLanguagePair": archivedLanguagePair.string,
                        "SynthesisLanguagePair": "\(archivedLanguagePair.to)-\(originalLanguagePair.to)",
                        "TargetLanguagePair": originalLanguagePair.string,
                    ],
                    metadata: .init(sender: self)
                ),
                domain: .Networking.hostedTranslation,
                with: .toastInPrerelease(style: .success)
            )

            return .success(derivedTranslation)
        }

        return .failure(.init(
            "Failed to derive translation from existing data.",
            metadata: .init(sender: self)
        ))
    }

    private nonisolated(nonsending) func populateTranslationDataSnapshot(
        expiryThreshold: Duration
    ) async -> Exception? {
        let shouldProceed = $state.withValue { state in
            guard !state.isPopulating,
                  state.translationDataSample.isExpired ||
                  state.translationDataSample == .empty else { return false }
            state.isPopulating = true
            return true
        }

        guard shouldProceed else { return nil }
        let getValuesResult = await database.getValues(at: NetworkPath.translations.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: [String: Any]] else {
                $state.withValue { $0.isPopulating = false }
                return .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
            }

            for (languagePairKey, value) in dictionary {
                for (translationKey, translationValue) in value {
                    CoreDatabaseStore.addValue(
                        .init(
                            data: translationValue,
                            expiresAfter: .seconds(600)
                        ),
                        forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(languagePairKey)/\(translationKey)"
                    )
                }
            }

            let translationDataSample = TranslationDataSample(
                data: dictionary,
                expiresAfter: expiryThreshold
            )

            $state.withValue {
                $0.translationDataSample = translationDataSample
                $0.isPopulating = false
            }

            Task.detached(priority: .utility) {
                self.localTranslationArchiver.addValues(
                    translationDataSample
                        .data
                        .reduce(into: Set<Translation>()) { partialResult, dictionary in
                            if let languagePair = LanguagePair(dictionary.key),
                               let dataForLanguagePair = dictionary.value as? [String: String] {
                                partialResult.formUnion(
                                    dataForLanguagePair
                                        .values
                                        .compactMap(\.decodedTranslationComponents)
                                        .map {
                                            Translation(
                                                input: .init($0.input),
                                                output: $0.output,
                                                languagePair: languagePair
                                            )
                                        }
                                )
                            }
                        }
                )
            }

            return nil

        case let .failure(exception):
            $state.withValue { $0.isPopulating = false }
            return exception
        }
    }
}
