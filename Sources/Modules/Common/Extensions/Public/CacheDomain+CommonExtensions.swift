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

/// A namespace for networking-specific cache domains.
///
/// These domains partition the networking module's cached
/// data into discrete, independently clearable categories.
public extension CacheDomain {
    enum Networking {
        // MARK: - Properties

        /// The cache domain for database operations.
        public static let database: CacheDomain = .init("database") { clearDatabaseCache() }

        /// The cache domain for Gemini API operations.
        public static let gemini: CacheDomain = .init("gemini") { clearGeminiCache() }

        /// The cache domain for file storage operations.
        public static let storage: CacheDomain = .init("storage") { clearStorageCache() }

        // MARK: - Methods

        private static func clearDatabaseCache() {
            CoreDatabaseStore.clearStore()
        }

        private static func clearGeminiCache() {
            Task { @MainActor in
                HostedTranslationService.shared.geminiCataloguedTranslationInputs = []
            }
        }

        private static func clearStorageCache() {
            @Dependency(\.networking.storage) var storage: StorageDelegate
            storage.clearStore()
        }
    }
}
