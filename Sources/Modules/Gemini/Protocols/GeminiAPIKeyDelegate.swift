//
//  GeminiAPIKeyDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// An interface for providing a Gemini API key.
///
/// Conform to `GeminiAPIKeyDelegate` and register your
/// implementation with
/// ``Networking/Config/registerGeminiAPIKeyDelegate(_:)``
/// to enable AI-enhanced translations.
// swiftlint:disable:next class_delegate_protocol
public protocol GeminiAPIKeyDelegate {
    /// The API key used to authenticate requests to the
    /// Gemini API.
    var apiKey: String { get }
}
