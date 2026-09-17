//
//  DomainDnsNewView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 25.10.25.
//

import SwiftUI

struct DomainDnsNewView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var isChanged: Bool
    @State var fqdn: String
    
    @StateObject private var api = ApiService()
    
    @State private var selectedRecordType: String = "".v64DnsRecordTypes().first!
    @State private var praefix: String = ""
    @State private var content: String = ""
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Praefix") {
                    TextField("eg.: dkim._domainkey", text: $praefix)
                        .lineLimit(1)
                        .textInputAutocapitalization(.never)   // 👈 verhindert Großschreibung
                        .autocorrectionDisabled(true)
                }
                Section("Record Type") {
                    Picker(selection: $selectedRecordType, label: Text("Record Type")
                        .font(.system(.callout))
                        .padding(.horizontal, 5)) {
                            ForEach("".v64DnsRecordTypes(), id: \.self) { type in
                                Text(type)
                                    .tag(type)
                            }
                        }
                }
                Section("Content") {
                    TextField("eg.: IP, TXT record", text: $content)
                        .lineLimit(1)
                        .textInputAutocapitalization(.never)   // 👈 verhindert Großschreibung
                        .autocorrectionDisabled(true)
                }
            }
            .navigationTitle(Text("New DNS Record"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem{
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm, action: {
                            PostDNSRecord()
                        }) {
                            Label("Save", systemImage: "paperplane")
                        }
                        .tint(.orange)
                        .disabled(praefix.isEmpty || content.isEmpty)
                    } else {
                        Button(action: {
                            PostDNSRecord()
                        }) {
                            Label("Save", systemImage: "paperplane")
                        }
                        .tint(.orange)
                        .disabled(praefix.isEmpty || content.isEmpty)
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
                return Alert(title: Text("Successfully created!"), message: Text("Your DNS Record has been created."), dismissButton: .cancel(Text("OK")) {
                    isChanged = true
                    dismiss()
                })
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func PostDNSRecord() {
        Task {
            let praefixNew = praefix.lowercased()
            if let res = await api.PostDNSRecord(domain: fqdn, praefix: praefixNew, typ: selectedRecordType, content: content) {
                if (!res.status.contains("201")) {
                    apiErrorMessage = res.status
                    alertType = .apiError
                } else {
                    alertType = .apiSuccess
                }
            }
        }
    }
}

#Preview {
    DomainDnsNewView(isChanged: .constant(false), fqdn: "")
}
