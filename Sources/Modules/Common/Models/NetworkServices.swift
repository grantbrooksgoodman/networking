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
    public let storage: StorageDelegate

    // MARK: - Init

    public init(
        auth: AuthDelegate,
        database: DatabaseDelegate,
        storage: StorageDelegate
    ) {
        self.auth = auth
        self.database = database
        self.storage = storage
    }
}
