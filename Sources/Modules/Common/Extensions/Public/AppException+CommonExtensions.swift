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

/// A namespace for catalogued networking exception
/// identifiers.
///
/// Use these constants to compare an `Exception` against
/// a known networking error condition:
///
/// ```swift
/// if exception.isEqual(
///     to: .Networking.Database.noValueExists
/// ) {
///     // Handle missing value.
/// }
/// ```
public extension AppException {
    enum Networking {
        /// Catalogued database exceptions.
        public enum Database {
            /// No value exists at the specified path.
            public static let noValueExists: AppException = .init("BE3A")
        }

        /// Catalogued serialization exceptions.
        public enum Serializable {
            /// Decoding the serialized data failed.
            public static let decodingFailed: AppException = .init("20FC")

            /// The type value was not serialized.
            public static let notSerialized: AppException = .init("7CC2")

            /// The serialization key is not updatable.
            public static let notUpdatable: AppException = .init("6446")

            /// A type mismatch occurred for a
            /// serialization key.
            public static let typeMismatch: AppException = .init("8117")
        }

        /// Catalogued storage exceptions.
        public enum Storage {
            /// A generic storage error occurred.
            public static let genericStorageError: AppException = .init("C81B") // TODO: Needs re-evaluation.

            /// The specified storage item does not exist.
            public static let storageItemDoesNotExist: AppException = .init("9207")
        }

        /// Catalogued translation exceptions.
        public enum Translation {
            /// All available translation platforms have
            /// been exhausted without success.
            public static let exhaustedAvailablePlatforms: AppException = .init("C526")

            /// The translation input and output are
            /// identical.
            public static let sameTranslationInputOutput: AppException = .init("6CEB")

            /// Derivation of the translation failed.
            public static let translationDerivationFailed: AppException = .init("43B4")
        }
    }
}
