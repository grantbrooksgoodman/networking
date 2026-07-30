//
//  ArchiveStrategy.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A strategy that determines when a newly retrieved
/// translation is written to the hosted archive.
///
/// Use `ArchiveStrategy` with
/// ``HostedTranslationDelegate/translate(_:with:hud:enhance:archive:)``
/// to control whether the translate call writes new
/// translations to the hosted archive itself, or defers
/// that write to you.
public enum ArchiveStrategy: Equatable, Sendable {
    /// Defers the hosted-archive write to the caller.
    ///
    /// The translate call performs no hosted-archive
    /// writes. Obtain the would-be archive entry with
    /// ``HostedTranslationDelegate/hostedArchiveEntry(for:)``
    /// and merge it into your own atomic
    /// ``DatabaseDelegate/commit(_:)`` payload. The local
    /// archive still receives new translations
    /// immediately.
    case deferred

    /// Writes new translations to the hosted archive
    /// immediately, within the translate call.
    case immediate
}
