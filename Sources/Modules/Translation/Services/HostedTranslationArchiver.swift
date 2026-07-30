//
//  HostedTranslationArchiver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/* Proprietary */
import AppSubsystem
import Translator

// swiftlint:disable:next type_body_length
final class HostedTranslationArchiver: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.networking.database) private var database: DatabaseDelegate
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Types

    private struct State {
        var isPopulating = false
        var translationDataSample: TranslationDataSample = .empty
    }

    // MARK: - Properties

    @LockIsolated private var state = State()

    // MARK: - Computed Properties

    private var hasFreshTranslationDataSnapshot: Bool {
        $state.translationDataSample != .empty &&
            !$state.translationDataSample.isExpired
    }

    // MARK: - Init

    init() {
        registerForegroundRefreshObserver()

        Task.background(delayedBy: .seconds(10)) { [weak self] in
            while true {
                await self?.refreshTranslationDataSnapshot(forced: true)
                guard self != nil else { return }
                try await Task.sleep(
                    for: TranslationConstants.translationDataSampleRefreshInterval
                )
            }
        }
    }

    // MARK: - Add to Hosted Archive

    nonisolated(nonsending) func addToHostedArchive(
        _ translation: Translation
    ) async throws(Exception) {
        try TranslationValidator.validate(
            translation: translation,
            metadata: .init(sender: self)
        )

        guard let entry = hostedArchiveEntry(for: translation) else {
            throw Exception(
                "Translation language pair is idempotent; ineligible for hosted archive.",
                metadata: .init(sender: self)
            )
        }

        try await database.commit([entry.key: entry.value])

        Logger.log(
            .init(
                "Added retrieved translation to hosted archive.",
                isReportable: false,
                userInfo: ["ReferenceHostingKey": translation.reference.hostingKey],
                metadata: .init(sender: self)
            ),
            domain: .Networking.hostedTranslation
        )
    }

    func hostedArchiveEntry(
        for translation: Translation
    ) -> (key: String, value: Any)? {
        do {
            try TranslationValidator.validate(
                translation: translation,
                metadata: .init(sender: self)
            )
        } catch {
            return nil
        }

        guard !translation.languagePair.isIdempotent,
              let referenceValue = translation.reference.type.value else { return nil }

        let key = [
            NetworkPath.translations.rawValue,
            translation.languagePair.string,
            translation.reference.type.key,
        ].joined(separator: "/")

        return (key: key, value: referenceValue)
    }

    // MARK: - Find Archived Translations

    nonisolated(nonsending) func findArchivedTranslation(
        input: TranslationInput,
        languagePair: LanguagePair
    ) async throws(Exception) -> Translation {
        let inputValueEncodedHash = input.value.encodedHash

        // With a fresh snapshot, absence is authoritative here; skip the per-hash network read.
        if hasFreshTranslationDataSnapshot {
            try TranslationValidator.validate(
                languagePair: languagePair,
                metadata: .init(sender: self)
            )

            if let archivedTranslation = archivedTranslationFromSnapshot(
                id: inputValueEncodedHash,
                languagePair: languagePair
            ) {
                return archivedTranslation
            }

            return try await deriveTranslation(
                input: input,
                inputValueEncodedHash: inputValueEncodedHash,
                languagePair: languagePair
            )
        }

        do {
            return try await findArchivedTranslation(
                id: inputValueEncodedHash,
                languagePair: languagePair
            )
        } catch {
            guard error.isEqual(
                to: .Networking.Database.noValueExists
            ) else { throw error }
            return try await deriveTranslation(
                input: input,
                inputValueEncodedHash: inputValueEncodedHash,
                languagePair: languagePair
            )
        }
    }

    nonisolated(nonsending) func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async throws(Exception) -> Translation {
        let path = "\(NetworkPath.translations.rawValue)/\(languagePair.string)/\(inputValueEncodedHash)"
        let userInfo = ["Path": path]

        do {
            try TranslationValidator.validate(
                languagePair: languagePair,
                metadata: .init(sender: self)
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        // NIT: Theoretically, we should have these in the archive already.
        if let archivedTranslation = archivedTranslationFromSnapshot(
            id: inputValueEncodedHash,
            languagePair: languagePair
        ) {
            return archivedTranslation
        }

        let translationDataString: String
        do {
            translationDataString = try await database.getValues(
                at: path
            )
        } catch {
            guard error.isEqual(
                to: .Networking.Database.noValueExists
            ) else { throw error.appending(userInfo: userInfo) }
            return try await deriveTranslation(
                input: nil,
                inputValueEncodedHash: inputValueEncodedHash,
                languagePair: languagePair
            )
        }

        guard let components = translationDataString.decodedTranslationComponents else {
            throw .Networking.decodingFailed(
                data: translationDataString,
                .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        return .init(
            input: .init(components.input),
            output: components.output,
            languagePair: languagePair
        )
    }

    // MARK: - Remove Archived Translations

    nonisolated(nonsending) func removeArchivedTranslation(
        for input: TranslationInput,
        languagePair: LanguagePair
    ) async throws(Exception) {
        let path = "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(languagePair.string)"

        try await database.updateChildValues(
            forKey: path,
            with: [input.value.encodedHash: NSNull()],
            prependingEnvironment: false
        )

        CoreDatabaseStore.removeValue(
            forKey: "\(path)/\(input.value.encodedHash)"
        )
    }

    // MARK: - Auxiliary

    private func archivedTranslationFromSnapshot(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) -> Translation? {
        guard hasFreshTranslationDataSnapshot,
              let dataForLanguagePair = $state.translationDataSample.data[languagePair.string] as? [String: String],
              let components = dataForLanguagePair[inputValueEncodedHash]?.decodedTranslationComponents else { return nil }

        return .init(
            input: .init(components.input),
            output: components.output,
            languagePair: languagePair
        )
    }

    private nonisolated(nonsending) func deriveTranslation(
        input originalInput: TranslationInput?,
        inputValueEncodedHash originalInputHash: String,
        languagePair originalLanguagePair: LanguagePair
    ) async throws(Exception) -> Translation {
        // Derivation consults only in-memory data; an empty or expired snapshot fails fast.
        if hasFreshTranslationDataSnapshot {
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

                if !derivedTranslation.languagePair.isIdempotent {
                    try await addToHostedArchive(derivedTranslation)
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

                return derivedTranslation
            }
        }

        throw Exception(
            "Failed to derive translation from existing data.",
            metadata: .init(sender: self)
        )
    }

    private nonisolated(nonsending) func populateTranslationDataSnapshot(forced: Bool) async throws(Exception) {
        let shouldProceed = $state.withValue { state in
            guard !state.isPopulating,
                  forced ||
                  state.translationDataSample.isExpired ||
                  state.translationDataSample == .empty else { return false }
            state.isPopulating = true
            return true
        }

        guard shouldProceed else { return }
        let translationData: [String: [String: Any]]

        do {
            translationData = try await database.getValues(
                at: NetworkPath.translations.rawValue
            )
        } catch {
            $state.withValue { $0.isPopulating = false }
            throw error
        }

        $state.withValue {
            $0.translationDataSample = TranslationDataSample(
                data: translationData,
                expiresAfter: TranslationConstants.translationDataSampleExpiryThreshold
            )
            $0.isPopulating = false
        }

        Logger.log(
            "Populated translation data snapshot.",
            domain: .Networking.hostedTranslation,
            sender: self
        )

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            let captureDate = Date.now
            let pathPrefix = "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/"

            var dataSamples = [String: DataSample]()
            dataSamples.reserveCapacity(translationData.values.reduce(0) { $0 + $1.count })

            var translations = Set<Translation>()

            for (languagePairKey, value) in translationData {
                let keyPrefix = "\(pathPrefix)\(languagePairKey)/"
                let languagePair = LanguagePair(languagePairKey)

                for (translationKey, translationValue) in value {
                    dataSamples["\(keyPrefix)\(translationKey)"] = DataSample(
                        captureDate,
                        data: translationValue,
                        expiresAfter: .seconds(600)
                    )

                    if let languagePair,
                       let stringValue = translationValue as? String,
                       let components = stringValue.decodedTranslationComponents {
                        translations.insert(Translation(
                            input: .init(components.input),
                            output: components.output,
                            languagePair: languagePair
                        ))
                    }
                }
            }

            CoreDatabaseStore.addValues(dataSamples)
            localTranslationArchiver.addValues(translations)
        }
    }

    private nonisolated(nonsending) func refreshTranslationDataSnapshot(forced: Bool) async {
        do throws(Exception) {
            try await populateTranslationDataSnapshot(forced: forced)
        } catch {
            Logger.log(
                error,
                domain: .Networking.hostedTranslation
            )
        }
    }

    private func registerForegroundRefreshObserver() {
        #if canImport(UIKit)
        _ = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task.background {
                await self.refreshTranslationDataSnapshot(forced: false)
            }
        }
        #endif
    }
}
