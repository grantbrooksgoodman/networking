//
//  WriteAction.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// The action to take when writing a value during an
/// ``RemotelyUpdatable/updateValue(writing:forKey:)`` call.
///
/// Return one of these cases from
/// ``RemotelyUpdatable/willWrite(_:forKey:updating:)`` to control
/// how the default implementation handles the database
/// write. To abort the update entirely, throw an
/// `Exception` from `willWrite` instead of returning a
/// write action.
///
/// ```swift
/// func willWrite(
///     _ value: Any,
///     forKey key: SerializableKey,
///     updating updated: MyModel
/// ) async throws(Exception) -> WriteAction<MyModel> {
///     if let date = value as? Date {
///         return .encoded(
///             dateFormatter.string(from: date)
///         )
///     }
///     return .proceed
/// }
/// ```
public enum WriteAction<T: Serializable> {
    /// Write the specified pre-encoded value directly,
    /// bypassing the standard encoding ladder.
    ///
    /// Use this case when the value requires custom
    /// serialization that the encoding ladder cannot
    /// perform – for example, converting a `Date` to a
    /// formatted string.
    case encoded(Any)

    /// The conformer has already performed the database
    /// write. The default implementation skips its own
    /// write and proceeds directly to
    /// ``RemotelyUpdatable/didWrite(_:forKey:)`` with the
    /// specified updated instance.
    case handled(T)

    /// Proceed with the standard encoding ladder.
    ///
    /// The default implementation attempts to encode the
    /// value as a ``Serializable``, an array of
    /// ``Serializable``, or a raw Foundation type, in
    /// that order.
    case proceed
}
