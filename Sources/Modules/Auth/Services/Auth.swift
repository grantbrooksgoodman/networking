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
    ) async -> Callback<String, Exception> {
        guard Networking.isReadWriteEnabled else {
            return .failure(.Networking.readWriteAccessDisabled(.init(sender: self)))
        }

        guard isOnline else {
            return .failure(.internetConnectionOffline(metadata: .init(sender: self)))
        }

        Networking.config.activityIndicatorDelegate.show()

        let credential = phoneAuthProvider.credential(withVerificationID: authID, verificationCode: verificationCode)

        do {
            let signInResult = try await firebaseAuth.signIn(with: credential)
            Networking.config.activityIndicatorDelegate.hide()
            return .success(signInResult.user.uid)
        } catch {
            Networking.config.activityIndicatorDelegate.hide()
            return .failure(.init(error, metadata: .init(sender: self)))
        }
    }

    // MARK: - Phone Number Verification

    func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String
    ) async -> Callback<String, Exception> {
        guard Networking.isReadWriteEnabled else {
            return .failure(.Networking.readWriteAccessDisabled(.init(sender: self)))
        }

        guard isOnline else {
            return .failure(.internetConnectionOffline(metadata: .init(sender: self)))
        }

        Networking.config.activityIndicatorDelegate.show()
        firebaseAuth.languageCode = languageCode

        let formattedNumber = "+\(internationalNumber.digits)"
        do {
            let authID = try await phoneAuthProvider.verifyPhoneNumber(formattedNumber, uiDelegate: nil)
            Networking.config.activityIndicatorDelegate.hide()
            return .success(authID)
        } catch {
            Networking.config.activityIndicatorDelegate.hide()
            return .failure(.init(error, metadata: .init(sender: self)))
        }
    }
}
