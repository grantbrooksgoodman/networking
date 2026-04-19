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

public extension Networking {
    /// A delegate that maps the active network environment
    /// to a colored dot on the build info overlay.
    ///
    /// Register this delegate with AppSubsystem to display
    /// a colored indicator that reflects the current
    /// ``NetworkEnvironment``:
    ///
    /// - **Development**: green
    /// - **Staging**: orange
    /// - **Production**: red
    // swiftlint:disable:next type_name
    struct BuildInfoOverlayDotIndicatorColorDelegate: AppSubsystem.Delegates.BuildInfoOverlayDotIndicatorColorDelegate, Sendable {
        /// The shared delegate instance.
        public static let shared = BuildInfoOverlayDotIndicatorColorDelegate()

        /// The color of the developer mode indicator dot,
        /// based on the active network environment.
        public var developerModeIndicatorDotColor: Color {
            switch Networking.config.environment {
            case .development: .green
            case .production: .red
            case .staging: .orange
            }
        }
    }
}
