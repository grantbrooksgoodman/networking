//
//  GuardedOperation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Shared precondition, timeout, and settlement machinery
/// for one-shot network operations.
///
/// `GuardedOperation` centralizes the boilerplate that
/// every network operation performs around its actual
/// work: read-write enablement and connectivity checks,
/// single-settlement protection, timeout arming, and –
/// where enabled – network activity indication and
/// censored health sample recording on timeout.
///
/// Operation coalescing is deliberately not provided
/// here; it remains the sole responsibility of each
/// service's `performOperation` entry point.
enum GuardedOperation {
    // MARK: - Methods

    /// Validates that network operations are currently
    /// permitted.
    ///
    /// - Parameter sender: The service on whose behalf
    ///   the check is performed.
    ///
    /// - Throws: An `Exception` if read-write access is
    ///   disabled or no internet connection is available.
    static func checkPreconditions(
        sender: any Sendable
    ) throws(Exception) {
        @Dependency(\.build.isOnline) var isOnline: Bool

        guard Networking.isReadWriteEnabled else {
            throw .Networking.readWriteAccessDisabled(
                .init(sender: sender)
            )
        }

        guard isOnline else {
            throw .internetConnectionOffline(
                metadata: .init(sender: sender)
            )
        }
    }

    /// Runs a network operation with precondition checks,
    /// a timeout, and single-settlement protection.
    ///
    /// The body receives a health sample token and a
    /// `settle` closure, performs its work, and calls
    /// `settle` exactly once with the result. Late or
    /// duplicate settlements are ignored. If the timeout
    /// elapses before the body settles, the operation
    /// throws `Exception.timedOut` – recording a censored
    /// health sample first when
    /// `recordsCensoredSampleOnTimeout` is `true`.
    ///
    /// Cancellation is cooperative: if the calling task is
    /// cancelled – on entry, in which case the body is
    /// never invoked, or while awaiting settlement – the
    /// operation throws a cancellation `Exception`
    /// immediately. The in-flight work itself is never
    /// interrupted; it continues until it settles or times
    /// out, with late results absorbed by the
    /// single-settlement guard.
    ///
    /// - Parameters:
    ///   - duration: The maximum time to wait before the
    ///     operation times out.
    ///   - recordsCensoredSampleOnTimeout: A Boolean
    ///     value that determines whether a censored
    ///     latency sample is recorded when the timeout
    ///     elapses.
    ///   - showsActivityIndicator: A Boolean value that
    ///     determines whether the network activity
    ///     indicator is shown for the operation's
    ///     duration.
    ///   - sender: The service on whose behalf the
    ///     operation is performed.
    ///   - body: A closure that performs the operation
    ///     and settles it with a result.
    ///
    /// - Returns: The value the body settled with.
    ///
    /// - Throws: An `Exception` if a precondition fails,
    ///   the timeout elapses, the calling task is
    ///   cancelled, or the body settles with a failure.
    @discardableResult
    static func run(
        timeout duration: Duration,
        recordsCensoredSampleOnTimeout: Bool,
        showsActivityIndicator: Bool,
        sender: any Sendable,
        _ body: @escaping @Sendable (
            _ healthToken: HealthSampleToken,
            _ settle: @Sendable @escaping (Result<Any?, Exception>) -> Void
        ) -> Void
    ) async throws(Exception) -> Any? {
        guard !Task.isCancelled else {
            throw .cancelled(
                metadata: .init(sender: sender)
            )
        }

        try checkPreconditions(sender: sender)
        if showsActivityIndicator {
            Networking.config.activityIndicatorDelegate.show()
        }

        // The settlement flow runs in its own task so that a
        // cancelled caller can abandon the wait; the timeout bounds
        // the task's lifetime regardless of whether anyone is still
        // awaiting it.
        let operationTask = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<LockIsolated<Result<Any?, Exception>>, Never>) in
                @LockIsolated var didSettle = false
                var canSettle: Bool {
                    $didSettle.withValue {
                        guard !$0 else { return false }
                        $0 = true
                        return true
                    }
                }

                let healthToken = HealthSampleToken()
                let timeout = Timeout(after: duration) {
                    guard canSettle else { return }

                    if showsActivityIndicator {
                        Networking.config.activityIndicatorDelegate.hide()
                    }

                    if recordsCensoredSampleOnTimeout,
                       healthToken.claim() {
                        Networking.config.healthDelegate.recordCensoredLatencySample(
                            seconds: duration.timeInterval
                        )
                    }

                    let timedOutResult: Result<Any?, Exception> = .failure(.timedOut(
                        metadata: .init(sender: sender)
                    ))

                    continuation.resume(
                        returning: LockIsolated(timedOutResult)
                    )
                }

                body(healthToken) { result in
                    timeout.cancel()
                    guard canSettle else { return }

                    if showsActivityIndicator {
                        Networking.config.activityIndicatorDelegate.hide()
                    }

                    // LockIsolated transfer satisfies resume's `sending` requirement.
                    continuation.resume(returning: LockIsolated(result))
                }
            }
        }

        guard let result = try? await operationTask.abandonableValue() else {
            throw .cancelled(
                metadata: .init(sender: sender)
            )
        }

        switch result.wrappedValue {
        case let .success(value): return value
        case let .failure(exception): throw exception
        }
    }
}
