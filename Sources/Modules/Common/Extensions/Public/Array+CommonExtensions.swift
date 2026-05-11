//
//  Array+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension [String] {
    /// A sentinel array (`["!"]`) that represents an
    /// intentionally empty list in the database.
    ///
    /// Writing an empty array to some database backends
    /// causes the key to be removed entirely, which
    /// corrupts the structure of the record. Writing
    /// `bangQualifiedEmpty` preserves the key while
    /// signaling that the list is logically empty.
    ///
    /// Use ``isBangQualifiedEmpty`` to test whether an
    /// array carries this sentinel.
    static var bangQualifiedEmpty: [String] { [.bangQualifiedEmpty] }

    /// A Boolean value that indicates whether the array is
    /// empty or contains only bang-qualified empty strings.
    var isBangQualifiedEmpty: Bool {
        isEmpty || allSatisfy(\.isBangQualifiedEmpty)
    }
}
