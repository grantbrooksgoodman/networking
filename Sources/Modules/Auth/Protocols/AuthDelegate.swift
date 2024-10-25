//
//  AuthDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// swiftlint:disable:next class_delegate_protocol
public protocol AuthDelegate {
    /// - Returns: On success, a string representing the user's ID.
    func authenticateUser(
        authID: String,
        verificationCode: String
    ) async -> Callback<String, Exception>

    /// - Returns: On success, a string representing the phone number verification ID.
    func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String
    ) async -> Callback<String, Exception>
}

public extension AuthDelegate {
    func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String = RuntimeStorage.languageCode
    ) async -> Callback<String, Exception> {
        await verifyPhoneNumber(
            internationalNumber: internationalNumber,
            languageCode: languageCode
        )
    }
}
