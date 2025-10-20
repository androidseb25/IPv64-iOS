//
//  AccountView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct AccountView: View {
    
    @Binding var popToRootTab: Tabs
    
    var body: some View {
        Text("Account View")
    }
}

#Preview {
    AccountView(popToRootTab: .constant(.domain))
}
