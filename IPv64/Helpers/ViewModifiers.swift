//
//  ViewModifiers.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import SwiftUI

struct LoadingViewModifier: ViewModifier {
    @Binding var showLoading: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if showLoading {
                    LoadingView(blurRadius: 0, bgOpacity: 0.4)
                        .zIndex(10)
                }
            }
            .allowsHitTesting(true)
    }
}

struct ColorGradientModifier: ViewModifier {
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(ColorGradient(color: color))
    }
}
