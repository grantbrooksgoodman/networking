//
//  EnhancementConfiguration.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Configuration options for AI-enhanced translations.
///
/// Pass an `EnhancementConfiguration` to
/// ``HostedTranslationDelegate/translate(_:with:hud:enhance:)``
/// or
/// ``HostedTranslationDelegate/getTranslations(for:languagePair:hud:enhance:)``
/// to enhance translations using the Gemini API:
///
/// ```swift
/// let config = EnhancementConfiguration(
///     additionalContext: "Medical terminology"
/// )
///
/// let translateResult = await hostedTranslation.translate(
///     input,
///     with: languagePair,
///     enhance: config
/// )
/// ```
///
/// - Important: A ``GeminiAPIKeyDelegate`` must be
///   registered with
///   ``Networking/Config/registerGeminiAPIKeyDelegate(_:)``
///   before using AI-enhanced translations.
public struct EnhancementConfiguration: Sendable {
    // MARK: - Properties

    let additionalContext: String?
    let maximumOutputTokens: Int
    let model: GeminiModel
    let temperature: Double

    // MARK: - Init

    /// Creates an enhancement configuration with the
    /// specified parameters.
    ///
    /// - Parameters:
    ///   - model: The Gemini model to use for
    ///     enhancement. The default is
    ///     ``GeminiModel/flash25``.
    ///   - maximumOutputTokens: The maximum number of
    ///     tokens in the enhanced output. The default
    ///     is `256`.
    ///   - temperature: The sampling temperature for
    ///     generation. Lower values produce more
    ///     deterministic results. The default is `0.0`.
    ///   - additionalContext: Optional context to guide
    ///     the enhancement, such as domain-specific
    ///     terminology.
    public init(
        model: GeminiModel = .flash25,
        maximumOutputTokens: Int = 256,
        temperature: Double = 0.0,
        additionalContext: String?
    ) {
        self.model = model
        self.maximumOutputTokens = maximumOutputTokens
        self.temperature = temperature
        self.additionalContext = additionalContext
    }
}
