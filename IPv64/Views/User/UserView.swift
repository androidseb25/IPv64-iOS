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
    @State private var selectedUser: User = .empty
    @State private var showEditUserSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(user.list, id: \.uuid) { u in
                        UserItemView(user: Binding(
                            get: { u },
                            set: { _ = $0 }   // ← schreibt zurück in die Quelle
                        ))
                        .swipeActions {
                            Button {
                                selectedUser = u
                                showEditUserSheet.toggle()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                            .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity)
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    NavigationLink(destination: LoginView(isFromAddUser: true), label: {
                        Label("Add", systemImage: "person.badge.plus")
                    })
                    .tint(.orange)
                }
            }
        }
        .sheet(isPresented: $showEditUserSheet.animation()) {
            UserEditView(user: $selectedUser).onDisappear {
                selectedUser = .empty
            }
        }
    }
}


#Preview {
    NavigationStack {
        UserView()
    }
}
