//
//  RemotelyUpdatableMacro+UpdatableKeyInfo.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension RemotelyUpdatableMacro {
    // MARK: - Types

    struct UpdatableKeyInfo {
        /* MARK: Properties */

        let nilCondition: String?
        let propertyName: String
        let propertyType: TypeSyntax

        /* MARK: Init */

        init(
            propertyName: String,
            propertyType: TypeSyntax,
            nilCondition: String?
        ) {
            self.propertyName = propertyName
            self.propertyType = propertyType
            self.nilCondition = nilCondition
        }
    }

    // MARK: - Methods

    static func extractKeys(
        from declaration: some DeclGroupSyntax
    ) -> [UpdatableKeyInfo] {
        var keys = [UpdatableKeyInfo]()

        for member in declaration.memberBlock.members {
            guard let variableDeclaration = member
                .decl
                .as(VariableDeclSyntax.self) else { continue }

            let hasUpdatableAttribute = variableDeclaration
                .attributes
                .contains { attribute in
                    guard case let .attribute(
                        attributeSyntax
                    ) = attribute else { return false }
                    return attributeSyntax.attributeName.trimmedDescription == "Updatable"
                }

            guard hasUpdatableAttribute,
                  let binding = variableDeclaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else { continue }

            keys.append(UpdatableKeyInfo(
                propertyName: pattern.identifier.text,
                propertyType: typeAnnotation.type,
                nilCondition: extractNilCondition(from: variableDeclaration)
            ))
        }

        return keys
    }

    private static func extractNilCondition(
        from variableDeclaration: VariableDeclSyntax
    ) -> String? {
        for attribute in variableDeclaration.attributes {
            guard case let .attribute(attributeSyntax) = attribute,
                  attributeSyntax.attributeName.trimmedDescription == "Updatable",
                  let arguments = attributeSyntax.arguments,
                  case let .argumentList(argumentList) = arguments else { continue }

            for argument in argumentList {
                guard argument.label?.text == "nilIf" else { continue }

                // .custom("expression") – extract the string literal
                if let functionCall = argument
                    .expression
                    .as(FunctionCallExprSyntax.self),
                    let firstArgument = functionCall
                    .arguments
                    .first,
                    let stringLiteral = firstArgument
                    .expression
                    .as(StringLiteralExprSyntax.self),
                    let segment = stringLiteral
                    .segments
                    .first?
                    .as(StringSegmentSyntax.self) {
                    return segment.content.text
                }

                // .isBangQualifiedEmpty / .isEmpty
                let caseName = String(
                    argument
                        .expression
                        .trimmedDescription
                        .drop(while: { $0 == "." })
                )

                switch caseName {
                case "isBangQualifiedEmpty": return "$0.isBangQualifiedEmpty"
                case "isEmpty": return "$0.isEmpty"
                default: return nil
                }
            }
        }

        return nil
    }
}
