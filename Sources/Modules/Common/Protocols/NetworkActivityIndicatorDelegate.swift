//
//  NetworkActivityIndicatorDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// swiftlint:disable:next class_delegate_protocol
public protocol NetworkActivityIndicatorDelegate {
    func show()
    func hide()
}

public struct DefaultNetworkActivityIndicatorDelegate: NetworkActivityIndicatorDelegate {
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
