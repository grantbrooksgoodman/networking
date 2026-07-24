//
//  PathState.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Network

/// A snapshot of the device's current network path properties,
/// captured from `NWPathMonitor` updates.
struct PathState {
    // MARK: - Properties

    var interfaceType: NWInterface.InterfaceType?
    var isConstrained: Bool
    var isExpensive: Bool
    var radioTechnology: RadioTechnology

    // MARK: - Init

    init(
        interfaceType: NWInterface.InterfaceType? = nil,
        isConstrained: Bool = false,
        isExpensive: Bool = false,
        radioTechnology: RadioTechnology = .unknown
    ) {
        self.interfaceType = interfaceType
        self.isConstrained = isConstrained
        self.isExpensive = isExpensive
        self.radioTechnology = radioTechnology
    }
}
