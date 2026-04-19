//
//  QueryStrategy.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that determines which subset of results to
/// return from a database query.
///
/// Pass a query strategy to
/// ``DatabaseDelegate/queryValues(at:strategy:prependingEnvironment:cacheStrategy:timeout:)``
/// to limit the number of results returned:
///
/// ```swift
/// let result = await database.queryValues(
///     at: "messages",
///     strategy: .last(25)
/// )
/// ```
public enum QueryStrategy {
    /// Returns the first *n* results.
    case first(Int)

    /// Returns the last *n* results.
    case last(Int)
}
