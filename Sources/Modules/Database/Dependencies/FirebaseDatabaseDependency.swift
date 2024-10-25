//
//  FirebaseDatabaseDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseDatabase

enum FirebaseDatabaseDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> DatabaseReference {
        FirebaseDatabase.Database.database().reference()
    }
}

extension DependencyValues {
    var firebaseDatabase: DatabaseReference {
        get { self[FirebaseDatabaseDependency.self] }
        set { self[FirebaseDatabaseDependency.self] = newValue }
    }
}
