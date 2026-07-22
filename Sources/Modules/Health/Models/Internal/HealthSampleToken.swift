//
//  HealthSampleToken.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Proprietary */
import AppSubsystem

/// A once-only recording guard for health instrumentation.
///
/// Each instrumented operation creates a single token shared
/// between the timeout handler and the operation's completion
/// path. Exactly one of {success sample, censored timeout
/// sample, discard} is recorded per operation – the first
/// caller to successfully ``claim()`` the token owns the
/// recording; all subsequent callers are rejected.
///
/// This mirrors the `OperationCompletion` pattern
/// (`@LockIsolated didComplete`) already used for continuation
/// safety, applied independently to health sample recording.
final class HealthSampleToken: @unchecked Sendable {
    // MARK: - Properties

    @LockIsolated private var didRecord = false

    // MARK: - Methods

    /// Atomically attempts to claim the token.
    ///
    /// - Returns: `true` if this caller won the claim (and
    ///   should record a sample); `false` if another caller
    ///   already claimed it.
    func claim() -> Bool {
        $didRecord.withValue {
            guard !$0 else { return false }
            $0 = true
            return true
        }
    }
}
