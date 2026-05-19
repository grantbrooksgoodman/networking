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
            let typeName = property.encodedTypeName
                ?? strippingOptionalWrapper(from: property.propertyType)
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

    static func generateEncodedProperty(
        _ properties: [SerializedProperty]
    ) -> String {
        let nonOptionalProperties = properties.filter { !$0.isOptional }
        let optionalProperties = properties.filter(\.isOptional)

        if optionalProperties.isEmpty {
            let entries = nonOptionalProperties.map { encodedEntry(for: $0) }
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
            let entries = nonOptionalProperties.map { encodedEntry(for: $0) }
            let entryBody = entries.joined(separator: ",\n            ")
            lines.append("    var encoded: [String: Any] = [")
            lines.append("        \(entryBody),")
            lines.append("    ]")
        }

        lines.append("")

        for property in optionalProperties {
            let value = property.encodeExpression.map {
                "(\($0))(\(property.propertyName))"
            } ?? property.propertyName

            lines.append(
                "    if let \(property.propertyName) " +
                    "{ encoded[SerializableKey.\(property.propertyName).rawValue] = \(value) }"
            )
        }

        lines.append("")
        lines.append("    return encoded")
        lines.append("}")

        return lines.joined(separator: "\n        ")
    }

    static func generateInitializer(
        serializedProperties: [SerializedProperty],
        initializerParameters: [RemotelyUpdatableMacro.InitializerParameter]
    ) -> String {
        let nonOptionalProperties = serializedProperties.filter { !$0.isOptional }
        let optionalProperties = serializedProperties.filter(\.isOptional)

        // Guard-let clauses for non-optional properties without transforms
        var guardLetClauses = [String]()
        for property in nonOptionalProperties where !property.hasTransform {
            let unwrappedTypeName = strippingOptionalWrapper(
                from: property.propertyType
            )

            guardLetClauses.append(
                "let \(property.propertyName) = " +
                    "data[SerializableKey.\(property.propertyName).rawValue] as? \(unwrappedTypeName)"
            )
        }

        // Two-step decode blocks for non-optional properties with transforms
        let transformedNonOptional = nonOptionalProperties.filter(\.hasTransform)

        // Let bindings for optional properties
        var optionalLetClauses = [String]()
        for property in optionalProperties {
            if let encodedTypeName = property.encodedTypeName,
               let decodeExpression = property.decodeExpression {
                optionalLetClauses.append(
                    "let \(property.propertyName) = " +
                        "(data[SerializableKey.\(property.propertyName).rawValue] as? \(encodedTypeName))" +
                        ".flatMap(\(decodeExpression))"
                )
            } else {
                let unwrappedTypeName = strippingOptionalWrapper(
                    from: property.propertyType
                )

                optionalLetClauses.append(
                    "let \(property.propertyName) = " +
                        "data[SerializableKey.\(property.propertyName).rawValue] as? \(unwrappedTypeName)"
                )
            }
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

        // Assemble initializer body
        var lines = [String]()
        lines.append("init(")
        lines.append("    from data: [String: Any]")
        lines.append(") async throws(Exception) {")

        if !guardLetClauses.isEmpty {
            let guardBody = guardLetClauses.joined(separator: ",\n              ")
            lines.append("    guard \(guardBody) else {")
            lines.append("        throw .Networking.decodingFailed(data: data, .init(sender: Self.self))")
            lines.append("    }")
        }

        for (index, property) in transformedNonOptional.enumerated() {
            if !guardLetClauses.isEmpty || index > 0 {
                lines.append("")
            }

            let unwrappedTypeName = strippingOptionalWrapper(
                from: property.propertyType
            )

            lines.append("    guard let raw_\(property.propertyName) = data[SerializableKey.\(property.propertyName).rawValue] as? \(property.encodedTypeName!) else {")
            lines.append("        throw .Networking.decodingFailed(data: data, .init(sender: Self.self))")
            lines.append("    }")
            lines.append("")
            lines.append("    let decoded_\(property.propertyName): \(unwrappedTypeName)? = (\(property.decodeExpression!))(raw_\(property.propertyName))")
            lines.append("    guard let \(property.propertyName) = decoded_\(property.propertyName) else {")
            lines.append("        throw .Networking.decodingFailed(data: data, .init(sender: Self.self))")
            lines.append("    }")
        }

        if !optionalLetClauses.isEmpty {
            if !guardLetClauses.isEmpty || !transformedNonOptional.isEmpty {
                lines.append("")
            }

            for clause in optionalLetClauses {
                lines.append("    \(clause)")
            }
        }

        if !guardLetClauses.isEmpty || !transformedNonOptional.isEmpty || !optionalLetClauses.isEmpty {
            lines.append("")
        }

        lines.append("    self.init(\(initCall))")
        lines.append("}")

        return lines.joined(separator: "\n        ")
    }

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

    // MARK: - Auxiliary

    private static func encodedEntry(
        for property: SerializedProperty
    ) -> String {
        let key = "SerializableKey.\(property.propertyName).rawValue"
        if let encodeExpr = property.encodeExpression {
            return "\(key): (\(encodeExpr))(\(property.propertyName))"
        }
        return "\(key): \(property.propertyName)"
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
}
