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

final class HostedTranslationArchiver {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate

    // MARK: - Properties

    private var isPopulatingTranslationDataSample = false
    private var translationDataSample: TranslationDataSample = .empty

    // MARK: - Init

    init() {
        Task {
            guard let exception = await populateTranslationDataSnapshot(expiryThreshold: .seconds(300)) else {
                return Logger.log(
                    "Populated translation data snapshot.",
                    domain: .Networking.hostedTranslation,
                    sender: self
                )
            }

            Logger.log(exception, domain: .Networking.hostedTranslation)
        }
    }

    // MARK: - Add to Hosted Archive

    func addToHostedArchive(_ translation: Translation) async -> Exception? {
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

    func findArchivedTranslation(
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
            guard exception.isEqual(to: .Networking.Database.noValueExists) else { return .failure(exception) }
            return await deriveTranslation(input: input, languagePair: languagePair)
        }
    }

    func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        let path = "\(NetworkPath.translations.rawValue)/\(languagePair.string)/\(inputValueEncodedHash)"
        let commonParams = ["Path": path]

        if let exception = TranslationValidator.validate(
            languagePair: languagePair,
            metadata: .init(sender: self)
        ) {
            return .failure(exception.appending(userInfo: commonParams))
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
                return .failure(exception.appending(userInfo: commonParams))
            }

            guard let components = string.decodedTranslationComponents else {
                return .failure(
                    .Networking.decodingFailed(
                        data: string,
                        .init(sender: self)
                    ).appending(userInfo: commonParams)
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
            return .failure(exception.appending(userInfo: commonParams))
        }
    }

    // MARK: - Remove Archived Translations

    func removeArchivedTranslation(
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

    private func deriveTranslation(
        input originalInput: TranslationInput,
        languagePair originalLanguagePair: LanguagePair
    ) async -> Callback<Translation, Exception> {
        if let exception = await populateTranslationDataSnapshot() {
            return .failure(exception)
        }

        let originalInputHash = originalInput.value.encodedHash
        for (archivedLanguagePairData, archivedTranslationData) in translationDataSample.data {
            guard let archivedLanguagePair = LanguagePair(archivedLanguagePairData),
                  let sourceLanguageTranslationData = archivedTranslationData as? [String: String],
                  let sourceLanguageTranslation = sourceLanguageTranslationData.first(where: { $0.key == originalInputHash }),
                  let sourceLanguageTranslationComponents = sourceLanguageTranslation.value.decodedTranslationComponents,
                  let targetLanguageTranslationData = translationDataSample.data["\(archivedLanguagePair.to)-\(originalLanguagePair.to)"],
                  let targetLanguageTranslation = targetLanguageTranslationData[sourceLanguageTranslationComponents.output.encodedHash] as? String,
                  let targetLanguageTranslationComponents = targetLanguageTranslation.decodedTranslationComponents else { continue }

            let derivedTranslation = Translation(
                input: .init(originalInput.value),
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

    private func populateTranslationDataSnapshot(expiryThreshold: Duration = .seconds(120)) async -> Exception? {
        guard !isPopulatingTranslationDataSample,
              translationDataSample.isExpired || translationDataSample == .empty else { return nil }

        isPopulatingTranslationDataSample = true
        let getValuesResult = await database.getValues(at: NetworkPath.translations.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: [String: Any]] else {
                isPopulatingTranslationDataSample = false
                return .Networking.typecastFailed(
                    "dictionary",
                    metadata: .init(sender: self)
                )
            }

            for (key, value) in dictionary {
                for (translationKey, translationValue) in value {
                    CoreDatabaseStore.addValue(
                        .init(
                            data: translationValue,
                            expiresAfter: .seconds(600)
                        ),
                        forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(key)/\(translationKey)"
                    )
                }
            }

            translationDataSample = .init(data: dictionary, expiresAfter: expiryThreshold)
            isPopulatingTranslationDataSample = false
            return nil

        case let .failure(exception):
            isPopulatingTranslationDataSample = false
            return exception
        }
    }
}
