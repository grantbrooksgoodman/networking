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
        public static let gemini: CacheDomain = .init("gemini") { clearGeminiCache() }
        public static let storage: CacheDomain = .init("storage") { clearStorageCache() }

        // MARK: - Methods

        private static func clearDatabaseCache() {
            CoreDatabaseStore.clearStore()
        }

        private static func clearGeminiCache() {
            HostedTranslationService.shared.geminiCataloguedTranslationInputs = []
        }

        private static func clearStorageCache() {
            @Dependency(\.networking.storage) var storage: StorageDelegate
            storage.clearStore()
        }
    }
}
