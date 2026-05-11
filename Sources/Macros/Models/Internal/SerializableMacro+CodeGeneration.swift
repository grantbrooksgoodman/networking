//
//  SerializableMacro+CodeGeneration.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension SerializableMacro {
    static func generateSerializableKeyEnum(
        _ properties: [SerializedProperty]
    ) -> String {
        var cases = [String]()

        for property in properties {
            if let customKeyName = property.customKeyName {
                cases.append(
                    "case \(property.propertyName) = \"\(customKeyName)\""
                )
            } else {
                cases.append("case \(property.propertyName)")
            }
        }

        let caseBody = cases.joined(separator: "\n        ")
        return """
        enum SerializableKey: String {
            \(caseBody)
        }
        """
    }

    static func generateEncodedProperty(
        _ properties: [SerializedProperty]
    ) -> String {
        let nonOptionalProperties = properties.filter { !$0.isOptional }
        let optionalProperties = properties.filter(\.isOptional)

        if optionalProperties.isEmpty {
            let entries = nonOptionalProperties.map {
                "SerializableKey.\($0.propertyName).rawValue: \($0.propertyName)"
            }

            let entryBody = entries.joined(separator: ",\n            ")
            return """
            var encoded: [String: Any] {
                [
                    \(entryBody),
                ]
            }
            """
        }

        var lines = [String]()
        lines.append("var encoded: [String: Any] {")

        if nonOptionalProperties.isEmpty {
            lines.append("    var encoded = [String: Any]()")
        } else {
            let entries = nonOptionalProperties.map {
                "SerializableKey.\($0.propertyName).rawValue: \($0.propertyName)"
            }

            let entryBody = entries.joined(separator: ",\n            ")
            lines.append("    var encoded: [String: Any] = [")
            lines.append("        \(entryBody),")
            lines.append("    ]")
        }

        lines.append("")

        for property in optionalProperties {
            lines.append(
                "    if let \(property.propertyName) " +
                    "{ encoded[SerializableKey.\(property.propertyName).rawValue] = \(property.propertyName) }"
            )
        }

        lines.append("")
        lines.append("    return encoded")
        lines.append("}")

        return lines.joined(separator: "\n        ")
    }

    static func generateCanDecodeMethod(
        _ properties: [SerializedProperty]
    ) -> String {
        let nonOptionalProperties = properties.filter { !$0.isOptional }

        if nonOptionalProperties.isEmpty {
            return """
            static func canDecode(from data: [String: Any]) -> Bool {
                true
            }
            """
        }

        var checks = [String]()
        for property in nonOptionalProperties {
            let typeName = strippingOptionalWrapper(from: property.propertyType)
            checks.append(
                "data[SerializableKey.\(property.propertyName).rawValue] is \(typeName)"
            )
        }

        let guardBody = checks.joined(separator: ",\n              ")
        return """
        static func canDecode(from data: [String: Any]) -> Bool {
            guard \(guardBody) else { return false }
            return true
        }
        """
    }

    static func generateDecodeMethod(
        typeName: String,
        serializedProperties: [SerializedProperty],
        initializerParameters: [RemotelyUpdatableMacro.InitializerParameter]
    ) -> String {
        let nonOptionalProperties = serializedProperties.filter { !$0.isOptional }
        let optionalProperties = serializedProperties.filter(\.isOptional)

        // Build guard-let clauses for non-optional properties
        var guardLetClauses = [String]()
        for property in nonOptionalProperties {
            let unwrappedTypeName = strippingOptionalWrapper(
                from: property.propertyType
            )

            guardLetClauses.append(
                "let \(property.propertyName) = " +
                    "data[SerializableKey.\(property.propertyName).rawValue] as? \(unwrappedTypeName)"
            )
        }

        // Build let bindings for optional properties
        var optionalLetClauses = [String]()
        for property in optionalProperties {
            let unwrappedTypeName = strippingOptionalWrapper(
                from: property.propertyType
            )

            optionalLetClauses.append(
                "let \(property.propertyName) = " +
                    "data[SerializableKey.\(property.propertyName).rawValue] as? \(unwrappedTypeName)"
            )
        }

        // Build init call using init parameter ordering and labels
        let encodedPropertyNames = Set(serializedProperties.map(\.propertyName))
        var initArguments = [String]()

        for parameter in initializerParameters {
            guard encodedPropertyNames.contains(parameter.internalName) else { continue }

            if parameter.isUnlabeled {
                initArguments.append(parameter.internalName)
            } else {
                let label = parameter.externalLabel ?? parameter.internalName
                initArguments.append("\(label): \(parameter.internalName)")
            }
        }

        let initCall = initArguments.joined(separator: ", ")

        // Assemble method body
        var lines = [String]()
        lines.append("static func decode(")
        lines.append("    from data: [String: Any]")
        lines.append(") async throws(Exception) -> \(typeName) {")

        if !guardLetClauses.isEmpty {
            let guardBody = guardLetClauses.joined(separator: ",\n              ")
            lines.append("    guard \(guardBody) else {")
            lines.append("        throw .Networking.decodingFailed(data: data, .init(sender: self))")
            lines.append("    }")
        }

        if !optionalLetClauses.isEmpty {
            if !guardLetClauses.isEmpty { lines.append("") }
            for clause in optionalLetClauses {
                lines.append("    \(clause)")
            }
        }

        if !guardLetClauses.isEmpty || !optionalLetClauses.isEmpty {
            lines.append("")
        }

        lines.append("    return .init(\(initCall))")
        lines.append("}")

        return lines.joined(separator: "\n        ")
    }

    // MARK: - Auxiliary

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
}
