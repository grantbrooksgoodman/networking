//
//  Networking.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseCore

// MARK: - Networking

public enum Networking {
    /* MARK: Properties */

    public static let config = Config.shared

    private(set) nonisolated(unsafe) static var didInitialize = false

    /* MARK: Initialize */

    @MainActor
    public static func initialize() {
        FirebaseApp.configure()
        didInitialize = true
        DevModeService.insertAction(.switchEnvironmentAction, at: 0)
        DevModeService.insertAction(.toggleNetworkActivityIndicatorAction, at: 1)

        Task.background { @MainActor in
            ReadWriteEnablementStatusService.shared.listenForReadWriteEnablementStatusChanges()
        }
    }
}

// MARK: - Config

public extension Networking {
    final class Config: @unchecked Sendable {
        /* MARK: Properties */

        fileprivate static let shared = Config()

        /// When `true`, enables system dialog translations to be enhanced with artificial intelligence.
        @LockIsolated public private(set) var isEnhancedDialogTranslationEnabled = false

        @LockIsolated package private(set) var activityIndicatorDelegate: NetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()
        @LockIsolated package private(set) var authDelegate: AuthDelegate = Auth()
        @LockIsolated package private(set) var databaseDelegate: DatabaseDelegate = Database()
        @LockIsolated package private(set) var hostedTranslationDelegate: any HostedTranslationDelegate = HostedTranslationService.shared
        @LockIsolated package private(set) var storageDelegate: StorageDelegate = Storage()

        private let _enhancedTranslationStatusVerbosity = LockIsolated<EnhancedTranslationStatusVerbosity?>(wrappedValue: nil)
        private let _geminiAPIKeyDelegate = LockIsolated<GeminiAPIKeyDelegate?>(wrappedValue: nil)

        /* MARK: Computed Properties */

        /// Determines verbosity level for AI-enhanced translation status messages.
        public var enhancedTranslationStatusVerbosity: EnhancedTranslationStatusVerbosity? {
            _enhancedTranslationStatusVerbosity.wrappedValue
        }

        public var environment: NetworkEnvironment {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            guard let persistedValue else {
                persistedValue = .production
                return .production
            }

            return persistedValue
        }

        package var geminiAPIKeyDelegate: GeminiAPIKeyDelegate? {
            _geminiAPIKeyDelegate.wrappedValue
        }

        /* MARK: Init */

        private init() {
            guard Networking.didInitialize else {
                fatalError("Networking.initialize() must be called at app launch")
            }
        }

        /* MARK: Set Environment */

        public func setEnvironment(_ environment: NetworkEnvironment) {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            persistedValue = environment
        }

        /* MARK: Enhanced Translation Configuraiton */

        public func setEnhancedTranslationStatusVerbosity(_ enhancedTranslationStatusVerbosity: EnhancedTranslationStatusVerbosity?) {
            _enhancedTranslationStatusVerbosity.wrappedValue = enhancedTranslationStatusVerbosity
        }

        public func setIsEnhancedDialogTranslationEnabled(_ isEnhancedDialogTranslationEnabled: Bool) {
            self.isEnhancedDialogTranslationEnabled = isEnhancedDialogTranslationEnabled
        }

        /* MARK: Delegate Registration */

        @discardableResult
        public func register(
            activityIndicatorDelegate: NetworkActivityIndicatorDelegate? = nil,
            authDelegate: AuthDelegate? = nil,
            databaseDelegate: DatabaseDelegate? = nil,
            geminiAPIKeyDelegate: GeminiAPIKeyDelegate? = nil,
            hostedTranslationDelegate: HostedTranslationDelegate? = nil,
            storageDelegate: StorageDelegate? = nil
        ) -> Exception? {
            guard activityIndicatorDelegate != nil ||
                authDelegate != nil ||
                databaseDelegate != nil ||
                geminiAPIKeyDelegate != nil ||
                hostedTranslationDelegate != nil ||
                storageDelegate != nil else {
                return .init(
                    "No delegates provided in arguments.",
                    metadata: .init(sender: self)
                )
            }

            if let activityIndicatorDelegate { self.activityIndicatorDelegate = activityIndicatorDelegate }
            if let authDelegate { self.authDelegate = authDelegate }
            if let databaseDelegate { self.databaseDelegate = databaseDelegate }
            if let geminiAPIKeyDelegate { _geminiAPIKeyDelegate.wrappedValue = geminiAPIKeyDelegate }
            if let hostedTranslationDelegate { self.hostedTranslationDelegate = hostedTranslationDelegate }
            if let storageDelegate { self.storageDelegate = storageDelegate }

            return nil
        }

        public func registerActivityIndicatorDelegate(_ activityIndicatorDelegate: NetworkActivityIndicatorDelegate) {
            register(activityIndicatorDelegate: activityIndicatorDelegate)
        }

        public func registerAuthDelegate(_ authDelegate: AuthDelegate) {
            register(authDelegate: authDelegate)
        }

        public func registerHostedTranslationDelegate(_ hostedTranslationDelegate: HostedTranslationDelegate) {
            register(hostedTranslationDelegate: hostedTranslationDelegate)
        }

        public func registerDatabaseDelegate(_ databaseDelegate: DatabaseDelegate) {
            register(databaseDelegate: databaseDelegate)
        }

        public func registerGeminiAPIKeyDelegate(_ geminiAPIKeyDelegate: GeminiAPIKeyDelegate) {
            register(geminiAPIKeyDelegate: geminiAPIKeyDelegate)
        }

        public func registerStorageDelegate(_ storageDelegate: StorageDelegate) {
            register(storageDelegate: storageDelegate)
        }
    }
}
