//
//  NetworkHealth.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - NetworkHealth

/// A representation of the network's current usability.
///
/// `NetworkHealth` communicates the quality of the device's
/// network connection as either a measured score with an
/// associated tier, or an unknown state when insufficient data
/// is available.
///
/// The health value is derived from passive observation of the
/// network operations the framework already performs – it
/// generates no traffic of its own.
public enum NetworkHealth: Equatable, Sendable {
    // MARK: - Cases

    /// The network's health has been evaluated.
    ///
    /// - Parameters:
    ///   - score: A continuous value in `[0.0, 1.0]` where
    ///     `0` indicates a completely unusable network and `1`
    ///     indicates an excellent connection.
    ///   - tier: A discrete classification derived from the score.
    case measured(score: Double, tier: NetworkHealthTier)

    /// Insufficient data is available to determine network health.
    ///
    /// This state occurs at launch, after a network interface
    /// transition (for example, switching from Wi-Fi to cellular),
    /// or after a prolonged period of inactivity.
    case unknown

    // MARK: - Computed Properties

    /// A Boolean value indicating whether the health is ``unknown``.
    public var isUnknown: Bool {
        self == .unknown
    }

    /// The health score, or `nil` when the health is ``unknown``.
    public var score: Double? {
        switch self {
        case let .measured(score, _):
            score
        case .unknown:
            nil
        }
    }

    /// The health tier, or `nil` when the health is ``unknown``.
    public var tier: NetworkHealthTier? {
        switch self {
        case let .measured(_, tier):
            tier
        case .unknown:
            nil
        }
    }
}

// MARK: - NetworkHealthTier

/// A discrete classification of network quality derived from
/// the health score.
///
/// Tier boundaries are configurable through
/// ``NetworkHealthConfiguration``.
public enum NetworkHealthTier: String, Equatable, Sendable {
    /// Network quality is acceptable but not optimal.
    case fair
    /// Network quality is strong.
    case good
    /// Network quality is degraded.
    case poor
}
