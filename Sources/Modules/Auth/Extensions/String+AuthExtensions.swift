//
//  String+AuthExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension String {
    var digits: String {
        components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}
