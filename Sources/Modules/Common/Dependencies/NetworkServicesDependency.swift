//
//  NetworkServicesDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// The dependency key for resolving the current
/// ``NetworkServices`` instance.
public enum NetworkServicesDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> NetworkServices {
        .init(
            auth: Networking.config.authDelegate,
            database: Networking.config.databaseDelegate,
            hostedTranslation: Networking.config.hostedTranslationDelegate,
            storage: Networking.config.storageDelegate
        )
    }
}

public extension DependencyValues {
    /// The current networking services, accessible
    /// through the dependency injection system.
    ///
    /// ```swift
    /// @Dependency(\.networking) var networking: NetworkServices
    /// ```
    var networking: NetworkServices {
        get { self[NetworkServicesDependency.self] }
        set { self[NetworkServicesDependency.self] = newValue }
    }
}
