//
//  NetworkActivityIndicatorReducer.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct NetworkActivityIndicatorReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build

    // MARK: - Actions

    enum Action {
        case isVisibleChanged(Bool)
    }

    // MARK: - Feedback

    enum Feedback {
        case hideIndicator
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

        var isVisible = false
        var yOffset: CGFloat = Floats.hiddenYOffset
    }

    // MARK: - Reduce

    func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(.isVisibleChanged(isVisible)):
            @Persistent(.isNetworkActivityIndicatorEnabled) var isNetworkActivityIndicatorEnabled: Bool?
            var canShowIndicator: Bool {
                guard build.milestone != .generalRelease,
                      build.developerModeEnabled,
                      let isNetworkActivityIndicatorEnabled,
                      isNetworkActivityIndicatorEnabled else { return false }
                return true
            }

            var hideIndicatorTask: Effect<Feedback> {
                .cancel(id: State.TaskID.hideIndicator)
                    .merge(with:
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

        case .feedback(.hideIndicator):
            guard state.isVisible else { return .none }
            state.isVisible = false
            state.yOffset = State.Floats.hiddenYOffset
        }

        return .none
    }
}
