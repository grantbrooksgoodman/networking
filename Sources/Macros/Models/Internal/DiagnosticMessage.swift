//
//  DiagnosticMessage.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import SwiftDiagnostics

struct DiagnosticMessage: SwiftDiagnostics.DiagnosticMessage {
    // MARK: - Properties

    let diagnosticID: MessageID
    let message: String
    let severity: DiagnosticSeverity

    // MARK: - Init

    init(
        _ message: String,
        id: String = "RemotelyUpdatableMacro",
        severity: DiagnosticSeverity = .error
    ) {
        self.message = message
        diagnosticID = .init(domain: "NetworkingMacros", id: id)
        self.severity = severity
    }
}
