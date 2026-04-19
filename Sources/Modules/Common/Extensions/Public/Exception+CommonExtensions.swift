//
//  Exception+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// A namespace for factory methods that create
/// networking-specific exceptions.
///
/// Use the methods on `Exception.Networking` to create
/// exceptions with descriptive context for common
/// networking error conditions:
///
/// ```swift
/// return .failure(
///     .Networking.decodingFailed(
///         data: rawData,
///         .init(sender: self)
///     )
/// )
/// ```
public extension Exception {
    enum Networking {
        // MARK: - Public

        /// Creates an exception indicating that decoding
        /// the specified data failed.
        ///
        /// - Parameters:
        ///   - data: The data that could not be decoded.
        ///   - metadata: The exception metadata.
        public static func decodingFailed(
            data: Any,
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Decoding failed.",
                userInfo: ["Data": data],
                metadata: metadata
            )
        }

        /// Creates an exception indicating that a
        /// serialized value does not conform to a
        /// supported Foundation type.
        ///
        /// - Parameters:
        ///   - value: The unsupported value.
        ///   - metadata: The exception metadata.
        public static func invalidType(
            value: Any,
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Serialized type values must conform to NSArray, NSDictionary, NSNull, NSNumber, or NSString.",
                userInfo: ["Value": value],
                metadata: metadata
            )
        }

        /// Creates an exception indicating that a type
        /// value was not serialized before use.
        ///
        /// - Parameters:
        ///   - data: The unserialized data.
        ///   - metadata: The exception metadata.
        public static func notSerialized(
            data: [String: Any],
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Type value must be serialized.",
                userInfo: ["Data": data],
                metadata: metadata
            )
        }

        /// Creates an exception indicating that the
        /// specified serialization key is not updatable.
        ///
        /// - Parameters:
        ///   - key: The key that was not updatable.
        ///   - metadata: The exception metadata.
        public static func notUpdatable(
            key: Any,
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "The specified serialization key is not updatable.",
                userInfo: ["Key": key],
                metadata: metadata
            )
        }

        /// Creates an exception indicating that a
        /// typecast operation failed.
        ///
        /// - Parameters:
        ///   - typeName: The name of the target type.
        ///     Pass `nil` for a generic failure message.
        ///   - userInfo: A dictionary of supplementary
        ///     information. The default is `nil`.
        ///   - metadata: The exception metadata.
        public static func typecastFailed(
            _ typeName: String? = nil,
            userInfo: [String: Any]? = nil,
            metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Failed to typecast values \(typeName == nil ? "." : "to \(typeName!).")",
                userInfo: userInfo,
                metadata: metadata
            )
        }

        /// Creates an exception indicating a type mismatch
        /// for the specified serialization key.
        ///
        /// - Parameters:
        ///   - key: The key with the mismatched type.
        ///   - metadata: The exception metadata.
        public static func typeMismatch(
            key: Any,
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Type mismatch for serialization key.",
                userInfo: ["Key": key],
                metadata: metadata
            )
        }

        // MARK: - Internal

        static func hostedItemTypeMismatch(
            at path: String,
            type: HostedItemType?,
            _ metadata: ExceptionMetadata
        ) -> Exception {
            func exception(_ descriptor: String) -> Exception {
                .init(
                    descriptor,
                    userInfo: [
                        "Path": path,
                        "StaticErrorCode": "9207",
                    ],
                    metadata: metadata
                )
            }

            guard let type else { return exception("No item exists at the specified key path.") }

            let actualType = type == .directory ? "file" : "directory"
            let expectedType = type == .directory ? "directory" : "file"

            return exception(
                "Specified key path points to an existing \(actualType), not a \(expectedType)."
            )
        }

        static func inputsFailValidation(
            userInfo: [String: Any],
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Input fails validation.",
                userInfo: userInfo,
                metadata: metadata
            )
        }

        static func languagePairFailsValidation(
            userInfo: [String: Any],
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Language pair fails validation.",
                userInfo: userInfo,
                metadata: metadata
            )
        }

        static func readWriteAccessDisabled(_ metadata: ExceptionMetadata) -> Exception {
            .init(
                "Read/write access has been disabled.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        static func translationFailsValidation(
            userInfo: [String: Any],
            _ metadata: ExceptionMetadata
        ) -> Exception {
            .init(
                "Translation fails validation.",
                userInfo: userInfo,
                metadata: metadata
            )
        }
    }
}
