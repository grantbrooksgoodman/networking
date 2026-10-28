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
                            "Latency:",
                            "Path:",
                            "Probing:",
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

        return DevModeAction(
            title: "Inspect Network Health",
            iconConfiguration: .init(
                backgroundColor: .mint,
                overlay: .symbol(name: "waveform.path.ecg")
            ),
            perform: inspectNetworkHealth
        )
    }

    static var networkingOptionsAction: DevModeAction {
        .init(
            title: "Networking Options",
            iconConfiguration: .init(
                backgroundColor: .green,
                overlay: .symbol(name: "network")
            ),
            destination: [
                inspectNetworkHealthAction,
                switchEnvironmentAction,
                toggleNetworkActivityIndicatorAction,
            ]
        )
    }

    private static var switchEnvironmentAction: DevModeAction {
        .init(
            title: "Switch Environment",
            iconConfiguration: .init(
                backgroundColor: .orange,
                overlay: .symbol(name: "arrow.left.arrow.right")
            ),
            destination: [
                NetworkEnvironment.development,
                .production,
                .staging,
            ]
            .filter { $0 != Networking.config.environment }
            .map(switchAction(to:))
        )
    }

    private static var toggleNetworkActivityIndicatorAction: DevModeAction {
        @Sendable
        func toggleNetworkActivityIndicator() {
            @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
            @Persistent(.isNetworkActivityIndicatorEnabled) var persistedValue: Bool?

            persistedValue = !(persistedValue == true)
            coreHUD.showSuccess(
                text: "Network Activity Indicator \(persistedValue == true ? "Enabled" : "Disabled")"
            )

            // Runtime-registered actions are stored as values, so the
            // parent must be re-registered for the switch to reflect
            // the new state.
            DevModeService.insertAction(
                .networkingOptionsAction,
                at: 0
            )
        }

        @Persistent(.isNetworkActivityIndicatorEnabled) var persistedValue: Bool?
        return .init(
            title: "Network Activity Indicator",
            iconConfiguration: .init(
                backgroundColor: .indigo,
                overlay: .symbol(name: "antenna.radiowaves.left.and.right")
            ),
            interaction: .switch(isOn: persistedValue == true),
            perform: toggleNetworkActivityIndicator
        )
    }

    private static func switchAction(to environment: NetworkEnvironment) -> DevModeAction {
        @Sendable
        func switchEnvironment() {
            Task {
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
        }

        return .init(
            title: "Switch to \(environment.description)",
            iconConfiguration: switchActionIconConfiguration(for: environment),
            isDestructive: environment == .production,
            perform: switchEnvironment
        )
    }

    private static func switchActionIconConfiguration(
        for environment: NetworkEnvironment
    ) -> SquareIconView.Configuration {
        switch environment {
        case .development:
            .init(
                backgroundColor: .blue,
                overlay: .symbol(name: "hammer.fill")
            )

        case .production:
            .init(
                backgroundColor: .red,
                overlay: .symbol(name: "shippingbox.fill")
            )

        case .staging:
            .init(
                backgroundColor: .purple,
                overlay: .symbol(name: "theatermasks.fill")
            )
        }
    }
}
