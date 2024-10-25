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

    static var didInitialize = false

    /* MARK: Initialize */

    @MainActor
    public static func initialize() {
        FirebaseApp.configure()
        didInitialize = true
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
        package var storageDelegate: StorageDelegate = Storage()

        /* MARK: Computed Properties */

        public var environment: NetworkEnvironment {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            guard let persistedValue else {
                persistedValue = .development
                return .development
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

        public func register(
            activityIndicatorDelegate: NetworkActivityIndicatorDelegate? = nil,
            authDelegate: AuthDelegate? = nil,
            databaseDelegate: DatabaseDelegate? = nil,
            storageDelegate: StorageDelegate? = nil
        ) {
            self.activityIndicatorDelegate = activityIndicatorDelegate ?? DefaultNetworkActivityIndicatorDelegate()
            self.authDelegate = authDelegate ?? Auth()
            self.databaseDelegate = databaseDelegate ?? Database()
            self.storageDelegate = storageDelegate ?? Storage()
        }

        public func registerActivityIndicatorDelegate(_ activityIndicatorDelegate: NetworkActivityIndicatorDelegate) {
            self.activityIndicatorDelegate = activityIndicatorDelegate
        }

        public func registerAuthDelegate(_ authDelegate: AuthDelegate) {
            self.authDelegate = authDelegate
        }

        public func registerDatabaseDelegate(_ databaseDelegate: DatabaseDelegate) {
            self.databaseDelegate = databaseDelegate
        }

        public func registerStorageDelegate(_ storageDelegate: StorageDelegate) {
            self.storageDelegate = storageDelegate
        }
    }
}
