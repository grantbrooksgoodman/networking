//
//  GeminiRequest+Content.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension GeminiRequest {
    struct Content: Encodable {
        // MARK: - Properties

        let parts: [Part]
        let role: Role

        // MARK: - Init

        init(
            role: Role,
            parts: [Part]
        ) {
            self.role = role
            self.parts = parts
        }
    }
}

extension GeminiRequest.Content {
    struct Part: Encodable {
        // MARK: - Properties

        let text: String

        // MARK: - Init

        init(_ text: String) {
            self.text = text
        }
    }

    enum Role: String, Encodable {
        case system
        case user
    }

    static func systemPrompt(_ prompt: String) -> GeminiRequest.Content {
        .init(
            role: .system,
            parts: [
                .init(prompt),
            ]
        )
    }

    static func userPrompt(_ prompt: String) -> GeminiRequest.Content {
        .init(
            role: .user,
            parts: [
                .init(prompt),
            ]
        )
    }
}
