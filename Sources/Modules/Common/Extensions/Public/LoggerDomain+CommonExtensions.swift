//
//  LoggerDomain+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension LoggerDomain {
    enum Networking {
        public static let database: LoggerDomain = .init("database")
        public static let hostedTranslation: LoggerDomain = .init("hostedTranslation")
        public static let storage: LoggerDomain = .init("storage")
    }
}
