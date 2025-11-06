//
//  LoggerView.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.25.
//

import SwiftUI
import SwiftyBeaver

struct LoggerView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    
    @State var showToolbar: Bool
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedLog = ""
    @State private var showLog = false
    @State private var logFiles: [String] = []
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack {
            if #available(iOS 26.0, *) {
                listContent
                    .setColorGradient(.orange)
            } else {
                listContent
            }
        }
        .navigationDestination(isPresented: $showLog) {
            LoggerViewDetail(selectedLog: selectedLog)
        }
        .alert("Do you really delete?", isPresented: $showDeleteAlert) {
            Button("Delete now", role: .destructive) {
                Task {
                    let result = await iLogger.removeLogFile(file: selectedLog)
                    if (result) {
                        iLogger.log.info("File: \"\(selectedLog)\" successfully deleted!")
                        logFiles = await iLogger.getFileList()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete the file: \n\'\(selectedLog)\' \n\nThe file cannot be restored!")
        }
    }
    
    private var listContent: some View {
        return List {
            ForEach(logFiles, id: \.self) { file in
                Button(action: {
                    selectedLog = file
                    showLog.toggle()
                }) {
                    NavigationLink(file, value: file)
                        .foregroundStyle(systemColorScheme == .dark ? Color.white : Color.black)
                }
                .swipeActions {
                    Button(action: {
                        withAnimation {
                            selectedLog = file
                            showDeleteAlert.toggle()
                        }
                    }) {
                        Image(systemName: "trash")
                            .resizable()
                            .symbolRenderingMode(.hierarchical)
                    }
                    .tint(.red)
                }
            }
        }
        .navigationTitle(Tabs.syslog.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            if (showToolbar) {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                    }
                }
            }
        })
        .onAppear {
            Task {
                logFiles = await iLogger.getFileList()
            }
        }
    }
}

#Preview {
    LoggerView(popToRootTab: .constant(Tabs.syslog), showToolbar: false)
}
