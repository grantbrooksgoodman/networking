//
//  Persistent+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Persistent {
    convenience init(_ networkingKey: UserDefaultsKey.NetworkingDefaultsKey) {
        self.init(.networking(networkingKey))
    }
}
