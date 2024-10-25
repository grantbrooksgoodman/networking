//
//  HostedTranslationDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Translator

// swiftlint:disable:next class_delegate_protocol
public protocol HostedTranslationDelegate: AlertKit.TranslationDelegate {
    func findArchivedTranslation(
        id inputValueEncodedHash: String,
        languagePair: LanguagePair
    ) async -> Callback<Translation, Exception>

    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?
    ) async -> Callback<[Translation], Exception>

    func resolve(_ strings: TranslatedLabelStrings.Type) async -> Callback<[TranslationOutputMap], Exception>

    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)?
    ) async -> Callback<Translation, Exception>
}

public extension HostedTranslationDelegate {
    func getTranslations(
        for inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil
    ) async -> Callback<[Translation], Exception> {
        await getTranslations(
            for: inputs,
            languagePair: languagePair,
            hud: hudConfig
        )
    }

    func translate(
        _ input: TranslationInput,
        with languagePair: LanguagePair,
        hud hudConfig: (appearsAfter: Duration, isModal: Bool)? = nil
    ) async -> Callback<Translation, Exception> {
        await translate(
            input,
            with: languagePair,
            hud: hudConfig
        )
    }
}
