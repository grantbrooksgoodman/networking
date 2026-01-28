//
//  GeminiResponse.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct GeminiResponse: Decodable {
    // MARK: - Properties

    let candidates: [Candidate]?

    // MARK: - Init

    init(_ candidates: [Candidate]?) {
        self.candidates = candidates
    }
}

extension GeminiResponse {
    struct Candidate: Decodable {
        // MARK: - Properties

        let content: Content?

        // MARK: - Init

        init(_ content: Content?) {
            self.content = content
        }
    }
}
