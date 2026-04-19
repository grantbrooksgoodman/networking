//
//  NetworkActivityViewModifier.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

private struct NetworkActivityViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                NetworkActivityIndicator(
                    .init(
                        initialState: .init(),
                        reducer: NetworkActivityIndicatorReducer()
                    )
                )
                Spacer()
            }
        }
    }
}

public extension View {
    /// Overlays a network activity indicator on the view.
    ///
    /// Apply this modifier to your root view to display
    /// an activity indicator whenever a networking
    /// operation is in progress:
    ///
    /// ```swift
    /// ContentView()
    ///     .indicatesNetworkActivity()
    /// ```
    func indicatesNetworkActivity() -> some View {
        modifier(NetworkActivityViewModifier())
    }
}
