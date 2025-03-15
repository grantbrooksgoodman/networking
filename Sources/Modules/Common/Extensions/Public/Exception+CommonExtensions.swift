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
