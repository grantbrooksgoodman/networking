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
    /// Ignores any cached data and always fetches from
    /// the network.
    case disregardCache

    /// Returns cached data immediately when available,
    /// without making a network request.
    case returnCacheFirst

    /// Fetches from the network first, and falls back to
    /// cached data only if the request fails.
    case returnCacheOnFailure
}
