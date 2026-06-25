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

/// An interface for managing user authentication.
///
/// `AuthDelegate` supports two authentication modes:
///
/// - **Anonymous sign-in.** Call
///   ``signInAnonymously()`` at launch to establish a
///   lightweight session that satisfies backend security
///   rules before the user completes phone verification.
///
/// - **Phone verification.** Request a verification code
///   by calling
///   ``verifyPhoneNumber(internationalNumber:languageCode:)``,
///   then complete sign-in by passing the returned
///   verification ID and the user-entered code to
///   ``authenticateUser(authID:verificationCode:)``:
///
/// ```swift
/// // 1. Establish an anonymous session at launch.
/// _ = try await auth.signInAnonymously()
///
/// // 2. Later, verify the user's phone number.
/// let authID = try await auth.verifyPhoneNumber(
///     internationalNumber: "15551234567"
/// )
///
/// // 3. Complete sign-in (links the phone credential
/// //    to the anonymous session automatically).
/// let userID = try await auth.authenticateUser(
///     authID: authID,
///     verificationCode: userEnteredCode
/// )
/// ```
///
/// A default implementation backed by Firebase
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
    /// When the current session is anonymous, the default
    /// implementation links the phone credential to that
    /// session, preserving the existing user identifier. If
    /// the phone number is already associated with another
    /// account, the method falls back to a standard sign-in
    /// and returns the existing account's identifier
    /// instead.
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

    /// Establishes an anonymous authentication session.
    ///
    /// Call this method before the user completes phone
    /// verification to obtain a valid session that satisfies
    /// backend security rules. If a persisted session already
    /// exists, the method returns its identifier without
    /// creating a new one.
    ///
    /// - Returns: A string representing the user's ID.
    ///
    /// - Throws: An ``Exception`` if sign-in fails.
    func signInAnonymously() async throws(Exception) -> String

    /// Ends the current authentication session.
    ///
    /// Call this method to sign out the current user and
    /// clear the persisted session. Subsequent requests to
    /// the backend are unauthenticated until a new session
    /// is established.
    ///
    /// - Throws: An ``Exception`` if sign-out fails.
    func signOut() throws(Exception)

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
