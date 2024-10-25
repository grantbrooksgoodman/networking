//
//  String+TranslationExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension String {
    var alphaEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }

    var base64Decoded: String {
        guard let data = Data(base64Encoded: self),
              let string = String(data: data, encoding: .utf8) else { return self }
        return string
    }

    var base64Encoded: String {
        data(using: .utf8)?.base64EncodedString() ?? self
    }

    var decodedTranslationComponents: (input: String, output: String)? {
        let components = components(separatedBy: "–")
        guard components.count == 2,
              let inputString = components[0].removingPercentEncoding,
              let outputString = components[1].removingPercentEncoding else { return nil }
        return (inputString, outputString)
    }
}
