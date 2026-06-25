//
//  Auth.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseAuth

struct Auth: AuthDelegate {
    // MARK: - Dependencies

    @Dependency(\.firebaseAuth) private var firebaseAuth: FirebaseAuth.Auth
    @Dependency(\.build.isOnline) private var isOnline: Bool
    @Dependency(\.firebasePhoneAuthProvider) private var phoneAuthProvider: PhoneAuthProvider

    // MARK: - Anonymous Sign-In

    func signInAnonymously() async throws(Exception) -> String {
        guard Networking.isReadWriteEnabled else {
            throw .Networking.readWriteAccessDisabled(
                .init(sender: self)
            )
        }

        guard isOnline else {
            throw .internetConnectionOffline(
                metadata: .init(sender: self)
            )
        }

        if let currentUser = firebaseAuth.currentUser {
            return currentUser.uid
        }

        do {
            return try await firebaseAuth
                .signInAnonymously()
                .user
                .uid
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    // MARK: - Authentication with Verification Code

    func authenticateUser(
        authID: String,
        verificationCode: String
    ) async throws(Exception) -> String {
        guard Networking.isReadWriteEnabled else {
            throw .Networking.readWriteAccessDisabled(
                .init(sender: self)
            )
        }

        guard isOnline else {
            throw .internetConnectionOffline(
                metadata: .init(sender: self)
            )
        }

        Networking.config.activityIndicatorDelegate.show()
        defer { Networking.config.activityIndicatorDelegate.hide() }

        let credential = phoneAuthProvider.credential(
            withVerificationID: authID,
            verificationCode: verificationCode
        )

        do {
            if let currentUser = firebaseAuth.currentUser,
               currentUser.isAnonymous {
                return try await currentUser
                    .link(with: credential)
                    .user
                    .uid
            }

            return try await firebaseAuth
                .signIn(with: credential)
                .user
                .uid
        } catch {
            // If linking fails because the phone number
            // already belongs to an existing account, fall
            // back to a standard sign-in with the updated
            // credential from the error.
            let nsError = error as NSError
            if nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue,
               let updatedCredential = nsError.userInfo[
                   AuthErrorUserInfoUpdatedCredentialKey
               ] as? AuthCredential {
                do {
                    return try await firebaseAuth
                        .signIn(with: updatedCredential)
                        .user
                        .uid
                } catch {
                    throw Exception(
                        error,
                        metadata: .init(sender: self)
                    )
                }
            }

            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    // MARK: - Phone Number Verification

    func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String
    ) async throws(Exception) -> String {
        guard Networking.isReadWriteEnabled else {
            throw .Networking.readWriteAccessDisabled(
                .init(sender: self)
            )
        }

        guard isOnline else {
            throw .internetConnectionOffline(
                metadata: .init(sender: self)
            )
        }

        Networking.config.activityIndicatorDelegate.show()
        defer { Networking.config.activityIndicatorDelegate.hide() }

        firebaseAuth.languageCode = languageCode

        let formattedNumber = "+\(internationalNumber.digits)"
        do {
            return try await phoneAuthProvider.verifyPhoneNumber(
                formattedNumber,
                uiDelegate: nil
            )
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    // MARK: - Sign-Out

    func signOut() throws(Exception) {
        do {
            try firebaseAuth.signOut()
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }
}
