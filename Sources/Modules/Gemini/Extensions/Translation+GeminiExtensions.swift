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
        // TODO: Strengthen this (i.e., length).
        output.hasPrefix(GeminiConstants.enhancementToken)
    }
}
