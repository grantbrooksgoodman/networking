//
//  NetworkActivityIndicatorDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// swiftlint:disable:next class_delegate_protocol
public protocol NetworkActivityIndicatorDelegate {
    func show()
    func hide()
}

public struct DefaultNetworkActivityIndicatorDelegate: NetworkActivityIndicatorDelegate {
    public func show() {}
    public func hide() {}
}
