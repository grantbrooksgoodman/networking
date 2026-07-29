//
//  SharedStates+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension SharedStates {
    var isNetworkActivityOccurring: StateStream<Bool> {
        state(false)
    }
}
