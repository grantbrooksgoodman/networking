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
            return try await firebaseAuth
                .signIn(with: credential)
                .user
                .uid
        } catch {
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
}
