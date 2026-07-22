//
//  DevModeAction+HealthExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem

extension DevModeAction {
    static var inspectNetworkHealthAction: DevModeAction {
        @Sendable
        func inspectNetworkHealth() {
            Task {
                let service = NetworkHealthService.shared
                let summary = await service.debugSummary()

                await AKAlert(
                    title: "Network Health",
                    message: summary,
                    actions: [.init(
                        "OK",
                        style: .preferred,
                        effect: {}
                    )]
                ).present(translating: [])
            }
        }

        return .init(
            title: "Inspect Network Health",
            perform: inspectNetworkHealth
        )
    }
}
