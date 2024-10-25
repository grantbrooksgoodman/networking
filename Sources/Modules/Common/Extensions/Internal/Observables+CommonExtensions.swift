//
//  Observables+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension ObservableKey {
    static let isNetworkActivityOccurring: ObservableKey = .init("isNetworkActivityOccurring")
}

extension Observables {
    static let isNetworkActivityOccurring: Observable<Bool> = .init(.isNetworkActivityOccurring, false)
}
