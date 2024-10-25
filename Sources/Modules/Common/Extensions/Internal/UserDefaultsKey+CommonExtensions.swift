//
//  UserDefaultsKey+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension UserDefaultsKey {
    // MARK: - Types

    enum NetworkingDefaultsKey: String {
        case networkEnvironment
    }

    // MARK: - Functions

    static func networking(_ key: NetworkingDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
}
