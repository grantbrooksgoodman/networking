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

    var backgroundColor: Color { get }
    var progressViewTintColor: Color { get }

    // MARK: - Methods

    func show()
    func hide()
}

public struct DefaultNetworkActivityIndicatorDelegate: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    public let progressViewTintColor: Color = .white

    // MARK: - Computed Properties

    public var backgroundColor: Color { .accent }

    // MARK: - Init

    public init() {}

    // MARK: - Methods

    public func show() {
        Observables.isNetworkActivityOccurring.value = true
    }

    public func hide() {
        Observables.isNetworkActivityOccurring.value = false
    }
}
