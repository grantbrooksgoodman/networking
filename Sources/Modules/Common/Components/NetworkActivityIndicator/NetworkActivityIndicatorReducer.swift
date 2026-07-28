//
//  NetworkActivityIndicatorReducer.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

struct NetworkActivityIndicatorReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build

    // MARK: - Actions

    enum Action {
        case healthChanged
        case hideIfInactive
        case hideIndicator
        case indicatorTapped
        case isVisibleChanged(Bool)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Constants Accessors */

        typealias Floats = AppConstants.CGFloats.NetworkActivityIndicator

        /* MARK: Types */

        enum TaskID {
            case hideIfInactive
            case hideIndicator
        }

        /* MARK: Properties */

        var backgroundColor: Color?
        var isVisible = false
        var yOffset: CGFloat = Floats.hiddenYOffset

        /* MARK: Computed Properties */

        @MainActor
        var allowsHitTesting: Bool {
            @Dependency(\.uiApplication) var uiApplication: UIApplication
            return isVisible && !uiApplication.isPresentingAlertController
        }

        @MainActor
        var progressViewTintColor: Color? {
            Networking.config.activityIndicatorDelegate.progressViewTintColor
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .healthChanged:
            state.backgroundColor = Networking
                .config
                .activityIndicatorDelegate
                .backgroundColor

        case .hideIfInactive:
            return hideIndicatorEffect

        case .hideIndicator:
            guard state.isVisible else { return .none }
            state.isVisible = false
            state.yOffset = State.Floats.hiddenYOffset

        case .indicatorTapped:
            guard state.allowsHitTesting else { return .none }
            return .fireAndForget { @MainActor in
                guard let tapAction = Networking
                    .config
                    .activityIndicatorDelegate
                    .tapAction else {
                    return DevModeAction.inspectNetworkHealthAction.perform()
                }

                tapAction()
            }

        case let .isVisibleChanged(isVisible):
            @Persistent(.isNetworkActivityIndicatorEnabled) var isNetworkActivityIndicatorEnabled: Bool?
            var canShowIndicator: Bool {
                guard build.milestone != .generalRelease,
                      build.isDeveloperModeEnabled,
                      let isNetworkActivityIndicatorEnabled,
                      isNetworkActivityIndicatorEnabled else { return false }
                return true
            }

            var activityChangeEffects: Effect<Action> {
                var effects = [
                    hideIfInactiveEffect,
                    hideIndicatorEffect,
                ]

                if canShowIndicator {
                    effects.append(.fireAndForget { @MainActor in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    })
                }

                return .merge(effects)
            }

            guard isVisible,
                  state.isVisible != canShowIndicator else { return activityChangeEffects }
            state.isVisible = canShowIndicator
            state.yOffset = canShowIndicator ? 0 : State.Floats.hiddenYOffset
            return activityChangeEffects
        }

        return .none
    }

    // MARK: - Auxiliary

    private var hideIfInactiveEffect: Effect<Action> {
        .task(delay: .seconds(State.Floats.hideIfInactiveTaskDelaySeconds)) {
            guard !Shared.isNetworkActivityOccurring.value else { return nil }
            return .hideIfInactive
        }
        .cancellable(
            id: State.TaskID.hideIfInactive,
            cancelInFlight: true
        )
    }

    // TODO: Should probably use Task.debounced for this.
    private var hideIndicatorEffect: Effect<Action> {
        .cancel(id: State.TaskID.hideIndicator)
            .merge(
                with:
                .task(delay: .seconds(State.Floats.hideIndicatorTaskDelaySeconds)) {
                    .hideIndicator
                }
                .cancellable(id: State.TaskID.hideIndicator)
            )
    }
}
