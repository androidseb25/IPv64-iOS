//
//  NoConnectionView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 03.11.25.
//

import SwiftUI

struct NoConnectionView: View {
    
    var body: some View {
        VStack {
            Image(systemName: "wifi.slash")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
                .font(.largeTitle)
            
            Text("No internet connection")
                .fontDesign(.rounded)
                .padding(.top)
                .font(.title3)
                .fontWeight(.bold)
            
            Text("The network connection appears to be offline. \nPlease check your connection.")
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .padding(.vertical)
        }
        .padding(.horizontal)
    }
}

#Preview {
    NoConnectionView()
}
