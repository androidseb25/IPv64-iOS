//
//  MyIpView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct MyIpView: View {
    
    @Binding var popToRootTab: Tabs
    
    @StateObject private var api = ApiService()
    @State var v4: MyIP = .emptyV4
    @State var v6: MyIP = .emptyV6
    
    var body: some View {
        if #available(iOS 26.0, *) {
            listView
                .setColorGradient(.orange)
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List {
            Section("IPv4") {
                Text(v4.ip ?? "0.0.0.0")
                    .swipeActions {
                        Button {
                            UIPasteboard.general.string = v4.ip ?? "0.0.0.0"
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Copy", systemImage: "document.on.document")
                        }
                        .tint(.blue)
                    }
            }
            Section("IPv6") {
                Text(v6.ip ?? "::")
                    .swipeActions {
                        Button {
                            UIPasteboard.general.string = v6.ip ?? "::"
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Copy", systemImage: "document.on.document")
                        }
                        .tint(.blue)
                    }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.myip.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let resv4 = await api.GetMyIp() {
                v4 = resv4
            }
            if let resv6 = await api.GetMyIp(false) {
                v6 = resv6
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyIpView(popToRootTab: .constant(.domain))
    }
}
