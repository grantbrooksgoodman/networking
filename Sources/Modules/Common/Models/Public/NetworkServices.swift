//
//  NetworkServices.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A collection of the networking delegates that power
/// authentication, database, health estimation, storage,
/// and translation operations.
///
/// Access the current services through the dependency
/// injection system:
///
/// ```swift
/// @Dependency(\.networking) var networking: NetworkServices
/// ```
public struct NetworkServices {
    // MARK: - Properties

    /// The delegate that handles user authentication.
    public let auth: AuthDelegate

    /// The delegate that handles database operations.
    public let database: DatabaseDelegate

    /// The delegate that provides passive network quality
    /// estimation.
    public let health: NetworkHealthDelegate

    /// The delegate that handles hosted translations.
    public let hostedTranslation: HostedTranslationDelegate

    /// The delegate that handles file storage operations.
    public let storage: StorageDelegate

    // MARK: - Init

    /// Creates a network services instance with the
    /// specified delegates.
    ///
    /// - Parameters:
    ///   - auth: The delegate that handles user
    ///     authentication.
    ///   - database: The delegate that handles database
    ///     operations.
    ///   - health: The delegate that provides passive
    ///     network quality estimation.
    ///   - hostedTranslation: The delegate that handles
    ///     hosted translations.
    ///   - storage: The delegate that handles file storage
    ///     operations.
    public init(
        auth: AuthDelegate,
        database: DatabaseDelegate,
        health: NetworkHealthDelegate,
        hostedTranslation: HostedTranslationDelegate,
        storage: StorageDelegate
    ) {
        self.auth = auth
        self.database = database
        self.health = health
        self.hostedTranslation = hostedTranslation
        self.storage = storage
    }

    /// Creates a network services instance with the
    /// specified delegates, defaulting the health delegate
    /// to the registered configuration value.
    ///
    /// This overload preserves source compatibility with
    /// existing call sites that do not pass a health
    /// delegate.
    ///
    /// - Parameters:
    ///   - auth: The delegate that handles user
    ///     authentication.
    ///   - database: The delegate that handles database
    ///     operations.
    ///   - hostedTranslation: The delegate that handles
    ///     hosted translations.
    ///   - storage: The delegate that handles file storage
    ///     operations.
    public init(
        auth: AuthDelegate,
        database: DatabaseDelegate,
        hostedTranslation: HostedTranslationDelegate,
        storage: StorageDelegate
    ) {
        self.auth = auth
        self.database = database
        health = Networking.config.healthDelegate
        self.hostedTranslation = hostedTranslation
        self.storage = storage
    }
}
