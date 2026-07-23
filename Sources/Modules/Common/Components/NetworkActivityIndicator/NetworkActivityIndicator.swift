//
//  NetworkActivityIndicator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI
import UIKit

/* Proprietary */
import AppSubsystem

struct NetworkActivityIndicator: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.NetworkActivityIndicator
    private typealias Floats = AppConstants.CGFloats.NetworkActivityIndicator

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<NetworkActivityIndicatorReducer>
    @StateObject private var observer: ViewObserver<NetworkActivityIndicatorObserver>

    // MARK: - Init

    init(_ viewModel: ViewModel<NetworkActivityIndicatorReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    var body: some View {
        Circle()
            .if(
                UIApplication.isFullyV26Compatible
            ) {
                $0.foregroundStyle(.clear)
            } else: {
                $0.foregroundStyle(viewModel.backgroundColor ?? .accent)
            }
            .padding(.all, Floats.padding)
            .frame(
                width: Floats.frameWidth,
                height: Floats.frameHeight
            )
            .overlay {
                ProgressView()
                    .dynamicTypeSize(.large)
                    .tint(viewModel.progressViewTintColor)
            }
            .if(UIApplication.isFullyV26Compatible) {
                $0.glassEffect(
                    isClear: viewModel.backgroundColor == nil,
                    padding: -1,
                    shape: Circle(),
                    tint: (viewModel.backgroundColor ?? Colors.glassEffectTint)
                        .opacity(Floats.glassEffectTintOpacity)
                )
            }
            .offset(y: viewModel.yOffset)
            .opacity(viewModel.isVisible ? 1 : 0)
            .animation(.spring(), value: viewModel.yOffset)
    }
}
