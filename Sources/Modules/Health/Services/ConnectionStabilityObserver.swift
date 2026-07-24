//
//  ConnectionStabilityObserver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseDatabase

/// A passive observer of the Firebase realtime client's own
/// connection state, reported at the special `.info/connected`
/// location.
///
/// Unexpected socket drops in the foreground (flaps) are
/// reported as ``NetworkHealthEvent/connectionFlap``;
/// reconnections are reported as
/// ``NetworkHealthEvent/connectionRestored(afterSeconds:)``.
/// Drops that coincide with going offline, backgrounding, or
/// the grace period after foregrounding are app lifecycle, not
/// network evidence, and are filtered out.
///
/// > Important: An attached observer keeps the realtime
/// > connection alive. Attach only once the app has shown
/// > evidence of realtime database use.
final class ConnectionStabilityObserver: @unchecked Sendable {
    // MARK: - Types

    private struct MutableState {
        var disconnectedAt: Date?
        var foregroundReturnedAt: Date?
        var isInBackground = false
        var lastReconnectDuration: TimeInterval?
        #if canImport(UIKit)
        var notificationObservers: [any NSObjectProtocol] = []
        #endif
        var observerHandle: DatabaseHandle?
        var previousConnectedState: Bool?
    }

    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    private let onEvent: @Sendable (NetworkHealthEvent) -> Void

    @LockIsolated private var state = MutableState()

    // MARK: - Computed Properties

    /// A textual description of the realtime client's last
    /// reported connection state, or `"unknown"` before the
    /// first value arrives.
    var connectedStateDescription: String {
        guard let isConnected = state.previousConnectedState else { return "unknown" }
        return isConnected.description
    }

    /// The duration of the most recently observed outage, or
    /// `nil` if no reconnection has been observed.
    var lastReconnectDuration: TimeInterval? {
        state.lastReconnectDuration
    }

    // MARK: - Object Lifecycle

    init(onEvent: @escaping @Sendable (NetworkHealthEvent) -> Void) {
        self.onEvent = onEvent
    }

    deinit {
        stop()
    }

    // MARK: - Methods

    /// Attaches the `.info/connected` observer and begins
    /// tracking connection state transitions.
    func start() {
        guard state.observerHandle == nil else { return }

        Logger.log(
            "Attaching realtime connection stability observer.",
            domain: .Networking.health,
            sender: self
        )

        registerLifecycleObservers()

        let handle = firebaseDatabase
            .database
            .reference(withPath: ".info/connected")
            .observe(.value) { [weak self] snapshot in
                self?.handleConnectedStateChange(snapshot.value as? Bool ?? false)
            }

        $state.withValue { $0.observerHandle = handle }
    }

    /// Removes the `.info/connected` observer and discards
    /// transition state.
    func stop() {
        let handle: DatabaseHandle? = $state.withValue { state in
            let handle = state.observerHandle
            state.disconnectedAt = nil
            state.observerHandle = nil
            state.previousConnectedState = nil
            return handle
        }

        guard let handle else { return }

        Logger.log(
            "Detaching realtime connection stability observer.",
            domain: .Networking.health,
            sender: self
        )

        firebaseDatabase
            .database
            .reference(withPath: ".info/connected")
            .removeObserver(withHandle: handle)

        removeLifecycleObservers()
    }

    // MARK: - Auxiliary

    private func handleConnectedStateChange(_ isConnected: Bool) {
        let flapForegroundGraceSeconds = Networking.config.networkHealthConfiguration.flapForegroundGraceSeconds
        let isOnline = isOnline
        let now = Date.now

        let event: NetworkHealthEvent? = $state.withValue { state in
            // The first observed value is initial state, not a
            // transition.
            guard let previousConnectedState = state.previousConnectedState else {
                state.previousConnectedState = isConnected
                return nil
            }

            guard previousConnectedState != isConnected else { return nil }
            state.previousConnectedState = isConnected

            if isConnected {
                guard let disconnectedAt = state.disconnectedAt else { return nil }

                let duration = now.timeIntervalSince(disconnectedAt)
                state.disconnectedAt = nil
                state.lastReconnectDuration = duration
                return .connectionRestored(afterSeconds: duration)
            }

            state.disconnectedAt = now

            // Going offline is already the hard-zero path, not
            // a flap.
            guard isOnline else { return nil }

            // The realtime client deliberately drops its socket
            // around backgrounding; that is app lifecycle, not
            // network evidence.
            guard !state.isInBackground else { return nil }

            if let foregroundReturnedAt = state.foregroundReturnedAt,
               now.timeIntervalSince(foregroundReturnedAt) < flapForegroundGraceSeconds {
                return nil
            }

            return .connectionFlap
        }

        guard let event else { return }
        onEvent(event)
    }

    private func registerLifecycleObservers() {
        #if canImport(UIKit)
        let didEnterBackgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            $state.withValue { $0.isInBackground = true }
        }

        let willEnterForegroundObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            $state.withValue {
                $0.foregroundReturnedAt = .now
                $0.isInBackground = false
            }
        }

        $state.withValue {
            $0.notificationObservers = [
                didEnterBackgroundObserver,
                willEnterForegroundObserver,
            ]
        }
        #endif
    }

    private func removeLifecycleObservers() {
        #if canImport(UIKit)
        let notificationObservers: [any NSObjectProtocol] = $state.withValue { state in
            let notificationObservers = state.notificationObservers
            state.notificationObservers = []
            return notificationObservers
        }

        for notificationObserver in notificationObservers {
            notificationCenter.removeObserver(notificationObserver)
        }
        #endif
    }
}
