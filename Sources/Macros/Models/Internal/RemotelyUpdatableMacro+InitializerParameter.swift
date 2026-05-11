//
//  RemotelyUpdatableMacro+InitializerParameter.swift
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

    struct InitializerParameter {
        /* MARK: Properties */

        let externalLabel: String?
        let internalName: String
        let isUnlabeled: Bool
        let typeName: String

        /* MARK: Init */

        init(
            externalLabel: String?,
            internalName: String,
            typeName: String,
            isUnlabeled: Bool
        ) {
            self.externalLabel = externalLabel
            self.internalName = internalName
            self.typeName = typeName
            self.isUnlabeled = isUnlabeled
        }
    }

    // MARK: - Methods

    static func extractInitializerParameters(
        from declaration: some DeclGroupSyntax
    ) -> [InitializerParameter]? {
        guard let initializerDeclaration = declaration.memberBlock.members
            .compactMap({ $0.decl.as(InitializerDeclSyntax.self) })
            .first else { return nil }

        return initializerDeclaration
            .signature
            .parameterClause
            .parameters
            .map {
                let externalName = $0.firstName.text
                let internalName = $0.secondName?.text ?? externalName
                let isUnlabeled = $0.firstName.tokenKind == .wildcard
                let parameterType = $0.type.trimmedDescription

                return InitializerParameter(
                    externalLabel: isUnlabeled ? nil : externalName,
                    internalName: internalName,
                    typeName: parameterType,
                    isUnlabeled: isUnlabeled
                )
            }
    }
}
