//
//  CacheStrategy.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum CacheStrategy: Sendable {
    case disregardCache
    case returnCacheFirst
    case returnCacheOnFailure
}
