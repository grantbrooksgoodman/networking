//
//  NetworkServices.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkServices {
    // MARK: - Properties

    public let auth: AuthDelegate
    public let database: DatabaseDelegate
    public let hostedTranslation: HostedTranslationDelegate
    public let storage: StorageDelegate

    // MARK: - Init

    public init(
        auth: AuthDelegate,
        database: DatabaseDelegate,
        hostedTranslation: HostedTranslationDelegate,
        storage: StorageDelegate
    ) {
        self.auth = auth
        self.database = database
        self.hostedTranslation = hostedTranslation
        self.storage = storage
    }
}
