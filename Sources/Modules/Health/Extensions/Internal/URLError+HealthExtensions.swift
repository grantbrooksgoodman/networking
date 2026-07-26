//
//  URLError+HealthExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension URLError {
    /// Whether the error indicates a network-level failure –
    /// evidence about the connection itself rather than the
    /// request's outcome.
    var isNetworkLevelFailure: Bool {
        switch code {
        case .cannotConnectToHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .timedOut: true
        default: false
        }
    }
}
