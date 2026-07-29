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

    // MARK: - Init

    init(_ viewModel: ViewModel<NetworkActivityIndicatorReducer>) {
        _viewModel = .init(
            wrappedValue: viewModel
                .observing(
                    // Dropping the first element skips the replayed current
                    // value; activity effects should only run for changes
                    // occurring after subscription.
                    SharedState(\.isNetworkActivityOccurring)
                        .projectedValue
                        .changes
                        .dropFirst()
                ) { .isVisibleChanged($0) }
                .observing(
                    SharedState(\.networkHealth)
                        .projectedValue
                        .changes
                ) { _ in .healthChanged }
        )
    }

    // MARK: - View

    var body: some View {
        Button {
            viewModel.send(.indicatorTapped)
        } label: {
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
        }
        .allowsHitTesting(viewModel.allowsHitTesting)
        .buttonStyle(.plain)
        .offset(y: viewModel.yOffset)
        .opacity(viewModel.isVisible ? 1 : 0)
        .animation(.spring(), value: viewModel.yOffset)
    }
}
