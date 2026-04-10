//
//  NetworkActivityIndicatorObserver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

final class NetworkActivityIndicatorObserver: Observer, @unchecked Sendable {
    // MARK: - Type Aliases

    typealias R = NetworkActivityIndicatorReducer

    // MARK: - Properties

    let id = UUID()
    let observedValues: [any ObservableProtocol] = [Observables.isNetworkActivityOccurring]
    let viewModel: ViewModel<NetworkActivityIndicatorReducer>

    @LockIsolated private var taskID = UUID()

    // MARK: - Init

    init(_ viewModel: ViewModel<NetworkActivityIndicatorReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func linkObservables() {
        Observers.link(NetworkActivityIndicatorObserver.self, with: observedValues)
    }

    func onChange(of observable: Observable<Any>) {
        @Dependency(\.build) var build: Build

        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            sender: self
        )

        switch observable.key {
        case .isNetworkActivityOccurring:
            guard let value = observable.value as? Bool else { return }
            send(.isVisibleChanged(value))

            @Persistent(.isNetworkActivityIndicatorEnabled) var isNetworkActivityIndicatorEnabled: Bool?
            if build.isDeveloperModeEnabled,
               build.milestone != .generalRelease,
               let isNetworkActivityIndicatorEnabled,
               isNetworkActivityIndicatorEnabled {
                Task { @MainActor in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            let taskID = UUID()
            self.taskID = taskID

            Task.delayed(by: .seconds(2)) {
                // swiftformat:disable all
                guard taskID == self.taskID,
                      !Observables.isNetworkActivityOccurring.value else { return }
                // swiftformat:enable all
                send(.isVisibleChanged(false))
            }

        default: ()
        }
    }

    func send(_ action: NetworkActivityIndicatorReducer.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
