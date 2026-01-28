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

        // MARK: - Init

        init(
            maxOutputTokens: Int?,
            temperature: Double?
        ) {
            self.maxOutputTokens = maxOutputTokens
            self.temperature = temperature
        }
    }
}
