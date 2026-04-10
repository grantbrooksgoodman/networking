//
//  DatabaseOperation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum DatabaseOperation: @unchecked Sendable {
    case getValues(
        atPath: String,
        cacheStrategy: CacheStrategy
    )

    case queryValues(
        atPath: String,
        strategy: QueryStrategy,
        cacheStrategy: CacheStrategy
    )

    case setValue(
        _ value: Any,
        forKey: String
    )

    case updateChildValues(
        forKey: String,
        withData: [String: Any]
    )
}
