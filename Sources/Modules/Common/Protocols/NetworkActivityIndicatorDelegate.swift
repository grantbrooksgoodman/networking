//
//  NetworkActivityIndicatorDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/// An interface for controlling the display of a network
/// activity indicator.
///
/// Adopt `NetworkActivityIndicatorDelegate` to customize
/// the appearance and behavior of the indicator shown
/// during network operations. Register your implementation
/// with
/// ``Networking/Config/registerActivityIndicatorDelegate(_:)``.
///
/// The framework provides
/// ``DefaultNetworkActivityIndicatorDelegate`` for
/// standard behavior.
// swiftlint:disable:next class_delegate_protocol
public protocol NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    /// The background color of the indicator.
    @MainActor
    var backgroundColor: Color? { get }

    /// The tint color of the progress view inside the
    /// indicator.
    @MainActor
    var progressViewTintColor: Color? { get }

    /// The action to perform when the indicator is tapped.
    ///
    /// Return `nil` to use the default behavior, which
    /// presents an alert summarizing the current network
    /// health.
    @MainActor
    var tapAction: (() -> Void)? { get }

    // MARK: - Methods

    /// Shows the network activity indicator.
    ///
    /// The framework calls this method once for each
    /// in-flight network operation. Balance every call with
    /// a corresponding call to ``hide()``.
    func show()

    /// Hides the network activity indicator.
    ///
    /// The framework calls this method once for each network
    /// operation that finishes. Each call balances a prior
    /// call to ``show()``.
    func hide()
}

/// A network activity indicator delegate that provides
/// default appearance and behavior.
public struct DefaultNetworkActivityIndicatorDelegate: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    /// The tint color of the progress view. The default
    /// is ``Color/white``.
    @MainActor
    public let progressViewTintColor: Color? = .white

    private static let activityReferenceCount = LockIsolated(0)

    // MARK: - Computed Properties

    /// The background color of the indicator. The default
    /// reflects the current network health tier: green for
    /// good, orange for fair, red for poor, and `nil`
    /// (transparent) when health is unknown.
    @MainActor
    public var backgroundColor: Color? {
        switch Networking.config.healthDelegate.health.tier {
        case .fair: .orange
        case .good: .green
        case .poor: .red
        case nil: nil
        }
    }

    // MARK: - Init

    /// Creates a default network activity indicator
    /// delegate.
    public init() {}

    // MARK: - Methods

    /// Increments the count of in-flight network operations,
    /// showing the network activity indicator if it is not
    /// already visible.
    ///
    /// Balance every call with a corresponding call to
    /// ``hide()``. The indicator remains visible until every
    /// in-flight operation has been balanced.
    public func show() {
        Self.activityReferenceCount.projectedValue.withValue { $0 += 1 }
        Self.synchronizeIndicatorVisibility()
    }

    /// Decrements the count of in-flight network operations,
    /// hiding the network activity indicator when no
    /// operations remain.
    ///
    /// Each call balances a prior call to ``show()``. Calls
    /// that would drive the count below zero have no effect.
    public func hide() {
        Self.activityReferenceCount.projectedValue.withValue { $0 = max(0, $0 - 1) }
        Self.synchronizeIndicatorVisibility()
    }

    // MARK: - Auxiliary

    private static func synchronizeIndicatorVisibility() {
        Task { @MainActor in
            SharedState(\.isNetworkActivityOccurring).wrappedValue = activityReferenceCount.wrappedValue > 0
        }
    }
}

public extension NetworkActivityIndicatorDelegate {
    /// The background color of the indicator.
    ///
    /// This default implementation returns `nil`, which
    /// causes the indicator's background color to adopt
    /// a system blue color.
    @MainActor
    var backgroundColor: Color? {
        nil
    }

    /// The action to perform when the indicator is tapped.
    ///
    /// This default implementation returns `nil`, which
    /// causes the indicator to present an alert summarizing
    /// the current network health.
    @MainActor
    var tapAction: (() -> Void)? {
        nil
    }
}
