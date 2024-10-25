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
                extraParams: ["Data": data],
                metadata: metadata
            )
        }

        public static func invalidType(
            value: Any,
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Serialized type values must conform to NSArray, NSDictionary, NSNull, NSNumber, or NSString.",
                extraParams: ["Value": value],
                metadata: metadata
            )
        }

        public static func notSerialized(
            data: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            return .init(
                "Type value must be serialized.",
                extraParams: ["Data": data],
                metadata: metadata
            )
        }

        public static func notUpdatable(
            key: Any,
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "The specified serialization key is not updatable.",
                extraParams: ["Key": key],
                metadata: metadata
            )
        }

        public static func typecastFailed(
            _ typeName: String? = nil,
            extraParams: [String: Any]? = nil,
            metadata: [Any]
        ) -> Exception {
            .init(
                "Failed to typecast values \(typeName == nil ? "." : "to \(typeName!).")",
                extraParams: extraParams,
                metadata: metadata
            )
        }

        public static func typeMismatch(
            key: Any,
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Type mismatch for serialization key.",
                extraParams: ["Key": key],
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
                    extraParams: [
                        "Path": path,
                        "StaticHashlet": "9207",
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
            extraParams: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Input fails validation.",
                extraParams: extraParams,
                metadata: metadata
            )
        }

        static func languagePairFailsValidation(
            extraParams: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Language pair fails validation.",
                extraParams: extraParams,
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
            extraParams: [String: Any],
            _ metadata: [Any]
        ) -> Exception {
            .init(
                "Translation fails validation.",
                extraParams: extraParams,
                metadata: metadata
            )
        }
    }
}
