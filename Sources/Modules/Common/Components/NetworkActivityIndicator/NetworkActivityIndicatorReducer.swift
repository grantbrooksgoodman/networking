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
        case backgroundColorChanged(Color?)
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
            case hideIndicator
        }

        /* MARK: Properties */

        var backgroundColor: Color?
        var isVisible = false
        var yOffset: CGFloat = Floats.hiddenYOffset

        /* MARK: Computed Properties */

        @MainActor
        var allowsHitTesting: Bool {
            @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
            @Dependency(\.uiApplication) var uiApplication: UIApplication
            guard isVisible,
                  !uiApplication.isPresentingAlertController,
                  uiApplication.presentedViews.first(where: {
                      $0.tag == coreUI.semTag(for: "OVERLAY_VIEW")
                  }) == nil else { return false }
            return true
        }

        @MainActor
        var progressViewTintColor: Color? {
            Networking.config.activityIndicatorDelegate.progressViewTintColor
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .backgroundColorChanged(color):
            state.backgroundColor = color

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

            // TODO: Should probably use Task.debounced for this.
            var hideIndicatorTask: Effect<Action> {
                .cancel(id: State.TaskID.hideIndicator)
                    .merge(
                        with:
                        .task(delay: .seconds(State.Floats.hideIndicatorTaskDelaySeconds)) {
                            .hideIndicator
                        }
                        .cancellable(id: State.TaskID.hideIndicator)
                    )
            }

            guard isVisible,
                  state.isVisible != canShowIndicator else { return hideIndicatorTask }
            state.isVisible = canShowIndicator
            state.yOffset = canShowIndicator ? 0 : State.Floats.hiddenYOffset
            return hideIndicatorTask
        }

        return .none
    }
}
