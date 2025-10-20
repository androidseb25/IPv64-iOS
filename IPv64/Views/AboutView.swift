//
//  AboutView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct AboutView: View {
    
    @Binding var popToRootTab: Tabs
    
    var body: some View {
        Text("About View")
    }
}

#Preview {
    AboutView(popToRootTab: .constant(.domain))
}
