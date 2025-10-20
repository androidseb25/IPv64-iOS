//
//  LogView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct LogView: View {
    
    @Binding var popToRootTab: Tabs
    
    var body: some View {
        Text("Log View")
    }
}

#Preview {
    LogView(popToRootTab: .constant(.domain))
}
