//
//  FirebasePhoneAuthProviderDependency.swift
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

enum FirebasePhoneAuthProviderDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> PhoneAuthProvider {
        .provider()
    }
}

extension DependencyValues {
    var firebasePhoneAuthProvider: PhoneAuthProvider {
        get { self[FirebasePhoneAuthProviderDependency.self] }
        set { self[FirebasePhoneAuthProviderDependency.self] = newValue }
    }
}
