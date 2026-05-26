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

    private let body: (Result<Any?, Exception>) -> Void

    @LockIsolated private var didComplete = false

    // MARK: - Init

    init(
        _ body: @escaping (Result<Any?, Exception>) -> Void
    ) {
        self.body = body
        Networking.config.activityIndicatorDelegate.show()
    }

    // MARK: - Call as Function

    func callAsFunction(
        _ result: Result<Any?, Exception>
    ) {
        let shouldProceed = $didComplete.withValue {
            guard !$0 else { return false }
            $0 = true
            return true
        }

        guard shouldProceed else { return }
        Networking.config.activityIndicatorDelegate.hide()
        body(result)
    }
}
