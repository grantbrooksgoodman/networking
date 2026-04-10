//
//  ReadWriteEnablementStatusService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Combine
import Foundation

/* Proprietary */
import AppSubsystem

@MainActor
final class ReadWriteEnablementStatusService {
    // MARK: - Properties

    static let shared = ReadWriteEnablementStatusService()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {}

    // MARK: - Listen for Read/Write Enablement Status Changes

    func listenForReadWriteEnablementStatusChanges() {
        guard let forcedUpdateModalDelegate = AppSubsystem.delegates.forcedUpdateModal else { return }

        forcedUpdateModalDelegate
            .forcedUpdateRequiredPublisher
            .filter { $0 }
            .prefix(1)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Networking.isReadWriteEnabled = false
            }
            .store(in: &cancellables)
    }
}

extension Networking {
    // MARK: - Properties

    private static let _isReadWriteEnabled = LockIsolated<Bool>(wrappedValue: true)

    // MARK: - Computed Properties

    static var isReadWriteEnabled: Bool {
        get { _isReadWriteEnabled.wrappedValue }
        set { _isReadWriteEnabled.projectedValue.withValue { $0 = newValue } }
    }
}
