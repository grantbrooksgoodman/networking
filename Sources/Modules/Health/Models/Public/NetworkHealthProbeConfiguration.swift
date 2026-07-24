//
//  NetworkHealthProbeConfiguration.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Configuration for opt-in active network health probing.
///
/// Probing is the health system's only source of self-generated
/// traffic. It exists to fill the idle-confidence gap – the
/// situation where a consumer wants a decision and the estimate
/// has decayed to ``NetworkHealth/unknown`` – and fires on
/// demand, never on a timer.
///
/// Enabling probing requires supplying an endpoint you control.
/// Choose one that returns a small response, such as an empty
/// `200` or `204` – a `HEAD` request against your own backend
/// host doubles as connection prewarming:
///
/// ```swift
/// var configuration = NetworkHealthConfiguration()
/// configuration.probeConfiguration = .init(
///     url: URL(string: "https://api.example.com/health")!
/// )
///
/// Networking.config.setNetworkHealthConfiguration(configuration)
/// ```
public struct NetworkHealthProbeConfiguration: Codable, Equatable, Sendable {
    // MARK: - Properties

    /// A Boolean value that determines whether probes may be
    /// sent while the network path is constrained (for
    /// example, Low Data Mode is active).
    ///
    /// Default value is `false`.
    public var allowsConstrainedPaths: Bool

    /// A Boolean value that determines whether probes may be
    /// sent while the network path is expensive (for example,
    /// a cellular or personal hotspot connection).
    ///
    /// Default value is `false`.
    public var allowsExpensivePaths: Bool

    /// The HTTP method used for probe requests.
    ///
    /// Default value is `"HEAD"`.
    public var httpMethod: String

    /// The hard budget of probe attempts per hour.
    ///
    /// Default value is `10`.
    public var maximumProbesPerHour: Int

    /// The minimum interval, in seconds, between any two probe
    /// attempts – successful or not.
    ///
    /// Default value is `60` seconds.
    public var minimumIntervalSeconds: TimeInterval

    /// The probe request's timeout, in seconds.
    ///
    /// A probe that fails at the network level contributes a
    /// censored latency sample bounded by this value.
    ///
    /// Default value is `5` seconds.
    public var timeoutSeconds: TimeInterval

    /// The endpoint probes are sent to.
    ///
    /// Supply an operator-controlled endpoint that returns a
    /// small response. Probes rely on default redirect
    /// handling; a redirect that lands on a different host
    /// records no evidence.
    public var url: URL

    // MARK: - Init

    /// Creates a probe configuration for the specified
    /// endpoint.
    ///
    /// All parameters other than `url` have sensible defaults;
    /// pass only the values you wish to customize.
    public init(
        allowsConstrainedPaths: Bool = false,
        allowsExpensivePaths: Bool = false,
        httpMethod: String = "HEAD",
        maximumProbesPerHour: Int = 10,
        minimumIntervalSeconds: TimeInterval = 60,
        timeoutSeconds: TimeInterval = 5,
        url: URL
    ) {
        self.allowsConstrainedPaths = allowsConstrainedPaths
        self.allowsExpensivePaths = allowsExpensivePaths
        self.httpMethod = httpMethod
        self.maximumProbesPerHour = maximumProbesPerHour
        self.minimumIntervalSeconds = minimumIntervalSeconds
        self.timeoutSeconds = timeoutSeconds
        self.url = url
    }
}
