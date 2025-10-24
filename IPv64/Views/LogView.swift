//
//  LogView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct LogView: View {
    
    @Binding var popToRootTab: Tabs
    
    @StateObject private var api = ApiService()
    @State var logs: Logs = .empty
    
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
            LazyVStack(spacing: 10) {
                if (logs.logs.isEmpty) {
                    Text("No logs found!")
                } else {
                    ForEach(logs.logs, id: \.id) { log in
                        LogItemView(log: log)
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.log.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let res = await api.GetLogs() {
                logs = res
                print(logs)
            }
        }
    }
}

#Preview {
    NavigationStack {
        var logs: Logs = .empty
        LogView(popToRootTab: .constant(.domain), logs: logs)
    }
}
