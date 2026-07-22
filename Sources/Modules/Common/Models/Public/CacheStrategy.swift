//
//  CacheStrategy.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that specifies how cached data is used during
/// a network operation.
///
/// When performing database or storage operations, pass a
/// cache strategy to control whether cached results are
/// preferred, used as a fallback, or bypassed entirely.
public enum CacheStrategy: Sendable {
    // MARK: - Cases

    /// Resolves to a concrete strategy at operation time based
    /// on the current ``NetworkHealth``.
    ///
    /// When the health score falls below
    /// ``NetworkHealthConfiguration/adaptiveScoreThreshold``,
    /// the strategy resolves to ``returnCacheFirst``. Otherwise
    /// – including when health is ``NetworkHealth/unknown`` –
    /// it resolves to ``returnCacheOnFailure``.
    ///
    /// The default behavior of the framework is unchanged:
    /// nothing resolves to `.adaptive` unless a caller
    /// explicitly passes it.
    case adaptive

    /// Ignores any cached data and always fetches from
    /// the network.
    case disregardCache

    /// Returns cached data immediately when available,
    /// without making a network request.
    case returnCacheFirst

    /// Fetches from the network first, and falls back to
    /// cached data only if the request fails.
    case returnCacheOnFailure

    // MARK: - Properties

    var rawValue: String {
        switch self {
        case .adaptive: "adaptive"
        case .disregardCache: "disregardCache"
        case .returnCacheFirst: "returnCacheFirst"
        case .returnCacheOnFailure: "returnCacheOnFailure"
        }
    }
}
