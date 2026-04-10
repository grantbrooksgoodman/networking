//
//  OperationCompletion.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

final class OperationCompletion: @unchecked Sendable {
    // MARK: - Properties

    private let body: (Callback<Any?, Exception>) -> Void
    private let didComplete = LockIsolated<Bool>(wrappedValue: false)

    // MARK: - Init

    init(_ body: @escaping (Callback<Any?, Exception>) -> Void) {
        self.body = body
    }

    // MARK: - Call as Function

    func callAsFunction(_ result: Callback<Any?, Exception>) {
        let shouldProceed: Bool = didComplete.projectedValue.withValue {
            guard !$0 else { return false }
            $0 = true
            return true
        }

        guard shouldProceed else { return } // TODO: Audit the commented line.
//        Networking.config.activityIndicatorDelegate.hide()
        body(result)
    }
}
