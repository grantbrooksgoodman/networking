//
//  RemotelyUpdatableExtensionMacro.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct RemotelyUpdatableMacro: ExtensionMacro {
    // MARK: - Extension Macro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let initializerDeclarations = declaration
            .memberBlock
            .members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

        guard let initializerParameters = extractInitializerParameters(
            from: declaration
        ) else {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "@RemotelyUpdatable requires at least one initializer."
                )
            ))
            return []
        }

        if initializerDeclarations.count > 1 {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "@RemotelyUpdatable found multiple initializers; using the first one.",
                    severity: .warning
                )
            ))
        }

        let keyTypeName = extractKeyTypeName(from: node)
        let typeName = type.trimmedDescription
        let exposedKeys = extractKeys(from: declaration)
        var generatedMembers = [String]()

        // Generate copying() methods
        for (parameterIndex, parameter) in initializerParameters.enumerated() {
            generatedMembers.append(generateCopyingMethod(
                typeName: typeName,
                targetParameter: parameter,
                targetIndex: parameterIndex,
                allParameters: initializerParameters
            ))
        }

        // Generate modifyKey and serializableKey when @Updatable markers exist
        if !exposedKeys.isEmpty,
           !declaration.memberBlock.members.contains(where: { member in
               guard let enumDecl = member.decl.as(EnumDeclSyntax.self) else { return false }
               return enumDecl.name.text == keyTypeName
           }) {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "No '\(keyTypeName)' enum found in this declaration. Ensure it exists in the type or an extension.",
                    severity: .note
                )
            ))
        }

        if !exposedKeys.isEmpty {
            generatedMembers.append(
                generateModifyKeyMethod(
                    typeName: typeName,
                    keyTypeName: keyTypeName,
                    exposedKeys: exposedKeys,
                    allParameters: initializerParameters
                )
            )

            generatedMembers.append(
                generateSerializableKeyMethod(
                    typeName: typeName,
                    keyTypeName: keyTypeName,
                    exposedKeys: exposedKeys
                )
            )
        }

        let extensionDeclaration = try ExtensionDeclSyntax(
            "extension \(raw: typeName)"
        ) {
            for member in generatedMembers {
                DeclSyntax(stringLiteral: member)
            }
        }

        return [extensionDeclaration]
    }

    // MARK: - Auxiliary

    private static func extractKeyTypeName(
        from node: AttributeSyntax
    ) -> String {
        guard let arguments = node.arguments,
              case let .argumentList(argumentList) = arguments else { return "SerializableKey" }

        for argument in argumentList {
            guard argument.label?.text == "keyType",
                  let stringLiteral = argument
                  .expression
                  .as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral
                  .segments
                  .first?
                  .as(StringSegmentSyntax.self) else { continue }
            return segment.content.text
        }

        return "SerializableKey"
    }
}
