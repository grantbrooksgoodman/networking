//
//  GeminiAPIKeyDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// swiftlint:disable:next class_delegate_protocol
public protocol GeminiAPIKeyDelegate {
    var apiKey: String { get }
}
