//
//  LoggerViewDetail.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.25.
//

import SwiftUI

struct LoggerViewDetail: View {
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @State var selectedLog: String
    
    @State private var log = ""
    
    var body: some View {
        VStack {
            if #available(iOS 26.0, *) {
                content
                    .setColorGradient(.orange)
            } else {
                content
            }
        }
        .showLoading(.constant(log.isEmpty))
        .navigationTitle(selectedLog)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    UIPasteboard.general.string = log
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }) {
                    Label("Copy log", systemImage: "doc.on.doc")
                }
                .tint(colorScheme == .dark ? .white : .black)
            }
        })
        .task {
            log = await iLogger.readLogFile(log: selectedLog)
        }
    }
    
    private var content: some View {
        return ScrollView {
            LazyVStack {
                Text(log)
                    .font(.callout)
                    .padding()
            }
        }
    }
}

#Preview {
    LoggerViewDetail(selectedLog: "test.log")
}
