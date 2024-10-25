//
//  DevModeAction+CommonExtensions.swift
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
    static var switchEnvironmentAction: DevModeAction {
        func switchEnvironment() {
            Task {
                @Sendable
                func switchTo(_ environment: NetworkEnvironment) async {
                    @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
                    @Dependency(\.userDefaults) var defaults: UserDefaults

                    Networking.config.setEnvironment(environment)

                    coreUtilities.clearCaches()
                    coreUtilities.eraseDocumentsDirectory()
                    coreUtilities.eraseTemporaryDirectory()

                    defaults.reset()

                    await AKAlert(
                        message: "Switched to \(environment.description) environment. You must now restart the app.",
                        actions: [.init("Exit", style: .destructivePreferred) { exit(0) }]
                    ).present(translating: [])
                }

                let switchToDevelopmentAction: AKAction = .init("Switch to Development") {
                    Task { await switchTo(.development) }
                }

                let switchToProductionAction: AKAction = .init("Switch to Production", style: .destructive) {
                    Task { await switchTo(.production) }
                }

                let switchToStagingAction: AKAction = .init("Switch to Staging") {
                    Task { await switchTo(.staging) }
                }

                var actions = [AKAction]()
                switch Networking.config.environment {
                case .development:
                    actions = [
                        switchToProductionAction,
                        switchToStagingAction,
                    ]

                case .production:
                    actions = [
                        switchToDevelopmentAction,
                        switchToStagingAction,
                    ]

                case .staging:
                    actions = [
                        switchToDevelopmentAction,
                        switchToProductionAction,
                    ]
                }

                await AKActionSheet(
                    title: "Switch from \(Networking.config.environment.description) Environment",
                    actions: actions
                ).present(translating: [])
            }
        }

        return .init(
            title: "Switch Environment",
            perform: switchEnvironment
        )
    }

    static var toggleNetworkActivityIndicatorAction: DevModeAction {
        func toggleNetworkActivityIndicator() {
            @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
            @Persistent(.isNetworkActivityIndicatorEnabled) var persistedValue: Bool?

            guard let value = persistedValue else {
                persistedValue = true
                coreHUD.showSuccess(text: "ON")
                return
            }

            persistedValue = !value
            coreHUD.showSuccess(text: !value == true ? "ON" : "OFF")
        }

        return .init(
            title: "Toggle Network Activity Indicator",
            perform: toggleNetworkActivityIndicator
        )
    }
}
