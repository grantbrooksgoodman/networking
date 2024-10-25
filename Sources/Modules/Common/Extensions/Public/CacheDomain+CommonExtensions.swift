//
//  CacheDomain+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension CacheDomain {
    enum Networking {
        public static let database: CacheDomain = .init("database")
        public static let storage: CacheDomain = .init("storage")
    }
}
