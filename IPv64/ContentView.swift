//
//  ContentView.swift
//  IPv64
//
//  Created by Sebastian Rank on 18.10.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userStorage = UserStorage.shared
    
    var body: some View {
        if (userStorage.ShowWelcomeView) {
            WelcomeView()
        } else if userStorage.ShowLoginView || userStorage.ApiKey.isEmpty {
            NavigationStack {
                LoginView()
            }
        } else {
            if #available(iOS 26.0, *) {
                TabbarView()
                    .tint(.orange)
            } else {
                TabbarView18()
                    .tint(.orange)
            }
        }
    }
}

#Preview {
    ContentView()
}
