//
//  FirebaseAuthDependency.swift
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

enum FirebaseAuthDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> FirebaseAuth.Auth {
        .auth()
    }
}

extension DependencyValues {
    var firebaseAuth: FirebaseAuth.Auth {
        get { self[FirebaseAuthDependency.self] }
        set { self[FirebaseAuthDependency.self] = newValue }
    }
}
