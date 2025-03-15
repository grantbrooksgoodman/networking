//
//  HostedTranslationArchiverDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

public protocol HostedTranslationArchiverDelegate {
    @discardableResult // TODO: This doesn't need to be mandatory.
    func addRecentlyUploadedLocalizedTranslationsToLocalArchive() async -> Exception?

    @discardableResult
    func addToHostedArchive(_ translation: Translation) async -> Exception?

    func findArchivedTranslation(
        input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception>

    func findArchivedTranslation(
        id: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception>

    @discardableResult
    func removeArchivedTranslation(
        for input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Exception?
}
