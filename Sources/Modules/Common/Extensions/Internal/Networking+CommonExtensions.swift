//
//  Networking+CommonExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Networking {
    static func cacheExpiryMilliseconds(for startDate: Date) -> Int {
        @Dependency(\.currentCalendar) var calendar: Calendar
        let milliseconds = abs(
            calendar.dateComponents(
                [.nanosecond],
                from: startDate,
                to: .now
            ).nanosecond ?? 0
        ) / 1_000_000

        return milliseconds < 100 ? 100 + milliseconds : milliseconds
    }
}
