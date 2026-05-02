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

    // MARK: - Methods

    /// Shows the network activity indicator.
    func show()

    /// Hides the network activity indicator.
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

    // MARK: - Computed Properties

    /// The background color of the indicator.
    @MainActor
    public var backgroundColor: Color? { nil }

    // MARK: - Init

    /// Creates a default network activity indicator
    /// delegate.
    public init() {}

    // MARK: - Methods

    /// Shows the network activity indicator.
    public func show() {
        Task { @MainActor in
            Observables.isNetworkActivityOccurring.value = true
        }
    }

    /// Hides the network activity indicator.
    public func hide() {
        Task { @MainActor in
            Observables.isNetworkActivityOccurring.value = false
        }
    }
}
