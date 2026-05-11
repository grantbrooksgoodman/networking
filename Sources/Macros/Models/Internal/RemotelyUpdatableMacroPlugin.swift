//
//  RemotelyUpdatableMacroPlugin.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NetworkingMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RemotelyUpdatableMacro.self,
        UpdatableMacro.self,
        SerializableMacro.self,
        SerializedMacro.self,
    ]
}
