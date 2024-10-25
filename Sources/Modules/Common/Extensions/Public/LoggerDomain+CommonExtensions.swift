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
    static let database: LoggerDomain = .init("database")
    static let storage: LoggerDomain = .init("storage")
}
