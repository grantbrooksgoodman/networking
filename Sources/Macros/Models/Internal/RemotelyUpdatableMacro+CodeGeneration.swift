//
//  RemotelyUpdatableMacro+CodeGeneration.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension RemotelyUpdatableMacro {
    static func generateCopyingMethod(
        typeName: String,
        targetParameter: InitializerParameter,
        targetIndex: Int,
        allParameters: [InitializerParameter]
    ) -> String {
        let parameterName = targetParameter.internalName
        let parameterType = targetParameter.typeName

        var initializerArguments = [String]()
        for (parameterIndex, parameter) in allParameters.enumerated() {
            let argumentValue = parameterIndex == targetIndex ? parameterName : "self.\(parameter.internalName)"
            if parameter.isUnlabeled {
                initializerArguments.append(argumentValue)
            } else {
                let argumentLabel = parameter.externalLabel ?? parameter.internalName
                initializerArguments.append("\(argumentLabel): \(argumentValue)")
            }
        }

        let initializerCall = initializerArguments.joined(separator: ", ")
        return """
        func copying(\(parameterName): \(parameterType)) -> \(typeName) {
            .init(\(initializerCall))
        }
        """
    }

    static func generateModifyKeyMethod(
        typeName: String,
        keyTypeName: String,
        exposedKeys: [UpdatableKeyInfo],
        allParameters: [InitializerParameter]
    ) -> String {
        var switchCases = [String]()

        for exposedKey in exposedKeys {
            let unwrappedTypeName = strippingOptionalWrapper(
                from: exposedKey.propertyType
            )

            let copyExpression = transformExpression(
                forProperty: exposedKey.propertyName,
                nilCondition: exposedKey.nilCondition
            )

            switchCases.append(
                "case .\(exposedKey.propertyName): " +
                    "return (value as? \(unwrappedTypeName)).map { \(copyExpression) }"
            )
        }

        let switchBody = switchCases.joined(separator: "\n        ")
        return """
        func modifyKey(
            _ key: \(keyTypeName),
            withValue value: Any
        ) -> \(typeName)? {
            switch key {
            \(switchBody)
            default: return nil
            }
        }
        """
    }

    static func generateExposedKeysProperty(
        _ keys: [UpdatableKeyInfo],
        keyTypeName: String
    ) -> String {
        let keyCases = keys
            .map { ".\($0.propertyName)" }
            .joined(separator: ", ")
        return """
        var exposedKeys: [\(keyTypeName)] {
            [\(keyCases)]
        }
        """
    }

    private static func strippingOptionalWrapper(
        from type: TypeSyntax
    ) -> String {
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return optionalType.wrappedType.trimmedDescription
        }

        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "Optional",
           let genericClause = identifierType.genericArgumentClause,
           let firstArgument = genericClause.arguments.first {
            return firstArgument.argument.trimmedDescription
        }

        return type.trimmedDescription
    }

    private static func transformExpression(
        forProperty propertyName: String,
        nilCondition: String?
    ) -> String {
        let copyingPrefix = "copying(\(propertyName):"

        if let nilCondition {
            return "\(copyingPrefix) \(nilCondition) ? nil : $0)"
        }

        return "\(copyingPrefix) $0)"
    }
}
