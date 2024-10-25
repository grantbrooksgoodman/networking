//
//  String+StorageExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension String {
    var fileName: String? {
        guard let fileNamePlusExtension = components(separatedBy: "/").last,
              fileNamePlusExtension
              .components(separatedBy: ".")
              .last?
              .isBlank == false else { return nil }
        return fileNamePlusExtension
    }
}
