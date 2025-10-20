//
//  ColorGradient.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//


import SwiftUI

struct ColorGradient: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    var color: Color
    
    var body: some View {
        
        let opacity1: Double = systemColorScheme == .dark ? 0.4 : 0.5
        let opacity2: Double = systemColorScheme == .dark ? 0.1 : 0.2
        let opacity3: Double = systemColorScheme == .dark ? 0.05 : 0.05
        let opacity4: Double = systemColorScheme == .dark ? 0.025 : 0
        let lastColor: Color = systemColorScheme == .dark ? .clear : .gray.opacity(0.07)
        
        LinearGradient(
            colors: [
                color.opacity(opacity1), // kräftiges Grün
                color.opacity(opacity2), // kräftiges Grün
                color.opacity(opacity3), // kräftiges Grün
                color.opacity(opacity4), // kräftiges Grün
                lastColor,
                lastColor,
                lastColor,
                lastColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .background(lastColor)
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
    }
}
