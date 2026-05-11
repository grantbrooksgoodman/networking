//
//  SerializableExtensionMacro.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct SerializableMacro: ExtensionMacro {
    // MARK: - Extension Macro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let serializedProperties = extractSerializedProperties(from: declaration)

        guard !serializedProperties.isEmpty else {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "@Serializable requires at least one @Serialized property."
                )
            ))
            return []
        }

        guard let initializerParameters = RemotelyUpdatableMacro
            .extractInitializerParameters(from: declaration) else {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "@Serializable requires at least one initializer."
                )
            ))
            return []
        }

        let initializerDeclarations = declaration
            .memberBlock
            .members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

        if initializerDeclarations.count > 1 {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "@Serializable found multiple initializers; using the first one.",
                    severity: .warning
                )
            ))
        }

        for property in serializedProperties {
            guard initializerParameters.contains(
                where: { $0.internalName == property.propertyName }
            ) else {
                context.diagnose(.init(
                    node: node,
                    message: DiagnosticMessage(
                        "@Serialized property '\(property.propertyName)' has no corresponding initializer parameter."
                    )
                ))
                return []
            }
        }

        let typeName = type.trimmedDescription
        var generatedMembers = [String]()

        generatedMembers.append(
            generateSerializableKeyEnum(serializedProperties)
        )

        generatedMembers.append(
            generateEncodedProperty(serializedProperties)
        )

        generatedMembers.append(
            generateCanDecodeMethod(serializedProperties)
        )

        generatedMembers.append(
            generateDecodeMethod(
                typeName: typeName,
                serializedProperties: serializedProperties,
                initializerParameters: initializerParameters
            )
        )

        let conformanceClause = protocols.isEmpty ? "" : ": Serializable"
        let extensionDeclaration = try ExtensionDeclSyntax(
            "extension \(raw: typeName)\(raw: conformanceClause)"
        ) {
            for member in generatedMembers {
                DeclSyntax(stringLiteral: member)
            }
        }

        return [extensionDeclaration]
    }
}
