//
//  ValidatableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol Validatable {
    /// Describes whether or not the type's data passes validation.
    var isWellFormed: Bool { get }
}
