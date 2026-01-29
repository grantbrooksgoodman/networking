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
    func indicatesNetworkActivity() -> some View {
        modifier(NetworkActivityViewModifier())
    }
}
