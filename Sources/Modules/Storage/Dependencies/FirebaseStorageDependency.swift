//
//  FirebaseStorageDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseStorage

enum FirebaseStorageDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> StorageReference {
        FirebaseStorage.Storage.storage().reference()
    }
}

extension DependencyValues {
    var firebaseStorage: StorageReference {
        get { self[FirebaseStorageDependency.self] }
        set { self[FirebaseStorageDependency.self] = newValue }
    }
}
