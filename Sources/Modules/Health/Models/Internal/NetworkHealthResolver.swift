//
//  NetworkHealthResolver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Resolves ``CacheStrategy/adaptive`` to a concrete cache
/// strategy based on the current network health.
///
/// This is the single internal function that maps a health
/// snapshot and configuration to a concrete strategy, ensuring
/// the resolution logic cannot drift between the database and
/// storage funnels.
enum NetworkHealthResolver {
    // MARK: - Methods

    /// Returns a concrete cache strategy for the current health.
    ///
    /// - Parameters:
    ///   - health: The current network health snapshot.
    ///   - configuration: The active health configuration.
    /// - Returns: ``CacheStrategy/returnCacheFirst`` when the
    ///   score falls below the adaptive threshold;
    ///   ``CacheStrategy/returnCacheOnFailure`` otherwise
    ///   (including when health is ``NetworkHealth/unknown``).
    static func resolve(
        health: NetworkHealth,
        configuration: NetworkHealthConfiguration
    ) -> CacheStrategy {
        switch health {
        case let .measured(score, _):
            if score < configuration.adaptiveScoreThreshold {
                return .returnCacheFirst
            }

            return .returnCacheOnFailure
        case .unknown:
            return .returnCacheOnFailure
        }
    }
}
