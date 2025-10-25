//
//  DomainDetailView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 25.10.25.
//

import SwiftUI

struct DomainDetailView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) var dismiss
    
    @State var domain: Domain
    @Binding var isChanged: Bool
    
    @StateObject private var api = ApiService()
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    @State private var selectedRecord: RecordInfos?
    @State private var showNewDnsSheet: Bool = false
    @State private var isDnsAdded: Bool = false
    
    var body: some View {
        if #available(iOS 26.0, *) {
            listView
                .setColorGradient(showNewDnsSheet ? .clear : .orange)
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List {
            if ((!domain.isSameTypeAAddress && domain.ipv4 != "0.0.0.0") || (!domain.isSameTypeAAAAAddress && domain.ipv6 != "::")) {
                Section("Notice") {
                    VStack {
                        Text("Your A or AAAA record doesn't match your current IP! This could be due to an active cellular connection or the IP address being assigned a server address.")
                    }
                    Button(action: {
                        withAnimation {
                            alertType = .updateAlert
                        }
                    }) {
                        if (!domain.isSameTypeAAddress && domain.ipv4 != "0.0.0.0") {
                            Text("Set A-Record to current IP?")
                        } else {
                            Text("Set AAAA-Record to current IP?")
                        }
                    }
                    .tint(.orange)
                }
            }
            Section("General") {
                Text("Wildcard:")
                    .badge(domain.isWildcardString)
                Text("Updates:")
                    .badge("\(domain.updates ?? 0)")
                Text("Domain Update URL")
                    .badge("swipe")
                    .swipeActions {
                        Button {
                            UIPasteboard.general.string = DomainUpdateUrl
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Copy", systemImage: "document.on.document")
                        }
                        .tint(.blue)
                    }
                    .foregroundStyle(.blue)
            }
            ForEach(domain.records, id: \.recordId) { record in
                Section(record.type ?? "") {
                    Text("Präfix:")
                        .badge(record.praefix ?? "")
                    Text("TTL:")
                        .badge(record.ttl ?? 0)
                    Text("Typ:")
                        .badge(record.type ?? "")
                    Text("Value:")
                        .badge(record.content ?? "")
                    Text("last update:")
                        .badge(record.LastUpdate)
                    Button(action: {
                        withAnimation {
                            selectedRecord = record
                            alertType = .deleteDNSAlert
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete DNS record?")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(domain.fqdn)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem {
                    Button(action: {
                        withAnimation {
                            showNewDnsSheet.toggle()
                        }
                    }){
                        Label("New DNS", systemImage: "plus")
                    }
                    .tint(systemColorScheme == .dark ? .white : .black)
                }
                ToolbarSpacer()
                ToolbarItem {
                    Button(action: {
                        withAnimation {
                            alertType = .deleteDomainAlert
                        }
                    }){
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            } else {
                ToolbarItem {
                    Button(action: {
                        withAnimation {
                            showNewDnsSheet.toggle()
                        }
                    }){
                        Label("New DNS", systemImage: "plus")
                    }
                    .tint(systemColorScheme == .dark ? .white : .black)
                }
                ToolbarItem {
                    Button(action: {
                        withAnimation {
                            alertType = .deleteDomainAlert
                        }
                    }){
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .sheet(isPresented: $showNewDnsSheet.animation()){
            DomainDnsNewView(isChanged: $isDnsAdded, fqdn: domain.fqdn).onDisappear {
                if (isDnsAdded) {
                    isDnsAdded = false
                    isChanged = true
                    dismiss()
                }
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .deleteDNSAlert:
                return Alert(
                    title: Text("Are you sure you want to delete this record?"),
                    message: Text("You can't undo this action. This will permanently delete the DNS record from your domain."),
                    primaryButton: .destructive(Text("Yes")) {
                        withAnimation {
                            DeleteDNSRecord()
                        }
                    },
                    secondaryButton: .cancel() { selectedRecord = nil }
                )
            case .deleteDomainAlert:
                return Alert(
                    title: Text("Are you sure you want to delete this domain?"),
                    message: Text("You can't undo this action. This will permanently delete your domain."),
                    primaryButton: .destructive(Text("Yes")) {
                        withAnimation {
                            DeleteDomain()
                        }
                    },
                    secondaryButton: .cancel() { selectedRecord = nil }
                )
            case .updateAlert:
                return Alert(
                    title: Text("Are you sure you want to update the DNS record?"),
                    message: Text("You can't undo this action. This will permanently change the A or AAAA DNS record from your domain."),
                    primaryButton: .destructive(Text("Yes")) {
                        withAnimation {
                            UpdateDNSRecord()
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            case .apiSuccessDelete:
                return Alert(title: Text("Successfully deleted!"), message: Text("Your record has been successfully deleted."), dismissButton: .cancel(Text("OK")) {
                    isChanged = true
                    dismiss()
                })
            case .apiSuccessUpdate:
                return Alert(title: Text("Successfully updated!"), message: Text("Your record has been successfully updated."), dismissButton: .cancel(Text("OK")) {
                    isChanged = true
                    dismiss()
                })
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private var DomainUpdateUrl: String {
        return "https://ipv64.net/nic/update?key=" + (domain.domainUpdateHash ?? "")
    }
    
    private func UpdateDNSRecord() {
        Task {
            if let res = await api.UpdateDNSRecord(urlDNSUpdate: DomainUpdateUrl) {
                withAnimation {
                    if (res.status.contains("success")) {
                        alertType = .apiSuccessUpdate
                    } else {
                        apiErrorMessage = res.info
                        alertType = .apiError
                    }
                }
            }
        }
    }
    
    private func DeleteDNSRecord() {
        Task {
            if let res = await api.DeleteDNSRecord(recordId: selectedRecord?.recordId ?? 0) {
                withAnimation {
                    if (res.status.contains("202")) {
                        alertType = .apiSuccessDelete
                    } else {
                        apiErrorMessage = res.add_domain ?? ""
                        alertType = .apiError
                    }
                }
            }
        }
    }
    
    private func DeleteDomain() {
        Task {
            if let res = await api.DeleteDomain(domain: domain.fqdn) {
                withAnimation {
                    if (res.status.contains("202")) {
                        alertType = .apiSuccessDelete
                    } else {
                        apiErrorMessage = "\(res.status) \(res.info ?? "") \n\(res.add_domain ?? "")"
                        alertType = .apiError
                        isChanged = true
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DomainDetailView(domain: Domain(updates: Optional(0), wildcard: Optional(1), domainUpdateHash: Optional("cE2179GCRmespNyALPuqaOnUIQx4MTX5"), records: [RecordInfos(recordId: Optional(442000), content: Optional("885.73.209.239"), ttl: Optional(60), type: Optional("A"), praefix: Optional(""), lastUpdate: Optional("2025-10-25 21:07:21"), recordKey: Optional("1k9mdtpb6vCeGORNVBKrHunD7LF5gqai"), deactivated: Optional(0), failoverPolicy: Optional("0"))], ipv6prefix: Optional(""), dualstack: Optional(""), deactivated: Optional(0), fqdn: "dom2.ipv64.net", ipv4: "88.73.209.239", ipv6: "::"), isChanged: .constant(false))
    }
}
