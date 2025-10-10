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

public extension Exception {
    enum Networking {
        // MARK: - Public

        public static func decodingFailed(
            data: Any,
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Decoding failed.",
                userInfo: ["Data": data],
                metadata: metadata
            )
        }

        public static func invalidType(
            value: Any,
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Serialized type values must conform to NSArray, NSDictionary, NSNull, NSNumber, or NSString.",
                userInfo: ["Value": value],
                metadata: metadata
            )
        }

        public static func notSerialized(
            data: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            return .init(
                "Type value must be serialized.",
                userInfo: ["Data": data],
                metadata: metadata
            )
        }

        public static func notUpdatable(
            key: Any,
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "The specified serialization key is not updatable.",
                userInfo: ["Key": key],
                metadata: metadata
            )
        }

        public static func typecastFailed(
            _ typeName: String? = nil,
            userInfo: [String: Any]? = nil,
            metadata: [Any]
        ) -> Exception {
            .init(
                "Failed to typecast values \(typeName == nil ? "." : "to \(typeName!).")",
                userInfo: userInfo,
                metadata: metadata
            )
        }

        public static func typeMismatch(
            key: Any,
            _ metadata: [Any]
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
            _ metadata: [Any]
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
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Input fails validation.",
                userInfo: userInfo,
                metadata: metadata
            )
        }

        static func languagePairFailsValidation(
            userInfo: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Language pair fails validation.",
                userInfo: userInfo,
                metadata: metadata
            )
        }

        static func readWriteAccessDisabled(_ metadata: [Any]) -> Exception {
            .init(
                "Read/write access has been disabled.",
                isReportable: false,
                metadata: [self, #file, #function, #line]
            )
        }

        static func translationFailsValidation(
            userInfo: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Translation fails validation.",
                userInfo: userInfo,
                metadata: metadata
            )
        }
    }
}
