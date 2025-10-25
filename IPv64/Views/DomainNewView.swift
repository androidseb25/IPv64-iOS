//
//  DomainNewView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 25.10.25.
//

import SwiftUI

struct DomainNewView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var isChanged: Bool
    
    @StateObject private var api = ApiService()
    
    @State private var selectedDomain: String = "".v64domains().first!
    @State private var subdomain: String = ""
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Subdomain") {
                    TextField("eg.: homelab01", text: $subdomain)
                        .lineLimit(1)
                        .textInputAutocapitalization(.never)   // 👈 verhindert Großschreibung
                        .autocorrectionDisabled(true)
                }
                Section("Domain") {
                    Picker(selection: $selectedDomain, label: Text("Domain")
                        .font(.system(.callout))
                        .padding(.horizontal, 5)) {
                            ForEach("".v64domains(), id: \.self) { domain in
                                Text(domain)
                                    .tag(domain)
                            }
                        }
                }
            }
            .navigationTitle(Text("New Domain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem{
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm, action: {
                            PostDomain()
                        }) {
                            Label("Save", systemImage: "paperplane")
                        }
                        .tint(.orange)
                        .disabled(subdomain.isEmpty)
                    } else {
                        Button(action: {
                            PostDomain()
                        }) {
                            Label("Save", systemImage: "paperplane")
                        }
                        .tint(.orange)
                        .disabled(subdomain.isEmpty)
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .alert(item: $alertType) { type in
            switch type {
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            case .apiSuccess:
                return Alert(title: Text("Successfully created!"), message: Text("Your domain has been created."), dismissButton: .cancel(Text("OK")) {
                    isChanged = true
                    dismiss()
                })
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func PostDomain() {
        Task {
            let domain = "\(subdomain).\(selectedDomain)".lowercased().replacingOccurrences(of: "[^a-z0-9.-]", with: "", options: .regularExpression)
            if let res = await api.PostDomain(domain: domain) {
                if (!res.status.contains("201")) {
                    apiErrorMessage = res.add_domain ?? ""
                    alertType = .apiError
                } else {
                    alertType = .apiSuccess
                }
            }
        }
    }
}

#Preview {
    DomainNewView(isChanged: .constant(false))
}
