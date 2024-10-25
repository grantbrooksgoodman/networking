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
        // MARK: - Properties

        public static let database: CacheDomain = .init("database") { clearDatabaseCache() }
        public static let storage: CacheDomain = .init("storage") { clearStorageCache() }

        // MARK: - Methods

        private static func clearDatabaseCache() {
            CoreDatabaseStore.clearStore()
        }

        private static func clearStorageCache() {
            @Dependency(\.networking.storage) var storage: StorageDelegate
            storage.clearStore()
        }
    }
}
