//
//  GeminiAPIKeyDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public protocol GeminiAPIKeyDelegate {
    var apiKey: String { get }
}
