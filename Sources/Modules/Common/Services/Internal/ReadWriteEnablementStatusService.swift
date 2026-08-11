//
//  ReadWriteEnablementStatusService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

@MainActor
struct ReadWriteEnablementStatusService {
    // MARK: - Properties

    static let shared = ReadWriteEnablementStatusService()

    // MARK: - Init

    private init() {}

    // MARK: - Listen for Read/Write Enablement Status Changes

    func listenForReadWriteEnablementStatusChanges() async {
        guard AppSubsystem.delegates.forcedUpdateModal != nil else { return }
        for await isForcedUpdateRequired in SharedState(\.isForcedUpdateRequired)
            .projectedValue
            .changes where isForcedUpdateRequired {
            Networking.isReadWriteEnabled = false
            break
        }
    }
}

extension Networking {
    // MARK: - Properties

    private static let _isReadWriteEnabled = LockIsolated(true)

    // MARK: - Computed Properties

    static var isReadWriteEnabled: Bool {
        get { _isReadWriteEnabled.wrappedValue }
        set { _isReadWriteEnabled.wrappedValue = newValue }
    }
}
