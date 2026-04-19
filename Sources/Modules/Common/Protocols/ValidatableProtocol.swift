//
//  ValidatableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A type that can verify the integrity of its own data.
///
/// Conform to `Validatable` to provide a single entry
/// point for checking whether a value's data is internally
/// consistent and suitable for use.
public protocol Validatable {
    /// A Boolean value that indicates whether the type's
    /// data passes validation.
    var isWellFormed: Bool { get }
}
