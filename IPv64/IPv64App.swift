//
//  IPv64App.swift
//  IPv64
//
//  Created by Sebastian Rank on 18.10.25.
//

import SwiftUI
import TipKit

@main
struct IPv64App: App {
    init() {
        
        /// Load and configure the state of all the tips of the app
        try? Tips.configure()
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Large Title (z. B. auf Listenansichten)
        let largeDesc = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.rounded) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        appearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: largeDesc, size: 0) // 0 = system size aus Descriptor (Dynamic Type)
        ]
        
        // Inline Title (z. B. Detailansichten)
        let inlineDesc = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .headline)
            .withDesign(.rounded) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        appearance.titleTextAttributes = [
            .font: UIFont(descriptor: inlineDesc, size: 0)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UserStorage.shared.IsInitDomain = true
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .fontDesign(.rounded)
        }
    }
}
