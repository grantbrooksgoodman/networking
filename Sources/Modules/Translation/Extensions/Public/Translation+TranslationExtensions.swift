//
//  Translation+TranslationExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Translator

public extension Translation {
    /// The serializable reference for this translation.
    ///
    /// Use this property to obtain a ``TranslationReference``
    /// that can be stored in the database and later decoded
    /// back into a `Translation`.
    var reference: TranslationReference { .init(self) }
}
