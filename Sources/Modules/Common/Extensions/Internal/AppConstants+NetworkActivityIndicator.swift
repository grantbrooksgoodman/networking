//
//  AppConstants+NetworkActivityIndicator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum NetworkActivityIndicator {
        static let frameHeight: CGFloat = 40
        static let frameWidth: CGFloat = 40

        static let glassEffectTintOpacity: CGFloat = 0.5

        static let hiddenYOffset: CGFloat = -1000
        static let hideIndicatorTaskDelaySeconds: CGFloat = 1.25

        static let padding: CGFloat = 5
    }
}

// MARK: - Color

extension AppConstants.Colors {
    enum NetworkActivityIndicator {
        static let glassEffectTint: Color = .init(.systemBlue)
    }
}
