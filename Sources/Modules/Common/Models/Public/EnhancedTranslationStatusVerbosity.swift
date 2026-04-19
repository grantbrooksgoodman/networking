//
//  EnhancedTranslationStatusVerbosity.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that determines which AI-enhanced translation
/// status messages are surfaced.
///
/// Pass a verbosity level to
/// ``Networking/Config/setEnhancedTranslationStatusVerbosity(_:)``
/// to control the feedback shown when translations are
/// enhanced with artificial intelligence.
public enum EnhancedTranslationStatusVerbosity {
    /// Surfaces status messages only when an enhancement
    /// fails.
    case errorsOnly

    /// Surfaces status messages for both successful and
    /// failed enhancements.
    case successAndErrors

    /// Surfaces status messages only when an enhancement
    /// succeeds.
    case successOnly
}
