//
//  NetworkPath.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that represents a path to a resource in the
/// network backend.
///
/// Use `NetworkPath` to create a type-safe reference to a
/// backend resource location:
///
/// ```swift
/// let path = NetworkPath("users/profile")
/// ```
public struct NetworkPath: Hashable, Sendable {
    // MARK: - Properties

    /// The string representation of the path.
    public let rawValue: String

    // MARK: - Init

    /// Creates a network path with the specified raw
    /// value.
    ///
    /// - Parameter rawValue: The string representation of
    ///   the path.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
