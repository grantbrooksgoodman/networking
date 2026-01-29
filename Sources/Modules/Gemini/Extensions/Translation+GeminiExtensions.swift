//
//  Translation+GeminiExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Translator

public extension Translation {
    var isAIEnhanced: Bool {
        output != GeminiConstants.enhancementToken &&
            output.hasPrefix(GeminiConstants.enhancementToken)
    }
}
