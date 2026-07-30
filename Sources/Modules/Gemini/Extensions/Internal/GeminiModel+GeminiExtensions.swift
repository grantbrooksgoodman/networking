//
//  GeminiModel+GeminiExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension GeminiModel {
    var supportsThinkingConfig: Bool {
        switch self {
        case .flash20: false
        case .flash25: true
        }
    }
}
