//
//  UpdatableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public protocol Updatable {
    // MARK: - Associated Types

    associatedtype SerializationKey
    associatedtype U: Serializable

    // MARK: - Properties

    var updatableKeys: [SerializationKey] { get }

    // MARK: - Methods

    func modifyKey(_ key: SerializationKey, withValue value: Any) -> U?
    func updateValue(_ value: Any, forKey key: SerializationKey) async -> Callback<U, Exception>
}
