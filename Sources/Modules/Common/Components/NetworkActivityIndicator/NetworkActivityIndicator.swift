//
//  NetworkActivityIndicator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

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
            .foregroundStyle(Color.accent)
            .padding(.all, Floats.padding)
            .frame(
                width: Floats.frameWidth,
                height: Floats.frameHeight
            )
            .overlay {
                ProgressView()
                    .dynamicTypeSize(.large)
                    .tint(Colors.progressViewTint)
            }
            .offset(y: viewModel.yOffset)
            .opacity(viewModel.isVisible ? 1 : 0)
            .animation(.spring(), value: viewModel.yOffset)
    }
}
