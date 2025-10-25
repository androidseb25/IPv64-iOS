//
//  UserEditView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 25.10.25.
//

import SwiftUI

struct UserEditView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var user: User
    
    var body: some View {
        NavigationStack {
            List {
                Section("Username") {
                    TextField("Username", text: $user.Username)
                }
                Section("Information") {
                    TextField("Information", text: $user.Information)
                }
            }
            .navigationTitle(Text("Edit User"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        user.update()
                        dismiss()
                    }, label: {
                        Label("Save", systemImage: "checkmark")
                    })
                }
            }
        }
    }
}

#Preview {
    UserEditView(user: .constant(User(Username: "Default User", ApiKey: "", Information: "")))
}
