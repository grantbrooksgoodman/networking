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

/// A namespace for networking-specific logger domains.
///
/// Use these domains to scope log output to a specific
/// networking subsystem.
public extension LoggerDomain {
    enum Networking {
        /// The logger domain for auth operations.
        public static let auth = LoggerDomain("auth")

        /// The logger domain for database operations.
        public static let database = LoggerDomain("database")

        /// The logger domain for hosted translation
        /// operations.
        public static let hostedTranslation = LoggerDomain("hostedTranslation")

        /// The logger domain for file storage operations.
        public static let storage = LoggerDomain("storage")
    }
}
