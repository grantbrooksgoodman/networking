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

    private(set) static var didInitialize = false

    /* MARK: Initialize */

    @MainActor
    public static func initialize() {
        FirebaseApp.configure()
        didInitialize = true
        DevModeService.insertAction(.toggleNetworkActivityIndicatorAction, at: 0)
    }
}

// MARK: - Config

public extension Networking {
    final class Config {
        /* MARK: Properties */

        fileprivate static let shared = Config()

        package var activityIndicatorDelegate: NetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()
        package var authDelegate: AuthDelegate = Auth()
        package var databaseDelegate: DatabaseDelegate = Database()
        package var hostedTranslationDelegate: HostedTranslationDelegate = HostedTranslationService()
        package var storageDelegate: StorageDelegate = Storage()

        /* MARK: Computed Properties */

        public var environment: NetworkEnvironment {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            guard let persistedValue else {
                persistedValue = .production
                return .production
            }

            return persistedValue
        }

        /* MARK: Init */

        private init() {
            guard Networking.didInitialize else { fatalError("Networking.initialize() must be called at app launch") }
        }

        /* MARK: Set Environment */

        public func setEnvironment(_ environment: NetworkEnvironment) {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            persistedValue = environment
        }

        /* MARK: Delegate Registration */

        @discardableResult
        public func register(
            activityIndicatorDelegate: NetworkActivityIndicatorDelegate? = nil,
            authDelegate: AuthDelegate? = nil,
            databaseDelegate: DatabaseDelegate? = nil,
            hostedTranslationDelegate: HostedTranslationDelegate? = nil,
            storageDelegate: StorageDelegate? = nil
        ) -> Exception? {
            guard activityIndicatorDelegate != nil ||
                authDelegate != nil ||
                databaseDelegate != nil ||
                hostedTranslationDelegate != nil ||
                storageDelegate != nil else {
                return .init(
                    "No delegates provided in arguments.",
                    metadata: [self, #file, #function, #line]
                )
            }

            if let activityIndicatorDelegate { registerActivityIndicatorDelegate(activityIndicatorDelegate) }
            if let authDelegate { registerAuthDelegate(authDelegate) }
            if let databaseDelegate { registerDatabaseDelegate(databaseDelegate) }
            if let hostedTranslationDelegate { registerHostedTranslationDelegate(hostedTranslationDelegate) }
            if let storageDelegate { registerStorageDelegate(storageDelegate) }

            return nil
        }

        public func registerActivityIndicatorDelegate(_ activityIndicatorDelegate: NetworkActivityIndicatorDelegate) {
            self.activityIndicatorDelegate = activityIndicatorDelegate
        }

        public func registerAuthDelegate(_ authDelegate: AuthDelegate) {
            self.authDelegate = authDelegate
        }

        public func registerHostedTranslationDelegate(_ hostedTranslationDelegate: HostedTranslationDelegate) {
            self.hostedTranslationDelegate = hostedTranslationDelegate
        }

        public func registerDatabaseDelegate(_ databaseDelegate: DatabaseDelegate) {
            self.databaseDelegate = databaseDelegate
        }

        public func registerStorageDelegate(_ storageDelegate: StorageDelegate) {
            self.storageDelegate = storageDelegate
        }
    }
}
