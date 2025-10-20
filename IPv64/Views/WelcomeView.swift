//
//  WelcomeView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var userStorage = UserStorage.shared
    
    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .setColorGradient(.orange)
        } else {
            content
        }
    }
    
    private var content: some View {
        return VStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    Image(uiImage: UIImage(named: "v64-logo") ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84)
                        .padding(.bottom)
                    
                    Text("Welcome to")
                        .fontDesign(.rounded)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("IPv64.net")
                        .foregroundStyle(.orange)
                        .fontDesign(.rounded)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("The App for the Free DynDNS2 Service from Dennis Schröder")
                        .fontDesign(.rounded)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity)
                Spacer()
                
                Spacer()
                
                if #available(iOS 26.0, *) {
                    letsgoBtn
                        .glassEffect(.regular.tint(.orange).interactive(true))
                } else {
                    letsgoBtn
                        .background(RoundedRectangle(cornerRadius: 24).fill(.orange))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var letsgoBtn: some View {
        return Button (action: {
            withAnimation {
                userStorage.ShowWelcomeView = false
                userStorage.ShowLoginView = true
            }
        }) {
            Text("Let's go!")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(16)
        }
    }
}

#Preview {
    WelcomeView()
}
