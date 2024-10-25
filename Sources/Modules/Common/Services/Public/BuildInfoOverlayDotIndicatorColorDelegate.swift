//
//  BuildInfoOverlayDotIndicatorColorDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public extension Networking { // swiftlint:disable:next type_name
    struct BuildInfoOverlayDotIndicatorColorDelegate: AppSubsystem.Delegates.BuildInfoOverlayDotIndicatorColorDelegate {
        public static let shared = BuildInfoOverlayDotIndicatorColorDelegate()
        public var developerModeIndicatorDotColor: Color {
            switch Networking.config.environment {
            case .development: return .green
            case .production: return .red
            case .staging: return .orange
            }
        }
    }
}
