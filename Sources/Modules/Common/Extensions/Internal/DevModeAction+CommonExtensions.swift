//
//  DevModeAction+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem

extension DevModeAction {
    static var inspectNetworkHealthAction: DevModeAction {
        @Sendable
        func inspectNetworkHealth() {
            Task { @MainActor in
                @Dependency(\.networking.health) var networkHealthService: NetworkHealthDelegate
                guard let summary = await (
                    networkHealthService as? NetworkHealthService
                )?.debugSummary() else {
                    return Logger.log(
                        .init(
                            "The registered NetworkHealthDelegate is incompatible.",
                            isReportable: false,
                            metadata: .init(sender: self)
                        ),
                        domain: .Networking.health,
                        with: .toast
                    )
                }

                let inspectionAlert = AKAlert(
                    title: "Network Health",
                    message: summary,
                    actions: [.init(
                        "OK",
                        style: .preferred,
                        effect: {}
                    )]
                )

                let fontSize: CGFloat = UIApplication.isFullyV26Compatible ? 15 : 13
                let labelFont: UIFont = .systemFont(
                    ofSize: fontSize,
                    weight: .semibold
                )

                var secondaryAttributes: [AlertKit.AttributedStringConfig.StringAttributes] = [
                    .init(
                        [.font: labelFont],
                        stringRanges: [
                            "Confidence:",
                            "Failures:",
                            "Flaps:",
                            "Last Probing:",
                            "Latency:",
                            "Path:",
                            "Score:",
                            "Socket:",
                            "Stalls:",
                            "Throughput:",
                            "Transfer:",
                        ]
                    ),
                ]

                if let tier = networkHealthService.health.tier {
                    let tierColor: UIColor = switch tier {
                    case .fair: .systemOrange
                    case .good: .systemGreen
                    case .poor: .systemRed
                    }

                    secondaryAttributes.append(.init(
                        [
                            .font: labelFont,
                            .foregroundColor: tierColor,
                        ],
                        stringRanges: ["(\(tier.rawValue.capitalized))"]
                    ))
                }

                inspectionAlert.setMessageAttributes(
                    .init(
                        [.font: UIFont.systemFont(ofSize: fontSize)],
                        secondaryAttributes: secondaryAttributes
                    )
                )

                await inspectionAlert.present(translating: [])
            }
        }

        return .init(
            title: "Inspect Network Health",
            perform: inspectNetworkHealth
        )
    }

    static var switchEnvironmentAction: DevModeAction {
        @Sendable
        func switchEnvironment() {
            Task {
                @Sendable
                func switchTo(_ environment: NetworkEnvironment) async {
                    @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
                    @Dependency(\.userDefaults) var defaults: UserDefaults

                    Networking.config.setEnvironment(environment)

                    coreUtilities.clearCaches()
                    try? coreUtilities.eraseApplicationSupportDirectory()
                    try? coreUtilities.eraseDocumentsDirectory()
                    try? coreUtilities.eraseTemporaryDirectory()

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
        @Sendable
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
