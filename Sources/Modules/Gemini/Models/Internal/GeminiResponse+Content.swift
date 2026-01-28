//
//  GeminiResponse+Content.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension GeminiResponse.Candidate {
    struct Content: Decodable {
        // MARK: - Properties

        let parts: [Part]?

        // MARK: - Computed Properties

        var concatenatedText: String? {
            guard let parts else { return nil }
            return parts.compactMap(\.text).joined()
        }

        // MARK: - Init

        init(_ parts: [Part]?) {
            self.parts = parts
        }
    }
}

extension GeminiResponse.Candidate.Content {
    struct Part: Decodable {
        // MARK: - Properties

        let text: String?

        // MARK: - Init

        init(_ text: String?) {
            self.text = text
        }
    }
}
