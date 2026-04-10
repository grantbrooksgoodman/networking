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

// swiftlint:disable:next class_delegate_protocol
public protocol NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    @MainActor
    var backgroundColor: Color { get }

    @MainActor
    var progressViewTintColor: Color { get }

    // MARK: - Methods

    func show()
    func hide()
}

public struct DefaultNetworkActivityIndicatorDelegate: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    @MainActor
    public let progressViewTintColor: Color = .white

    // MARK: - Computed Properties

    @MainActor
    public var backgroundColor: Color { .accent }

    // MARK: - Init

    public init() {}

    // MARK: - Methods

    public func show() {
        Task { @MainActor in
            Observables.isNetworkActivityOccurring.value = true
        }
    }

    public func hide() {
        Task { @MainActor in
            Observables.isNetworkActivityOccurring.value = false
        }
    }
}
