//
//  Extensions.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import SwiftUI

extension View {
    func showLoading(_ showLoading: Binding<Bool>) -> some View {
        modifier(LoadingViewModifier(showLoading: showLoading))
    }
    
    @available(iOS 26, *)
    func setColorGradient(_ color: Color) -> some View {
        modifier(ColorGradientModifier(color: color))
    }
}
