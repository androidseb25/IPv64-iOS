//
//  LoadingView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//


import SwiftUI

struct LoadingView: View {
    
    @State var blurRadius = CGFloat(5)
    @State var bgOpacity = CGFloat(0.9)
    @State var spinnerColor: UIColor = .systemOrange
    @State var message: String = "Loading..."
    
    var body: some View {
        VStack {
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.gray.opacity(bgOpacity))
        .blur(radius: blurRadius, opaque: false)
        .overlay {
            VStack {
                Spinner(isAnimating: true, style: .large, color: spinnerColor)
                Text(message)
                    .fontDesign(.rounded)
                    .font(.title3)
                    .fontWeight(.medium)
                    .padding(.top, 5)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .showLoading(.constant(true))
}
