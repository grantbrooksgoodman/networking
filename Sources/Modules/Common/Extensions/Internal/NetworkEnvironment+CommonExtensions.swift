//
//  NetworkEnvironment+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

extension NetworkEnvironment {
    /// The color that identifies the environment in Developer
    /// Mode: green for development, orange for staging, and red
    /// for production.
    var indicatorColor: Color {
        switch self {
        case .development: .green
        case .production: .red
        case .staging: .orange
        }
    }
}
