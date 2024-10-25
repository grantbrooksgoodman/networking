//
//  Exception+DatabaseExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Proprietary */
import AppSubsystem

/* Native */
import Foundation

extension Exception {
    static func invalidType(
        value: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Serialized type values must conform to NSArray, NSDictionary, NSNull, NSNumber, or NSString.",
            extraParams: ["Value": value],
            metadata: metadata
        )
    }
}
