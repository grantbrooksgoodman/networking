//
//  NetworkHealthProber.swift
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

/// A demand-driven, rate-limited network prober.
///
/// The prober exists to fill the idle-confidence gap – it
/// fires only when asked, never on a timer, and only when
/// every gate in its guard chain passes: probing configured,
/// device online and foregrounded, path permitted, Low Power
/// Mode inactive, rate limits satisfied, and no probe already
/// in flight. The probe budget is enforced with an exact
/// sliding one-hour window of attempt timestamps.
///
/// A successful probe reports its full round-trip duration as
/// a latency sample – a `HEAD` request has no server-side
/// confound, so total duration is honest evidence. A
/// network-level failure reports
/// ``NetworkHealthEvent/probeFailure(timeoutSeconds:)``. Any
/// other outcome – including unexpected status codes – means
/// the server answered, and counts as latency evidence.
struct NetworkHealthProber {
    // MARK: - Types

    private struct MutableState {
        var isProbeInFlight = false
        var lastAttemptAt: Date?
        var lastOutcomeDescription: String?
        var probeAttempts: [Date] = []
    }

    // MARK: - Dependencies

    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.urlSession) private var urlSession: URLSession

    // MARK: - Properties

    private static let budgetWindowSeconds: TimeInterval = 3600

    private let onEvent: @Sendable (NetworkHealthEvent) -> Void
    private let onLatencySample: @Sendable (TimeInterval) -> Void
    private let pathStateProvider: @Sendable () -> PathState
    private let state = LockIsolated(MutableState())

    // MARK: - Computed Properties

    /// A human-readable summary of probe activity for the
    /// Developer Mode inspection surface.
    var statsDescription: String {
        let maximumProbesPerHour = Networking.config.networkHealthConfiguration.probeConfiguration?.maximumProbesPerHour ?? 0
        let now = Date.now

        return state.projectedValue.withValue { state in
            state.probeAttempts.removeAll { now.timeIntervalSince($0) >= Self.budgetWindowSeconds }
            let remainingBudget = max(maximumProbesPerHour - state.probeAttempts.count, 0)

            guard let lastAttemptAt = state.lastAttemptAt else {
                return "never · ℛ \(remainingBudget)/\(maximumProbesPerHour)"
            }

            let secondsAgo = Int(now.timeIntervalSince(lastAttemptAt))
            let outcomeDescription = state.lastOutcomeDescription ?? "in flight"
            return "\(secondsAgo)s ago (\(outcomeDescription)) · \(remainingBudget)/\(maximumProbesPerHour) rem."
        }
    }

    // MARK: - Init

    init(
        onEvent: @escaping @Sendable (NetworkHealthEvent) -> Void,
        onLatencySample: @escaping @Sendable (TimeInterval) -> Void,
        pathStateProvider: @escaping @Sendable () -> PathState
    ) {
        self.onEvent = onEvent
        self.onLatencySample = onLatencySample
        self.pathStateProvider = pathStateProvider
    }

    // MARK: - Methods

    /// Sends a single probe if – and only if – every gate in
    /// the guard chain passes. Bails silently otherwise.
    func maybeProbe() async {
        guard let probeConfiguration = Networking
            .config
            .networkHealthConfiguration
            .probeConfiguration,
            isOnline else { return }

        #if canImport(UIKit)
        let isBackgrounded = await MainActor.run {
            UIApplication.shared.applicationState == .background
        }

        guard !isBackgrounded else { return }
        #endif

        let pathState = pathStateProvider()

        guard !pathState.isConstrained || probeConfiguration.allowsConstrainedPaths,
              !pathState.isExpensive || probeConfiguration.allowsExpensivePaths,
              !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }

        let now = Date.now
        let didClaimProbe: Bool = state.projectedValue.withValue { state in
            state.probeAttempts.removeAll { now.timeIntervalSince($0) >= Self.budgetWindowSeconds }

            guard !state.isProbeInFlight,
                  state.probeAttempts.count < probeConfiguration.maximumProbesPerHour else { return false }

            if let lastAttemptAt = state.lastAttemptAt,
               now.timeIntervalSince(lastAttemptAt) < probeConfiguration.minimumIntervalSeconds {
                return false
            }

            state.isProbeInFlight = true
            state.lastAttemptAt = now
            state.probeAttempts.append(now)
            return true
        }

        guard didClaimProbe else { return }
        await performProbe(with: probeConfiguration)
    }

    // MARK: - Auxiliary

    private func performProbe(with probeConfiguration: NetworkHealthProbeConfiguration) async {
        Logger.log(
            "Probing \"\(probeConfiguration.url.absoluteString)\" for network health.",
            domain: .Networking.health,
            sender: self
        )

        var urlRequest = URLRequest(url: probeConfiguration.url)
        urlRequest.httpMethod = probeConfiguration.httpMethod
        urlRequest.timeoutInterval = probeConfiguration.timeoutSeconds

        let startedAt = Date.now
        let outcomeDescription: String

        do {
            let (_, urlResponse) = try await urlSession.data(
                for: urlRequest,
                delegate: HealthTaskMetricsDelegate()
            )

            let elapsed = Date.now.timeIntervalSince(startedAt)

            if let landingHost = urlResponse.url?.host(),
               let probeHost = probeConfiguration.url.host(),
               landingHost.lowercased() != probeHost.lowercased() {
                // A redirect off the operator's host is not
                // evidence about their endpoint; record nothing.
                outcomeDescription = "cross-host redirect, discarded"
            } else {
                onLatencySample(elapsed)
                outcomeDescription = String(format: "%.3fs", elapsed)
            }
        } catch {
            if let urlError = error as? URLError,
               urlError.isNetworkLevelFailure {
                onEvent(.probeFailure(timeoutSeconds: probeConfiguration.timeoutSeconds))
                outcomeDescription = "network failure"
            } else {
                // The server answered or the failure was not
                // network-level; the round-trip duration is
                // still honest latency evidence.
                let elapsed = Date.now.timeIntervalSince(startedAt)
                onLatencySample(elapsed)
                outcomeDescription = String(format: "%.3fs (non-network error)", elapsed)
            }
        }

        state.projectedValue.withValue { state in
            state.isProbeInFlight = false
            state.lastOutcomeDescription = outcomeDescription
        }

        Logger.log(
            "Probe completed: \(outcomeDescription).",
            domain: .Networking.health,
            sender: self
        )
    }
}
