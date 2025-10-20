//
//  MyIpView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct MyIpView: View {
    
    @Binding var popToRootTab: Tabs
    
    var body: some View {
        Text("My IP")
    }
}

#Preview {
    MyIpView(popToRootTab: .constant(.domain))
}
