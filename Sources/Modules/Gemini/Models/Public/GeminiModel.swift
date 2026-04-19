//
//  GeminiModel.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The Gemini model used for AI-enhanced translations.
///
/// Specify a model when creating an
/// ``EnhancementConfiguration`` to control which Gemini
/// model performs the enhancement.
public enum GeminiModel: String, Sendable {
    /// Gemini 2.0 Flash.
    case flash20 = "gemini-2.0-flash"

    /// Gemini 2.5 Flash.
    case flash25 = "gemini-2.5-flash"
}
