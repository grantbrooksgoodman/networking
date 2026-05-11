//
//  SerializableMacro+SerializedProperty.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension SerializableMacro {
    // MARK: - Types

    struct SerializedProperty {
        /* MARK: Properties */

        let customKeyName: String?
        let isOptional: Bool
        let propertyName: String
        let propertyType: TypeSyntax

        /* MARK: Init */

        init(
            customKeyName: String?,
            isOptional: Bool,
            propertyName: String,
            propertyType: TypeSyntax
        ) {
            self.customKeyName = customKeyName
            self.isOptional = isOptional
            self.propertyName = propertyName
            self.propertyType = propertyType
        }
    }

    // MARK: - Methods

    static func extractSerializedProperties(
        from declaration: some DeclGroupSyntax
    ) -> [SerializedProperty] {
        var properties = [SerializedProperty]()

        for member in declaration.memberBlock.members {
            guard let variableDeclaration = member
                .decl
                .as(VariableDeclSyntax.self) else { continue }

            let hasSerializedAttribute = variableDeclaration
                .attributes
                .contains { attribute in
                    guard case let .attribute(
                        attributeSyntax
                    ) = attribute else { return false }
                    return attributeSyntax.attributeName.trimmedDescription == "Serialized"
                }

            guard hasSerializedAttribute,
                  let binding = variableDeclaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else { continue }

            let propertyType = typeAnnotation.type
            let isOptional = propertyType.is(OptionalTypeSyntax.self) ||
                (propertyType.as(IdentifierTypeSyntax.self)?.name.text == "Optional")

            properties.append(SerializedProperty(
                customKeyName: extractCustomKeyName(from: variableDeclaration),
                isOptional: isOptional,
                propertyName: pattern.identifier.text,
                propertyType: propertyType
            ))
        }

        return properties
    }

    // MARK: - Auxiliary

    private static func extractCustomKeyName(
        from variableDeclaration: VariableDeclSyntax
    ) -> String? {
        for attribute in variableDeclaration.attributes {
            guard case let .attribute(attributeSyntax) = attribute,
                  attributeSyntax.attributeName.trimmedDescription == "Serialized",
                  let arguments = attributeSyntax.arguments,
                  case let .argumentList(argumentList) = arguments,
                  let firstArgument = argumentList.first,
                  let stringLiteral = firstArgument
                  .expression
                  .as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral
                  .segments
                  .first?
                  .as(StringSegmentSyntax.self) else { continue }
            return segment.content.text
        }

        return nil
    }
}
