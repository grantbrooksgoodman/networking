//
//  NetworkPath.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkPath: Hashable, Sendable {
    // MARK: - Properties

    public let rawValue: String

    // MARK: - Init

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
