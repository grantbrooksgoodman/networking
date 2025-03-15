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
    var networking: NetworkServices {
        get { self[NetworkServicesDependency.self] }
        set { self[NetworkServicesDependency.self] = newValue }
    }
}
