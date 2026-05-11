//
//  String+InternalCommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension String {
    var prependingCurrentEnvironment: String {
        "\(Networking.config.environment.shortString)/\(trimmingLeadingForwardSlashes.trimmingTrailingForwardSlashes)"
    }

    private var trimmingLeadingForwardSlashes: String {
        var string = self
        while string.hasPrefix("/") {
            string = string.dropPrefix()
        }

        return string
    }

    private var trimmingTrailingForwardSlashes: String {
        var string = self
        while string.hasSuffix("/") {
            string = string.dropSuffix()
        }

        return string
    }
}
