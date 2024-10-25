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
    static func decodingFailed(
        data: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Decoding failed.",
            extraParams: ["Data": data],
            metadata: metadata
        )
    }

    static func notSerialized(
        data: [String: Any],
        _ metadata: [Any]
    ) -> Exception {
        return .init(
            "Type value must be serialized.",
            extraParams: ["Data": data],
            metadata: metadata
        )
    }

    static func notUpdatable(
        key: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "The specified serialization key is not updatable.",
            extraParams: ["Key": key],
            metadata: metadata
        )
    }

    static func typeMismatch(
        key: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Type mismatch for serialization key.",
            extraParams: ["Key": key],
            metadata: metadata
        )
    }
}
