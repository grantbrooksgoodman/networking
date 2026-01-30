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

public extension UserDefaultsKey {
    // MARK: - Types

    enum NetworkingDefaultsKey: String {
        case geminiCataloguedTranslationInputs
        case isNetworkActivityIndicatorEnabled
        case networkEnvironment
    }

    // MARK: - Methods

    static func networking(_ key: NetworkingDefaultsKey) -> UserDefaultsKey { .init(key.rawValue) }
}
