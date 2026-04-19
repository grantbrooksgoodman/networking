//
//  NetworkEnvironment.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The server environment used for network operations.
///
/// The active environment determines which backend
/// endpoints the app communicates with. Use
/// ``Networking/Config/setEnvironment(_:)`` to change the
/// active environment at runtime.
public enum NetworkEnvironment: String, Codable {
    // MARK: - Cases

    /// The development environment.
    case development

    /// The staging environment.
    case staging

    /// The production environment.
    case production

    // MARK: - Properties

    /// A human-readable description of the environment,
    /// such as `"Development"`.
    public var description: String { rawValue.firstUppercase }

    /// An abbreviated label for the environment, such as
    /// `"dev"`, `"stage"`, or `"prod"`.
    public var shortString: String {
        switch self {
        case .development: "dev"
        case .staging: "stage"
        case .production: "prod"
        }
    }
}
