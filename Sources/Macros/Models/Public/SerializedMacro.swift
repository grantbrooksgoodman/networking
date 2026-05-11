//
//  SerializedMacro.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftSyntax
import SwiftSyntaxMacros

/// A peer macro that serves as a marker for `@Serializable`.
/// Generates no declarations on its own.
public struct SerializedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(VariableDeclSyntax.self) else {
            context.diagnose(.init(
                node: node,
                message: DiagnosticMessage(
                    "@Serialized can only be applied to stored properties."
                )
            ))
            return []
        }

        return []
    }
}
