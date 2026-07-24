//
//  RadioTechnology.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
#if canImport(CoreTelephony) && !os(macOS)
import CoreTelephony
#endif

/// A coarse classification of the device's current cellular
/// radio access technology.
///
/// The classification is a prior, not a measurement – it caps
/// the health score on legacy cellular technologies where a
/// starved estimator would otherwise over-report. Unavailable
/// or unrecognized technologies – including future ones –
/// classify as ``unknown`` and have no effect on scoring. On
/// platforms without CoreTelephony the type always reports
/// ``unknown``.
enum RadioTechnology: String {
    // MARK: - Cases

    /// 3G-class technologies (WCDMA, HSPA, EV-DO, eHRPD).
    case intermediate

    /// 2G-class technologies (GPRS, EDGE, CDMA 1x).
    case legacy

    /// 4G- and 5G-class technologies (LTE, NR).
    case modern

    /// The technology is unavailable or unrecognized.
    case unknown

    // MARK: - Computed Properties

    /// The best radio access technology currently reported
    /// across all of the device's cellular services.
    static var current: RadioTechnology {
        #if canImport(CoreTelephony) && !os(macOS)
        guard let radioAccessTechnologies = CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology,
              !radioAccessTechnologies.isEmpty else {
            return .unknown
        }

        return radioAccessTechnologies.values
            .map(RadioTechnology.init(radioAccessTechnology:))
            .max { $0.rank < $1.rank } ?? .unknown
        #else
        return .unknown
        #endif
    }

    /// The classification's quality rank, used to reduce
    /// multiple cellular services to the best one. Recognized
    /// technologies always outrank ``unknown``.
    private var rank: Int {
        switch self {
        case .unknown: 0
        case .legacy: 1
        case .intermediate: 2
        case .modern: 3
        }
    }

    // MARK: - Init

    #if canImport(CoreTelephony) && !os(macOS)
    private init(radioAccessTechnology: String) {
        switch radioAccessTechnology {
        case CTRadioAccessTechnologyCDMA1x,
             CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyGPRS:
            self = .legacy

        case CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyWCDMA:
            self = .intermediate

        case CTRadioAccessTechnologyLTE,
             CTRadioAccessTechnologyNR,
             CTRadioAccessTechnologyNRNSA:
            self = .modern

        default:
            self = .unknown
        }
    }
    #endif
}
