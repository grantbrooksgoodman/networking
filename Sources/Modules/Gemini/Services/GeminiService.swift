//
//  GeminiService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

final class GeminiService {
    // MARK: - Dependencies

    @Dependency(\.jsonDecoder) private var jsonDecoder: JSONDecoder
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.urlSession) private var urlSession: URLSession

    // MARK: - Properties

    static let shared = GeminiService()

    // MARK: - Init

    private init() {}

    // MARK: - Enhance Translation

    func enhance(
        _ translation: Translation,
        using configuration: EnhancementConfiguration
    ) async -> Callback<Translation, Exception>? {
        guard let geminiAPIKey = Networking.config.geminiAPIKeyDelegate?.apiKey else {
            return .failure(.init(
                "Gemini API key delegate has not been registered.",
                metadata: .init(sender: self)
            ))
        }

        var urlRequest: URLRequest!
        let getURLRequestResult = getURLRequest(
            for: getGeminiRequest(
                for: translation,
                using: configuration
            ),
            apiKey: geminiAPIKey,
            using: configuration.model
        )

        switch getURLRequestResult { // swiftlint:disable:next identifier_name
        case let .success(_urlRequest): urlRequest = _urlRequest
        case let .failure(exception): return .failure(exception)
        }

        do {
            let (data, urlResponse) = try await urlSession.data(for: urlRequest)

            var geminiResponse: GeminiResponse!
            let getGeminiResponseResult = getGeminiResponse(
                from: data,
                urlResponse: urlResponse
            )

            switch getGeminiResponseResult { // swiftlint:disable:next identifier_name
            case let .success(_geminiResponse): geminiResponse = _geminiResponse
            case let .failure(exception): return .failure(exception)
            }

            guard let candidates = geminiResponse.candidates else {
                return .failure(.init(
                    "No candidates returned in response.",
                    metadata: .init(sender: self)
                ))
            }

            if candidates.count > 1 {
                let concatenatedCandidates = candidates
                    .compactMap(\.content?.concatenatedText)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: "\n\n")

                Logger.log(.init(
                    "Gemini response had multiple candidates.",
                    isReportable: false,
                    userInfo: ["ConcatenatedCandidates": concatenatedCandidates],
                    metadata: .init(sender: self)
                ), domain: .Networking.hostedTranslation)
            }

            guard let enhancedOutput = candidates
                .compactMap(\.content)
                .first?
                .concatenatedText?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !enhancedOutput.isEmpty else {
                return .failure(.init(
                    "Response was empty.",
                    metadata: .init(sender: self)
                ))
            }

            if let exception = await validateEnhancedOutput(
                for: translation,
                enhancedOutput: enhancedOutput
            ) {
                return .failure(exception)
            }

            Logger.log(.init(
                "Successfully AI-enhanced translation.",
                isReportable: false,
                userInfo: [
                    "OriginalOutput": translation.output,
                    "EnhancedOutput": enhancedOutput,
                ],
                metadata: .init(sender: self)
            ), domain: .Networking.hostedTranslation)

            return .success(.init(
                input: translation.input,
                output: "※\(enhancedOutput)",
                languagePair: translation.languagePair
            ))
        } catch {
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    // MARK: - Auxiliary

    private func getGeminiRequest(
        for translation: Translation,
        using configuration: EnhancementConfiguration
    ) -> GeminiRequest {
        let sourceLanguageCode = translation.languagePair.from
        let targetLanguageCode = translation.languagePair.to

        let sourceLanguageName = sourceLanguageCode.englishLanguageName ?? sourceLanguageCode.uppercased()
        let targetLanguageName = targetLanguageCode.englishLanguageName ?? targetLanguageCode.uppercased()

        // swiftlint:disable line_length
        let systemPrompt = """
        You are a translation post-editor.
        Task: Fix grammatical issues in the provided translation WITHOUT changing meaning.
        Pay special attention to gendered pronouns and agreement (e.g., Spanish feminine forms if the recipient is female).
        Output ONLY the corrected translation text. No quotes. No explanations.
        If there is nothing wrong with the translation as-is, return the original translation output.
        If anything goes wrong, return the original translation output.
        ALWAYS default to returning the original translation output if your normal instinct would be to return something which is not either the original or corrected translation output.
        """ // swiftlint:enable line_length

        var userPrompt = """
        Original input (in \(sourceLanguageName)): '\(translation.input.value)'
        Original translation output: '\(translation.output)'
        Target language: \(targetLanguageName)
        """

        if let additionalContext = configuration.additionalContext,
           !additionalContext.isEmpty {
            userPrompt += "\n-----\nADDITIONAL CONTEXT:\n\n\(additionalContext)"
        }

        return .init(
            systemInstruction: .systemPrompt(systemPrompt),
            contents: [.userPrompt(userPrompt)],
            generationConfig: .init(
                maxOutputTokens: configuration.maximumOutputTokens,
                temperature: configuration.temperature
            )
        )
    }

    private func getGeminiResponse(
        from data: Data,
        urlResponse: URLResponse
    ) -> Callback<GeminiResponse, Exception> {
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            let serverBody = String(
                data: data,
                encoding: .utf8
            ) ?? "<non-utf8>"

            return .failure(.init(
                "URL response did not indicate success.",
                userInfo: [
                    "ServerBody": serverBody,
                    "URLResponseCode": (urlResponse as? HTTPURLResponse)?.statusCode ?? -1,
                ],
                metadata: .init(sender: self)
            ))
        }

        do {
            return try .success(jsonDecoder.decode(
                GeminiResponse.self,
                from: data
            ))
        } catch {
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    private func getURLRequest(
        for geminiRequest: GeminiRequest,
        apiKey: String,
        using model: GeminiModel
    ) -> Callback<URLRequest, Exception> {
        guard let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent?key=\(apiKey)"
        ) else {
            return .failure(.init(
                "Failed to synthesize URL.",
                metadata: .init(sender: self)
            ))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try jsonEncoder.encode(geminiRequest)
            return .success(urlRequest)
        } catch {
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    private func validateEnhancedOutput(
        for translation: Translation,
        enhancedOutput: String
    ) async -> Exception? {
        let languageRecognitionService = LanguageRecognitionService.shared
        let normalizedEnhancedOutput = enhancedOutput.normalized
        let normalizedOriginalOutput = translation.output.normalized

        if normalizedEnhancedOutput == normalizedOriginalOutput {
            return .init(
                "Normalized outputs are equal.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        if normalizedOriginalOutput.count > normalizedEnhancedOutput.count {
            return .init(
                "Original output is longer than enhanced version.",
                isReportable: false,
                userInfo: [
                    "EnhancedTranslationOutput": enhancedOutput,
                    "OriginalTranslationOutput": translation.output,
                ],
                metadata: .init(sender: self)
            )
        }

        if translation.output.count != enhancedOutput.count,
           translation.output.hasPrefix(
               enhancedOutput.halfOfWhitespaceSeparatedComponents
           ) {
            return .init(
                "Mismatched terminator in enhanced output.",
                isReportable: false,
                userInfo: [
                    "EnhancedTranslationOutput": enhancedOutput,
                    "OriginalTranslationOutput": translation.output,
                ],
                metadata: .init(sender: self)
            )
        }

        if await LanguageRecognitionService.shared.matchConfidence(
            for: enhancedOutput,
            inLanguage: translation.languagePair.to
        ) <= 0.8 {
            return .init(
                "Enhanced translation is not confidently in target language.",
                isReportable: false,
                userInfo: ["EnhancedTranslationOutput": enhancedOutput],
                metadata: .init(sender: self)
            )
        }

        if await languageRecognitionService.matchConfidence(
            for: enhancedOutput,
            inLanguage: translation.languagePair.to
        ) < languageRecognitionService.matchConfidence(
            for: translation.output,
            inLanguage: translation.languagePair.to
        ) {
            return .init(
                "Had greater confidence in original output.",
                isReportable: false,
                userInfo: [
                    "EnhancedTranslationOutput": enhancedOutput,
                    "OriginalTranslationOutput": translation.output,
                ],
                metadata: .init(sender: self)
            )
        }

        if let lastEnhancedOutputWord = enhancedOutput.components(separatedBy: " ").last,
           let lastOriginalOutputWord = translation.output.components(separatedBy: " ").last,
           await languageRecognitionService.matchConfidence(
               for: lastEnhancedOutputWord,
               inLanguage: translation.languagePair.to
           ) < languageRecognitionService.matchConfidence(
               for: lastOriginalOutputWord,
               inLanguage: translation.languagePair.to
           ) {
            return .init(
                "Had greater confidence in last word of original output.",
                isReportable: false,
                userInfo: [
                    "LastEnhancedOutputWord": lastEnhancedOutputWord,
                    "LastOriginalOutputWord": lastOriginalOutputWord,
                ],
                metadata: .init(sender: self)
            )
        }

        return nil
    }
}

private extension String {
    var halfOfWhitespaceSeparatedComponents: String {
        let components = components(separatedBy: " ")
        return String(components[0 ... components.count / 2].joined(separator: " "))
    }

    var normalized: String {
        lowercasedTrimmingWhitespaceAndNewlines
    }
}
