//
//  GeminiRequest.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct GeminiRequest: Encodable {
    // MARK: - Properties

    let contents: [Content]
    let systemInstruction: Content?
    let generationConfig: GenerationConfig?

    // MARK: - Init

    init(
        systemInstruction: Content?,
        contents: [Content],
        generationConfig: GenerationConfig?
    ) {
        self.systemInstruction = systemInstruction
        self.contents = contents
        self.generationConfig = generationConfig
    }
}
