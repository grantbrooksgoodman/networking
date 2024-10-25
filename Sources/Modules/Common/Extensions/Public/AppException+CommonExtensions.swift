//
//  AppException+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension AppException {
    enum Networking {
        public enum Database {
            public static let noValueExists: AppException = .init("BE3A")
        }

        public enum Serializable {
            public static let decodingFailed: AppException = .init("20FC")
            public static let notSerialized: AppException = .init("7CC2")
            public static let notUpdatable: AppException = .init("6446")
            public static let typeMismatch: AppException = .init("8117")
        }

        public enum Storage {
            public static let genericStorageError: AppException = .init("C81B") // TODO: Needs re-evaluation.
            public static let storageItemDoesNotExist: AppException = .init("9207")
        }

        public enum Translation {
            public static let exhaustedAvailablePlatforms: AppException = .init("C526")
            public static let sameTranslationInputOutput: AppException = .init("6CEB")
            public static let translationDerivationFailed: AppException = .init("43B4")
        }
    }
}
