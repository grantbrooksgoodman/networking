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
        let decodeExpression: String?
        let encodeExpression: String?
        let encodedTypeName: String?
        let isOptional: Bool
        let propertyName: String
        let propertyType: TypeSyntax

        /* MARK: Computed Properties */

        var hasTransform: Bool {
            encodedTypeName != nil
        }

        /* MARK: Init */

        init(
            customKeyName: String?,
            decodeExpression: String? = nil,
            encodeExpression: String? = nil,
            encodedTypeName: String? = nil,
            isOptional: Bool,
            propertyName: String,
            propertyType: TypeSyntax
        ) {
            self.customKeyName = customKeyName
            self.decodeExpression = decodeExpression
            self.encodeExpression = encodeExpression
            self.encodedTypeName = encodedTypeName
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

            let transformInfo = extractTransformInfo(from: variableDeclaration)
            properties.append(SerializedProperty(
                customKeyName: extractCustomKeyName(from: variableDeclaration),
                decodeExpression: transformInfo?.decodeExpression,
                encodeExpression: transformInfo?.encodeExpression,
                encodedTypeName: transformInfo?.encodedTypeName,
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

    private static func extractTransformInfo(
        from variableDeclaration: VariableDeclSyntax
    ) -> (encodedTypeName: String, encodeExpression: String, decodeExpression: String)? {
        for attribute in variableDeclaration.attributes {
            guard case let .attribute(attributeSyntax) = attribute,
                  attributeSyntax.attributeName.trimmedDescription == "Serialized",
                  let arguments = attributeSyntax.arguments,
                  case let .argumentList(argumentList) = arguments else { continue }

            var decodeExpression: String?
            var encodeExpression: String?
            var encodedTypeName: String?

            for argument in argumentList {
                switch argument.label?.text {
                case "decode":
                    decodeExpression = argument.expression.trimmedDescription

                case "encode":
                    encodeExpression = argument.expression.trimmedDescription

                case "encodedAs":
                    let text = argument.expression.trimmedDescription
                    encodedTypeName = text.hasSuffix(".self")
                        ? String(text.dropLast(5))
                        : text

                default:
                    break
                }
            }

            if let decodeExpression,
               let encodeExpression,
               let encodedTypeName {
                return (
                    encodedTypeName,
                    encodeExpression,
                    decodeExpression
                )
            }
        }

        return nil
    }
}
