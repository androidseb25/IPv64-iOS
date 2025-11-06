//
//  UserEditView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 25.10.25.
//

import SwiftUI
import WidgetKit

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
                Section("Widgets") {
                    Toggle("Use this User for the Widgets", isOn: Binding(get: { UserStorage.shared.ApiKeyWidget == self.user.ApiKey }, set: {
                        if ($0) {
                            UserStorage.shared.ApiKeyWidget = self.user.ApiKey
                            Task {
                                _ = try? await ClearHealthCheckCacheIntent().perform()
                                ClearHealthCheckCacheIntent().setApiKey(self.user.ApiKey)
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                        }
                    })).disabled(UserStorage.shared.ApiKeyWidget == self.user.ApiKey)
                    Button("Force Refresh") {
                        WidgetCenter.shared.reloadTimelines(ofKind: "HealthcheckSmallWidget")
                        WidgetCenter.shared.reloadTimelines(ofKind: "HealthcheckMediumWidget")
                        WidgetCenter.shared.reloadTimelines(ofKind: "HealthcheckLargeWidget")
                    }
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
