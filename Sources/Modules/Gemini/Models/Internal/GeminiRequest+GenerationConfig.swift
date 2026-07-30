//
//  GeminiRequest+GenerationConfig.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension GeminiRequest {
    struct GenerationConfig: Encodable {
        // MARK: - Properties

        let maxOutputTokens: Int?
        let temperature: Double?
        let thinkingConfig: ThinkingConfig?

        // MARK: - Init

        init(
            maxOutputTokens: Int?,
            temperature: Double?,
            thinkingConfig: ThinkingConfig?
        ) {
            self.maxOutputTokens = maxOutputTokens
            self.temperature = temperature
            self.thinkingConfig = thinkingConfig
        }
    }
}

extension GeminiRequest.GenerationConfig {
    struct ThinkingConfig: Encodable {
        // MARK: - Properties

        let thinkingBudget: Int

        // MARK: - Init

        init(thinkingBudget: Int) {
            self.thinkingBudget = thinkingBudget
        }
    }
}
