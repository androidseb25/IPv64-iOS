//
//  UserView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 22.10.25.
//

import SwiftUI

struct UserView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    
    @State private var user: User = .empty
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    //                    if #available(iOS 26.0, *) {
                    ForEach(user.list, id: \.uuid) { u in
                        UserItemView(user: u)
                    }
                    //                    } else {
                    //                        LazyVStack {
                    //                            ForEach(selectedCRS, id: \.name) { crs in
                    //                                ServerItemView(crs: crs)
                    //                            }
                    //                        }
                    //                        .padding(.top, 10)
                    //                    }
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity)
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    NavigationLink(destination: LoginView(isFromAddUser: true).onDisappear {
                        withAnimation {
//                            dismiss()
                        }
                    }, label: {
                        Label("Add", systemImage: "person.badge.plus")
                    })
                    .tint(.orange)
                }
            }
        }
    }
}


#Preview {
    NavigationStack {
        UserView()
    }
}
