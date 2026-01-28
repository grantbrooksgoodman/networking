//
//  EnhancementConfiguration.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct EnhancementConfiguration {
    // MARK: - Properties

    let additionalContext: String?
    let maximumOutputTokens: Int
    let model: GeminiModel
    let temperature: Double

    // MARK: - Init

    public init(
        model: GeminiModel = .flash25,
        maximumOutputTokens: Int = 256,
        temperature: Double = 0.0,
        additionalContext: String? = nil
    ) {
        self.model = model
        self.maximumOutputTokens = maximumOutputTokens
        self.temperature = temperature
        self.additionalContext = additionalContext
    }
}
