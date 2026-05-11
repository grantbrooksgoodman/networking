//
//  String+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension String {
    /// A sentinel string (`"!"`) that represents an
    /// intentionally empty value in the database.
    ///
    /// Some database backends treat `null` and missing keys
    /// differently, or silently remove keys set to `null`,
    /// which can corrupt the structure of a record. Writing
    /// `bangQualifiedEmpty` instead preserves the key while
    /// signaling that its value is logically empty.
    ///
    /// Use ``isBangQualifiedEmpty`` to test whether a string
    /// carries this sentinel.
    static var bangQualifiedEmpty: String { "!" }

    /// A Boolean value that indicates whether the string is
    /// blank or equal to ``bangQualifiedEmpty``.
    var isBangQualifiedEmpty: Bool {
        isBlank || self == .bangQualifiedEmpty
    }
}
