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

/// An interface for authenticating users with phone number
/// verification.
///
/// Adopt `AuthDelegate` to perform two-step phone
/// authentication. First, request a verification code by
/// calling
/// ``verifyPhoneNumber(internationalNumber:languageCode:)``.
/// Then, complete sign-in by passing the returned
/// verification ID and the user-entered code to
/// ``authenticateUser(authID:verificationCode:)``:
///
/// ```swift
/// let authID = try await auth.verifyPhoneNumber(
///     internationalNumber: "15551234567"
/// )
///
/// let userID = try await auth.authenticateUser(
///     authID: authID,
///     verificationCode: userEnteredCode
/// )
/// ```
///
/// A default implementation backed by Firebase Phone
/// Authentication is provided automatically. To supply a
/// custom conformance, register it with
/// ``Networking/Config/registerAuthDelegate(_:)``.
// swiftlint:disable:next class_delegate_protocol
public protocol AuthDelegate {
    /// Signs in the user with a phone authentication
    /// credential.
    ///
    /// Call this method after the user receives and enters
    /// the verification code sent by
    /// ``verifyPhoneNumber(internationalNumber:languageCode:)``.
    ///
    /// - Parameters:
    ///   - authID: The verification ID returned by a prior
    ///     call to
    ///     ``verifyPhoneNumber(internationalNumber:languageCode:)``.
    ///   - verificationCode: The one-time code the user
    ///     received via SMS.
    ///
    /// - Returns: A string representing the user's ID.
    ///
    /// - Throws: An ``Exception`` if sign-in fails.
    func authenticateUser(
        authID: String,
        verificationCode: String
    ) async throws(Exception) -> String

    /// Sends a verification code to the specified phone
    /// number.
    ///
    /// This method initiates phone authentication by
    /// requesting that a one-time code be sent via SMS.
    /// Pass the returned verification ID – along with the
    /// code the user enters – to
    /// ``authenticateUser(authID:verificationCode:)`` to
    /// complete sign-in.
    ///
    /// - Parameters:
    ///   - internationalNumber: The phone number to verify,
    ///     in international format (for example,
    ///     `"15551234567"`).
    ///   - languageCode: A language code used to localize
    ///     the verification SMS.
    ///
    /// - Returns: A string representing the phone number
    ///   verification ID.
    ///
    /// - Throws: An ``Exception`` if verification fails.
    func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String
    ) async throws(Exception) -> String
}

public extension AuthDelegate {
    /// Sends a verification code to the specified phone
    /// number.
    ///
    /// This method calls
    /// ``verifyPhoneNumber(internationalNumber:languageCode:)``
    /// with `RuntimeStorage.languageCode` as the default
    /// language code.
    ///
    /// - Parameters:
    ///   - internationalNumber: The phone number to verify,
    ///     in international format (for example,
    ///     `"15551234567"`).
    ///   - languageCode: A language code used to localize
    ///     the verification SMS. The default is
    ///     `RuntimeStorage.languageCode`.
    ///
    /// - Returns: A string representing the phone number
    ///   verification ID.
    ///
    /// - Throws: An ``Exception`` if verification fails.
    func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String = RuntimeStorage.languageCode
    ) async throws(Exception) -> String {
        try await verifyPhoneNumber(
            internationalNumber: internationalNumber,
            languageCode: languageCode
        )
    }
}
