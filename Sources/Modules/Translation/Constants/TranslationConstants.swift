//
//  TranslationConstants.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum TranslationConstants {
    static let idempotentPrefix = "IDEM "
    static let translationDataSampleExpiryThreshold: Duration = .seconds(300)
    static let translationDataSampleRefreshInterval: Duration = .seconds(240)
}
